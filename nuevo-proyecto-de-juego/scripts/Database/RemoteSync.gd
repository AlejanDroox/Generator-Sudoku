extends RefCounted
class_name RemoteSync
## RemoteSync — Sincronización de estadísticas de estudiantes y profesores con Supabase.
##
## Instanciado internamente por RemoteDB. No usar directamente.

var _db: Node


func _init(db: Node) -> void:
	_db = db


# ── Sincronización de Estadísticas ────────────────────────────────────────────

## Sincroniza las estadísticas del estudiante activo con Supabase.
## [param stats]         Diccionario { cumulative_stats, best_runs } del LocalDB.
## [param es_manual]     true = cuenta en el límite de 2/día.
## [param session_token] Token UUID de la sesión del estudiante.
## Devuelve true si fue exitoso.
func rpc_sync_student(stats: Dictionary, es_manual: bool, session_token: String) -> bool:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/sincronizar_estudiante"
	var body: String = JSON.stringify({
		"p_estadisticas": stats,
		"p_es_manual":    es_manual
	})
	var res: Array = await _db._send(url, _db._headers_student(session_token), HTTPClient.METHOD_POST, body)
	if not _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Dictionary:
			_db.emit_signal("request_failed", parsed.get("message", "Error al sincronizar estadísticas del estudiante."))
		return false
	return true


## Sincroniza las estadísticas del profesor activo con Supabase.
## Requiere sesión de staff activa.
## Devuelve true si fue exitoso.
func rpc_sync_teacher(stats: Dictionary, es_manual: bool) -> bool:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/rpc/sincronizar_profesor"
	var body: String = JSON.stringify({
		"p_estadisticas": stats,
		"p_es_manual":    es_manual
	})
	var res: Array = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_POST, body)
	if not _db._ok(res):
		var parsed = _db._parse(res)
		if parsed is Dictionary:
			_db.emit_signal("request_failed", parsed.get("message", "Error al sincronizar estadísticas del profesor."))
		return false
	return true
