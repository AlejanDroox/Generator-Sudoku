extends Node
## AuthManager — Gestor central de sesión (Autoload)
##
## Es el único punto de entrada para autenticación de los tres roles:
##   - Institución  → login/logout via Supabase Auth (email + password)
##   - Profesor     → login/logout via Supabase Auth + cambio de contraseña obligatorio
##   - Estudiante   → login/logout via RPC personalizada (usuario + PIN numérico)
##
## Coordina con:
##   - RemoteDB  → peticiones HTTP a Supabase
##   - LocalDB   → inicialización del perfil local al loguearse y limpieza al salir
##
## Consultas de estado:
##   AuthManager.session_type  → "none" | "student" | "teacher" | "institution"
##   AuthManager.is_logged_in  → bool
##   AuthManager.user_id       → UUID del usuario activo (String)
##   AuthManager.user_name     → Nombre del usuario activo
##   AuthManager.group_id      → grupo_id del estudiante (vacío para otros roles)
##   AuthManager.needs_password_change → true si el profesor debe cambiar contraseña


# ── Señales Públicas ──────────────────────────────────────────────────────────

## Emitida cuando cualquier login es exitoso.
## [param session_type] "student" | "teacher" | "institution"
signal login_success(session_type: String)

## Emitida cuando cualquier login falla.
## [param reason] Mensaje de error legible para mostrar en UI.
signal login_failed(reason: String)

## Emitida cuando el logout completa (incluye sincronización y limpieza local).
signal logout_complete()

## Emitida cuando el profesor necesita cambiar su contraseña antes de continuar.
signal password_change_required()

## Emitida cuando el cambio de contraseña del profesor se realiza con éxito.
signal password_changed()

## Emitida cuando una sincronización manual de estadísticas se completa.
## [param success] true = datos guardados en nube; false = falló (offline u otro error)
signal sync_complete(success: bool)


# ── Estado de Sesión ──────────────────────────────────────────────────────────

## Tipo de sesión activa. "none" si no hay nadie logueado.
var session_type: String = "none"

## UUID del usuario activo (estudiante, profesor o institución).
var user_id: String = ""

## Nombre para mostrar del usuario activo.
var user_name: String = ""

## grupo_id del estudiante activo (vacío para profesores e instituciones).
var group_id: String = ""

## Token de sesión del estudiante (UUID). Vacío para otros roles.
## Este token debe enviarse como cabecera 'x-student-token' en llamadas RLS.
var student_session_token: String = ""

## true si el profesor logueado debe cambiar su contraseña antes de jugar.
var needs_password_change: bool = false

## true si hay un usuario logueado de cualquier tipo.
var is_logged_in: bool = false

# ── Límite de Intentos y Fuerza Bruta Local ────────────────────────────────────
const LOCKOUT_CFG_PATH: String = "user://auth_lockouts.cfg"
const MAX_ATTEMPTS: int = 5
const LOCKOUT_DURATION_SEC: int = 60

var _local_attempts: Dictionary = {}


# ── Login — Estudiante ─────────────────────────────────────────────────────────

## Autentica a un estudiante mediante usuario y PIN numérico.
## Llama a la función RPC de Supabase 'login_estudiante'.
## Al tener éxito: inicializa LocalDB con los datos de la nube.
##
## [param p_usuario] Nombre de usuario único del estudiante.
## [param p_pin]     PIN numérico de exactamente 6 dígitos.
func login_student(p_usuario: String, p_pin: String) -> void:
	if is_logged_in:
		push_warning("AuthManager.login_student: ya hay una sesión activa. Ciérrala antes de iniciar otra.")
		return

	# Validación de formato de PIN en el cliente antes de enviar la petición
	if not p_pin.is_valid_int() or p_pin.length() != 6:
		login_failed.emit("El PIN debe ser un número de exactamente 6 dígitos.")
		return

	# Verificar bloqueo local antes de llamar a la API
	var key: String = "student_" + p_usuario.to_lower()
	var remaining_sec: int = _check_lockout(key)
	if remaining_sec > 0:
		login_failed.emit("Demasiados intentos incorrectos. Bloqueado por %d segundos." % remaining_sec)
		return

	var result: Dictionary = await RemoteDB.rpc_login_student(p_usuario, p_pin)

	if not result.get("success", false):
		var err_msg: String = result.get("error", "Credenciales incorrectas.")
		
		# Verificar si es error de conexión/red
		var is_network_error: bool = false
		var err_lower = err_msg.to_lower()
		if "conexion" in err_lower or "conexión" in err_lower or "connect" in err_lower or "network" in err_lower or "offline" in err_lower:
			is_network_error = true
		
		if "bloqueada" in err_msg or "Demasiados intentos" in err_msg or "bloqueado" in err_msg:
			# Si el servidor indica que la cuenta ya está bloqueada
			_save_lockout_until(key, Time.get_unix_time_from_system() + LOCKOUT_DURATION_SEC)
			_local_attempts[key] = 0
			login_failed.emit(err_msg)
		elif not is_network_error:
			# Registrar el fallo localmente (decrementa los intentos restantes y bloquea si llega al máximo)
			var msg: String = _register_failure(key)
			login_failed.emit(msg)
		else:
			login_failed.emit(err_msg)
		return

	# Limpiar intentos al tener éxito
	_clear_lockout(key)
	_local_attempts.erase(key)

	# Establecer estado de sesión
	session_type          = "student"
	user_id               = result.get("student_id", "")
	user_name             = result.get("usuario", "")
	group_id              = result.get("grupo_id", "")
	student_session_token = result.get("session_token", "")
	is_logged_in          = true

	# Inicializar el perfil local con las estadísticas descargadas de la nube
	var cloud_stats: Dictionary = result.get("estadisticas", {})
	LocalDB.init_profile(user_id, cloud_stats)

	login_success.emit("student")


# ── Login — Profesor / Institución ────────────────────────────────────────────

## Autentica a un profesor o institución mediante email y contraseña.
## Usa el endpoint nativo de Supabase Auth.
## Si el metadato 'temp_password' es true, emite [signal password_change_required].
##
## [param p_email]    Correo electrónico registrado en Supabase Auth.
## [param p_password] Contraseña del usuario.
func login_staff(p_email: String, p_password: String) -> void:
	if is_logged_in:
		push_warning("AuthManager.login_staff: ya hay una sesión activa. Ciérrala antes de iniciar otra.")
		return

	# Verificar bloqueo local antes de llamar a la API
	var key: String = "staff_" + p_email.to_lower()
	var remaining_sec: int = _check_lockout(key)
	if remaining_sec > 0:
		login_failed.emit("Demasiados intentos incorrectos. Bloqueado por %d segundos." % remaining_sec)
		return

	var result: Dictionary = await RemoteDB.auth_sign_in(p_email, p_password)

	if not result.get("success", false):
		var server_error: String = result.get("error", "Credenciales incorrectas.")
		
		# Verificar si es error de conexión/red
		var is_network_error: bool = false
		var err_lower = server_error.to_lower()
		if "conexion" in err_lower or "conexión" in err_lower or "connect" in err_lower or "network" in err_lower or "offline" in err_lower:
			is_network_error = true
			
		if not is_network_error:
			var msg: String = _register_failure(key)
			login_failed.emit(msg)
		else:
			login_failed.emit(server_error)
		return

	# Limpiar intentos al tener éxito
	_clear_lockout(key)
	_local_attempts.erase(key)

	var rol: String = (result.get("rol", "") as String).to_lower().strip_edges()
	session_type = "institution" if (rol == "institucion" or rol == "institución" or rol == "institution") else "teacher"
	user_id      = result.get("user_id", "")
	user_name    = result.get("nombre", p_email)
	is_logged_in = true

	# Detectar si el profesor tiene contraseña temporal pendiente de cambio
	needs_password_change = result.get("temp_password", false)

	# Inicializar perfil local con estadísticas en nube (solo relevante para profesores)
	if session_type == "teacher":
		var cloud_stats: Dictionary = result.get("estadisticas", {})
		LocalDB.init_profile(user_id, cloud_stats)

	login_success.emit(session_type)

	if needs_password_change:
		password_change_required.emit()


# ── Cambio de Contraseña (Primer Login de Profesor) ───────────────────────────

## Cambia la contraseña temporal del profesor y desbloquea el acceso completo.
## Solo válido cuando [member needs_password_change] es true.
##
## [param p_nueva_password] Nueva contraseña definitiva del profesor.
func change_teacher_password(p_nueva_password: String) -> void:
	if session_type != "teacher" or not needs_password_change:
		push_warning("AuthManager.change_teacher_password: no aplica en la sesión actual.")
		return

	if p_nueva_password.length() < 8:
		login_failed.emit("La contraseña debe tener al menos 8 caracteres.")
		return

	var ok: bool = await RemoteDB.rpc_change_teacher_password(p_nueva_password)

	if ok:
		needs_password_change = false
		password_changed.emit()
	else:
		login_failed.emit("No se pudo cambiar la contraseña. Inténtalo de nuevo.")


# ── Logout ────────────────────────────────────────────────────────────────────

## Cierra la sesión del usuario activo.
## Proceso:
##   1. Sincroniza estadísticas locales con Supabase (automático, sin límite diario).
##   2. Si la sincronización fue exitosa → elimina el archivo local del dispositivo.
##   3. Si falló (offline) → el archivo se conserva para el próximo login.
##   4. Limpia el estado de sesión en memoria.
##   5. Emite [signal logout_complete].
func logout() -> void:
	if not is_logged_in:
		return

	# Paso 1: sincronizar estadísticas locales → Supabase (es_manual = false)
	var sync_ok: bool = false
	if LocalDB.has_active_profile():
		var stats_data: Dictionary = LocalDB.get_full_data()
		sync_ok = await _sync_stats(stats_data, false)  # automático, sin límite

	# Paso 2 y 3: limpiar perfil local según resultado de sincronización
	LocalDB.close_profile(sync_ok)

	# Paso 4: invalidar token de sesión del estudiante en Supabase
	if session_type == "student" and student_session_token != "":
		await RemoteDB.rpc_logout_student(student_session_token)

	# Paso 5: cerrar sesión de Auth de Supabase (institución / profesor)
	if session_type in ["teacher", "institution"]:
		await RemoteDB.auth_sign_out()

	# Limpiar estado interno
	_clear_session()

	logout_complete.emit()



## Guarda el resultado de una partida completada, actualiza estadísticas locales y las sincroniza con Supabase.
## Si la partida es un récord, también la envía al leaderboard remoto correspondientemente.
func save_and_sync_game(
	modo: String,
	dificultad: String,
	variantes: Array,
	score: int,
	tableros_completados: int,
	tiempo_seg: float,
	errores: int,
	ganada: bool
) -> void:
	if not LocalDB.has_active_profile():
		return

	# 1. Guardar localmente
	var res_save = LocalDB.save_game_session(
		modo, dificultad, variantes, score, tableros_completados, tiempo_seg, errores, ganada
	)

	# Si no estamos logueados, no sincronizamos con la nube
	if not is_logged_in:
		return

	# 2. Sincronizar estadísticas en la nube (segundo plano)
	var stats_data = LocalDB.get_full_data()
	var sync_ok = await _sync_stats(stats_data, false) # es_manual = false (sin límites)

	# 3. Si es récord y la sincronización fue exitosa, subir al leaderboard de Supabase
	var es_nuevo_record = res_save.get("es_nuevo_record", false) if res_save is Dictionary else false
	if es_nuevo_record and sync_ok:
		if session_type == "student":
			await RemoteDB.submit_student_score(
				student_session_token,
				user_id,
				dificultad,
				modo,
				variantes,
				score,
				tableros_completados,
				int(tiempo_seg)
			)
		elif session_type == "teacher":
			await RemoteDB.submit_teacher_score(
				user_id,
				dificultad,
				modo,
				variantes,
				score,
				tableros_completados,
				int(tiempo_seg)
			)


# ── Sincronización Manual ─────────────────────────────────────────────────────

## Sincronización iniciada manualmente por el usuario (máx. 2 veces al día).
## Los datos locales se suben a Supabase. Emite [signal sync_complete].
func sync_stats_manual() -> void:
	if not is_logged_in or not LocalDB.has_active_profile():
		sync_complete.emit(false)
		return

	var stats_data: Dictionary = LocalDB.get_full_data()
	var ok: bool = await _sync_stats(stats_data, true)  # es_manual = true → cuenta el límite
	sync_complete.emit(ok)


# ── API de Consulta ───────────────────────────────────────────────────────────

## Devuelve true si el profesor autenticado tiene una contraseña temporal pendiente.
func requires_password_change() -> bool:
	return session_type == "teacher" and needs_password_change


## Devuelve las cabeceras HTTP necesarias para llamadas RLS de estudiante.
## Incluye la cabecera 'x-student-token' si hay sesión de estudiante activa.
func get_student_headers() -> PackedStringArray:
	if session_type != "student" or student_session_token.is_empty():
		return PackedStringArray()
	return PackedStringArray(["x-student-token: " + student_session_token])


# ── Privados ──────────────────────────────────────────────────────────────────

## Envía las estadísticas a la función RPC correspondiente según el rol.
## [param stats]       Diccionario { cumulative_stats, best_runs } del LocalDB.
## [param es_manual]   true = cuenta en el límite diario.
## Devuelve true si la sincronización fue aceptada por Supabase.
func _sync_stats(stats: Dictionary, es_manual: bool) -> bool:
	match session_type:
		"student":
			return await RemoteDB.rpc_sync_student(stats, es_manual, student_session_token)
		"teacher":
			return await RemoteDB.rpc_sync_teacher(stats, es_manual)
		_:
			# Las instituciones no tienen estadísticas de juego
			return true


func _clear_session() -> void:
	session_type          = "none"
	user_id               = ""
	user_name             = ""
	group_id              = ""
	student_session_token = ""
	needs_password_change = false
	is_logged_in          = false


# ── Métodos de Fuerza Bruta y Lockout ───────────────────────────────────────────

func _load_lockout_until(key: String) -> float:
	var cfg = ConfigFile.new()
	if cfg.load(LOCKOUT_CFG_PATH) == OK:
		return cfg.get_value("lockout", key, 0.0) as float
	return 0.0


func _save_lockout_until(key: String, until: float) -> void:
	var cfg = ConfigFile.new()
	cfg.load(LOCKOUT_CFG_PATH)
	cfg.set_value("lockout", key, until)
	cfg.save(LOCKOUT_CFG_PATH)


func _clear_lockout(key: String) -> void:
	var cfg = ConfigFile.new()
	if cfg.load(LOCKOUT_CFG_PATH) == OK:
		if cfg.has_section_key("lockout", key):
			cfg.erase_section_key("lockout", key)
			cfg.save(LOCKOUT_CFG_PATH)


func _check_lockout(key: String) -> int:
	var now: float = Time.get_unix_time_from_system()
	var lockout_until: float = _load_lockout_until(key)
	if lockout_until > now:
		return int(ceil(lockout_until - now))
	return 0


func _register_failure(key: String) -> String:
	var now: float = Time.get_unix_time_from_system()
	var attempts: int = _local_attempts.get(key, 0) + 1
	_local_attempts[key] = attempts
	
	if attempts >= MAX_ATTEMPTS:
		var lockout_until = now + LOCKOUT_DURATION_SEC
		_save_lockout_until(key, lockout_until)
		_local_attempts[key] = 0
		return "Demasiados intentos incorrectos. Inicio de sesión bloqueado por %d segundos." % LOCKOUT_DURATION_SEC
	
	var remaining = MAX_ATTEMPTS - attempts
	return "Credenciales incorrectas. Intentos restantes: %d." % remaining
