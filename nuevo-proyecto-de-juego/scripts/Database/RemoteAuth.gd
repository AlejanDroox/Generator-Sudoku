extends RefCounted
class_name RemoteAuth
## RemoteAuth — Autenticación de Staff y Estudiantes vía Supabase GoTrue + RPC.
##
## Instanciado internamente por RemoteDB. No usar directamente.
## Accede al nodo padre (RemoteDB) para HTTP helpers y cabeceras.

var _db: Node  # Referencia al RemoteDB Node para acceder a _send, _parse, _ok, headers


func _init(db: Node) -> void:
	_db = db


# ── Autenticación de Staff (GoTrue) ────────────────────────────────────────────

## Inicia sesión como institución o profesor via Supabase Auth (email + password).
## Devuelve un Dictionary con los campos de sesión o un error.
func auth_sign_in(p_email: String, p_password: String) -> Dictionary:
	var url: String = _db.SUPABASE_URL + "/auth/v1/token?grant_type=password"
	var body: String = JSON.stringify({
		"email":    p_email.strip_edges(),
		"password": p_password
	})
	var headers: PackedStringArray = PackedStringArray([
		"apikey: "       + _db.ANON_KEY,
		"Content-Type: application/json"
	])

	var res: Array = await _db._send(url, headers, HTTPClient.METHOD_POST, body)

	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "Error de conexión con el servidor. Verifica tu internet."}

	if not _db._ok(res):
		var parsed = _db._parse(res)
		var msg: String = "Credenciales incorrectas."
		if parsed is Dictionary:
			msg = parsed.get("error_description", parsed.get("msg", msg)) as String
		return {"success": false, "error": msg}

	var json = _db._parse(res)
	if not (json is Dictionary) or not json.has("access_token"):
		return {"success": false, "error": "Respuesta inesperada del servidor de autenticación."}

	_db._staff_access_token  = json.get("access_token",  "") as String
	_db._staff_refresh_token = json.get("refresh_token", "") as String

	var user_data: Dictionary = json.get("user", {}) as Dictionary
	var user_meta: Dictionary = user_data.get("user_metadata", user_data.get("raw_user_meta_data", {})) as Dictionary
	var rol: String           = (user_meta.get("rol", "") as String).to_lower().strip_edges()
	var uid: String           = user_data.get("id", "") as String

	var estadisticas: Dictionary = {}
	if rol == "profesor" or rol == "teacher":
		estadisticas = await _fetch_profesor_stats(uid)

	return {
		"success":       true,
		"user_id":       uid,
		"nombre":        user_meta.get("nombre", p_email),
		"rol":           rol,
		"temp_password": user_meta.get("temp_password", false),
		"estadisticas":  estadisticas
	}


## Cierra la sesión de staff en Supabase (invalida el access token).
func auth_sign_out() -> void:
	if _db._staff_access_token.is_empty():
		return
	var url: String = _db.SUPABASE_URL + "/auth/v1/logout"
	await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_POST)
	_db._staff_access_token  = ""
	_db._staff_refresh_token = ""


## Descarga las estadísticas de un profesor desde public.profesores.
func _fetch_profesor_stats(uid: String) -> Dictionary:
	var url: String = _db.SUPABASE_URL + "/rest/v1/profesores?select=estadisticas&id=eq." + uid
	var res: Array  = await _db._send(url, _db._headers_staff())
	if _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Array and not parsed.is_empty():
			return parsed[0].get("estadisticas", {}) as Dictionary
	return {}


# ── RPC — Login / Logout de Estudiante ────────────────────────────────────────

## Llama a la función RPC 'login_estudiante' en Supabase.
func rpc_login_student(p_usuario: String, p_pin: String) -> Dictionary:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/login_estudiante"
	var body: String = JSON.stringify({
		"p_usuario": p_usuario.strip_edges(),
		"p_pin":     p_pin.strip_edges()
	})

	var res: Array = await _db._send(url, _db._headers_anon(), HTTPClient.METHOD_POST, body)

	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return {"success": false, "error": "Error de conexión con el servidor. Verifica tu internet."}

	if not _db._ok(res):
		var parsed = _db._parse(res)
		var msg: String = "Credenciales incorrectas."
		if parsed is Dictionary:
			msg = parsed.get("message", parsed.get("hint", msg)) as String
		return {"success": false, "error": msg}

	var json = _db._parse(res)
	if not (json is Dictionary) or not json.get("success", false):
		var msg: String = "Respuesta inesperada del servidor."
		if json is Dictionary and json.has("error"):
			msg = json.get("error") as String
		return {"success": false, "error": msg}

	return json


## Llama a la función RPC 'logout_estudiante' para invalidar el token de sesión.
func rpc_logout_student(session_token: String) -> void:
	if session_token.is_empty():
		return
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/logout_estudiante"
	var body: String = JSON.stringify({"p_token": session_token})
	await _db._send(url, _db._headers_anon(), HTTPClient.METHOD_POST, body)


# ── RPC — Cambio de Contraseña de Profesor ─────────────────────────────────────

## Llama a 'cambiar_contrasena_profesor' para actualizar la contraseña del profesor.
func rpc_change_teacher_password(p_nueva_password: String) -> bool:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/cambiar_contrasena_profesor"
	var body: String = JSON.stringify({"p_nueva_password": p_nueva_password})
	var res: Array   = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_POST, body)
	return _db._ok(res)


# ── RPC — Registro de Profesor ─────────────────────────────────────────────────

## Llama a 'registrar_profesor' para crear un profesor con contraseña temporal.
## Solo puede ser llamada por una institución autenticada.
## Devuelve el UUID del nuevo profesor o "" si falla.
func rpc_register_teacher(
	p_email:          String,
	p_password_temp:  String,
	p_nombre:         String,
	p_institucion_id: String
) -> String:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/registrar_profesor"
	var body: String = JSON.stringify({
		"p_email":          p_email.strip_edges(),
		"p_password_temp":  p_password_temp,
		"p_nombre":         p_nombre.strip_edges(),
		"p_institucion_id": p_institucion_id
	})
	var res: Array = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_POST, body)
	if _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is String:
			return parsed
	var err_parsed = _db._parse(res)
	if err_parsed is Dictionary:
		_db.emit_signal("request_failed", err_parsed.get("message", "No se pudo registrar el profesor."))
	return ""
