extends RefCounted
class_name RemoteCrud
## RemoteCrud — Operaciones CRUD de gestión escolar: Profesores, Grupos y Estudiantes.
##
## Instanciado internamente por RemoteDB. No usar directamente.
## Emite señales directamente a través del nodo _db (RemoteDB).

var _db: Node


func _init(db: Node) -> void:
	_db = db


# ── Estudiantes ────────────────────────────────────────────────────────────────

## Obtiene todos los estudiantes visibles para el staff autenticado.
## RLS filtra automáticamente: un profesor solo ve sus grupos; la institución los ve todos.
## Emite [signal entities_fetched("student", data)].
func fetch_students() -> void:
	var url: String = (
		_db.SUPABASE_URL
		+ "/rest/v1/estudiantes"
		+ "?select=id,usuario,grupo_id,created_at,estadisticas"
		+ "&order=usuario.asc"
	)
	var res: Array = await _db._send(url, _db._headers_staff())
	if _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Array:
			_db.emit_signal("entities_fetched", "student", parsed)
			return
	_db.emit_signal("request_failed", "Error al obtener estudiantes.")


## Crea un nuevo estudiante en el grupo indicado.
## El PIN se genera aleatoriamente si no se provee.
## Emite [signal entity_created("student")].
func create_student(p_usuario: String, p_grupo_id: String, p_pin: String = "") -> void:
	var pin_val: String = p_pin
	if pin_val.is_empty():
		pin_val = "%06d" % (randi() % 1000000)

	if not pin_val.is_valid_int() or pin_val.length() != 6:
		_db.emit_signal("request_failed", "El PIN debe ser un número de 6 dígitos.")
		return

	var url: String  = _db.SUPABASE_URL + "/rest/v1/estudiantes"
	var body: String = JSON.stringify({
		"usuario":  p_usuario.strip_edges(),
		"grupo_id": p_grupo_id,
		"pin":      pin_val
	})
	var res: Array = await _db._send(url, _db._headers_staff_return(), HTTPClient.METHOD_POST, body)
	if _db._ok(res):
		_db.emit_signal("entity_created", "student")
	else:
		var parsed = _db._parse(res)
		var msg: String = "Error al crear el estudiante."
		if parsed is Dictionary:
			msg = parsed.get("message", msg) as String
		_db.emit_signal("request_failed", msg)


## Actualiza el usuario o grupo de un estudiante existente.
## Emite [signal entity_updated("student")].
func update_student(student_id: String, p_usuario: String, p_grupo_id: String) -> void:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/estudiantes?id=eq." + student_id
	var body: String = JSON.stringify({
		"usuario":  p_usuario.strip_edges(),
		"grupo_id": p_grupo_id
	})
	var res: Array = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_PATCH, body)
	if _db._ok(res):
		_db.emit_signal("entity_updated", "student")
	else:
		_db.emit_signal("request_failed", "Error al actualizar el estudiante.")


## Actualiza el PIN de un estudiante.
## Emite [signal entity_updated("student_pin")].
func update_student_pin(student_id: String, new_pin: String) -> void:
	if not new_pin.is_valid_int() or new_pin.length() != 6:
		_db.emit_signal("request_failed", "El PIN debe ser un número de 6 dígitos.")
		return
	var url: String  = _db.SUPABASE_URL + "/rest/v1/estudiantes?id=eq." + student_id
	var body: String = JSON.stringify({"pin": new_pin})
	var res: Array   = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_PATCH, body)
	if _db._ok(res):
		_db.emit_signal("entity_updated", "student_pin")
	else:
		_db.emit_signal("request_failed", "Error al cambiar el PIN del estudiante.")


## Elimina un estudiante. RLS restringe esta operación a la institución.
## Emite [signal entity_deleted("student")].
func delete_student(student_id: String) -> void:
	var url: String = _db.SUPABASE_URL + "/rest/v1/estudiantes?id=eq." + student_id
	var res: Array  = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_DELETE)
	if _db._ok(res) or res[1] == 204:
		_db.emit_signal("entity_deleted", "student")
	else:
		_db.emit_signal("request_failed", "Error al eliminar el estudiante.")


# ── Grupos ─────────────────────────────────────────────────────────────────────

## Obtiene todos los grupos de la institución autenticada.
## Emite [signal entities_fetched("group", data)].
func fetch_groups() -> void:
	var url: String = (
		_db.SUPABASE_URL
		+ "/rest/v1/grupos"
		+ "?select=id,codigo_grupo,profesor_encargado_id,institucion_id,created_at,profesores!profesor_encargado_id(nombre),estudiantes(id,usuario)"
		+ "&order=codigo_grupo.asc"
	)
	var res: Array = await _db._send(url, _db._headers_staff())
	if _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Array:
			_db.emit_signal("entities_fetched", "group", parsed)
			return
	_db.emit_signal("request_failed", "Error al obtener los grupos.")


## Crea un grupo nuevo.
## Emite [signal entity_created("group")].
func create_group(
	p_codigo:                String,
	p_institucion_id:        String,
	p_profesor_encargado_id: String
) -> void:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/grupos"
	var body: String = JSON.stringify({
		"codigo_grupo":          p_codigo.strip_edges().left(10),
		"institucion_id":        p_institucion_id,
		"profesor_encargado_id": p_profesor_encargado_id
	})
	var res: Array = await _db._send(url, _db._headers_staff_return(), HTTPClient.METHOD_POST, body)
	if _db._ok(res):
		_db.emit_signal("entity_created", "group")
	else:
		var parsed = _db._parse(res)
		var msg: String = "Error al crear el grupo."
		if parsed is Dictionary:
			msg = parsed.get("message", msg) as String
		_db.emit_signal("request_failed", msg)


## Actualiza el profesor encargado de un grupo.
## Emite [signal entity_updated("group")].
func update_group_teacher(group_id: String, new_teacher_id: String) -> void:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/grupos?id=eq." + group_id
	var body: String = JSON.stringify({"profesor_encargado_id": new_teacher_id})
	var res: Array   = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_PATCH, body)
	if _db._ok(res):
		_db.emit_signal("entity_updated", "group")
	else:
		_db.emit_signal("request_failed", "Error al actualizar el profesor del grupo.")


## Elimina un grupo. Fallará si hay estudiantes asignados (ON DELETE RESTRICT en BD).
## Emite [signal entity_deleted("group")].
func delete_group(group_id: String) -> void:
	var url: String = _db.SUPABASE_URL + "/rest/v1/grupos?id=eq." + group_id
	var res: Array  = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_DELETE)
	if _db._ok(res) or res[1] == 204:
		_db.emit_signal("entity_deleted", "group")
	else:
		var parsed = _db._parse(res)
		var msg: String = "No se pudo eliminar el grupo. Puede tener estudiantes asignados."
		if parsed is Dictionary:
			msg = parsed.get("message", msg) as String
		_db.emit_signal("request_failed", msg)


# ── Profesores ─────────────────────────────────────────────────────────────────

## Obtiene todos los profesores de la institución autenticada.
## Emite [signal entities_fetched("teacher", data)].
func fetch_teachers() -> void:
	var url: String = (
		_db.SUPABASE_URL
		+ "/rest/v1/profesores"
		+ "?select=id,nombre,email,created_at,grupos(id,codigo_grupo)"
		+ "&order=nombre.asc"
	)
	var res: Array = await _db._send(url, _db._headers_staff())
	if _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Array:
			_db.emit_signal("entities_fetched", "teacher", parsed)
			return
	_db.emit_signal("request_failed", "Error al obtener los profesores.")


## Actualiza el nombre y correo de un profesor.
## Emite [signal entity_updated("teacher")].
func update_teacher(teacher_id: String, new_name: String, new_email: String) -> void:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/profesores?id=eq." + teacher_id
	var body: String = JSON.stringify({
		"nombre": new_name.strip_edges(),
		"email":  new_email.strip_edges()
	})
	var res: Array = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_PATCH, body)
	if _db._ok(res):
		_db.emit_signal("entity_updated", "teacher")
	else:
		_db.emit_signal("request_failed", "Error al actualizar el profesor.")


## Elimina un profesor.
## Emite [signal entity_deleted("teacher")].
func delete_teacher(teacher_id: String) -> void:
	var url: String = _db.SUPABASE_URL + "/rest/v1/profesores?id=eq." + teacher_id
	var res: Array  = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_DELETE)
	if _db._ok(res) or res[1] == 204:
		_db.emit_signal("entity_deleted", "teacher")
	else:
		_db.emit_signal("request_failed", "Error al eliminar el profesor.")


## Asigna un profesor a un grupo buscando por código de grupo.
## Si el grupo no existe, lo crea automáticamente para la institución.
func rpc_assign_teacher_to_group_by_code(group_code: String, teacher_id: String) -> bool:
	var select_url: String = _db.SUPABASE_URL + "/rest/v1/grupos?codigo_grupo=eq." + group_code.uri_encode()
	var select_res: Array  = await _db._send(select_url, _db._headers_staff())
	if not _db._ok(select_res):
		return false

	var parsed = _db._parse(select_res)
	if parsed is Array and not parsed.is_empty():
		var group_id: String  = parsed[0].get("id", "") as String
		var update_url: String = _db.SUPABASE_URL + "/rest/v1/grupos?id=eq." + group_id
		var body: String       = JSON.stringify({"profesor_encargado_id": teacher_id})
		var update_res: Array  = await _db._send(update_url, _db._headers_staff(), HTTPClient.METHOD_PATCH, body)
		return _db._ok(update_res)
	else:
		var inst_id: String    = AuthManager.user_id
		var create_url: String = _db.SUPABASE_URL + "/rest/v1/grupos"
		var body: String       = JSON.stringify({
			"codigo_grupo":          group_code.strip_edges().left(10),
			"institucion_id":        inst_id,
			"profesor_encargado_id": teacher_id
		})
		var create_res: Array = await _db._send(create_url, _db._headers_staff_return(), HTTPClient.METHOD_POST, body)
		return _db._ok(create_res)
