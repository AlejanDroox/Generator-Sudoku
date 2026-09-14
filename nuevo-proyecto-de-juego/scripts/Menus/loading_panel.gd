extends Panel

signal start_pressed

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var label_aclaracion: Label = $Aclaracion
@onready var label_status: Label = $Label
@onready var rich_label_consejos: RichTextLabel = $Consejos

var is_ready_to_start: bool = false

func _ready() -> void:
	# Capturar entradas para que no pasen a elementos de atrás
	mouse_filter = MOUSE_FILTER_STOP
	if progress_bar:
		progress_bar.value = 0.0
	is_ready_to_start = false

func update_progress(value: float) -> void:
	if progress_bar:
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", value, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func set_tip(text: String) -> void:
	if rich_label_consejos:
		rich_label_consejos.text = text

func show_aclaracion(visible: bool) -> void:
	if label_aclaracion:
		label_aclaracion.visible = visible

func set_ready() -> void:
	is_ready_to_start = true
	if label_status:
		label_status.text = "¡Listo!\nPresiona la pantalla para empezar"
		
		# Animación de parpadeo para indicar interactividad
		var tween = create_tween().set_loops()
		tween.tween_property(label_status, "modulate:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(label_status, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _gui_input(event: InputEvent) -> void:
	if is_ready_to_start and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		start_pressed.emit()
		accept_event()
