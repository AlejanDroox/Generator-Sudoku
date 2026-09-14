extends CheckButton

@export var des_x: int = 25
@export var des_y: int = 5
@export var rescale: float = 1.1
@export var time: float = 0.25
@export var number: String = "8":
	set(valor):
		number = valor
		# Esto asegura que si cambias el valor en el inspector en tiempo de ejecución o edición,
		# el Label se actualice inmediatamente.
		if is_node_ready(): 
			$Container/Label.text = valor
var original_position: Vector2
var original_scale: Vector2 = Vector2.ONE
var is_initialized: bool = false

var tween: Tween

func _ready():
# 2. Asignamos el texto al Label cuando la escena esté lista
	$Container/Label.text = number
	_update_font()
	Global.font_changed.connect(func(_use_neutral): _update_font())

func _update_font() -> void:
	var lbl: Label = $Container/Label
	if lbl and lbl.label_settings:
		var ls = lbl.label_settings.duplicate()
		ls.font = Global.get_current_font()
		lbl.label_settings = ls

func _on_toggled(toggled_on: bool) -> void:
	if not is_initialized:
		original_position = position
		original_scale = scale
		is_initialized = true
		
	if tween:
		tween.kill()
		
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if toggled_on:
		var target_pos = Vector2(original_position.x + des_x, original_position.y - des_y)
		var target_scale = original_scale * rescale
		tween.tween_property(self, "position", target_pos, time)
		tween.tween_property(self, "scale", target_scale, time)
	else:
		tween.tween_property(self, "position", original_position, time)
		tween.tween_property(self, "scale", original_scale, time)

func set_knight_visible(visible_state: bool) -> void:
	var k = get_node_or_null("knight")
	if k:
		k.visible = visible_state
