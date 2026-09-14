extends Node
## RemoteDB — Punto central de acceso a Supabase REST API y GoTrue Auth.
##
## Este nodo actúa como fachada (facade) que delega cada operación al
## sub-servicio correspondiente:
##   - RemoteAuth      → Autenticación de staff y estudiantes
##   - RemoteSync      → Sincronización de estadísticas
##   - RemoteLeaderboard → Rankings
##   - RemoteCrud      → CRUD de gestión escolar (grupos, profesores, estudiantes)
##
## Convenciones de seguridad:
##   - Nunca se concatena input del usuario directamente en URLs o cuerpos JSON.
##     Todo input se pasa a JSON.stringify() como campo de un Dictionary.
##   - El token de estudiante viaja en la cabecera HTTP 'x-student-token',
##     nunca como query param en la URL.
##   - Las credenciales de staff viajan en el cuerpo JSON de la petición POST de Auth,
##     nunca en la URL.

# ── Configuración Supabase ─────────────────────────────────────────────────────

## URL base del proyecto Supabase (cargada dinámicamente desde Env.gd).
var SUPABASE_URL: String:
	get:
		return Env.get_supabase_url()

## Clave pública anónima de Supabase (cargada dinámicamente desde Env.gd).
var ANON_KEY: String:
	get:
		return Env.get_supabase_anon_key()

# ── Estado interno de sesión de staff ─────────────────────────────────────────

var _staff_access_token:  String = ""
var _staff_refresh_token: String = ""

# ── Configuración Local de Invitado ───────────────────────────────────────────

const CONFIG_PATH: String = "user://player.cfg"
var player_name: String   = "SudokuPlayer"

# ── Sub-servicios ──────────────────────────────────────────────────────────────

var _auth:        RemoteAuth
var _sync:        RemoteSync
var _leaderboard: RemoteLeaderboard
var _crud:        RemoteCrud

# ── Señales Públicas ──────────────────────────────────────────────────────────

## Emitida cuando se obtiene el leaderboard de estudiantes.
signal leaderboard_students_received(data: Array)

## Emitida cuando se obtiene el leaderboard de profesores.
signal leaderboard_teachers_received(data: Array)

## Emitida cuando cualquier petición HTTP falla de forma inesperada.
signal request_failed(error: String)

## Emitida al crear un estudiante, grupo o profesor exitosamente.
signal entity_created(entity_type: String)

## Emitida al actualizar una entidad exitosamente.
signal entity_updated(entity_type: String)

## Emitida al eliminar una entidad exitosamente.
signal entity_deleted(entity_type: String)

## Emitida al obtener listados (estudiantes, grupos, profesores).
signal entities_fetched(entity_type: String, data: Array)


# ── Ciclo de Vida ──────────────────────────────────────────────────────────────

func _ready() -> void:
	_auth        = RemoteAuth.new(self)
	_sync        = RemoteSync.new(self)
	_leaderboard = RemoteLeaderboard.new(self)
	_crud        = RemoteCrud.new(self)
	_load_player_name()


# ── Gestión del Nombre de Invitado ────────────────────────────────────────────

func _load_player_name() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		player_name = cfg.get_value("player", "player_name", "SudokuPlayer") as String


func set_player_name(new_name: String) -> void:
	var trimmed: String = new_name.strip_edges()
	if trimmed != "":
		player_name = trimmed
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(CONFIG_PATH)
		cfg.set_value("player", "player_name", player_name)
		cfg.save(CONFIG_PATH)


# ── HTTP Helper (compartido con sub-servicios) ─────────────────────────────────

## Envía una petición HTTP y espera la respuesta de forma asíncrona.
## Devuelve Array: [result_code, http_status, headers, PackedByteArray body]
func _send(
	url:    String,
	headers: PackedStringArray,
	method:  HTTPClient.Method = HTTPClient.METHOD_GET,
	body:    String            = ""
) -> Array:
	var req: HTTPRequest = HTTPRequest.new()
	add_child(req)
	var err: Error = req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return [HTTPRequest.RESULT_CANT_CONNECT, 0, [], PackedByteArray()]
	var res: Array = await req.request_completed
	req.queue_free()
	return res


## Parsea el body de la respuesta como JSON. Devuelve null si falla.
func _parse(res: Array):
	var raw: String = (res[3] as PackedByteArray).get_string_from_utf8()
	return JSON.parse_string(raw)


## Devuelve true si la respuesta indica éxito (HTTP 2xx).
func _ok(res: Array) -> bool:
	return res[0] == HTTPRequest.RESULT_SUCCESS and res[1] >= 200 and res[1] < 300


# ── Constructores de Cabeceras (compartidos con sub-servicios) ─────────────────

func _headers_anon() -> PackedStringArray:
	return PackedStringArray([
		"apikey: "              + ANON_KEY,
		"Authorization: Bearer " + ANON_KEY,
		"Content-Type: application/json"
	])


func _headers_anon_return() -> PackedStringArray:
	var h: PackedStringArray = _headers_anon()
	h.append("Prefer: return=representation")
	return h


func _headers_staff() -> PackedStringArray:
	return PackedStringArray([
		"apikey: "              + ANON_KEY,
		"Authorization: Bearer " + _staff_access_token,
		"Content-Type: application/json"
	])


func _headers_staff_return() -> PackedStringArray:
	var h: PackedStringArray = _headers_staff()
	h.append("Prefer: return=representation")
	return h


## Cabeceras para estudiante: añade el token de sesión como cabecera personalizada.
## Este token es leído por la función get_current_student_id() en PostgreSQL.
func _headers_student(session_token: String) -> PackedStringArray:
	return PackedStringArray([
		"apikey: "              + ANON_KEY,
		"Authorization: Bearer " + ANON_KEY,
		"Content-Type: application/json",
		"x-student-token: "    + session_token
	])


# ════════════════════════════════════════════════════════════════════════════════
# API PÚBLICA — Delega a sub-servicios
# ════════════════════════════════════════════════════════════════════════════════

# ── Auth ───────────────────────────────────────────────────────────────────────

func auth_sign_in(p_email: String, p_password: String) -> Dictionary:
	return await _auth.auth_sign_in(p_email, p_password)


func auth_sign_out() -> void:
	await _auth.auth_sign_out()


func rpc_login_student(p_usuario: String, p_pin: String) -> Dictionary:
	return await _auth.rpc_login_student(p_usuario, p_pin)


func rpc_logout_student(session_token: String) -> void:
	await _auth.rpc_logout_student(session_token)


func rpc_change_teacher_password(p_nueva_password: String) -> bool:
	return await _auth.rpc_change_teacher_password(p_nueva_password)


func rpc_register_teacher(
	p_email:          String,
	p_password_temp:  String,
	p_nombre:         String,
	p_institucion_id: String
) -> String:
	return await _auth.rpc_register_teacher(p_email, p_password_temp, p_nombre, p_institucion_id)


# ── Sync ───────────────────────────────────────────────────────────────────────

func rpc_sync_student(stats: Dictionary, es_manual: bool, session_token: String) -> bool:
	return await _sync.rpc_sync_student(stats, es_manual, session_token)


func rpc_sync_teacher(stats: Dictionary, es_manual: bool) -> bool:
	return await _sync.rpc_sync_teacher(stats, es_manual)


# ── Leaderboard ────────────────────────────────────────────────────────────────

func fetch_student_leaderboard(
	session_token: String = "",
	p_dificultad:  String = "",
	p_modo:        String = ""
) -> void:
	await _leaderboard.fetch_student_leaderboard(session_token, p_dificultad, p_modo)


func fetch_teacher_leaderboard(p_dificultad: String = "", p_modo: String = "") -> void:
	await _leaderboard.fetch_teacher_leaderboard(p_dificultad, p_modo)


func submit_student_score(
	session_token:        String,
	student_id:           String,
	dificultad:           String,
	modo:                 String,
	variantes_activas:    Array,
	puntuacion:           int,
	tableros_completados: int,
	tiempo_seg:           int
) -> bool:
	return await _leaderboard.submit_student_score(
		session_token, student_id, dificultad, modo,
		variantes_activas, puntuacion, tableros_completados, tiempo_seg
	)


func submit_teacher_score(
	teacher_id:           String,
	dificultad:           String,
	modo:                 String,
	variantes_activas:    Array,
	puntuacion:           int,
	tableros_completados: int,
	tiempo_seg:           int
) -> bool:
	return await _leaderboard.submit_teacher_score(
		teacher_id, dificultad, modo,
		variantes_activas, puntuacion, tableros_completados, tiempo_seg
	)


# ── CRUD — Estudiantes ─────────────────────────────────────────────────────────

func fetch_students() -> void:
	await _crud.fetch_students()


func create_student(p_usuario: String, p_grupo_id: String, p_pin: String = "") -> void:
	await _crud.create_student(p_usuario, p_grupo_id, p_pin)


func update_student(student_id: String, p_usuario: String, p_grupo_id: String) -> void:
	await _crud.update_student(student_id, p_usuario, p_grupo_id)


func update_student_pin(student_id: String, new_pin: String) -> void:
	await _crud.update_student_pin(student_id, new_pin)


func delete_student(student_id: String) -> void:
	await _crud.delete_student(student_id)


# ── CRUD — Grupos ──────────────────────────────────────────────────────────────

func fetch_groups() -> void:
	await _crud.fetch_groups()


func create_group(
	p_codigo:                String,
	p_institucion_id:        String,
	p_profesor_encargado_id: String
) -> void:
	await _crud.create_group(p_codigo, p_institucion_id, p_profesor_encargado_id)


func update_group_teacher(group_id: String, new_teacher_id: String) -> void:
	await _crud.update_group_teacher(group_id, new_teacher_id)


func delete_group(group_id: String) -> void:
	await _crud.delete_group(group_id)


# ── CRUD — Profesores ──────────────────────────────────────────────────────────

func fetch_teachers() -> void:
	await _crud.fetch_teachers()


func update_teacher(teacher_id: String, new_name: String, new_email: String) -> void:
	await _crud.update_teacher(teacher_id, new_name, new_email)


func delete_teacher(teacher_id: String) -> void:
	await _crud.delete_teacher(teacher_id)


func rpc_assign_teacher_to_group_by_code(group_code: String, teacher_id: String) -> bool:
	return await _crud.rpc_assign_teacher_to_group_by_code(group_code, teacher_id)


# ════════════════════════════════════════════════════════════════════════════════
# GENERADOR DE REPORTES PDF (API REST EXTERNA)
# ════════════════════════════════════════════════════════════════════════════════

## URL local para pruebas. En producción se puede configurar mediante variables de entorno o archivo de configuración.
const REPORT_API_URL: String = "http://localhost:3000"

## Solicita al microservicio la generación del PDF de un estudiante.
## Retorna un Dictionary: { "success": bool, "pdf_data": PackedByteArray, "error": String }
func request_student_report(student_id: String, use_mock: bool = false) -> Dictionary:
	var url: String = REPORT_API_URL + "/api/reportes/estudiantes"
	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json"
	])
	
	# Usar el token del staff autenticado si está disponible
	var token: String = _staff_access_token
	
	var payload: Dictionary = {
		"estudiante_id": student_id,
		"auth_token": token,
		"mock": use_mock
	}
	
	var body: String = JSON.stringify(payload)
	var res: Array = await _send(url, headers, HTTPClient.METHOD_POST, body)
	
	if _ok(res):
		return {
			"success": true,
			"pdf_data": res[3] as PackedByteArray,
			"error": ""
		}
	else:
		var err_msg: String = "Error de conexión con el servidor de reportes."
		if res[3] is PackedByteArray and res[3].size() > 0:
			var parsed = _parse(res)
			if parsed is Dictionary and parsed.has("error"):
				err_msg = parsed["error"] as String
		return {
			"success": false,
			"pdf_data": PackedByteArray(),
			"error": err_msg
		}



## Guarda un PackedByteArray como archivo PDF local y lo abre con el lector nativo.
## Retorna un string vacío si tiene éxito, o el mensaje de error en caso de fallo.
func save_and_open_pdf(pdf_data: PackedByteArray, filename: String) -> String:
	var path: String = "user://" + filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "No se pudo crear el archivo local."
	
	file.store_buffer(pdf_data)
	file.close()
	
	# Abrir el PDF usando el lector del sistema operativo
	var global_path: String = ProjectSettings.globalize_path(path)
	var err = OS.shell_open(global_path)
	if err != OK:
		return "No se pudo abrir el archivo PDF automáticamente. Ruta: " + global_path
	
	return ""


## Realiza una petición POST a la API de reportes y devuelve { success, pdf_data, error }.
func _post_report(endpoint: String, payload: Dictionary) -> Dictionary:
	var url: String = REPORT_API_URL + endpoint
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	payload["auth_token"] = _staff_access_token
	var body: String = JSON.stringify(payload)
	var res: Array = await _send(url, headers, HTTPClient.METHOD_POST, body)
	if _ok(res):
		return {"success": true, "pdf_data": res[3] as PackedByteArray, "error": ""}
	var err_msg: String = "Error de conexión con el servidor de reportes."
	if res[3] is PackedByteArray and res[3].size() > 0:
		var parsed = _parse(res)
		if parsed is Dictionary and parsed.has("error"):
			err_msg = parsed["error"] as String
	return {"success": false, "pdf_data": PackedByteArray(), "error": err_msg}


## Reporte de lista de profesores.
func request_teachers_report() -> Dictionary:
	return await _post_report("/api/reportes/profesores", {})


## Reporte de listado de estudiantes, con filtro opcional por grupo.
func request_students_list_report(grupo_codigo: String = "") -> Dictionary:
	var payload: Dictionary = {}
	if not grupo_codigo.is_empty():
		payload["grupo_codigo"] = grupo_codigo
	return await _post_report("/api/reportes/estudiantes/listado", payload)


## Reporte en lote (PDF único multipágina), con filtro opcional por grupo.
func request_students_batch_report(grupo_codigo: String = "") -> Dictionary:
	var payload: Dictionary = {}
	if not grupo_codigo.is_empty():
		payload["grupo_codigo"] = grupo_codigo
	return await _post_report("/api/reportes/estudiantes/lote", payload)


## Reporte de clasificaciones (leaderboard) con todos los filtros del juego.
func request_leaderboard_report(modo: String, dificultad: String, grupo_codigo: String, variantes_activas: Array, ordenacion: String) -> Dictionary:
	var payload: Dictionary = {"ordenacion": ordenacion}
	if not modo.is_empty(): payload["modo"] = modo
	if not dificultad.is_empty(): payload["dificultad"] = dificultad
	if not grupo_codigo.is_empty(): payload["grupo_codigo"] = grupo_codigo
	if variantes_activas.size() > 0: payload["variantes_activas"] = variantes_activas
	return await _post_report("/api/reportes/leaderboard", payload)
