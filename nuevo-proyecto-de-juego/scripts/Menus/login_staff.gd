extends Control
## LoginStaff — Controlador para la interfaz de inicio de sesión y gestión administrativa (CRUD de Profesores, Grupos y Estudiantes).

# ── Constantes de Posicionamiento ──
const POS_CENTER := Vector2(351, 144)
const POS_DOWN := Vector2(351, 700)
const POS_UP := Vector2(351, -450)

# ── Estilo Unificado ──
@onready var _label_style: LabelSettings = preload("res://scenas/Menus/login_staff.tscn").instantiate().get_node("LoginPanel/VBoxContainer/Title").label_settings

# ── Paneles principales ──
@onready var _login_panel: Panel = $LoginPanel
@onready var _change_panel: Panel = $ChangePasswordPanel
@onready var _dashboard_panel: Panel = $DashboardPanel
@onready var _list_panel: Panel = $ListManagerPanel
@onready var _edit_panel: Panel = $EditEntityPanel

# ── Paneles de creación ──
@onready var _create_teacher_panel: Panel = $CreateTeacherPanel
@onready var _create_group_panel: Panel = $CreateGroupPanel
@onready var _create_student_panel: Panel = $CreateStudentPanel

# ── Inputs del Login ──
@onready var _email_input: LineEdit = $LoginPanel/VBoxContainer/EmailInput
@onready var _password_input: LineEdit = $LoginPanel/VBoxContainer/PasswordInput
@onready var _btn_login: Button = $LoginPanel/VBoxContainer/BtnLogin
@onready var _btn_back: Button = $LoginPanel/VBoxContainer/BtnBack

# ── Inputs de Cambio de Contraseña ──
@onready var _new_password_input: LineEdit = $ChangePasswordPanel/VBoxContainer/NewPasswordInput
@onready var _confirm_password_input: LineEdit = $ChangePasswordPanel/VBoxContainer/ConfirmPasswordInput
@onready var _btn_confirm_change: Button = $ChangePasswordPanel/VBoxContainer/BtnConfirmChange

# ── Elementos del Dashboard ──
@onready var _lbl_user_name: Label = $DashboardPanel/VBoxContainer/GridContainer/LblUserName
@onready var _lbl_user_role: Label = $DashboardPanel/VBoxContainer/GridContainer/LblUserRole
@onready var _lbl_user_id: Label = $DashboardPanel/VBoxContainer/GridContainer/LblUserId

@onready var _btn_show_create_teacher: Button = $DashboardPanel/VBoxContainer/HBoxCreate/BtnShowCreateTeacher
@onready var _btn_show_create_group: Button = $DashboardPanel/VBoxContainer/HBoxCreate/BtnShowCreateGroup
@onready var _btn_show_create_student: Button = $DashboardPanel/VBoxContainer/HBoxCreate/BtnShowCreateStudent

@onready var _btn_manage_teachers: Button = $DashboardPanel/VBoxContainer/HBoxManage/BtnManageTeachers
@onready var _btn_manage_groups: Button = $DashboardPanel/VBoxContainer/HBoxManage/BtnManageGroups
@onready var _btn_manage_students: Button = $DashboardPanel/VBoxContainer/HBoxManage/BtnManageStudents
@onready var _btn_logout: Button = $DashboardPanel/VBoxContainer/BtnLogout
@onready var _btn_back_to_menu: Button = $DashboardPanel/VBoxContainer/BtnBackToMenu

# ── Inputs de Creación de Profesor ──
@onready var _t_email_input: LineEdit = $CreateTeacherPanel/VBoxContainer/EmailInput
@onready var _t_password_input: LineEdit = $CreateTeacherPanel/VBoxContainer/PasswordInput
@onready var _t_name_input: LineEdit = $CreateTeacherPanel/VBoxContainer/NameInput
@onready var _t_btn_create: Button = $CreateTeacherPanel/VBoxContainer/BtnCreateTeacher
@onready var _t_btn_cancel: Button = $CreateTeacherPanel/VBoxContainer/BtnCancelTeacher

# ── Inputs de Creación de Grupo ──
@onready var _g_code_input: LineEdit = $CreateGroupPanel/VBoxContainer/CodeInput
@onready var _g_teacher_input: OptionButton = $CreateGroupPanel/VBoxContainer/TeacherInput
@onready var _g_btn_create: Button = $CreateGroupPanel/VBoxContainer/BtnCreateGroup
@onready var _g_btn_cancel: Button = $CreateGroupPanel/VBoxContainer/BtnCancelGroup

# ── Inputs de Creación de Estudiante ──
@onready var _s_username_input: LineEdit = $CreateStudentPanel/VBoxContainer/UsernameInput
@onready var _s_group_input: OptionButton = $CreateStudentPanel/VBoxContainer/GroupInput
@onready var _s_pin_input: LineEdit = $CreateStudentPanel/VBoxContainer/PinInput
@onready var _s_btn_create: Button = $CreateStudentPanel/VBoxContainer/BtnCreateStudent
@onready var _s_btn_cancel: Button = $CreateStudentPanel/VBoxContainer/BtnCancelStudent

# ── Elementos de Lista de Gestión ──
@onready var _list_title: Label = $ListManagerPanel/VBoxContainer/Title
@onready var _list_container: VBoxContainer = $ListManagerPanel/VBoxContainer/ScrollContainer/VBoxContainer
@onready var _list_btn_close: Button = $ListManagerPanel/VBoxContainer/BtnCloseList

# ── Elementos del Editor de Entidad (Pop-up/Overlay) ──
@onready var _edit_title: Label = $EditEntityPanel/VBoxContainer/Title
@onready var _edit_input1: LineEdit = $EditEntityPanel/VBoxContainer/EditInput1
@onready var _edit_input2: LineEdit = $EditEntityPanel/VBoxContainer/EditInput2
@onready var _edit_input3: LineEdit = $EditEntityPanel/VBoxContainer/EditInput3
@onready var _edit_btn_confirm: Button = $EditEntityPanel/VBoxContainer/BtnConfirmEdit
@onready var _edit_btn_cancel: Button = $EditEntityPanel/VBoxContainer/BtnCancelEdit

# ── Panel de Reportes ──
@onready var _report_panel: Panel = $ReportManagerPanel
@onready var _opt_report_type: OptionButton = $ReportManagerPanel/VBoxContainer/HBoxType/OptReportType
@onready var _hbox_group: HBoxContainer = $ReportManagerPanel/VBoxContainer/HBoxGroup
@onready var _opt_report_group: OptionButton = $ReportManagerPanel/VBoxContainer/HBoxGroup/OptReportGroup
@onready var _lb_filters: VBoxContainer = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer
@onready var _opt_lb_modo: OptionButton = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridParams/OptLbModo
@onready var _opt_lb_diff: OptionButton = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridParams/OptLbDiff
@onready var _opt_lb_order: OptionButton = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridParams/OptLbOrder
@onready var _chk_anti_knight: CheckBox = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridVariants/ChkAntiKnight
@onready var _chk_thermo: CheckBox = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridVariants/ChkThermo
@onready var _chk_killer: CheckBox = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridVariants/ChkKiller
@onready var _chk_arrow: CheckBox = $ReportManagerPanel/VBoxContainer/LeaderboardFiltersContainer/GridVariants/ChkArrow
@onready var _btn_generate_report: Button = $ReportManagerPanel/VBoxContainer/BtnGenerateReport
@onready var _btn_close_reports: Button = $ReportManagerPanel/VBoxContainer/BtnCloseReports

# ── Estado general ──
@onready var _status_label: Label = $StatusLabel

var _t_group_dropdown: OptionButton = null
var _edit_dropdown: OptionButton = null

var _active_creation_panel: Panel = null
var _active_sub_panel: Panel = null # Para lista/edición
var _tween_panel: Tween = null
var _tween_fade: Tween = null

# Estado CRUD
var _current_entity_type: String = "" # "teacher" | "group" | "student"
var _editing_id: String = ""
var _editing_mode: String = "" # "teacher" | "group" | "student" | "pin"

func _ready() -> void:
	# Posicionar inicialmente los paneles fuera de escena
	_login_panel.position = POS_CENTER
	_login_panel.show()
	_login_panel.modulate.a = 1.0

	_change_panel.position = POS_DOWN
	_change_panel.hide()

	_dashboard_panel.position = POS_UP
	_dashboard_panel.modulate.a = 0.0
	_dashboard_panel.hide()

	_create_teacher_panel.position = POS_DOWN
	_create_teacher_panel.hide()

	_create_group_panel.position = POS_DOWN
	_create_group_panel.hide()

	_create_student_panel.position = POS_DOWN
	_create_student_panel.hide()

	_list_panel.position = POS_DOWN
	_list_panel.hide()

	_edit_panel.position = POS_DOWN
	_edit_panel.hide()

	_report_panel.position = POS_DOWN
	_report_panel.hide()

	_status_label.text = ""

	# Dynamic GroupDropdown for CreateTeacherPanel
	_t_group_dropdown = OptionButton.new()
	_t_group_dropdown.name = "GroupDropdown"
	_t_group_dropdown.custom_minimum_size = Vector2(0, 40)
	$CreateTeacherPanel/VBoxContainer.add_child(_t_group_dropdown)
	$CreateTeacherPanel/VBoxContainer.move_child(_t_group_dropdown, 4)
	
	# Dynamic Dropdown for EditEntityPanel
	_edit_dropdown = OptionButton.new()
	_edit_dropdown.name = "EditDropdown"
	_edit_dropdown.custom_minimum_size = Vector2(0, 40)
	$EditEntityPanel/VBoxContainer.add_child(_edit_dropdown)
	$EditEntityPanel/VBoxContainer.move_child(_edit_dropdown, 4)
	_edit_dropdown.visible = false

	# Configurar campos ocultos
	_password_input.secret = true
	_new_password_input.secret = true
	_confirm_password_input.secret = true
	_t_password_input.secret = true

	# Conectar botones de sesión
	_btn_login.pressed.connect(_on_login_pressed)
	_btn_back.pressed.connect(_on_back_pressed)
	_btn_confirm_change.pressed.connect(_on_confirm_change_pressed)
	_btn_logout.pressed.connect(_on_logout_pressed)

	# Conectar botones de apertura de creación
	_btn_show_create_teacher.pressed.connect(func():
		_slide_panel_in(_create_teacher_panel)
		_fill_groups_in_dropdown(_t_group_dropdown)
	)
	_btn_show_create_group.pressed.connect(func():
		_slide_panel_in(_create_group_panel)
		_populate_teachers_dropdown()
	)
	_btn_show_create_student.pressed.connect(func():
		_slide_panel_in(_create_student_panel)
		_populate_groups_dropdown()
	)

	# Conectar botones de apertura de gestión (listas)
	_btn_manage_teachers.pressed.connect(func(): _fetch_and_show_list("teacher"))
	_btn_manage_groups.pressed.connect(func(): _fetch_and_show_list("group"))
	_btn_manage_students.pressed.connect(func(): _fetch_and_show_list("student"))

	# Conectar botones de cancelación de creación
	_t_btn_cancel.pressed.connect(func(): _slide_panel_out(_create_teacher_panel))
	_g_btn_cancel.pressed.connect(func(): _slide_panel_out(_create_group_panel))
	_s_btn_cancel.pressed.connect(func(): _slide_panel_out(_create_student_panel))

	# Conectar botones de acción de creación
	_t_btn_create.pressed.connect(_on_create_teacher_submit)
	_g_btn_create.pressed.connect(_on_create_group_submit)
	_s_btn_create.pressed.connect(_on_create_student_submit)

	# Conectar controles de lista
	_list_btn_close.pressed.connect(_close_list_panel)

	# Conectar controles del editor
	_edit_btn_cancel.pressed.connect(_close_edit_panel)
	_edit_btn_confirm.pressed.connect(_on_edit_submit)

	# Conectar señales de AuthManager
	AuthManager.login_success.connect(_on_auth_success)
	AuthManager.login_failed.connect(_on_auth_failed)
	AuthManager.password_change_required.connect(_on_password_change_required)
	AuthManager.password_changed.connect(_on_password_changed)
	AuthManager.logout_complete.connect(_on_logout_complete)

	# Conectar señales de RemoteDB
	RemoteDB.entity_created.connect(_on_entity_created)
	RemoteDB.entity_updated.connect(_on_entity_updated)
	RemoteDB.entity_deleted.connect(_on_entity_deleted)
	RemoteDB.entities_fetched.connect(_on_entities_fetched)
	RemoteDB.request_failed.connect(_on_request_failed)

	# Conectar nuevo botón de volver al menú manteniendo sesión
	_btn_back_to_menu.pressed.connect(_on_back_to_menu_pressed)

	# Conectar botón de reportes del Dashboard
	$DashboardPanel/VBoxContainer/BtnGoToReports.pressed.connect(_open_report_panel)
	_btn_close_reports.pressed.connect(_close_report_panel)
	_btn_generate_report.pressed.connect(_on_generate_report_pressed)
	_opt_report_type.item_selected.connect(_on_report_type_changed)

	# Poblar opciones estáticas del panel de reportes
	_opt_lb_modo.add_item("Todos")
	_opt_lb_modo.add_item("Práctica")
	_opt_lb_modo.add_item("Desafío")
	_opt_lb_diff.add_item("Todas")
	_opt_lb_diff.add_item("Facil")
	_opt_lb_diff.add_item("Medio")
	_opt_lb_diff.add_item("Dificil")
	_opt_lb_diff.add_item("Extremo")
	_opt_lb_order.add_item("Puntuación")
	_opt_lb_order.add_item("Tableros Completados")

	# Si ya hay una sesión activa, saltar el login y mostrar directamente el dashboard
	if AuthManager.is_logged_in:
		_login_panel.position = POS_DOWN
		_login_panel.hide()
		
		_dashboard_panel.position = POS_CENTER
		_dashboard_panel.modulate.a = 1.0
		_dashboard_panel.show()
		
		_lbl_user_name.text = AuthManager.user_name
		_lbl_user_role.text = "Institución" if AuthManager.session_type == "institution" else "Profesor"
		_lbl_user_id.text = AuthManager.user_id

		var is_inst: bool = (AuthManager.session_type == "institution")
		_btn_show_create_teacher.visible = is_inst
		_btn_show_create_group.visible = is_inst
		_btn_show_create_student.visible = true

		_btn_manage_teachers.visible = is_inst
		_btn_manage_groups.visible = is_inst
		_btn_manage_students.visible = true


func _exit_tree() -> void:
	# Desconectar señales al destruir para evitar pérdidas de memoria
	if AuthManager.login_success.is_connected(_on_auth_success):
		AuthManager.login_success.disconnect(_on_auth_success)
	if AuthManager.login_failed.is_connected(_on_auth_failed):
		AuthManager.login_failed.disconnect(_on_auth_failed)
	if AuthManager.password_change_required.is_connected(_on_password_change_required):
		AuthManager.password_change_required.disconnect(_on_password_change_required)
	if AuthManager.password_changed.is_connected(_on_password_changed):
		AuthManager.password_changed.disconnect(_on_password_changed)
	if AuthManager.logout_complete.is_connected(_on_logout_complete):
		AuthManager.logout_complete.disconnect(_on_logout_complete)

	if RemoteDB.entity_created.is_connected(_on_entity_created):
		RemoteDB.entity_created.disconnect(_on_entity_created)
	if RemoteDB.entity_updated.is_connected(_on_entity_updated):
		RemoteDB.entity_updated.disconnect(_on_entity_updated)
	if RemoteDB.entity_deleted.is_connected(_on_entity_deleted):
		RemoteDB.entity_deleted.disconnect(_on_entity_deleted)
	if RemoteDB.entities_fetched.is_connected(_on_entities_fetched):
		RemoteDB.entities_fetched.disconnect(_on_entities_fetched)
	if RemoteDB.request_failed.is_connected(_on_request_failed):
		RemoteDB.request_failed.disconnect(_on_request_failed)


# ── Lógica de Login y Sesión ──

func _on_login_pressed() -> void:
	var email = _email_input.text.strip_edges()
	var password = _password_input.text

	if email.is_empty() or password.is_empty():
		_show_status("Por favor, introduce tu correo y contraseña.", Color.RED)
		return

	_show_status("Iniciando sesión...", Color.WHITE)
	_set_login_inputs_disabled(true)
	AuthManager.login_staff(email, password)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")


func _on_logout_pressed() -> void:
	_show_status("Cerrando sesión...", Color.WHITE)
	AuthManager.logout()


func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")


func _on_confirm_change_pressed() -> void:
	var new_pass = _new_password_input.text
	var confirm_pass = _confirm_password_input.text

	if new_pass.length() < 8:
		_show_status("La nueva contraseña debe tener al menos 8 caracteres.", Color.RED)
		return
	if new_pass != confirm_pass:
		_show_status("Las contraseñas no coinciden.", Color.RED)
		return

	_show_status("Actualizando contraseña...", Color.WHITE)
	_btn_confirm_change.disabled = true
	AuthManager.change_teacher_password(new_pass)


# ── Callbacks de AuthManager ──

func _on_auth_success(session_type: String) -> void:
	_set_login_inputs_disabled(false)
	_show_status("¡Sesión iniciada con éxito!", Color.GREEN)

	if not AuthManager.needs_password_change:
		_lbl_user_name.text = AuthManager.user_name
		_lbl_user_role.text = "Institución" if session_type == "institution" else "Profesor"
		_lbl_user_id.text = AuthManager.user_id

		# Configurar visibilidad según el rol
		var is_inst: bool = (session_type == "institution")
		_btn_show_create_teacher.visible = is_inst
		_btn_show_create_group.visible = is_inst
		_btn_show_create_student.visible = true

		_btn_manage_teachers.visible = is_inst
		_btn_manage_groups.visible = is_inst
		_btn_manage_students.visible = true

		_animate_login_success()


func _on_auth_failed(reason: String) -> void:
	_set_login_inputs_disabled(false)
	_btn_confirm_change.disabled = false
	_show_status("Error: " + reason, Color.RED)


func _on_password_change_required() -> void:
	_show_status("Debes actualizar tu contraseña temporal.", Color.YELLOW)
	_change_panel.show()
	if _tween_panel: _tween_panel.kill()
	
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_login_panel, "position", POS_DOWN, 0.6)
	_tween_panel.tween_property(_change_panel, "position", POS_CENTER, 0.6)


func _on_password_changed() -> void:
	_show_status("¡Contraseña actualizada con éxito!", Color.GREEN)
	_lbl_user_name.text = AuthManager.user_name
	_lbl_user_role.text = "Profesor"
	_lbl_user_id.text = AuthManager.user_id
	_btn_show_create_teacher.visible = false
	_btn_show_create_group.visible = false
	_btn_show_create_student.visible = true

	_btn_manage_teachers.visible = false
	_btn_manage_groups.visible = false
	_btn_manage_students.visible = true

	# Animar el cambio a panel de dashboard
	if _tween_panel: _tween_panel.kill()
	_dashboard_panel.show()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_change_panel, "position", POS_DOWN, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_CENTER, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "modulate:a", 1.0, 0.4)


func _on_logout_complete() -> void:
	_show_status("Sesión cerrada.", Color.YELLOW)
	# Animar retorno al login
	if _tween_panel: _tween_panel.kill()
	_login_panel.position = POS_DOWN
	_login_panel.show()
	_email_input.text = ""
	_password_input.text = ""
	
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_UP, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "modulate:a", 0.0, 0.4)
	_tween_panel.tween_property(_login_panel, "position", POS_CENTER, 0.6)
	_tween_panel.finished.connect(func(): _dashboard_panel.hide())


# ── Acciones de Creación (Llamadas a API) ──

func _on_create_teacher_submit() -> void:
	var email = _t_email_input.text.strip_edges()
	var pass_temp = _t_password_input.text
	var name_val = _t_name_input.text.strip_edges()

	if email.is_empty() or pass_temp.is_empty() or name_val.is_empty():
		_show_status("Completa todos los campos.", Color.RED)
		return

	_show_status("Registrando profesor...", Color.WHITE)
	_t_btn_create.disabled = true
	
	var uuid = await RemoteDB.rpc_register_teacher(email, pass_temp, name_val, AuthManager.user_id)
	_t_btn_create.disabled = false
	if uuid != "":
		_show_status("¡Profesor registrado con éxito!", Color.GREEN)
		
		var selected_group_idx = _t_group_dropdown.selected
		if selected_group_idx > 0:
			var group_id = _t_group_dropdown.get_item_metadata(selected_group_idx) as String
			if not group_id.is_empty():
				await RemoteDB.update_group_teacher(group_id, uuid)
				
		_slide_panel_out(_create_teacher_panel)
		_clear_inputs(_create_teacher_panel)
	else:
		# El error ya es emitido por request_failed de RemoteDB
		pass


func _populate_teachers_dropdown() -> void:
	_g_teacher_input.clear()
	_g_teacher_input.add_item("Cargando profesores...")
	_g_teacher_input.disabled = true
	
	var url = RemoteDB.SUPABASE_URL + "/rest/v1/profesores?select=id,nombre&order=nombre.asc"
	var res = await RemoteDB._send(url, RemoteDB._headers_staff())
	
	_g_teacher_input.clear()
	if RemoteDB._ok(res):
		var parsed = RemoteDB._parse(res)
		if parsed is Array:
			_g_teacher_input.add_item("Seleccionar Profesor encargado...", 0)
			_g_teacher_input.set_item_metadata(0, "")
			
			var idx = 1
			for teacher in parsed:
				var t_name = teacher.get("nombre", "") as String
				var t_id = teacher.get("id", "") as String
				_g_teacher_input.add_item(t_name, idx)
				_g_teacher_input.set_item_metadata(idx, t_id)
				idx += 1
			_g_teacher_input.disabled = false
			return
			
	_g_teacher_input.add_item("Error al cargar profesores")


func _on_create_group_submit() -> void:
	var code = _g_code_input.text.strip_edges()
	
	var selected_idx = _g_teacher_input.selected
	var teacher_id = ""
	if selected_idx != -1:
		teacher_id = _g_teacher_input.get_item_metadata(selected_idx) as String

	if code.is_empty():
		_show_status("El código de grupo es obligatorio.", Color.RED)
		return
	if teacher_id.is_empty():
		_show_status("Debes seleccionar un profesor encargado.", Color.RED)
		return

	_show_status("Creando grupo...", Color.WHITE)
	_g_btn_create.disabled = true
	RemoteDB.create_group(code, AuthManager.user_id, teacher_id)


func _populate_groups_dropdown() -> void:
	_s_group_input.clear()
	_s_group_input.add_item("Cargando grupos...")
	_s_group_input.disabled = true
	
	var url = RemoteDB.SUPABASE_URL + "/rest/v1/grupos?select=id,codigo_grupo&order=codigo_grupo.asc"
	var res = await RemoteDB._send(url, RemoteDB._headers_staff())
	
	_s_group_input.clear()
	if RemoteDB._ok(res):
		var parsed = RemoteDB._parse(res)
		if parsed is Array:
			_s_group_input.add_item("Seleccionar Grupo...", 0)
			_s_group_input.set_item_metadata(0, "")
			
			var idx = 1
			for group in parsed:
				var g_code = group.get("codigo_grupo", "") as String
				var g_id = group.get("id", "") as String
				_s_group_input.add_item(g_code, idx)
				_s_group_input.set_item_metadata(idx, g_id)
				idx += 1
			_s_group_input.disabled = false
			return
			
	_s_group_input.add_item("Error al cargar grupos")


func _on_create_student_submit() -> void:
	var username = _s_username_input.text.strip_edges()
	
	var selected_idx = _s_group_input.selected
	var group_id = ""
	if selected_idx != -1:
		group_id = _s_group_input.get_item_metadata(selected_idx) as String
		
	var pin = _s_pin_input.text.strip_edges()

	if username.is_empty() or group_id.is_empty():
		_show_status("Usuario y Grupo son obligatorios.", Color.RED)
		return

	_show_status("Creando estudiante...", Color.WHITE)
	_s_btn_create.disabled = true
	RemoteDB.create_student(username, group_id, pin)


# ── Lógica de Carga y Gestión de Listas (CRUD) ──

func _fetch_and_show_list(type: String) -> void:
	_current_entity_type = type
	_show_status("Cargando lista...", Color.WHITE)
	_set_dashboard_buttons_disabled(true)

	if type == "teacher":
		_list_title.text = "Gestionar Profesores"
		RemoteDB.fetch_teachers()
	elif type == "group":
		_list_title.text = "Gestionar Grupos"
		RemoteDB.fetch_groups()
	elif type == "student":
		_list_title.text = "Gestionar Estudiantes"
		RemoteDB.fetch_students()


func _on_entities_fetched(entity_type: String, data: Array) -> void:
	if entity_type != _current_entity_type:
		return
	
	_show_status("", Color.WHITE)
	_populate_list_ui(data)
	_slide_sub_panel_in(_list_panel)


func _populate_list_ui(data: Array) -> void:
	# Limpiar lista anterior
	for child in _list_container.get_children():
		child.queue_free()

	if data.is_empty():
		var lbl_empty: Label = Label.new()
		lbl_empty.text = "No se encontraron registros."
		if _label_style:
			lbl_empty.label_settings = _label_style
		_list_container.add_child(lbl_empty)
		return

	for item in data:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)

		var id = item.get("id", "")
		var text_val = ""

		if _current_entity_type == "teacher":
			var email_str = item.get("email", "Sin email")
			if email_str == null or email_str.is_empty():
				email_str = "Sin email"
			text_val = item.get("nombre", "Profesor sin nombre") + " (" + email_str + ")"
			
			var groups_list = item.get("grupos", [])
			if groups_list is Array and not groups_list.is_empty():
				var codes: Array[String] = []
				for g in groups_list:
					if g is Dictionary:
						codes.append(g.get("codigo_grupo", ""))
				text_val += " [Grupos: " + ", ".join(codes) + "]"
			else:
				text_val += " [Sin grupo]"
				
			var lbl: Label = Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _label_style:
				lbl.label_settings = _label_style
			lbl.text = text_val
			row.add_child(lbl)

		elif _current_entity_type == "student":
			text_val = item.get("usuario", "Estudiante sin nombre")
			
			var lbl: Label = Label.new()
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if _label_style:
				lbl.label_settings = _label_style
			lbl.text = text_val
			row.add_child(lbl)

		elif _current_entity_type == "group":
			var left_container: VBoxContainer = VBoxContainer.new()
			left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			left_container.add_theme_constant_override("separation", 2)
			
			var prof_name = "Sin profesor"
			var prof_data = item.get("profesores")
			if prof_data is Dictionary:
				prof_name = prof_data.get("nombre", "Sin profesor") as String
			elif prof_data is Array and not prof_data.is_empty():
				var first = prof_data[0]
				if first is Dictionary:
					prof_name = first.get("nombre", "Sin profesor") as String
					
			var lbl_group: Label = Label.new()
			if _label_style:
				lbl_group.label_settings = _label_style
			lbl_group.text = "Grupo: " + item.get("codigo_grupo", "") + " | Prof: " + prof_name
			left_container.add_child(lbl_group)
			
			var students_hbox: HBoxContainer = HBoxContainer.new()
			students_hbox.add_theme_constant_override("separation", 8)
			
			var lbl_students: Label = Label.new()
			if _label_style:
				lbl_students.label_settings = _label_style
			
			var btn_prev: Button = Button.new()
			btn_prev.text = "<"
			
			var btn_next: Button = Button.new()
			btn_next.text = ">"
			
			students_hbox.add_child(lbl_students)
			students_hbox.add_child(btn_prev)
			students_hbox.add_child(btn_next)
			left_container.add_child(students_hbox)
			
			row.add_child(left_container)
			
			var studs = item.get("estudiantes", [])
			lbl_students.set_meta("students", studs)
			lbl_students.set_meta("page", 0)
			
			var update_students_text = func():
				var page: int = lbl_students.get_meta("page")
				var s_list: Array = lbl_students.get_meta("students")
				if s_list.is_empty():
					lbl_students.text = "  Alumnos: (Ninguno)"
					btn_prev.visible = false
					btn_next.visible = false
					return
				
				var total_studs = s_list.size()
				var page_size = 5
				var total_pages = int(ceil(total_studs / float(page_size)))
				
				var start_idx = page * page_size
				var end_idx = min(start_idx + page_size, total_studs)
				
				var page_students = s_list.slice(start_idx, end_idx)
				var names: Array[String] = []
				for s in page_students:
					if s is Dictionary:
						names.append(s.get("usuario", "") as String)
						
				lbl_students.text = "  Alumnos (%d-%d/%d): %s" % [start_idx + 1, end_idx, total_studs, ", ".join(names)]
				
				btn_prev.visible = total_studs > page_size
				btn_next.visible = total_studs > page_size
				btn_prev.disabled = (page == 0)
				btn_next.disabled = (page == total_pages - 1)
				
			btn_prev.pressed.connect(func():
				var page: int = lbl_students.get_meta("page")
				if page > 0:
					lbl_students.set_meta("page", page - 1)
					update_students_text.call()
			)
			btn_next.pressed.connect(func():
				var page: int = lbl_students.get_meta("page")
				var s_list: Array = lbl_students.get_meta("students")
				var total_pages = int(ceil(s_list.size() / 5.0))
				if page < total_pages - 1:
					lbl_students.set_meta("page", page + 1)
					update_students_text.call()
			)
			
			update_students_text.call()
			
			text_val = "Grupo: " + item.get("codigo_grupo", "")

		# Botón Editar (Nombre, profesor encargado o datos estudiante)
		var btn_edit: Button = Button.new()
		btn_edit.text = "Editar"
		btn_edit.pressed.connect(func(): _open_editor_overlay(item, "edit"))
		row.add_child(btn_edit)

		# Botón Cambiar PIN (Exclusivo para Estudiantes)
		if _current_entity_type == "student":
			var btn_pin: Button = Button.new()
			btn_pin.text = "PIN"
			btn_pin.pressed.connect(func(): _open_editor_overlay(item, "pin"))
			row.add_child(btn_pin)

		# Botón Borrar (Profesores solo estudiantes; Instituciones borran todo)
		var can_delete = true
		if AuthManager.session_type == "teacher" and _current_entity_type != "student":
			can_delete = false

		if can_delete:
			var btn_del: Button = Button.new()
			btn_del.text = "Borrar"
			btn_del.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
			btn_del.pressed.connect(func(): _on_delete_confirm_request(id, text_val))
			row.add_child(btn_del)

		_list_container.add_child(row)


func _close_list_panel() -> void:
	_slide_sub_panel_out(_list_panel)
	_current_entity_type = ""


# ── Lógica de Edición y Actualización (Editor Panel) ──

func _open_editor_overlay(item: Dictionary, mode: String) -> void:
	_editing_id = item.get("id", "")
	_editing_mode = mode
	_edit_input1.text = ""
	_edit_input2.text = ""
	_edit_input3.text = ""
	_edit_dropdown.visible = false
	
	if mode == "pin":
		_edit_title.text = "Cambiar PIN"
		_edit_input1.placeholder_text = "Nuevo PIN de 6 dígitos"
		_edit_input1.visible = true
		_edit_input2.visible = false
		_edit_input3.visible = false
	elif _current_entity_type == "teacher":
		_edit_title.text = "Editar Profesor"
		_edit_input1.placeholder_text = "Nombre Completo"
		_edit_input1.text = item.get("nombre", "")
		_edit_input1.visible = true
		
		_edit_input2.placeholder_text = "Email"
		_edit_input2.text = item.get("email", "")
		_edit_input2.visible = true
		
		_edit_input3.visible = false
		
		_edit_dropdown.visible = true
		await _fill_groups_in_dropdown(_edit_dropdown)
		
		var current_group_id = ""
		var groups_list = item.get("grupos", [])
		if groups_list is Array and not groups_list.is_empty():
			var g = groups_list[0]
			if g is Dictionary:
				current_group_id = g.get("id", "")
				
		if current_group_id != "":
			for idx in range(_edit_dropdown.item_count):
				if _edit_dropdown.get_item_metadata(idx) == current_group_id:
					_edit_dropdown.selected = idx
					break
	elif _current_entity_type == "group":
		_edit_title.text = "Editar Grupo"
		_edit_input1.visible = false
		_edit_input2.visible = false
		_edit_input3.visible = false
		
		_edit_dropdown.visible = true
		await _fill_teachers_in_dropdown(_edit_dropdown)
		
		var current_teacher_id = item.get("profesor_encargado_id", "")
		if current_teacher_id != "":
			for idx in range(_edit_dropdown.item_count):
				if _edit_dropdown.get_item_metadata(idx) == current_teacher_id:
					_edit_dropdown.selected = idx
					break
	elif _current_entity_type == "student":
		_edit_title.text = "Editar Estudiante"
		_edit_input1.placeholder_text = "Nombre de Usuario"
		_edit_input1.text = item.get("usuario", "")
		_edit_input1.visible = true
		_edit_input2.visible = false
		_edit_input3.visible = false
		
		_edit_dropdown.visible = true
		await _fill_groups_in_dropdown(_edit_dropdown)
		
		var current_group_id = item.get("grupo_id", "")
		if current_group_id != "":
			for idx in range(_edit_dropdown.item_count):
				if _edit_dropdown.get_item_metadata(idx) == current_group_id:
					_edit_dropdown.selected = idx
					break

	# Transición: empujar lista arriba y meter editor
	if _tween_panel: _tween_panel.kill()
	_edit_panel.show()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_list_panel, "position", POS_UP, 0.7)
	_tween_panel.tween_property(_edit_panel, "position", POS_CENTER, 0.7)


func _close_edit_panel(reload: bool = false) -> void:
	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_edit_panel, "position", POS_DOWN, 0.6)
	if not reload:
		_tween_panel.tween_property(_list_panel, "position", POS_CENTER, 0.6)
	_tween_panel.finished.connect(func():
		_edit_panel.hide()
		_editing_id = ""
		_editing_mode = ""
		if reload:
			_fetch_and_show_list(_current_entity_type)
	)


func _on_edit_submit() -> void:
	var val1 = _edit_input1.text.strip_edges()
	var val2 = _edit_input2.text.strip_edges()

	_edit_btn_confirm.disabled = true
	_show_status("Actualizando registro...", Color.WHITE)

	if _editing_mode == "pin":
		RemoteDB.update_student_pin(_editing_id, val1)
	elif _current_entity_type == "teacher":
		if val1.is_empty() or val2.is_empty():
			_show_status("El nombre y el correo no pueden estar vacíos.", Color.RED)
			_edit_btn_confirm.disabled = false
			return
		
		if RemoteDB.entity_updated.is_connected(_on_entity_updated):
			RemoteDB.entity_updated.disconnect(_on_entity_updated)
			
		await RemoteDB.update_teacher(_editing_id, val1, val2)
		
		var selected_group_idx = _edit_dropdown.selected
		var selected_group_id = ""
		if selected_group_idx > 0:
			selected_group_id = _edit_dropdown.get_item_metadata(selected_group_idx) as String
		
		if not selected_group_id.is_empty():
			await RemoteDB.update_group_teacher(selected_group_id, _editing_id)
			
		RemoteDB.entity_updated.connect(_on_entity_updated)
		_on_entity_updated("teacher")
	elif _current_entity_type == "group":
		var selected_teacher_idx = _edit_dropdown.selected
		var selected_teacher_id = ""
		if selected_teacher_idx > 0:
			selected_teacher_id = _edit_dropdown.get_item_metadata(selected_teacher_idx) as String
			
		if selected_teacher_id.is_empty():
			_show_status("Debes seleccionar un profesor encargado.", Color.RED)
			_edit_btn_confirm.disabled = false
			return
			
		RemoteDB.update_group_teacher(_editing_id, selected_teacher_id)
	elif _current_entity_type == "student":
		var selected_group_idx = _edit_dropdown.selected
		var selected_group_id = ""
		if selected_group_idx > 0:
			selected_group_id = _edit_dropdown.get_item_metadata(selected_group_idx) as String
			
		if val1.is_empty() or selected_group_id.is_empty():
			_show_status("Usuario y Grupo son requeridos.", Color.RED)
			_edit_btn_confirm.disabled = false
			return
		RemoteDB.update_student(_editing_id, val1, selected_group_id)


# ── Confirmaciones de Borrado (CRUD) ──

func _on_delete_confirm_request(id: String, name_display: String) -> void:
	# Por simplicidad en esta interfaz, solicitamos confirmación rápida en el label de estado,
	# o ejecutamos el borrado directo. Haremos el borrado directo informando en el status label.
	_show_status("Eliminando: " + name_display + "...", Color.YELLOW)

	if _current_entity_type == "teacher":
		RemoteDB.delete_teacher(id)
	elif _current_entity_type == "group":
		RemoteDB.delete_group(id)
	elif _current_entity_type == "student":
		RemoteDB.delete_student(id)


# ── Callbacks de Operaciones Exitosas (DB CRUD) ──

func _on_entity_created(entity_type: String) -> void:
	if entity_type == "group":
		_g_btn_create.disabled = false
		_show_status("¡Grupo creado con éxito!", Color.GREEN)
		_slide_panel_out(_create_group_panel)
		_clear_inputs(_create_group_panel)
	elif entity_type == "student":
		_s_btn_create.disabled = false
		_show_status("¡Estudiante creado con éxito!", Color.GREEN)
		_slide_panel_out(_create_student_panel)
		_clear_inputs(_create_student_panel)


func _on_entity_updated(entity_type: String) -> void:
	_edit_btn_confirm.disabled = false
	_show_status("¡Registro actualizado con éxito!", Color.GREEN)
	_close_edit_panel(true)


func _on_entity_deleted(entity_type: String) -> void:
	_show_status("¡Registro eliminado correctamente!", Color.GREEN)
	# Recargar la lista activa
	_fetch_and_show_list(_current_entity_type)


func _on_request_failed(reason: String) -> void:
	_show_status("Error: " + reason, Color.RED)
	_t_btn_create.disabled = false
	_g_btn_create.disabled = false
	_s_btn_create.disabled = false
	_edit_btn_confirm.disabled = false


# ── Helpers de Animaciones y Tweens ──

func _animate_login_success() -> void:
	if _tween_panel: _tween_panel.kill()
	if _tween_fade: _tween_fade.kill()

	_dashboard_panel.position = POS_UP
	_dashboard_panel.modulate.a = 0.0
	_dashboard_panel.show()
	
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_login_panel, "position", POS_DOWN, 0.7)
	
	_tween_fade = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_fade.tween_property(_dashboard_panel, "position", POS_CENTER, 0.8)
	_tween_fade.tween_property(_dashboard_panel, "modulate:a", 1.0, 0.6)
	
	_tween_panel.finished.connect(func():
		_login_panel.hide()
	)


func _slide_panel_in(panel: Panel) -> void:
	if _active_creation_panel or _active_sub_panel:
		return
	
	_active_creation_panel = panel
	_active_creation_panel.position = POS_DOWN
	_active_creation_panel.show()

	_set_dashboard_buttons_disabled(true)

	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_UP, 0.7)
	_tween_panel.tween_property(_active_creation_panel, "position", POS_CENTER, 0.7)


func _slide_panel_out(panel: Panel) -> void:
	if _active_creation_panel != panel:
		return
	
	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_active_creation_panel, "position", POS_DOWN, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_CENTER, 0.6)

	_tween_panel.finished.connect(func():
		panel.hide()
		_active_creation_panel = null
		_set_dashboard_buttons_disabled(false)
	)


func _slide_sub_panel_in(panel: Panel) -> void:
	_active_sub_panel = panel
	_active_sub_panel.position = POS_DOWN
	_active_sub_panel.show()

	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_UP, 0.7)
	_tween_panel.tween_property(_active_sub_panel, "position", POS_CENTER, 0.7)


func _slide_sub_panel_out(panel: Panel) -> void:
	if _active_sub_panel != panel:
		return
	
	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_active_sub_panel, "position", POS_DOWN, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_CENTER, 0.6)

	_tween_panel.finished.connect(func():
		panel.hide()
		_active_sub_panel = null
		_set_dashboard_buttons_disabled(false)
	)


# ── Helpers de Utilidad de UI ──

func _show_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _set_login_inputs_disabled(disabled: bool) -> void:
	_email_input.editable = not disabled
	_password_input.editable = not disabled
	_btn_login.disabled = disabled
	_btn_back.disabled = disabled


func _set_dashboard_buttons_disabled(disabled: bool) -> void:
	_btn_show_create_teacher.disabled = disabled
	_btn_show_create_group.disabled = disabled
	_btn_show_create_student.disabled = disabled

	_btn_manage_teachers.disabled = disabled
	_btn_manage_groups.disabled = disabled
	_btn_manage_students.disabled = disabled

	_btn_logout.disabled = disabled
	_btn_back_to_menu.disabled = disabled


func _clear_inputs(panel: Panel) -> void:
	for child in panel.get_node("VBoxContainer").get_children():
		if child is LineEdit:
			child.text = ""
		elif child is OptionButton:
			child.selected = 0


func _fill_groups_in_dropdown(dropdown: OptionButton) -> void:
	dropdown.clear()
	dropdown.add_item("Cargando grupos...")
	dropdown.disabled = true
	
	var url = RemoteDB.SUPABASE_URL + "/rest/v1/grupos?select=id,codigo_grupo&order=codigo_grupo.asc"
	var res = await RemoteDB._send(url, RemoteDB._headers_staff())
	
	dropdown.clear()
	if RemoteDB._ok(res):
		var parsed = RemoteDB._parse(res)
		if parsed is Array:
			dropdown.add_item("Seleccionar Grupo...", 0)
			dropdown.set_item_metadata(0, "")
			
			var idx = 1
			for group in parsed:
				var g_code = group.get("codigo_grupo", "") as String
				var g_id = group.get("id", "") as String
				dropdown.add_item(g_code, idx)
				dropdown.set_item_metadata(idx, g_id)
				idx += 1
			dropdown.disabled = false
			return
			
	dropdown.add_item("Error al cargar grupos")


func _fill_teachers_in_dropdown(dropdown: OptionButton) -> void:
	dropdown.clear()
	dropdown.add_item("Cargando profesores...")
	dropdown.disabled = true
	
	var url = RemoteDB.SUPABASE_URL + "/rest/v1/profesores?select=id,nombre&order=nombre.asc"
	var res = await RemoteDB._send(url, RemoteDB._headers_staff())
	
	dropdown.clear()
	if RemoteDB._ok(res):
		var parsed = RemoteDB._parse(res)
		if parsed is Array:
			dropdown.add_item("Seleccionar Profesor...", 0)
			dropdown.set_item_metadata(0, "")
			
			var idx = 1
			for teacher in parsed:
				var t_name = teacher.get("nombre", "") as String
				var t_id = teacher.get("id", "") as String
				dropdown.add_item(t_name, idx)
				dropdown.set_item_metadata(idx, t_id)
				idx += 1
			dropdown.disabled = false
			return
			
	dropdown.add_item("Error al cargar profesores")


# ════════════════════════════════════════════════════════════════════════════════
# PANEL DE GENERACIÓN DE REPORTES PDF
# ════════════════════════════════════════════════════════════════════════════════

func _open_report_panel() -> void:
	if _active_creation_panel or _active_sub_panel:
		return

	# Poblar el selector de tipo según el rol del usuario autenticado
	_opt_report_type.clear()
	if AuthManager.session_type == "institution":
		_opt_report_type.add_item("Lista de Profesores", 0)
	_opt_report_type.add_item("Listado de Estudiantes", 1)
	_opt_report_type.add_item("Estadísticas en Lote", 2)
	_opt_report_type.add_item("Tabla de Clasificación", 3)

	# Forzar refresco de UI (el primer ítem visible)
	_on_report_type_changed(_opt_report_type.get_selected_id())

	# Cargar grupos disponibles en el selector
	_populate_report_groups_dropdown()

	# Animar entrada usando el sistema de sub-paneles ya existente
	_active_sub_panel = _report_panel
	_report_panel.position = POS_DOWN
	_report_panel.show()

	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_UP, 0.7)
	_tween_panel.tween_property(_report_panel, "position", POS_CENTER, 0.7)


func _close_report_panel() -> void:
	if _active_sub_panel != _report_panel:
		return

	_show_status("", Color.WHITE)

	if _tween_panel: _tween_panel.kill()
	_tween_panel = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween_panel.tween_property(_report_panel, "position", POS_DOWN, 0.6)
	_tween_panel.tween_property(_dashboard_panel, "position", POS_CENTER, 0.6)

	_tween_panel.finished.connect(func():
		_report_panel.hide()
		_active_sub_panel = null
	)


func _on_report_type_changed(_idx: int) -> void:
	# Resolvemos el tipo por texto para ser robustos ante el desplazamiento de índices según rol
	var sel_text: String = _opt_report_type.get_item_text(_opt_report_type.selected)

	var needs_group: bool = sel_text != "Lista de Profesores"
	var needs_lb: bool = sel_text == "Tabla de Clasificación"

	_hbox_group.visible = needs_group
	_lb_filters.visible = needs_lb


func _populate_report_groups_dropdown() -> void:
	_opt_report_group.clear()
	_opt_report_group.add_item("Todos los grupos", 0)
	_opt_report_group.set_item_metadata(0, "")
	_opt_report_group.disabled = true

	var url = RemoteDB.SUPABASE_URL + "/rest/v1/grupos?select=id,codigo_grupo&order=codigo_grupo.asc"
	var res = await RemoteDB._send(url, RemoteDB._headers_staff())

	if RemoteDB._ok(res):
		var parsed = RemoteDB._parse(res)
		if parsed is Array:
			var idx = 1
			for group in parsed:
				var g_code = group.get("codigo_grupo", "") as String
				var g_id = group.get("id", "") as String
				_opt_report_group.add_item(g_code, idx)
				_opt_report_group.set_item_metadata(idx, g_id)
				idx += 1
	_opt_report_group.disabled = false


func _on_generate_report_pressed() -> void:
	_btn_generate_report.disabled = true
	_btn_generate_report.text = "Generando..."
	_show_status("Conectando con el servidor de reportes...", Color.WHITE)

	var sel_text: String = _opt_report_type.get_item_text(_opt_report_type.selected)

	# Obtener código de grupo seleccionado (vacío = todos)
	var grupo_codigo: String = ""
	var g_sel = _opt_report_group.selected
	if g_sel != -1:
		grupo_codigo = _opt_report_group.get_item_metadata(g_sel) as String

	var result: Dictionary = {}
	var filename: String = "reporte.pdf"

	if sel_text == "Lista de Profesores":
		result = await RemoteDB.request_teachers_report()
		filename = "reporte_profesores.pdf"

	elif sel_text == "Listado de Estudiantes":
		result = await RemoteDB.request_students_list_report(grupo_codigo)
		filename = "listado_estudiantes.pdf"

	elif sel_text == "Estadísticas en Lote":
		result = await RemoteDB.request_students_batch_report(grupo_codigo)
		filename = "estadisticas_lote.pdf"

	elif sel_text == "Tabla de Clasificación":
		# Leer filtros del leaderboard
		var modo_map: Array = ["", "practice", "challenge"]
		var diff_map: Array = ["", "facil", "medio", "dificil", "extremo"]
		var order_map: Array = ["score", "boards"]

		var modo_idx: int = _opt_lb_modo.selected
		var diff_idx: int = _opt_lb_diff.selected
		var order_idx: int = _opt_lb_order.selected

		var modo: String = modo_map[modo_idx] if modo_idx < modo_map.size() else ""
		var diff: String = diff_map[diff_idx] if diff_idx < diff_map.size() else ""
		var order: String = order_map[order_idx] if order_idx < order_map.size() else "score"

		var variantes: Array = []
		if _chk_anti_knight.button_pressed: variantes.append("anti_knight")
		if _chk_thermo.button_pressed: variantes.append("thermo")
		if _chk_killer.button_pressed: variantes.append("killer")
		if _chk_arrow.button_pressed: variantes.append("arrow")

		result = await RemoteDB.request_leaderboard_report(modo, diff, grupo_codigo, variantes, order)
		filename = "leaderboard.pdf"

	_btn_generate_report.disabled = false
	_btn_generate_report.text = "Generar y Abrir PDF"

	if result.is_empty() or not result.get("success", false):
		var err: String = result.get("error", "Error desconocido.")
		_show_status("Error: " + err, Color.RED)
		return

	var open_err: String = await RemoteDB.save_and_open_pdf(result["pdf_data"], filename)
	if open_err.is_empty():
		_show_status("✓ PDF generado y abierto exitosamente.", Color.GREEN)
	else:
		_show_status("Error al abrir: " + open_err, Color.RED)
