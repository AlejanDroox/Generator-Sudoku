extends Control

@onready var seleccionar: Sprite2D = $Seleccionar
@onready var btn_facil: CheckButton = $Facil
@onready var btn_medio: CheckButton = $medio
@onready var btn_dificil: CheckButton = $dificl
@onready var btn_extremo: CheckButton = $extremo

var tween: Tween

func _ready() -> void:
	# Conectar señales de toggled
	btn_facil.toggled.connect(func(pressed): if pressed: _move_selector(btn_facil))
	btn_medio.toggled.connect(func(pressed): if pressed: _move_selector(btn_medio))
	btn_dificil.toggled.connect(func(pressed): if pressed: _move_selector(btn_dificil))
	btn_extremo.toggled.connect(func(pressed): if pressed: _move_selector(btn_extremo))
	
	# Inicializar en Facil
	btn_facil.button_pressed = true
	_move_selector(btn_facil, true) # inmediato sin transicion en ready

func _move_selector(button: CheckButton, immediate: bool = false) -> void:
	if not is_instance_valid(seleccionar) or not is_instance_valid(button):
		return
		
	# Calcular la posición central del botón
	var target_x = button.position.x + (button.size.x / 2.0)
	var target_pos = Vector2(target_x, seleccionar.position.y)
	
	if tween:
		tween.kill()
		
	if immediate:
		seleccionar.position = target_pos
	else:
		tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(seleccionar, "position", target_pos, 0.25)

func get_selected_difficulty() -> int:
	if btn_facil.button_pressed:
		return LevelConfig.DifficultyLevel.EASY
	elif btn_medio.button_pressed:
		return LevelConfig.DifficultyLevel.MEDIUM
	elif btn_dificil.button_pressed:
		return LevelConfig.DifficultyLevel.HARD
	elif btn_extremo.button_pressed:
		return LevelConfig.DifficultyLevel.EXTREME
	return LevelConfig.DifficultyLevel.MEDIUM
