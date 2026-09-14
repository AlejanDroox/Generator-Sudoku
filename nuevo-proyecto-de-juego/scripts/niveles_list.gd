extends Node2D

@onready var _btn_back: Button = $Container/btn_back
@onready var _btn_custom: Button = $BoxContainer/Perzonalizado/VBoxContainer/btn_custom

@onready var _container: BoxContainer = $Container
@onready var _box_container: VBoxContainer = $BoxContainer
@onready var _custom_panel: Node2D = $PerzonalizacionNivel

# Referencias a botones de niveles predefinidos
@onready var _btn_ac_p: Button = $BoxContainer/AntiCaballo/AC_P
@onready var _btn_ac_d: Button = $BoxContainer/AntiCaballo/AC_D
@onready var _btn_killer_p: Button = $BoxContainer/Killer/Killer_P
@onready var _btn_killer_d: Button = $BoxContainer/Killer/Killer_D
@onready var _btn_termo_p: Button = $BoxContainer/Termo/Termo_P
@onready var _btn_termo_d: Button = $BoxContainer/Termo/Termo_D
@onready var _btn_arrow_p: Button = $BoxContainer/Arrow/Arrow_P
@onready var _btn_arrow_d: Button = $BoxContainer/Arrow/Arrow_D

## Botón de reanudar partida (ya colocado en la escena por el diseñador).
## Se oculta automáticamente si no existe una partida guardada activa.
@onready var _btn_resume: Button = $BoxContainer/Perzonalizado/VBoxContainer/btn_reanudar
var _tween_panel: Tween
var _tween_ui: Tween

func _ready() -> void:
	# Botón de reanudar: visible sólo si hay una partida guardada activa
	_btn_resume.visible = SaveGameManager.has_saved_game()
	_btn_resume.pressed.connect(_on_resume_pressed)

	# Conectar botones básicos
	_btn_back.pressed.connect(_on_back_pressed)
	_btn_custom.pressed.connect(_on_custom_pressed)
	
	# Conectar botones de niveles predefinidos
	_btn_ac_p.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_anti_knightP.tres"))
	_btn_ac_d.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_anti_knigtD.tres"))
	_btn_killer_p.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_killerP.tres"))
	_btn_killer_d.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_killerD.tres"))
	_btn_termo_p.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_TermoP.tres"))
	_btn_termo_d.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_TermoD.tres"))
	_btn_arrow_p.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_arrowP.tres"))
	_btn_arrow_d.pressed.connect(func(): _load_predefined_level("res://extra/Levels/only_arrowD.tres"))
	
	# Asegurar posición inicial fuera de pantalla
	_custom_panel.position = Vector2(210, 750)
	
	# Conectar señal de volver de la personalización
	_custom_panel.back_pressed.connect(_on_custom_back_pressed)


func _on_resume_pressed() -> void:
	Global.active_save_to_resume = SaveGameManager.load_active_game()
	if Global.active_save_to_resume.is_empty():
		# El archivo estaba corrupto o fue borrado entre frames; ocultar el botón
		_btn_resume.visible = false
		return
	# Limpiar la configuración de nivel personalizado para no interferir
	Global.custom_level_config = null
	get_tree().change_scene_to_file("res://scenas/Levels/samurai_level.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")

func _on_custom_pressed() -> void:
	# Detener tweens anteriores si existen
	if _tween_panel: _tween_panel.kill()
	if _tween_ui: _tween_ui.kill()
	
	# Desactivar interactividad de la lista de niveles
	_container.process_mode = PROCESS_MODE_DISABLED
	_box_container.process_mode = PROCESS_MODE_DISABLED
	
	# Animación de subida con tambaleo (TRANS_BACK, EASE_OUT)
	_tween_panel = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_custom_panel, "position", Vector2(210, 83), 0.7)
	
	# Atenuar visualmente la lista de niveles
	_tween_ui = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_ui.tween_property(_container, "modulate:a", 0.3, 0.4)
	_tween_ui.tween_property(_box_container, "modulate:a", 0.3, 0.4)

func _on_custom_back_pressed() -> void:
	if _tween_panel: _tween_panel.kill()
	if _tween_ui: _tween_ui.kill()
	
	# Animación de caída hacia abajo (TRANS_BACK, EASE_IN)
	_tween_panel = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_custom_panel, "position", Vector2(210, 750), 0.6)
	
	# Restaurar visualmente la lista de niveles
	_tween_ui = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_ui.tween_property(_container, "modulate:a", 1.0, 0.4)
	_tween_ui.tween_property(_box_container, "modulate:a", 1.0, 0.4)
	
	# Reactivar interactividad una vez termine de caer
	_tween_panel.finished.connect(func():
		_container.process_mode = PROCESS_MODE_INHERIT
		_box_container.process_mode = PROCESS_MODE_INHERIT
	)

func _load_predefined_level(path: String) -> void:
	var level_res = load(path)
	if level_res:
		# Asignar modo de juego en el recurso según el nombre del archivo
		if "game_mode" in level_res:
			if path.ends_with("P.tres"):
				level_res.game_mode = Global.GameMode.PRACTICE
			else:
				level_res.game_mode = Global.GameMode.CHALLENGE
			
		Global.custom_level_config = level_res
		print("niveles_list: Cargando nivel predefinido desde ", path)
		get_tree().change_scene_to_file("res://scenas/Levels/samurai_level.tscn")
	else:
		push_error("niveles_list: Error al cargar el recurso del nivel en: " + path)
