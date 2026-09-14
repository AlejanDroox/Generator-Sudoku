extends Node
## LocalDB — Persistencia local aislada por usuario
##
## Responsabilidades:
##   - Mantener estadísticas acumuladas de la sesión actual en un archivo JSON
##     cuyo nombre incluye el ID del usuario activo → aislamiento en dispositivos compartidos.
##   - Evaluar y guardar la mejor marca histórica por configuración de juego
##     (modo + dificultad + variantes) usando la jerarquía de prioridad:
##     1. puntuacion DESC  2. tableros_completados DESC  3. tiempo ASC
##   - Al cerrar sesión: si la sincronización remota fue exitosa, eliminar el
##     archivo local del dispositivo para evitar residuos de otros jugadores.
##     Si falló (offline), conservar el archivo para subirlo en el próximo login.
##
## Uso típico (desde AuthManager):
##   LocalDB.init_profile("uuid-aqui", cloud_stats_dict)
##   LocalDB.save_game_session(...)   # después de cada partida
##   var data = LocalDB.get_full_data()  # antes de sincronizar
##   LocalDB.close_profile(sync_ok)    # al cerrar sesión

# ── Constantes ────────────────────────────────────────────────────────────────

const _SAVE_TEMPLATE: String = "user://player_stats_%s.json"

# Estructura por defecto de estadísticas acumuladas
const _DEFAULT_CUMULATIVE: Dictionary = {
	"total_partidas":            0,
	"total_tableros_completados": 0,
	"total_puntos":              0,
	"total_tiempo":              0,   # segundos acumulados
	"total_errores":             0,
	"promedio_errores":          0.0,
	"partidas_ganadas":          0
}

# ── Estado interno ─────────────────────────────────────────────────────────────

var _user_id:   String = ""
var _data:      Dictionary = {}   # { "cumulative_stats": {...}, "best_runs": {...} }

# ── Señales ────────────────────────────────────────────────────────────────────

## Emitida cuando se registra un nuevo récord en alguna configuración de juego.
signal new_record_set(config_key: String, record: Dictionary)


func _ready() -> void:
	if _user_id.is_empty():
		init_profile("guest", {})



## Inicializa el perfil del usuario que acaba de iniciar sesión.
## [param user_id]      UUID del jugador (estudiante o profesor).
## [param cloud_stats]  Diccionario con estadísticas descargadas desde Supabase.
##                      Si está vacío, se asume primera sesión o sin conexión.
func init_profile(user_id: String, cloud_stats: Dictionary) -> void:
	if user_id.is_empty():
		push_error("LocalDB.init_profile: user_id vacío.")
		return

	_user_id = user_id
	var path: String = _save_path()

	if FileAccess.file_exists(path):
		# El archivo ya existe en este dispositivo → cargar datos locales
		_load_from_disk()
	else:
		# No hay archivo local: inicializar con los datos de la nube (o defaults)
		_data = {
			"cumulative_stats": cloud_stats.get("cumulative_stats", _DEFAULT_CUMULATIVE.duplicate(true)),
			"best_runs":        cloud_stats.get("best_runs", {})
		}
		_persist()


## Cierra la sesión del usuario activo y gestiona el archivo local.
## [param sync_successful] true si la sincronización remota fue confirmada.
##   - true  → elimina el archivo local (datos seguros en la nube).
##   - false → conserva el archivo (datos guardados para la próxima sesión).
func close_profile(sync_successful: bool) -> void:
	if _user_id.is_empty():
		return

	if sync_successful:
		_delete_local_file()
	else:
		# Garantizar que el estado más reciente esté en disco antes de limpiar la RAM
		_persist()

	_user_id = ""
	_data    = {}
	init_profile("guest", {})


# ── Lectura ────────────────────────────────────────────────────────────────────

## Devuelve una copia de las estadísticas acumuladas del usuario activo.
func get_cumulative_stats() -> Dictionary:
	return _data.get("cumulative_stats", _DEFAULT_CUMULATIVE.duplicate(true))


## Devuelve la mejor marca registrada para una configuración concreta de juego.
## Devuelve un diccionario vacío si no hay marca para esa configuración.
func get_best_run(modo: String, dificultad: String, variantes: Array) -> Dictionary:
	var key: String = _build_key(modo, dificultad, variantes)
	return _data.get("best_runs", {}).get(key, {})


## Devuelve el diccionario completo { cumulative_stats, best_runs } listo para
## serializar como JSONB y enviarlo a Supabase.
func get_full_data() -> Dictionary:
	return _data.duplicate(true)


## Devuelve true si hay un perfil de usuario cargado en memoria.
func has_active_profile() -> bool:
	return not _user_id.is_empty()


# ── Escritura ──────────────────────────────────────────────────────────────────

## Registra una partida completada.
## Actualiza los acumulados y evalúa si esta partida establece un nuevo récord.
##
## [param modo]                 Identificador del modo de juego (p.ej. "samurai").
## [param dificultad]           Nivel de dificultad (p.ej. "medio").
## [param variantes]            Array de strings con las variantes activas (p.ej. ["knight"]).
## [param score]                Puntuación obtenida en la partida.
## [param tableros_completados] Número de tableros completados en la partida.
## [param tiempo_seg]           Duración de la partida en segundos (float).
## [param errores]              Número de errores cometidos.
## [param ganada]               true si la partida se considera una victoria.
##
## [return] Diccionario con { "es_nuevo_record": bool, "best_record": Dictionary }
func save_game_session(
	modo:                 String,
	dificultad:           String,
	variantes:            Array,
	score:                int,
	tableros_completados: int,
	tiempo_seg:           float,
	errores:              int,
	ganada:               bool
) -> Dictionary:
	if _user_id.is_empty():
		push_error("LocalDB.save_game_session: no hay perfil activo. Llama a init_profile primero.")
		return {}

	# -- 1. Actualizar estadísticas acumuladas ----------------------------------
	var stats: Dictionary = _data.get("cumulative_stats", _DEFAULT_CUMULATIVE.duplicate(true))

	stats["total_partidas"]             = stats.get("total_partidas", 0) + 1
	stats["total_tableros_completados"] = stats.get("total_tableros_completados", 0) + tableros_completados
	stats["total_puntos"]               = stats.get("total_puntos", 0) + score
	stats["total_tiempo"]               = stats.get("total_tiempo", 0) + int(tiempo_seg)
	stats["total_errores"]              = stats.get("total_errores", 0) + errores
	stats["partidas_ganadas"]           = stats.get("partidas_ganadas", 0) + (1 if ganada else 0)

	var total_partidas: int = stats["total_partidas"]
	var total_errores: int  = stats["total_errores"]
	stats["promedio_errores"] = float(total_errores) / float(total_partidas) if total_partidas > 0 else 0.0

	_data["cumulative_stats"] = stats

	# -- 2. Evaluar mejor partida en esta configuración ------------------------
	var key: String = _build_key(modo, dificultad, variantes)
	var best_runs      : Dictionary = _data.get("best_runs", {})
	var record_actual  : Dictionary = best_runs.get(key, {})
	var es_nuevo_record: bool       = false

	if record_actual.is_empty():
		es_nuevo_record = true
	else:
		var prev_score:     int   = record_actual.get("score", 0)
		var prev_tableros:  int   = record_actual.get("tableros_completados", 0)
		var prev_tiempo:    float = record_actual.get("tiempo_seg", INF)

		# Jerarquía de prioridad estricta
		if score > prev_score:
			es_nuevo_record = true
		elif score == prev_score:
			if tableros_completados > prev_tableros:
				es_nuevo_record = true
			elif tableros_completados == prev_tableros:
				if tiempo_seg < prev_tiempo:
					es_nuevo_record = true

	var best_record: Dictionary = record_actual
	if es_nuevo_record:
		best_record = {
			"score":                score,
			"tableros_completados": tableros_completados,
			"tiempo_seg":           snappedf(tiempo_seg, 0.01),
			"errores":              errores,
			"modo":                 modo,
			"dificultad":           dificultad,
			"variantes":            variantes,
			"date":                 Time.get_date_string_from_system()
		}
		best_runs[key]     = best_record
		_data["best_runs"] = best_runs
		new_record_set.emit(key, best_record)

	_persist()

	return {
		"es_nuevo_record": es_nuevo_record,
		"best_record":     best_record
	}


# ── Privados ───────────────────────────────────────────────────────────────────

func _save_path() -> String:
	return _SAVE_TEMPLATE % _user_id


## Construye una clave única para la combinación modo + dificultad + variantes.
## Las variantes se ordenan alfabéticamente para garantizar idempotencia.
func _build_key(modo: String, dificultad: String, variantes: Array) -> String:
	var vars_sorted: Array = variantes.duplicate()
	vars_sorted.sort()
	var vars_str: String = "_".join(vars_sorted) if not vars_sorted.is_empty() else "ninguna"
	return "%s|%s|%s" % [modo.strip_edges().to_lower(), dificultad.strip_edges().to_lower(), vars_str.to_lower()]


func _load_from_disk() -> void:
	var path: String = _save_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("LocalDB: no se pudo abrir '%s'. Se usarán datos por defecto." % path)
		_data = { "cumulative_stats": _DEFAULT_CUMULATIVE.duplicate(true), "best_runs": {} }
		return

	var raw: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		_data = parsed
		# Garantizar que las claves principales existen (migración hacia adelante)
		if not _data.has("cumulative_stats"):
			_data["cumulative_stats"] = _DEFAULT_CUMULATIVE.duplicate(true)
		if not _data.has("best_runs"):
			_data["best_runs"] = {}
	else:
		push_warning("LocalDB: el archivo '%s' está corrupto. Se reinicializará." % path)
		_data = { "cumulative_stats": _DEFAULT_CUMULATIVE.duplicate(true), "best_runs": {} }


func _persist() -> void:
	if _user_id.is_empty():
		return
	var file: FileAccess = FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("LocalDB: no se pudo escribir en '%s'." % _save_path())
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()


func _delete_local_file() -> void:
	var path: String = _save_path()
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("LocalDB: no se pudo abrir el directorio 'user://' para eliminar el archivo de perfil.")
		return
	var err: Error = dir.remove(path.get_file())
	if err != OK:
		push_error("LocalDB: fallo al eliminar '%s' (error %d)." % [path, err])
	else:
		print("LocalDB: archivo de perfil local eliminado tras sincronización exitosa → '%s'." % path)
