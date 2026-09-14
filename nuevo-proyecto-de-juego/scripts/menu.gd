extends Node2D

@onready var _btn_play: Button = $play
@onready var _btn_leaderboard: Button = $leaderboard
@onready var _btn_staff_login: Button = $staff_login
@onready var _btn_student_login: Button = $student_login
@onready var _btn_stats: Button = $stats
@onready var _btn_how_to_play: Button = $how_to_play
@onready var _name_user: Label = $NameUser
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _local_db = $Node
@onready var _alerta_label: Label = $Alerta

@onready var _btn_settings: Button = $settings
@onready var _settings_panel: Panel = $SettingsPanel
@onready var _font_check: CheckButton = $SettingsPanel/VBoxContainer/FontCheck
@onready var _tutorial_font_check: CheckButton = $SettingsPanel/VBoxContainer/TutorialFontCheck
@onready var _btn_close_settings: Button = $SettingsPanel/VBoxContainer/BtnClose

# Nodos del menú principal para atenuar/desactivar al abrir Ajustes
@onready var _menu_buttons: Array[Button] = [
	_btn_play,
	_btn_stats,
	_btn_leaderboard,
	_btn_how_to_play,
	_btn_student_login,
	_btn_staff_login,
	_btn_settings
]

var _tween_panel: Tween = null
var _tween_fade: Tween = null

const POS_CENTER = Vector2(351, 144)
const POS_DOWN = Vector2(351, 750)

func _ready() -> void:
	# Configurar estado de autenticación inicial
	_update_auth_ui()
	
	# Asegurar estado inicial de Ajustes
	_settings_panel.position = POS_DOWN
	_settings_panel.visible = true
	_font_check.button_pressed = Global.use_neutral_font
	_tutorial_font_check.button_pressed = Global.use_neutral_tutorial_font
	
	# Connect buttons
	_btn_play.pressed.connect(_on_play_pressed)
	_btn_leaderboard.pressed.connect(_on_leaderboard_pressed)
	_btn_staff_login.pressed.connect(_on_staff_login_pressed)
	_btn_student_login.pressed.connect(_on_student_login_pressed)
	_btn_stats.pressed.connect(_on_stats_pressed)
	_btn_how_to_play.pressed.connect(_on_how_to_play_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_close_settings.pressed.connect(_on_close_settings_pressed)
	_font_check.toggled.connect(func(pressed: bool): Global.use_neutral_font = pressed)
	_tutorial_font_check.toggled.connect(func(pressed: bool): Global.use_neutral_tutorial_font = pressed)
	
	# Escuchar cambios de sesión
	AuthManager.logout_complete.connect(_update_auth_ui)
	
	# Play title animation if available
	if _animated_sprite:
		_animated_sprite.play("default")

func _on_play_pressed() -> void:
	_save_player_name()
	get_tree().change_scene_to_file("res://scenas/Levels/niveles_list.tscn")

func _on_leaderboard_pressed() -> void:
	_save_player_name()
	get_tree().change_scene_to_file("res://scenas/leaderboard.tscn")

func _on_staff_login_pressed() -> void:
	_save_player_name()
	get_tree().change_scene_to_file("res://scenas/Menus/login_staff.tscn")

func _on_student_login_pressed() -> void:
	if AuthManager.is_logged_in:
		# Cerrar sesión
		_btn_student_login.disabled = true
		await AuthManager.logout()
		_btn_student_login.disabled = false
		_update_auth_ui()
	else:
		_save_player_name()
		get_tree().change_scene_to_file("res://scenas/Menus/login_student.tscn")

func _on_stats_pressed() -> void:
	_save_player_name()
	get_tree().change_scene_to_file("res://scenas/Menus/stats_view.tscn")

func _on_how_to_play_pressed() -> void:
	_save_player_name()
	get_tree().change_scene_to_file("res://scenas/Menus/como_jugar.tscn")

func _save_player_name() -> void:
	if AuthManager.is_logged_in:
		return
	var name_text = _name_user.text.strip_edges()
	if name_text != "":
		RemoteDB.set_player_name(name_text)

func _update_auth_ui() -> void:
	if AuthManager.is_logged_in:
		var prefix = ""
		match AuthManager.session_type:
			"teacher": prefix = "[Profesor] "
			"institution": prefix = "[Institución] "
			"student": prefix = "[Estudiante] "
		_name_user.text = prefix + AuthManager.user_name
		
		if AuthManager.session_type == "student":
			_btn_staff_login.visible = false
			_btn_student_login.text = "Cerrar Sesión"
			_btn_student_login.visible = true
		else:
			# Profesor o Institución
			_btn_staff_login.text = "Control Staff"
			_btn_staff_login.visible = true
			_btn_student_login.visible = false
			
		if AuthManager.session_type == "institution":
			_btn_play.disabled = true
			_alerta_label.visible = true
		else:
			_btn_play.disabled = false
			_alerta_label.visible = false
	else:
		_name_user.text = RemoteDB.player_name

		_btn_staff_login.visible = true
		_btn_student_login.visible = true
		_btn_play.disabled = false
		_alerta_label.visible = false

func _on_settings_pressed() -> void:
	if _tween_panel: _tween_panel.kill()
	if _tween_fade: _tween_fade.kill()
	
	# Desactivar interactividad de botones del menú principal
	for btn in _menu_buttons:
		btn.disabled = true
	
	# Animación de subida del panel
	_tween_panel = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_settings_panel, "position", POS_CENTER, 0.7)
	
	# Atenuar los botones del menú
	_tween_fade = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for btn in _menu_buttons:
		_tween_fade.tween_property(btn, "modulate:a", 0.3, 0.4)

func _on_close_settings_pressed() -> void:
	if _tween_panel: _tween_panel.kill()
	if _tween_fade: _tween_fade.kill()
	
	# Animación de bajada del panel
	_tween_panel = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_settings_panel, "position", POS_DOWN, 0.6)
	
	# Restaurar botones
	_tween_fade = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for btn in _menu_buttons:
		_tween_fade.tween_property(btn, "modulate:a", 1.0, 0.4)
		
	# Reactivar interactividad al terminar la animación
	_tween_panel.finished.connect(func():
		for btn in _menu_buttons:
			btn.disabled = false
	)
