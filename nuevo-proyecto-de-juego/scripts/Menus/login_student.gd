extends Control
## LoginStudent — Controlador para el inicio de sesión de estudiantes.

@onready var _username_input: LineEdit = $LoginPanel/VBoxContainer/UsernameInput
@onready var _pin_input: LineEdit = $LoginPanel/VBoxContainer/PinInput
@onready var _btn_login: Button = $LoginPanel/VBoxContainer/BtnLogin
@onready var _btn_back: Button = $LoginPanel/VBoxContainer/BtnBack
@onready var _status_label: Label = $StatusLabel
@onready var _login_panel: Panel = $LoginPanel

var _tween: Tween = null

func _ready() -> void:
	# Configurar estado inicial
	_status_label.text = ""
	_login_panel.scale = Vector2(0.5, 0.5)
	_login_panel.pivot_offset = _login_panel.size / 2.0
	_login_panel.modulate.a = 0.0
	
	# Animar panel de entrada
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_login_panel, "scale", Vector2.ONE, 0.6)
	_tween.tween_property(_login_panel, "modulate:a", 1.0, 0.6)
	
	# Conectar señales de AuthManager
	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_login_failed)
	
	_btn_login.pressed.connect(_on_login_pressed)
	_btn_back.pressed.connect(_on_back_pressed)

func _exit_tree() -> void:
	# Desconectar señales de forma segura
	if AuthManager.login_success.is_connected(_on_login_success):
		AuthManager.login_success.disconnect(_on_login_success)
	if AuthManager.login_failed.is_connected(_on_login_failed):
		AuthManager.login_failed.disconnect(_on_login_failed)

func _on_login_pressed() -> void:
	var username = _username_input.text.strip_edges()
	var pin = _pin_input.text.strip_edges()
	
	if username.is_empty():
		_show_status("El nombre de usuario es obligatorio.", Color.RED)
		return
	if pin.is_empty():
		_show_status("El PIN es obligatorio.", Color.RED)
		return
	if pin.length() != 6 or not pin.is_valid_int():
		_show_status("El PIN debe tener exactamente 6 dígitos.", Color.RED)
		return
		
	_set_inputs_disabled(true)
	_show_status("Iniciando sesión...", Color.WHITE)
	
	AuthManager.login_student(username, pin)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")

func _on_login_success(session_type: String) -> void:
	if session_type == "student":
		_show_status("¡Bienvenido, " + AuthManager.user_name + "!", Color.GREEN)
		# Pequeño retardo para feedback visual
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")

func _on_login_failed(reason: String) -> void:
	_set_inputs_disabled(false)
	_show_status(reason, Color.RED)

func _show_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.label_settings.font_color = color

func _set_inputs_disabled(disabled: bool) -> void:
	_username_input.editable = not disabled
	_pin_input.editable = not disabled
	_btn_login.disabled = disabled
	_btn_back.disabled = disabled
