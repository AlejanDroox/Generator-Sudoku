extends Node2D

# ============================================================
#   TEST INTENSIVO DE GENERACIÓN DE SUDOKUS
#   Genera sudokus en múltiples configuraciones y guarda
#   estadísticas técnicas en texto plano y CSV.
# ============================================================

# --- Configuración exportable ---
@export var iteraciones_por_configuracion: int = 5
@export var dificultades_a_probar: Array[LevelConfig.DifficultyLevel] = [
	LevelConfig.DifficultyLevel.EASY,
	LevelConfig.DifficultyLevel.MEDIUM,
	LevelConfig.DifficultyLevel.HARD,
	LevelConfig.DifficultyLevel.EXTREME
]

@export var probar_variante_classic: bool = true
@export var probar_variante_antiknight: bool = true
@export var probar_variante_killer: bool = true
@export var probar_variante_thermo: bool = true
@export var probar_variante_arrow: bool = true
@export var probar_multivariante: bool = true

# --- Datos internos ---
var _registros: Array = []        # Array de Dictionary con los datos de cada prueba
var _id_prueba: int = 0

# --- Mapeo de dificultades (Enum -> Valor Objetivo del Generador) ---
var _valores_dificultad: Dictionary = {
	LevelConfig.DifficultyLevel.EASY: 2,
	LevelConfig.DifficultyLevel.MEDIUM: 15,
	LevelConfig.DifficultyLevel.HARD: 60,
	LevelConfig.DifficultyLevel.EXTREME: 150
}

# --- Nombres legibles de dificultades ---
var _nombres_dificultad: Dictionary = {
	LevelConfig.DifficultyLevel.EASY: "EASY",
	LevelConfig.DifficultyLevel.MEDIUM: "MEDIUM",
	LevelConfig.DifficultyLevel.HARD: "HARD",
	LevelConfig.DifficultyLevel.EXTREME: "EXTREME"
}

# --- Nombres legibles de variantes ---
var _nombres_variantes: Dictionary = {
	SudokuGenerator.VariantType.CLASSIC:      "CLASSIC",
	SudokuGenerator.VariantType.ANTI_KNIGHT:  "ANTI_KNIGHT",
	SudokuGenerator.VariantType.KILLER:       "KILLER",
	SudokuGenerator.VariantType.THERMO:       "THERMO",
	SudokuGenerator.VariantType.ARROW:        "ARROW"
}

func _enter_tree() -> void:
	print("=== TEST INTENSIVO: Iniciando ===")
	_ejecutar_todas_las_pruebas()
	_guardar_estadisticas()
	print("=== TEST INTENSIVO: Completado. Archivos guardados. ===")
	get_tree().quit()

# -----------------------------------------------------------
#   Construye y ejecuta la matriz de pruebas completa
# -----------------------------------------------------------
func _ejecutar_todas_las_pruebas() -> void:
	var configs_variantes: Array = []
	if probar_variante_classic:
		configs_variantes.append([SudokuGenerator.VariantType.CLASSIC])
	if probar_variante_antiknight:
		configs_variantes.append([SudokuGenerator.VariantType.ANTI_KNIGHT])
	if probar_variante_killer:
		configs_variantes.append([SudokuGenerator.VariantType.KILLER])
	if probar_variante_thermo:
		configs_variantes.append([SudokuGenerator.VariantType.THERMO])
	if probar_variante_arrow:
		configs_variantes.append([SudokuGenerator.VariantType.ARROW])
	if probar_multivariante:
		configs_variantes.append([
			SudokuGenerator.VariantType.KILLER,
			SudokuGenerator.VariantType.THERMO,
			SudokuGenerator.VariantType.ARROW
		])

	var total: int = dificultades_a_probar.size() * configs_variantes.size() * iteraciones_por_configuracion
	var progreso: int = 0

	for dif_level in dificultades_a_probar:
		var dif_label: String = _nombres_dificultad.get(dif_level, "UNKNOWN")
		var dif_val: int = _valores_dificultad.get(dif_level, 15)
		for variantes in configs_variantes:
			for i in range(iteraciones_por_configuracion):
				progreso += 1
				print("[", progreso, "/", total, "] Nivel=", dif_label, " (", dif_val, ") Variantes=", _variantes_a_texto(variantes), " iter=", i + 1)
				_ejecutar_prueba(dif_label, dif_val, variantes)

# -----------------------------------------------------------
#   Ejecuta una sola prueba y guarda sus métricas
# -----------------------------------------------------------
func _ejecutar_prueba(dif_label: String, dif_objetivo: int, variantes: Array) -> void:
	var generator: SudokuGenerator = SudokuGenerator.new()
	var t_inicio: int = Time.get_ticks_usec()

	var datos_nivel: Dictionary = generator.create_level({}, dif_objetivo, variantes)

	var t_total_us: int = Time.get_ticks_usec() - t_inicio
	var t_ms: float = float(t_total_us) / 1000.0

	var puzzle: Dictionary = datos_nivel.get("puzzle", {})
	var num_pistas: int = _contar_pistas(puzzle)

	_id_prueba += 1
	var registro: Dictionary = {
		"id":              _id_prueba,
		"dif_label":       dif_label,
		"dif_objetivo":    dif_objetivo,
		"dif_real":        datos_nivel.get("difficulty", -1),
		"num_pistas":      num_pistas,
		"variantes":       _variantes_a_texto(datos_nivel.get("variants", variantes)),
		"tiempo_ms":       t_ms,
		"intentos":        datos_nivel.get("attempts", -1),
		"fallback":        datos_nivel.get("fallback", false)
	}
	_registros.append(registro)

# -----------------------------------------------------------
#   Cuenta las celdas con valor > 0 (pistas visibles al jugador)
# -----------------------------------------------------------
func _contar_pistas(puzzle: Dictionary) -> int:
	var count: int = 0
	for v in puzzle.values():
		if v != 0:
			count += 1
	return count

# -----------------------------------------------------------
#   Convierte un array de VariantType a texto legible
# -----------------------------------------------------------
func _variantes_a_texto(variantes: Array) -> String:
	var nombres: Array = []
	for v in variantes:
		if _nombres_variantes.has(v):
			nombres.append(_nombres_variantes[v])
		else:
			nombres.append("UNKNOWN(" + str(v) + ")")
	return "+".join(nombres)

# -----------------------------------------------------------
#   Agrupación de registros para calcular estadísticas
# -----------------------------------------------------------
func _agrupar_por_clave(clave: String) -> Dictionary:
	var grupos: Dictionary = {}
	for r in _registros:
		var k: String = str(r[clave])
		if not grupos.has(k):
			grupos[k] = []
		grupos[k].append(r)
	return grupos

func _media_campo(lista: Array, campo: String) -> float:
	if lista.is_empty():
		return 0.0
	var suma: float = 0.0
	for r in lista:
		suma += float(r[campo])
	return suma / float(lista.size())

func _min_campo(lista: Array, campo: String) -> float:
	if lista.is_empty():
		return 0.0
	var m: float = float(lista[0][campo])
	for r in lista:
		if float(r[campo]) < m:
			m = float(r[campo])
	return m

func _max_campo(lista: Array, campo: String) -> float:
	if lista.is_empty():
		return 0.0
	var m: float = float(lista[0][campo])
	for r in lista:
		if float(r[campo]) > m:
			m = float(r[campo])
	return m

func _contar_fallbacks(lista: Array) -> int:
	var c: int = 0
	for r in lista:
		if r["fallback"]:
			c += 1
	return c

# -----------------------------------------------------------
#   Guarda los dos archivos de estadísticas
# -----------------------------------------------------------
func _guardar_estadisticas() -> void:
	_guardar_csv()
	_guardar_reporte_txt()

func _guardar_csv() -> void:
	var ruta: String = "res://generator_stats_raw.csv"
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_error("TEST: No se pudo abrir " + ruta)
		return

	# Cabecera
	f.store_line("id,dificultad_nivel,dif_objetivo,dif_real,num_pistas,variantes,tiempo_ms,intentos,fallback")

	# Filas
	for r in _registros:
		var fallback_str: String = "SI" if r["fallback"] else "NO"
		var linea: String = (
			str(r["id"]) + "," +
			str(r["dif_label"]) + "," +
			str(r["dif_objetivo"]) + "," +
			str(r["dif_real"]) + "," +
			str(r["num_pistas"]) + "," +
			str(r["variantes"]) + "," +
			("%.2f" % r["tiempo_ms"]) + "," +
			str(r["intentos"]) + "," +
			fallback_str
		)
		f.store_line(linea)

	f.close()
	print("CSV guardado en: ", ruta)

func _guardar_reporte_txt() -> void:
	var ruta: String = "res://generator_stats_report.txt"
	var f: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		push_error("TEST: No se pudo abrir " + ruta)
		return

	var timestamp: String = Time.get_datetime_string_from_system()
	var separador: String = "=" .repeat(70)
	var sep_sec: String = "-".repeat(70)

	f.store_line(separador)
	f.store_line("  REPORTE DE PRUEBAS INTENSIVAS — GENERADOR DE SUDOKUS")
	f.store_line("  Fecha: " + timestamp)
	f.store_line("  Total de pruebas ejecutadas: " + str(_registros.size()))
	f.store_line("  Iteraciones por configuracion: " + str(iteraciones_por_configuracion))
	f.store_line(separador)
	f.store_line("")

	# --- SECCIÓN 1: RESUMEN POR DIFICULTAD ---
	f.store_line("SECCION 1: RESUMEN POR NIVEL DE DIFICULTAD")
	f.store_line(sep_sec)
	var por_dif: Dictionary = _agrupar_por_clave("dif_label")
	var claves_dif: Array = por_dif.keys()
	# Ordenación personalizada para que aparezcan EASY -> MEDIUM -> HARD -> EXTREME
	var orden_difs: Dictionary = {"EASY": 0, "MEDIUM": 1, "HARD": 2, "EXTREME": 3}
	claves_dif.sort_custom(func(a, b): return orden_difs.get(a, 99) < orden_difs.get(b, 99))
	
	f.store_line(_col("Nivel", 12) + _col("N", 6) + _col("Dif.Real(avg)", 15) + _col("Pistas(avg)", 13) + _col("T.ms(avg)", 12) + _col("T.ms(min)", 12) + _col("T.ms(max)", 12) + _col("Intentos(avg)", 14) + "Fallbacks")
	f.store_line(sep_sec)
	for k in claves_dif:
		var g: Array = por_dif[k]
		var linea: String = (
			_col(k, 12) +
			_col(str(g.size()), 6) +
			_col("%.1f" % _media_campo(g, "dif_real"), 15) +
			_col("%.1f" % _media_campo(g, "num_pistas"), 13) +
			_col("%.1f" % _media_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _min_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _max_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _media_campo(g, "intentos"), 14) +
			str(_contar_fallbacks(g))
		)
		f.store_line(linea)
	f.store_line("")

	# --- SECCIÓN 2: RESUMEN POR VARIANTE ---
	f.store_line("SECCION 2: RESUMEN POR VARIANTE")
	f.store_line(sep_sec)
	var por_var: Dictionary = _agrupar_por_clave("variantes")
	var claves_var: Array = por_var.keys()
	claves_var.sort()
	f.store_line(_col("Variantes", 32) + _col("N", 6) + _col("Pistas(avg)", 13) + _col("T.ms(avg)", 12) + _col("T.ms(min)", 12) + _col("T.ms(max)", 12) + _col("Intentos(avg)", 14) + "Fallbacks")
	f.store_line(sep_sec)
	for k in claves_var:
		var g: Array = por_var[k]
		var linea: String = (
			_col(k, 32) +
			_col(str(g.size()), 6) +
			_col("%.1f" % _media_campo(g, "num_pistas"), 13) +
			_col("%.1f" % _media_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _min_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _max_campo(g, "tiempo_ms"), 12) +
			_col("%.1f" % _media_campo(g, "intentos"), 14) +
			str(_contar_fallbacks(g))
		)
		f.store_line(linea)
	f.store_line("")

	# --- SECCIÓN 3: DATOS CRUDOS ---
	f.store_line("SECCION 3: DATOS INDIVIDUALES")
	f.store_line(sep_sec)
	f.store_line(_col("ID", 6) + _col("Nivel", 10) + _col("DifObj", 8) + _col("DifReal", 9) + _col("Pistas", 8) + _col("T.ms", 10) + _col("Intentos", 10) + _col("Fallback", 10) + "Variantes")
	f.store_line(sep_sec)
	for r in _registros:
		var fallback_str: String = "SI" if r["fallback"] else "NO"
		var linea: String = (
			_col(str(r["id"]), 6) +
			_col(r["dif_label"], 10) +
			_col(str(r["dif_objetivo"]), 8) +
			_col(str(r["dif_real"]), 9) +
			_col(str(r["num_pistas"]), 8) +
			_col("%.2f" % r["tiempo_ms"], 10) +
			_col(str(r["intentos"]), 10) +
			_col(fallback_str, 10) +
			str(r["variantes"])
		)
		f.store_line(linea)

	f.store_line("")
	f.store_line(separador)
	f.store_line("  FIN DEL REPORTE")
	f.store_line(separador)
	f.close()
	print("Reporte TXT guardado en: ", ruta)

# -----------------------------------------------------------
#   Utilidad: rellena/recorta un texto para alinear columnas
# -----------------------------------------------------------
func _col(texto: String, ancho: int) -> String:
	var s: String = str(texto)
	if s.length() >= ancho:
		return s.left(ancho - 1) + " "
	return s + " ".repeat(ancho - s.length())
