extends Node2D

signal back_pressed

@onready var lbl_num_boards: Label = $Control/NumBoard/num
@onready var btn_plus: Button = $"Control/NumBoard/+"
@onready var btn_minus: Button = $"Control/NumBoard/-"

@onready var select_dificultad: Control = $Control/SelectDificultada

@onready var btn_guiado: CheckButton = $Control/Modo/Guiado
@onready var btn_desafio: CheckButton = $Control/Modo/Desafio
@onready var x_guiado: Sprite2D = $Control/Modo/X_Guiado
@onready var x_desafio: Sprite2D = $Control/Modo/X_Desafio

@onready var btn_clasico: CheckButton = $Control/Variantes/BotonClasico
@onready var btn_ac: CheckButton = $"Control/Variantes/BotonA-C"
@onready var btn_killer: CheckButton = $Control/Variantes/BotonKiller
@onready var btn_termo: CheckButton = $Control/Variantes/BotonTermo
@onready var btn_flecha: CheckButton = $Control/Variantes/BotonFlecha

@onready var x_clasico: Sprite2D = $Control/Variantes/Clasico
@onready var x_ac: Sprite2D = $"Control/Variantes/Anti-Caballo"
@onready var x_killer: Sprite2D = $Control/Variantes/Killer
@onready var x_termo: Sprite2D = $Control/Variantes/Termo
@onready var x_flecha: Sprite2D = $Control/Variantes/Flecha

@onready var btn_complejidad: CheckButton = $Control/Avanzado/BotonComplejidad
@onready var btn_primer_tablero: CheckButton = $Control/Avanzado/BotonPrimerTablero
@onready var x_complejidad: Sprite2D = $Control/Avanzado/X_Complejidad
@onready var x_primer_tablero: Sprite2D = $Control/Avanzado/X_PrimerTablero

@onready var txt_semilla: TextEdit = $Control/Avanzado/Semilla

@onready var btn_back: Button = $Control/back
@onready var btn_jugar: Button = $Control/Jugar

var total_boards: int = 3

func _ready() -> void:
	# 1. Configurar cantidad de tableros
	_update_boards_label()
	btn_plus.pressed.connect(func():
		if total_boards < 25:
			total_boards += 1
			_update_boards_label()
	)
	btn_minus.pressed.connect(func():
		if total_boards > 1:
			total_boards -= 1
			_update_boards_label()
	)

	# 2. Configurar modo
	# Inicializar en Guiado (Práctica)
	btn_guiado.button_pressed = true
	x_guiado.visible = true
	x_desafio.visible = false
	
	btn_guiado.toggled.connect(func(pressed):
		x_guiado.visible = pressed
	)
	btn_desafio.toggled.connect(func(pressed):
		x_desafio.visible = pressed
	)

	# 3. Configurar variantes
	# Conectar toggles a visibilidad de X
	btn_clasico.toggled.connect(func(pressed):
		# Al menos una variante debe estar seleccionada
		if not pressed and not _has_any_variant_selected_except(btn_clasico):
			btn_clasico.button_pressed = true # Re-check
			return
		x_clasico.visible = btn_clasico.button_pressed
	)
	btn_ac.toggled.connect(func(pressed):
		if not pressed and not _has_any_variant_selected_except(btn_ac):
			btn_ac.button_pressed = true
			return
		x_ac.visible = btn_ac.button_pressed
	)
	btn_killer.toggled.connect(func(pressed):
		if not pressed and not _has_any_variant_selected_except(btn_killer):
			btn_killer.button_pressed = true
			return
		x_killer.visible = btn_killer.button_pressed
	)
	btn_termo.toggled.connect(func(pressed):
		if not pressed and not _has_any_variant_selected_except(btn_termo):
			btn_termo.button_pressed = true
			return
		x_termo.visible = btn_termo.button_pressed
	)
	btn_flecha.toggled.connect(func(pressed):
		if not pressed and not _has_any_variant_selected_except(btn_flecha):
			btn_flecha.button_pressed = true
			return
		x_flecha.visible = btn_flecha.button_pressed
	)

	# Configurar estado inicial de variantes (solo clásico seleccionado por defecto)
	btn_clasico.button_pressed = true
	x_clasico.visible = true
	btn_ac.button_pressed = false
	x_ac.visible = false
	btn_killer.button_pressed = false
	x_killer.visible = false
	btn_termo.button_pressed = false
	x_termo.visible = false
	btn_flecha.button_pressed = false
	x_flecha.visible = false

	# 4. Configurar avanzados (seleccionados por defecto)
	btn_complejidad.button_pressed = true
	x_complejidad.visible = true
	btn_complejidad.toggled.connect(func(pressed):
		x_complejidad.visible = pressed
	)

	btn_primer_tablero.button_pressed = true
	x_primer_tablero.visible = true
	btn_primer_tablero.toggled.connect(func(pressed):
		x_primer_tablero.visible = pressed
	)

	# 5. Botón Volver y Jugar
	btn_back.pressed.connect(func():
		back_pressed.emit()
		if back_pressed.get_connections().is_empty():
			get_tree().change_scene_to_file("res://scenas/Levels/niveles_list.tscn")
	)
	
	btn_jugar.pressed.connect(_on_jugar_pressed)

func _update_boards_label() -> void:
	lbl_num_boards.text = str(total_boards)

func _has_any_variant_selected_except(exclude_btn: CheckButton) -> bool:
	if btn_clasico != exclude_btn and btn_clasico.button_pressed: return true
	if btn_ac != exclude_btn and btn_ac.button_pressed: return true
	if btn_killer != exclude_btn and btn_killer.button_pressed: return true
	if btn_termo != exclude_btn and btn_termo.button_pressed: return true
	if btn_flecha != exclude_btn and btn_flecha.button_pressed: return true
	return false

func _on_jugar_pressed() -> void:
	# Crear y configurar recurso LevelConfig
	var config = LevelConfig.new()
	config.is_custom = true
	config.total_boards = total_boards
	
	# Mapear dificultad del script SelectDificultada
	if select_dificultad.has_method("get_selected_difficulty"):
		config.difficulty_level = select_dificultad.get_selected_difficulty()
	
	# Mapear modo de juego
	if btn_desafio.button_pressed:
		config.game_mode = Global.GameMode.CHALLENGE
	else:
		config.game_mode = Global.GameMode.PRACTICE
		
	# Mapear variantes habilitadas
	var valid_vars: Array[int] = []
	if btn_clasico.button_pressed:
		valid_vars.append(SudokuGenerator.VariantType.CLASSIC)
	if btn_ac.button_pressed:
		valid_vars.append(SudokuGenerator.VariantType.ANTI_KNIGHT)
	if btn_killer.button_pressed:
		valid_vars.append(SudokuGenerator.VariantType.KILLER)
	if btn_termo.button_pressed:
		valid_vars.append(SudokuGenerator.VariantType.THERMO)
	if btn_flecha.button_pressed:
		valid_vars.append(SudokuGenerator.VariantType.ARROW)
	config.valid_variants = valid_vars
	
	# Opciones avanzadas
	config.progressive_complexity = btn_complejidad.button_pressed
	config.first_board_has_variants = btn_primer_tablero.button_pressed
	
	# Semilla
	var seed_text = txt_semilla.text.strip_edges()
	if seed_text.is_valid_int():
		config.custom_rng_seed = int(seed_text)
	else:
		config.custom_rng_seed = 0
		
	# Guardar en Global e iniciar nivel
	Global.custom_level_config = config
	get_tree().change_scene_to_file("res://scenas/Levels/samurai_level.tscn")
