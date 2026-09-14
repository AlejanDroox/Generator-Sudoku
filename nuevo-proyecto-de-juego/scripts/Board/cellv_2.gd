extends Node2D
class_name CellUI

## Emitida cuando el jugador ingresa un valor en esta celda
signal cell_value_changed(coords: Vector2i, new_value: int, is_correct: bool)
## Emitida cuando esta celda es seleccionada por el jugador
signal cell_selected(cell: CellUI)
## Emitida cuando el jugador activa o desactiva una marca de lápiz
signal pencil_marks_changed(coords: Vector2i, number: int, is_visible: bool)

@onready var sprite: Sprite2D = $Sprite2D
@onready var animted_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animated_border: AnimatedSprite2D = $Border
@onready var text_label: Label = $Label
@onready var area: Area2D = $Area2D
@onready var animated_values: AnimatedSprite2D = $Values
@onready var sprite_jaula: AnimatedSprite2D = $jaula

@onready var pencil_labels: Array[Label] = [
	$PanelContainer/BoxContainer/VBoxContainer/Label,
	$PanelContainer/BoxContainer/VBoxContainer/Label2,
	$PanelContainer/BoxContainer/VBoxContainer/Label3,
	$PanelContainer/BoxContainer/VBoxContainer2/Label4,
	$PanelContainer/BoxContainer/VBoxContainer2/Label5,
	$PanelContainer/BoxContainer/VBoxContainer2/Label6,
	$PanelContainer/BoxContainer/VBoxContainer3/Label7,
	$PanelContainer/BoxContainer/VBoxContainer3/Label8,
	$PanelContainer/BoxContainer/VBoxContainer3/Label9
]

var coords: Vector2i = Vector2i.ZERO
var value: int = 0
var true_value: int
var is_fixed: bool = false
var is_focus: bool = false 

var mistake_count: int = 0
var has_been_incorrect: bool = false

## Identificador del board al que pertenece esta celda
var board_id: StringName = &""
## Referencia al nodo Board que contiene a esta celda
var board = null
## Si es true, esta celda es compartida entre dos boards (zona de solapamiento)
var is_shared: bool = false
## Referencia a la celda gemela en el otro board (si is_shared es true)
var linked_cell: CellUI = null
## Flag para evitar loops infinitos al sincronizar celdas compartidas
var _syncing: bool = false
var has_knight_restriction: bool = false
var _click_start_pos: Vector2 = Vector2.ZERO
var _is_click_active: bool = false

func highlight_cell_state(is_error: bool, is_conflict: bool) -> void:
	if is_error:
		sprite.visible = true
		sprite.self_modulate = Color(1.0, 0.4, 0.4, 0.9) # Rojo distintivo
		text_label.modulate = Color.RED
	elif is_conflict:
		sprite.visible = true
		sprite.self_modulate = Color(1.0, 0.6, 0.2, 0.9) # Naranja/Ámbar de conflicto
		text_label.modulate = Color.RED
	else:
		sprite.visible = false
		text_label.modulate = Color.BLACK if is_fixed else Color.DARK_SLATE_GRAY


## Propiedades de jaula Killer
var killer_cell: bool = false
var cage_sum: int = 0
var cage_borders = {"top": false, "bottom": false, "left": false, "right": false}

func update_pencil_container_position() -> void:
	if has_node("PanelContainer"):
		$PanelContainer.global_position = global_position + Vector2(-27, -28)

func clear_all_pencil_marks() -> void:
	for label in pencil_labels:
		if is_instance_valid(label):
			label.visible = false

func toggle_pencil_mark(number: int) -> void:
	if is_fixed:
		return
	if number < 1 or number > 9:
		return
	
	# Si la celda tenía un valor principal asignado, lo borramos
	if value != 0:
		value = 0
		text_label.text = ""
		cell_value_changed.emit(coords, 0, true)
		_update_visuals()
		
	var label = pencil_labels[number - 1]
	if is_instance_valid(label):
		label.visible = not label.visible
		pencil_marks_changed.emit(coords, number, label.visible)
		
	# Sincronizar con celda gemela si es compartida
	if is_shared and linked_cell != null and not _syncing:
		_syncing = true
		linked_cell.sync_pencil_mark(number, label.visible)
		_syncing = false

func sync_pencil_mark(number: int, is_visible: bool) -> void:
	if is_fixed:
		return
	if number < 1 or number > 9:
		return
		
	if value != 0:
		value = 0
		text_label.text = ""
		cell_value_changed.emit(coords, 0, true)
		_update_visuals()
		
	var label = pencil_labels[number - 1]
	if is_instance_valid(label):
		label.visible = is_visible
		pencil_marks_changed.emit(coords, number, is_visible)

func setup(_value: int, _coords: Vector2i) -> void:
	value = _value
	coords = _coords
	
	# Si al iniciar el nivel el valor es diferente de 0, es una pista fija
	if _value != 0:
		is_fixed = true
	else:
		is_fixed = false
		
	if is_node_ready():
		_assign_border()
		_refresh()
		_update_visuals()
		update_cage_visuals()
		update_pencil_container_position()
		clear_all_pencil_marks()

func update_cage_visuals() -> void:
	# Eliminar etiqueta de suma previa si existe
	var old_label = get_node_or_null("CageSumLabel")
	if old_label:
		old_label.queue_free()
		
	# Intentar usar el label pre-creado en la escena
	var killer_val_label = get_node_or_null("Killervalue")
	if killer_val_label:
		if cage_sum > 0:
			killer_val_label.text = str(cage_sum)
			killer_val_label.visible = true
		else:
			killer_val_label.visible = false
			killer_val_label.text = ""
	else:
		# Fallback por si la escena no tiene el nodo "Killervalue"
		if cage_sum > 0:
			var sum_label = Label.new()
			sum_label.name = "CageSumLabel"
			sum_label.text = str(cage_sum)
			
			var settings = LabelSettings.new()
			settings.font_size = 14
			settings.font_color = Color(0.2, 0.2, 0.2, 0.8)
			if text_label and text_label.label_settings and text_label.label_settings.font:
				settings.font = text_label.label_settings.font
				
			sum_label.label_settings = settings
			sum_label.position = Vector2(6, 2)
			add_child(sum_label)
		
	_update_visuals()


func _ready() -> void:		
	_refresh()
	_update_visuals()
	update_pencil_container_position()
	clear_all_pencil_marks()
	_update_fonts()
	Global.font_changed.connect(func(_use_neutral): _update_fonts())

func _update_fonts() -> void:
	var font: Font = Global.get_current_font()
	# Número principal de la celda
	if is_instance_valid(text_label) and text_label.label_settings:
		var ls = text_label.label_settings.duplicate()
		ls.font = font
		text_label.label_settings = ls
	# Candidatos (marcas de lápiz)
	for lbl in pencil_labels:
		if is_instance_valid(lbl) and lbl.label_settings:
			var ls = lbl.label_settings.duplicate()
			ls.font = font
			lbl.label_settings = ls
	# Suma de jaula Killer
	var kv = get_node_or_null("Killervalue")
	if kv and kv.label_settings:
		var ls = kv.label_settings.duplicate()
		ls.font = font
		kv.label_settings = ls

func set_knight_restriction(active: bool) -> void:
	has_knight_restriction = active
	if is_node_ready():
		_update_visuals()

func _update_visuals() -> void:
	if has_knight_restriction and value == true_value:
		animated_values.visible = true
		animated_values.play("knight")
		text_label.visible = false
	else:
		animated_values.visible = false
		animated_values.stop()
		text_label.visible = true
		
	if killer_cell:
		sprite_jaula.visible = true
		var t = cage_borders.get("top", false)
		var b = cage_borders.get("bottom", false)
		var l = cage_borders.get("left", false)
		var r = cage_borders.get("right", false)
		
		sprite_jaula.play('default')
			
		# 1 borde activo (Paredes simples)
		if t and not b and not l and not r:
			sprite_jaula.frame = 16
		elif b and not t and not l and not r:
			sprite_jaula.frame = 20
		elif l and not t and not b and not r:
			sprite_jaula.frame = 22
		elif r and not t and not b and not l:
			sprite_jaula.frame = 18
			
		# 2 bordes activos (Esquinas y pasillos)
		elif t and b and not l and not r: # Pasillo vertical
			sprite_jaula.frame = 4
		elif l and r and not t and not b: # Pasillo horizontal
			sprite_jaula.frame = 5
		elif t and l and not b and not r: # Esquina superior izquierda
			sprite_jaula.frame = 15
		elif t and r and not b and not l: # Esquina superior derecha
			sprite_jaula.frame = 17
		elif b and l and not t and not r: # Esquina inferior izquierda
			sprite_jaula.frame = 21
		elif b and r and not t and not l: # Esquina inferior derecha
			sprite_jaula.frame = 19
			
		# 3 bordes activos (Bordes tipo "T" o callejones sin salida de 3 lados)
		elif t and b and l and not r:
			sprite_jaula.frame = 0
		elif t and b and r and not l:
			sprite_jaula.frame = 2
		elif t and l and r and not b:
			sprite_jaula.frame = 1
		elif b and l and r and not t:
			sprite_jaula.frame = 3
			
		# 4 bordes activos (Celda aislada de 1x1)
		elif t and b and l and r:
			sprite_jaula.frame = 0
	else:
		sprite_jaula.visible = false
	
	
func _on_area_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Casilla clickeada: ", name)
		# Aquí manejas la lógica de la casilla
		toggle_selected()

func is_mouse_over_cell() -> bool:
	var cell_size_val = board.cell_size if board and "cell_size" in board else 64.0
	var half_size = cell_size_val / 2.0
	var local_pos = to_local(get_global_mouse_position())
	return abs(local_pos.x) <= half_size and abs(local_pos.y) <= half_size

# En CellUI.gd
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_mouse_over_cell():
					_click_start_pos = event.position
					_is_click_active = true
			else:
				if _is_click_active:
					_is_click_active = false
					# Si se soltó a menos de 15 píxeles de donde se presionó, es un click/tap válido (no un arrastre)
					if event.position.distance_to(_click_start_pos) < 15.0:
						animted_sprite.visible = true
						animted_sprite.play("default")
						Global.change_focus(self)
						cell_selected.emit(self)
						
						# Print de informacion de las jaulas killer
						#if board and board.get("cell_to_cage") and board.cell_to_cage.has(coords):
							#var cage_info = board.cell_to_cage[coords]
							#print("=== JAULA KILLER SELECCIONADA ===")
							#print("Celda seleccionada: ", coords)
							#print("Suma objetivo de la jaula: ", cage_info["sum"])
							#print("Celdas que pertenecen a la misma jaula: ", cage_info["cells"])
							#print("=================================")
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_mouse_over_cell():
				verify_number(0) # Borrar
				get_viewport().set_input_as_handled()

func toggle_selected(): pass
func _refresh() -> void:
	if value == 0:
		text_label.text = ""
	else:
		text_label.text = str(value)
		
	# [OPCIONAL] Feedback visual en blanco y negro de alto contraste:
	if is_fixed:
		text_label.modulate = Color.BLACK # Las pistas se ven sólidas
	else:
		text_label.modulate = Color.DARK_SLATE_GRAY # Lo que el jugador modifique se ve distinto

func verify_number(number) -> void:
	if is_fixed:
		return
	if number == value:
		return
	
	var is_correct = (number == true_value)
	value = number
	
	# Restaurar modulación por defecto
	highlight_cell_state(false, false)
	
	if number == 0:
		text_label.text = ""
	else:
		text_label.text = str(number)
		
	# Si es incorrecto y estamos en Modo Práctica, registrar que fue incorrecto
	var current_mode = Global.GameMode.PRACTICE
	if board and "game_mode" in board:
		current_mode = board.game_mode
		
	if not is_correct and number != 0:
		if current_mode == Global.GameMode.PRACTICE:
			has_been_incorrect = true
	
	# Si se introduce un número en modo normal, ocultamos todos los candidatos
	clear_all_pencil_marks()
	
	# Emitir señal de cambio de valor
	cell_value_changed.emit(coords, number, is_correct)
	
	# Actualizar aspectos visuales (por ejemplo, mostrar/ocultar caballo)
	_update_visuals()
	
	# Sincronizar con celda gemela si es compartida
	if is_shared and linked_cell != null and not _syncing:
		_syncing = true
		linked_cell.set_value_from_link(number)
		_syncing = false

## Recibe un valor desde la celda gemela (compartida).
## Usa _syncing para evitar loops infinitos de sincronización.
func set_value_from_link(number: int) -> void:
	if is_fixed or _syncing:
		return
	if number == value:
		return
	_syncing = true
	value = number
	var is_correct = (number == true_value)
	
	highlight_cell_state(false, false)
	
	if number == 0:
		text_label.text = ""
	else:
		text_label.text = str(number)
		
	var current_mode = Global.GameMode.PRACTICE
	if board and "game_mode" in board:
		current_mode = board.game_mode
		
	if not is_correct and number != 0:
		if current_mode == Global.GameMode.PRACTICE:
			has_been_incorrect = true
	
	# Si se introduce un número en modo normal, ocultamos todos los candidatos
	clear_all_pencil_marks()
	
	cell_value_changed.emit(coords, number, is_correct)
	_update_visuals()
	_syncing = false


## Vincula esta celda con su gemela en otro board (zona de solapamiento)
func link_to(other_cell: CellUI) -> void:
	is_shared = true
	linked_cell = other_cell
	other_cell.is_shared = true
	other_cell.linked_cell = self

func _on_area_2d_mouse_entered() -> void:
	is_focus = true

func _on_area_2d_mouse_exited() -> void:
	is_focus = false
func _assign_border():
	var x = coords.x % 3
	var y = coords.y % 3
	if y == 0:
		if x < 2:
			animated_border.play("LeftUpDown")
		else:
			animated_border.play("All")
	else:
		if x < 2:
			animated_border.play("LeftDown")
		else :
			animated_border.play("SidesDown")
