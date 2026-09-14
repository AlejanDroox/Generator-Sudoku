extends Label

var current_displayed_score: float = 0.0
var score_tween: Tween = null
var scale_tween: Tween = null
var color_tween: Tween = null

@onready var original_color: Color = modulate

func _ready() -> void:
	# Asegurar que el punto de pivote esté en el centro para el efecto de escalado
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	
	current_displayed_score = ScoreManager.total_score
	text = str(int(current_displayed_score))
	
	# Suscribirse a la señal del ScoreManager
	if ScoreManager.has_signal("score_changed"):
		ScoreManager.score_changed.connect(_on_score_changed)
	
	_update_font()
	Global.font_changed.connect(func(_use_neutral): _update_font())

func _update_font() -> void:
	if label_settings:
		var ls = label_settings.duplicate()
		ls.font = Global.get_current_font()
		label_settings = ls

func _on_score_changed(new_score: int) -> void:
	var difference = new_score - current_displayed_score
	if difference == 0:
		return
		
	# 1. Cancelar tweens anteriores si están corriendo
	if score_tween and score_tween.is_running():
		score_tween.kill()
	if scale_tween and scale_tween.is_running():
		scale_tween.kill()
	if color_tween and color_tween.is_running():
		color_tween.kill()

	score_tween = create_tween()
	scale_tween = create_tween()
	color_tween = create_tween()

	# 2. Animación de incremento numérico progresivo (0.5s)
	score_tween.tween_method(
		func(val: float):
			text = str(int(val)),
		current_displayed_score,
		float(new_score),
		0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Actualizar valor de referencia al terminar o durante el proceso
	current_displayed_score = float(new_score)

	# 3. Efecto de Escala (Punch)
	scale = Vector2(1.0, 1.0)
	scale_tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 4. Efecto de Color Flash
	var target_flash_color = Color.GOLD if difference > 0 else Color.RED
	modulate = target_flash_color
	color_tween.tween_property(self, "modulate", original_color, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
