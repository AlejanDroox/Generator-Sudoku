extends Node2D

# ── Referencias a los 5 contenedores de filas ────────────────────────────────
@onready var _rows: Array[HBoxContainer] = [
	$Control/VBoxContainer/show_score,
	$Control/VBoxContainer/show_score2,
	$Control/VBoxContainer/show_score3,
	$Control/VBoxContainer/show_score4,
	$Control/VBoxContainer/show_score5
]

@onready var _btn_left:   Button = %left
@onready var _btn_right:  Button = %right
@onready var _lbl_page:   Label  = %lbl_page       # "Página X de Y"

const PAGE_SIZE := 5

var _raw_data: Array = []       # todos los datos sin filtrar del servidor
var _filtered_data: Array = []  # datos filtrados localmente
var _page: int = 0              # página actual (base 0)


func _ready() -> void:
	# Conexión de señales de red
	RemoteDB.leaderboard_students_received.connect(_on_data)
	RemoteDB.leaderboard_teachers_received.connect(_on_data)
	RemoteDB.request_failed.connect(_on_fail)
	RemoteDB.entities_fetched.connect(_on_entities_fetched)
	
	# Conexión de botones del panel de clasificación
	_btn_left.pressed.connect(_prev_page)
	_btn_right.pressed.connect(_next_page)
	
	# Conexión de botones del panel de filtros
	%btn_filter_toggle.pressed.connect(_toggle_filter_panel)
	%BtnClose.pressed.connect(_toggle_filter_panel)
	%BtnApply.pressed.connect(_apply_filters)
	%BtnClear.pressed.connect(_clear_filters)
	
	# Configurar opciones iniciales de los desplegables
	_setup_options()
	
	# Cargar datos
	_load_leaderboard_data()


func _setup_options() -> void:
	# Opciones de Modo
	%OptMode.clear()
	%OptMode.add_item("Todos", 0)
	%OptMode.set_item_metadata(0, "")
	%OptMode.add_item("Práctica", 1)
	%OptMode.set_item_metadata(1, "practice")
	%OptMode.add_item("Desafío", 2)
	%OptMode.set_item_metadata(2, "challenge")
	
	# Opciones de Dificultad
	%OptDiff.clear()
	%OptDiff.add_item("Todas", 0)
	%OptDiff.set_item_metadata(0, "")
	%OptDiff.add_item("Fácil", 1)
	%OptDiff.set_item_metadata(1, "facil")
	%OptDiff.add_item("Medio", 2)
	%OptDiff.set_item_metadata(2, "medio")
	%OptDiff.add_item("Difícil", 3)
	%OptDiff.set_item_metadata(3, "dificil")
	%OptDiff.add_item("Extremo", 4)
	%OptDiff.set_item_metadata(4, "extremo")
	
	# Opciones de Ordenación
	%OptSort.clear()
	%OptSort.add_item("Puntuación", 0)
	%OptSort.set_item_metadata(0, "score")
	%OptSort.add_item("Más Tableros", 1)
	%OptSort.set_item_metadata(1, "boards")
	
	# Inicializar desplegable de Grupo (se populará dinámicamente si es staff)
	%OptGroup.clear()
	%OptGroup.add_item("Todos", 0)
	%OptGroup.set_item_metadata(0, "")


func _load_leaderboard_data() -> void:
	if not AuthManager.is_logged_in:
		_show_message_state("Inicia sesion para ver las clasificaciones.")
		return

	_show_message_state("Cargando...")
	
	var is_staff = AuthManager.session_type in ["teacher", "institution"]
	if is_staff:
		RemoteDB.fetch_student_leaderboard()
		RemoteDB.fetch_groups() # Solicitar la lista de grupos para el filtro
	else:
		RemoteDB.fetch_student_leaderboard(AuthManager.student_session_token)


# ── Callbacks RemoteDB ────────────────────────────────────────────────────────

func _on_data(data: Array) -> void:
	_raw_data = data
	_filtered_data = data.duplicate()
	_sort_data("score") # Ordenación por defecto: puntuación
	_page = 0
	
	if _filtered_data.is_empty():
		_show_message_state("No hay registros para mostrar.")
	else:
		_restore_normal_ui()
		_render()


func _on_fail(_err: String) -> void:
	_show_message_state("Error de conexión al obtener clasificaciones.")


func _on_entities_fetched(type: String, list: Array) -> void:
	if type == "group":
		_populate_groups_dropdown(list)


func _populate_groups_dropdown(list: Array) -> void:
	%OptGroup.clear()
	%OptGroup.add_item("Todos", 0)
	%OptGroup.set_item_metadata(0, "")
	var idx = 1
	for g in list:
		if g is Dictionary and g.has("codigo_grupo"):
			var code = g["codigo_grupo"]
			%OptGroup.add_item(code, idx)
			%OptGroup.set_item_metadata(idx, code)
			idx += 1


# ── Animación del Panel de Filtros ────────────────────────────────────────────

func _toggle_filter_panel() -> void:
	if %FilterPanel.visible:
		# Animación de cierre
		var tween = create_tween().set_parallel(true)
		tween.tween_property(%FilterPanel, "scale", Vector2(0.5, 0.5), 0.15)
		tween.tween_property(%FilterPanel, "modulate:a", 0.0, 0.15)
		await tween.finished
		%FilterPanel.visible = false
	else:
		# Animación de apertura
		%FilterPanel.visible = true
		%FilterPanel.scale = Vector2(0.5, 0.5)
		%FilterPanel.modulate.a = 0.0
		%FilterPanel.pivot_offset = %FilterPanel.size / 2.0
		var tween = create_tween().set_parallel(true)
		tween.tween_property(%FilterPanel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(%FilterPanel, "modulate:a", 1.0, 0.25)


# ── Filtrado y Ordenación ─────────────────────────────────────────────────────

func _apply_filters() -> void:
	# 1. Obtener filtros de modo y dificultad
	var mode_idx = %OptMode.selected
	var selected_mode = %OptMode.get_item_metadata(mode_idx) if mode_idx >= 0 else ""
	
	var diff_idx = %OptDiff.selected
	var selected_diff = %OptDiff.get_item_metadata(diff_idx) if diff_idx >= 0 else ""
	
	# 2. Obtener filtro de grupo (solo profesores/instituciones)
	var group_code = ""
	if AuthManager.session_type in ["teacher", "institution"]:
		var group_idx = %OptGroup.selected
		group_code = %OptGroup.get_item_metadata(group_idx) if group_idx >= 0 else ""
	
	# 3. Obtener ordenación seleccionada
	var sort_idx = %OptSort.selected
	var selected_sort = %OptSort.get_item_metadata(sort_idx) if sort_idx >= 0 else "score"
	
	# Filtrar localmente
	_filtered_data = []
	for entry in _raw_data:
		if selected_mode != "" and entry.get("modo", "") != selected_mode:
			continue
		if selected_diff != "" and entry.get("dificultad", "") != selected_diff:
			continue
		if group_code != "" and _get_group_code(entry) != group_code:
			continue
			
		# Filtro de variantes activas (inclusivo: el registro debe tener todas las marcadas)
		var record_vars = entry.get("variantes_activas", [])
		if not (record_vars is Array):
			record_vars = []
		var match_vars = true
		if %ChkKnight.button_pressed and not ("anti_knight" in record_vars):
			match_vars = false
		if %ChkTermo.button_pressed and not ("thermo" in record_vars):
			match_vars = false
		if %ChkKiller.button_pressed and not ("killer" in record_vars):
			match_vars = false
		if %ChkArrow.button_pressed and not ("arrow" in record_vars):
			match_vars = false
		if not match_vars:
			continue
			
		_filtered_data.append(entry)
		
	# Aplicar ordenación
	_sort_data(selected_sort)
	
	# Renderizar
	_page = 0
	if _filtered_data.is_empty():
		_show_message_state("No hay registros que coincidan con los filtros.")
	else:
		_restore_normal_ui()
		_render()
		
	_toggle_filter_panel()


func _clear_filters() -> void:
	%OptMode.selected = 0
	%OptDiff.selected = 0
	if AuthManager.session_type in ["teacher", "institution"]:
		%OptGroup.selected = 0
	%OptSort.selected = 0
	%ChkKnight.button_pressed = false
	%ChkTermo.button_pressed = false
	%ChkKiller.button_pressed = false
	%ChkArrow.button_pressed = false
	
	# Restaurar todos los datos
	_filtered_data = _raw_data.duplicate()
	_sort_data("score")
	_page = 0
	
	if _filtered_data.is_empty():
		_show_message_state("No hay registros para mostrar.")
	else:
		_restore_normal_ui()
		_render()
		
	_toggle_filter_panel()


func _sort_data(sort_type: String) -> void:
	if sort_type == "score":
		_filtered_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var score_a = a.get("puntuacion", 0)
			var score_b = b.get("puntuacion", 0)
			if score_a != score_b:
				return score_a > score_b # Puntos más altos primero
			
			var tab_a = a.get("tableros_completados", 0)
			var tab_b = b.get("tableros_completados", 0)
			if tab_a != tab_b:
				return tab_a < tab_b # Menos tableros es mejor (desempate 1)
			
			var time_a = a.get("tiempo", 0)
			var time_b = b.get("tiempo", 0)
			return time_a < time_b # Menos tiempo es mejor (desempate 2)
		)
	elif sort_type == "boards":
		_filtered_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var tab_a = a.get("tableros_completados", 0)
			var tab_b = b.get("tableros_completados", 0)
			if tab_a != tab_b:
				return tab_a > tab_b # Más tableros completados primero
			
			var score_a = a.get("puntuacion", 0)
			var score_b = b.get("puntuacion", 0)
			if score_a != score_b:
				return score_a > score_b # A igual tableros, más puntos primero
			
			var time_a = a.get("tiempo", 0)
			var time_b = b.get("tiempo", 0)
			return time_a < time_b # Menos tiempo es mejor
		)


func _get_group_code(entry: Dictionary) -> String:
	if entry.has("estudiantes") and entry["estudiantes"] != null:
		var est = entry["estudiantes"]
		if est.has("grupos") and est["grupos"] != null:
			return est["grupos"].get("codigo_grupo", "")
	return ""


# ── Paginación ────────────────────────────────────────────────────────────────

func _prev_page() -> void:
	if _page > 0:
		_page -= 1
		_render()


func _next_page() -> void:
	var total_pages := _total_pages()
	if _page < total_pages - 1:
		_page += 1
		_render()


func _total_pages() -> int:
	return max(1, ceili(float(_filtered_data.size()) / PAGE_SIZE))


# ── Estados de Interfaz y Mensajes ───────────────────────────────────────────

func _show_message_state(msg: String) -> void:
	$Control/VBoxContainer/Cabezeras.visible = false
	_lbl_page.visible = false
	if has_node("%lbl_total"):
		%lbl_total.visible = false
	%btn_filter_toggle.visible = AuthManager.is_logged_in
	_btn_left.visible = false
	_btn_right.visible = false
	
	# Mostrar mensaje en la columna Nombre de la primera fila y ocultar las demás
	for i in range(_rows.size()):
		var row = _rows[i]
		if i == 0:
			row.visible = true
			for child in row.get_children():
				if child.name == "Nombre":
					child.visible = true
					child.text = msg
				else:
					child.visible = false
		else:
			row.visible = false


func _restore_normal_ui() -> void:
	var is_staff = AuthManager.session_type in ["teacher", "institution"]
	
	$Control/VBoxContainer/Cabezeras.visible = true
	$Control/VBoxContainer/Cabezeras/grupo.visible = is_staff
	_lbl_page.visible = true
	if has_node("%lbl_total"):
		%lbl_total.visible = true
	%btn_filter_toggle.visible = true
	_btn_left.visible = true
	_btn_right.visible = true
	
	# Mostrar el filtro de grupo sólo si es profesor o institución
	%RowGroup.visible = is_staff


# ── Renderizado de Filas ──────────────────────────────────────────────────────

func _render() -> void:
	var is_staff = AuthManager.session_type in ["teacher", "institution"]
	var start := _page * PAGE_SIZE
	
	for i in range(PAGE_SIZE):
		var row = _rows[i]
		var idx := start + i
		
		if idx >= _filtered_data.size():
			row.visible = false
			continue
			
		row.visible = true
		
		# Asegurar visibilidad correcta de los componentes de la fila
		for child in row.get_children():
			if child.name == "grupo":
				child.visible = is_staff
			else:
				child.visible = true
				
		var entry: Dictionary = _filtered_data[idx]
		
		# 1. Modo
		var modo_val = entry.get("modo", "")
		var modo_lbl = row.get_node("modo")
		if modo_val == "practice":
			modo_lbl.text = "Guiado"
		elif modo_val == "challenge":
			modo_lbl.text = "Desafio"
		else:
			modo_lbl.text = modo_val.capitalize()
			
		# 2. Nombre
		var name_ : String = "???"
		if entry.has("estudiantes") and entry["estudiantes"] != null:
			name_ = entry["estudiantes"].get("usuario", "???")
		elif entry.has("profesores") and entry["profesores"] != null:
			name_ = entry["profesores"].get("nombre", "???")
		elif entry.has("usuario"):
			name_ = entry.get("usuario", "???")
		row.get_node("Nombre").text = name_
		
		# 3. Dificultad
		var diff_val = entry.get("dificultad", "")
		var diff_lbl = row.get_node("Dificultad")
		match diff_val:
			"facil": diff_lbl.text = "Facil"
			"medio": diff_lbl.text = "Medio"
			"dificil": diff_lbl.text = "Dificil"
			"extremo": diff_lbl.text = "Extremo"
			_: diff_lbl.text = diff_val.capitalize()
			
		# 4. Variantes (toggles de visibilidad en HBoxContainer)
		var record_vars = entry.get("variantes_activas", [])
		if not (record_vars is Array):
			record_vars = []
			
		row.get_node("variantes/HBoxContainer/knight").visible = "anti_knight" in record_vars
		row.get_node("variantes/HBoxContainer/termo").visible = "thermo" in record_vars
		row.get_node("variantes/HBoxContainer/killer").visible = "killer" in record_vars
		row.get_node("variantes/HBoxContainer/arrow").visible = "arrow" in record_vars
		
		# 5. Puntuación
		row.get_node("puntuacio").text = str(entry.get("puntuacion", 0))
		
		# 6. Tiempo
		var secs : int = entry.get("tiempo", 0)
		var mins := secs / 60
		var rem  := secs % 60
		row.get_node("tiempo").text = "%02d:%02d" % [mins, rem]
		
		# 7. Tableros
		row.get_node("tableros").text = str(entry.get("tableros_completados", 0))
		
		# 8. Grupo
		if is_staff:
			row.get_node("grupo").text = _get_group_code(entry)
			
	_update_page_label()
	_btn_left.disabled = _page == 0
	_btn_right.disabled = _page >= _total_pages() - 1


func _update_page_label() -> void:
	if _lbl_page:
		_lbl_page.text = "Pagina %d de %d" % [_page + 1, _total_pages()]
	if has_node("%lbl_total") and %lbl_total:
		%lbl_total.text = "Total de registros: %d" % _filtered_data.size()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")
