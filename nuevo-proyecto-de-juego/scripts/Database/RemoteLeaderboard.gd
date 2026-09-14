extends RefCounted
class_name RemoteLeaderboard
## RemoteLeaderboard — Obtención y envío de rankings al leaderboard de Supabase.
##
## Instanciado internamente por RemoteDB. No usar directamente.

var _db: Node


func _init(db: Node) -> void:
	_db = db


# ── Leaderboard de Estudiantes ─────────────────────────────────────────────────

## Obtiene el leaderboard de ESTUDIANTES del mismo grupo del estudiante activo.
## RLS de Supabase filtra automáticamente: el estudiante solo ve su grupo.
## [param session_token] Token UUID de la sesión del estudiante.
## [param p_dificultad]  Filtrar por dificultad (vacío = sin filtro).
## [param p_modo]        Filtrar por modo de juego (vacío = sin filtro).
## Emite [signal leaderboard_students_received] con un Array de filas.
func fetch_student_leaderboard(
	session_token: String = "",
	p_dificultad:  String = "",
	p_modo:        String = ""
) -> void:
	var url: String = (
		_db.SUPABASE_URL
		+ "/rest/v1/leaderboards"
		+ "?select=estudiante_id,estudiantes(usuario,grupo_id,grupos(codigo_grupo)),dificultad,modo,variantes_activas,puntuacion,tableros_completados,tiempo,created_at"
		+ "&estudiante_id=not.is.null"
		+ "&order=puntuacion.desc,tableros_completados.desc,tiempo.asc"
		+ "&limit=200"
	)
	if p_dificultad != "":
		url += "&dificultad=eq." + p_dificultad.uri_encode()
	if p_modo != "":
		url += "&modo=eq." + p_modo.uri_encode()

	var headers = _db._headers_student(session_token) if session_token != "" else _db._headers_staff()
	var res: Array = await _db._send(url, headers)
	if not _db._ok(res):
		_db.emit_signal("request_failed", "Error al obtener el ranking de estudiantes.")
		return

	var parsed = _db._parse(res)
	if parsed is Array:
		_db.emit_signal("leaderboard_students_received", parsed)
	else:
		_db.emit_signal("request_failed", "Respuesta inesperada del servidor para el ranking.")


# ── Leaderboard de Profesores ──────────────────────────────────────────────────

## Obtiene el leaderboard de PROFESORES de la misma institución.
## Solo accesible para profesores e instituciones (RLS lo garantiza).
## Emite [signal leaderboard_teachers_received] con un Array de filas.
func fetch_teacher_leaderboard(
	p_dificultad: String = "",
	p_modo:       String = ""
) -> void:
	var url: String = (
		_db.SUPABASE_URL
		+ "/rest/v1/leaderboards"
		+ "?select=profesor_id,profesores(nombre),dificultad,modo,variantes_activas,puntuacion,tableros_completados,tiempo,created_at"
		+ "&profesor_id=not.is.null"
		+ "&order=puntuacion.desc,tableros_completados.desc,tiempo.asc"
		+ "&limit=200"
	)
	if p_dificultad != "":
		url += "&dificultad=eq." + p_dificultad.uri_encode()
	if p_modo != "":
		url += "&modo=eq." + p_modo.uri_encode()

	var res: Array = await _db._send(url, _db._headers_staff())
	if not _db._ok(res):
		_db.emit_signal("request_failed", "Error al obtener el ranking de profesores.")
		return

	var parsed = _db._parse(res)
	if parsed is Array:
		_db.emit_signal("leaderboard_teachers_received", parsed)
	else:
		_db.emit_signal("request_failed", "Respuesta inesperada del servidor para el ranking de profesores.")


# ── Envío de Puntuaciones ──────────────────────────────────────────────────────

## Envía la mejor partida de un estudiante al leaderboard.
## Devuelve true si fue aceptada por el servidor.
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
	var url: String  = _db.SUPABASE_URL + "/rest/v1/leaderboards"
	var body: String = JSON.stringify({
		"estudiante_id":       student_id,
		"dificultad":          dificultad,
		"modo":                modo,
		"variantes_activas":   variantes_activas,
		"puntuacion":          puntuacion,
		"tableros_completados": tableros_completados,
		"tiempo":              tiempo_seg
	})
	var res: Array = await _db._send(url, _db._headers_student(session_token), HTTPClient.METHOD_POST, body)
	return _db._ok(res)


## Envía la mejor partida de un profesor al leaderboard.
## Requiere sesión de staff activa. Devuelve true si fue aceptada.
func submit_teacher_score(
	teacher_id:           String,
	dificultad:           String,
	modo:                 String,
	variantes_activas:    Array,
	puntuacion:           int,
	tableros_completados: int,
	tiempo_seg:           int
) -> bool:
	var url: String  = _db.SUPABASE_URL + "/rest/v1/leaderboards"
	var body: String = JSON.stringify({
		"profesor_id":         teacher_id,
		"dificultad":          dificultad,
		"modo":                modo,
		"variantes_activas":   variantes_activas,
		"puntuacion":          puntuacion,
		"tableros_completados": tableros_completados,
		"tiempo":              tiempo_seg
	})
	var res: Array = await _db._send(url, _db._headers_staff(), HTTPClient.METHOD_POST, body)
	return _db._ok(res)
