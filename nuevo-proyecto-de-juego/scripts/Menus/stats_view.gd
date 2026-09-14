extends Control
## StatsView — Visualizador de estadísticas acumuladas e historial de récords.

@onready var _lbl_total_games: Label = $PanelStats/VBoxCumulative/GridContainer/LblTotalGames
@onready var _lbl_boards_completed: Label = $PanelStats/VBoxCumulative/GridContainer/LblBoardsCompleted
@onready var _lbl_total_score: Label = $PanelStats/VBoxCumulative/GridContainer/LblTotalScore
@onready var _lbl_total_time: Label = $PanelStats/VBoxCumulative/GridContainer/LblTotalTime
@onready var _lbl_total_errors: Label = $PanelStats/VBoxCumulative/GridContainer/LblTotalErrors
@onready var _lbl_avg_errors: Label = $PanelStats/VBoxCumulative/GridContainer/LblAvgErrors
@onready var _lbl_win_rate: Label = $PanelStats/VBoxCumulative/GridContainer/LblWinRate
@onready var _records_container: VBoxContainer = $PanelRecords/ScrollContainer/VBoxRecords
@onready var _btn_back: Button = $BtnBack

func _ready() -> void:
	_btn_back.pressed.connect(_on_back_pressed)
	_load_stats()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")

func _load_stats() -> void:
	# 1. Cargar estadísticas acumuladas
	var c_stats = LocalDB.get_cumulative_stats()
	var total_games = c_stats.get("total_partidas", 0)
	var boards_completed = c_stats.get("total_tableros_completados", 0)
	var total_score = c_stats.get("total_puntos", 0)
	var total_time = c_stats.get("total_tiempo", 0)
	var total_errors = c_stats.get("total_errores", 0)
	var avg_errors = c_stats.get("promedio_errores", 0.0)
	var wins = c_stats.get("partidas_ganadas", 0)
	
	var win_rate = (float(wins) / float(total_games) * 100.0) if total_games > 0 else 0.0
	
	# Formatear tiempo
	var hours = int(total_time) / 3600
	var minutes = (int(total_time) % 3600) / 60
	var seconds = int(total_time) % 60
	var time_str = ""
	if hours > 0:
		time_str = "%dh %dm" % [hours, minutes]
	else:
		time_str = "%dm %ds" % [minutes, seconds]

	_lbl_total_games.text = str(total_games)
	_lbl_boards_completed.text = str(boards_completed)
	_lbl_total_score.text = str(total_score)
	_lbl_total_time.text = time_str
	_lbl_total_errors.text = str(total_errors)
	_lbl_avg_errors.text = "%.2f" % avg_errors
	_lbl_win_rate.text = "%.1f%% (%d/%d)" % [win_rate, wins, total_games]

	# 2. Cargar récords (best runs)
	for child in _records_container.get_children():
		child.queue_free()

	var full_data = LocalDB.get_full_data()
	var best_runs = full_data.get("best_runs", {})

	if best_runs.is_empty():
		var lbl = Label.new()
		lbl.text = "No se registran récords aún.\n¡Completa tu primer nivel para verlos!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_records_container.add_child(lbl)
		return

	# Ordenar los récords por clave
	var keys = best_runs.keys()
	keys.sort()

	for key in keys:
		var record = best_runs[key]
		if not record is Dictionary:
			continue
		
		# Extraer datos formateados
		var modo = record.get("modo", "???").capitalize()
		var dificultad = record.get("dificultad", "???").capitalize()
		var score = record.get("score", 0)
		var tableros = record.get("tableros_completados", 0)
		var tiempo = record.get("tiempo_seg", 0)
		var errores = record.get("errores", 0)
		var variantes = record.get("variantes", [])
		var date = record.get("date", "")

		var var_names = []
		for v in variantes:
			var_names.append(v.replace("_", " ").capitalize())
		var var_str = ", ".join(var_names) if not var_names.is_empty() else "Ninguna"

		# Formatear tiempo en mm:ss
		var mins = int(tiempo) / 60
		var secs = int(tiempo) % 60
		var time_fmt = "%02d:%02d" % [mins, secs]

		# Crear un panel contenedor elegante para cada fila de récord
		var row_panel = PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 85)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		row_panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)
		
		# Fila 1: Título de configuración y fecha
		var hbox1 = HBoxContainer.new()
		vbox.add_child(hbox1)
		
		var lbl_title = Label.new()
		lbl_title.text = "%s — Dificultad %s" % [modo, dificultad]
		lbl_title.add_theme_font_size_override("font_size", 15)
		hbox1.add_child(lbl_title)
		
		# Espaciador
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox1.add_child(spacer)
		
		var lbl_date = Label.new()
		lbl_date.text = date
		lbl_date.add_theme_font_size_override("font_size", 11)
		lbl_date.self_modulate = Color(0.7, 0.7, 0.7)
		hbox1.add_child(lbl_date)
		
		# Fila 2: Detalles de la marca
		var hbox2 = HBoxContainer.new()
		vbox.add_child(hbox2)
		
		var lbl_stats = Label.new()
		lbl_stats.text = "%d pts  |  %d Tableros  |  %s  |  %d Errores" % [score, tableros, time_fmt, errores]
		lbl_stats.add_theme_font_size_override("font_size", 13)
		hbox2.add_child(lbl_stats)
		
		# Fila 3: Variantes
		var lbl_vars = Label.new()
		lbl_vars.text = "Variantes: %s" % var_str
		lbl_vars.add_theme_font_size_override("font_size", 11)
		lbl_vars.self_modulate = Color(0.5, 0.8, 1.0)
		vbox.add_child(lbl_vars)

		_records_container.add_child(row_panel)
