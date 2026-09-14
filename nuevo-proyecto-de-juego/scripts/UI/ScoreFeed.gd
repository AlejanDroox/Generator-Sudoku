extends VBoxContainer

@export var item_lifetime: float = 5.0
@export var feed_width: float = 300.0
@export var feed_height: float = 30.0

func _ready() -> void:
	# Alinear los elementos hacia el final (abajo del feed)
	alignment = BoxContainer.ALIGNMENT_END
	
	if ScoreManager.has_signal("achievement_unlocked"):
		ScoreManager.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(type: StringName, base_points: int, multiplier: float, final_points: int) -> void:
	var desc = ""
	match type:
		&"correct_cell":
			desc = "casilla marcada"
		&"redemption_bonus":
			desc = "bono redencion"
		&"variant_constraint":
			desc = "restriccion variante"
		&"row_complete":
			desc = "fila completada"
		&"col_complete":
			desc = "columna completada"
		&"sector_complete":
			desc = "sector completado"
		&"sudoku_complete":
			desc = "tablero completado"
		&"perfect_board":
			desc = "sudoku perfecto!"
		&"combo_double":
			desc = "combo doble!"
		&"combo_triple":
			desc = "combo triple!"
		&"penalty":
			desc = "penalizacion"
		&"validation_penalty":
			desc = "penalizacion validacion"
		_:
			desc = str(type).replace("_", " ")

	# Generar texto de notificación estilo Twitch
	var text_msg = ""
	if final_points > 0:
		text_msg = "+%d * x%.1f (%s)" % [base_points, multiplier, desc]
	else:
		# Penalizaciones
		text_msg = "%d (%s)" % [final_points, desc]

	# Crear contenedor wrapper para posibilitar animación X del Label dentro del VBoxContainer
	var wrapper = Control.new()
	wrapper.custom_minimum_size = Vector2(feed_width, feed_height)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = text_msg
	label.size = Vector2(feed_width, feed_height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var label_settings = LabelSettings.new()
	label_settings.font_size = 15
	label_settings.outline_color = Color.BLACK
	label_settings.outline_size = 4
	
	if final_points > 0:
		# Destacar logros especiales en dorado/amarillo
		if type in [&"row_complete", &"col_complete", &"sector_complete", &"sudoku_complete", &"perfect_board", &"combo_double", &"combo_triple"]:
			label_settings.font_color = Color.GOLD
		else:
			label_settings.font_color = Color.WHITE
	else:
		label_settings.font_color = Color.RED
		
	# Usar fuente personalizada del proyecto si está disponible
	var shonen_font = load("res://extra/fuentes/ShonenPunk custom bold.ttf")
	if shonen_font:
		label_settings.font = shonen_font

	label.label_settings = label_settings
	wrapper.add_child(label)
	add_child(wrapper)
	
	# Animación de entrada: derecha a izquierda y opacidad
	label.position.x = 200.0
	label.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Desvanecimiento tras 5 segundos
	var timer_tween = create_tween()
	timer_tween.tween_interval(item_lifetime)
	timer_tween.tween_property(wrapper, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	timer_tween.tween_callback(wrapper.queue_free)
