extends Control

@onready var _lbl_modo: Label = $CardContainer/VBoxContainer/GridContainer/LblModoVal
@onready var _lbl_dificultad: Label = $CardContainer/VBoxContainer/GridContainer/LblDificultadVal
@onready var _lbl_puntuacion: Label = $CardContainer/VBoxContainer/GridContainer/LblPuntuacionVal
@onready var _lbl_tiempo: Label = $CardContainer/VBoxContainer/GridContainer/LblTiempoVal
@onready var _lbl_errores: Label = $CardContainer/VBoxContainer/GridContainer/LblErroresVal
@onready var _lbl_semilla: Label = $CardContainer/VBoxContainer/GridContainer/LblSemillaVal

@onready var _btn_copiar: Button = $CardContainer/VBoxContainer/HBoxContainer/BtnCopiar
@onready var _btn_continuar: Button = $CardContainer/VBoxContainer/HBoxContainer/BtnContinuar
@onready var _card_container: Control = $CardContainer

var _seed: int = 0

func _ready() -> void:
	_btn_copiar.pressed.connect(_on_copiar_pressed)
	_btn_continuar.pressed.connect(_on_continuar_pressed)
	
	# Ocultar inicialmente para la animacion
	_card_container.modulate.a = 0.0

func setup(score: int, errors: int, time_seconds: float, boards_count: int, seed_val: int, difficulty: String, mode: String) -> void:
	_seed = seed_val
	
	# Mapear modo sin acentos
	var mode_text: String = "Practica"
	if mode.to_lower() == "challenge" or mode.to_lower() == "desafio":
		mode_text = "Desafio"
		
	# Mapear dificultad sin acentos
	var diff_text: String = "Medio"
	match difficulty.to_lower():
		"facil":
			diff_text = "Facil"
		"medio":
			diff_text = "Medio"
		"dificil":
			diff_text = "Dificil"
		"extremo":
			diff_text = "Extremo"
			
	# Formatear tiempo mm:ss
	var minutes: int = int(time_seconds) / 60
	var seconds: int = int(time_seconds) % 60
	var time_text: String = "%02d:%02d" % [minutes, seconds]
	
	# Asignar textos
	_lbl_modo.text = mode_text
	_lbl_dificultad.text = diff_text
	_lbl_puntuacion.text = str(score)
	_lbl_tiempo.text = time_text
	_lbl_errores.text = str(errors)
	_lbl_semilla.text = str(seed_val)

func play_enter_animation() -> void:
	_card_container.position = Vector2(336, 700)
	_card_container.modulate.a = 0.0
	
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card_container, "position", Vector2(336, 74), 0.6)
	tween.tween_property(_card_container, "modulate:a", 1.0, 0.4)

func _on_copiar_pressed() -> void:
	DisplayServer.clipboard_set(str(_seed))
	_btn_copiar.text = "Copiada!"
	
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(_btn_copiar):
		_btn_copiar.text = "Copiar Semilla"

func _on_continuar_pressed() -> void:
	ScoreManager.reset()
	get_tree().change_scene_to_file("res://scenas/Levels/niveles_list.tscn")
