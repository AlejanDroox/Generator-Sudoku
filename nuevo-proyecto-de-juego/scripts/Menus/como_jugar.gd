extends Control

# Referencias a nodos de las fichas en la pila
@onready var card_top: TextureRect = $StackContainer/CardTop
@onready var card_middle: TextureRect = $StackContainer/CardMiddle
@onready var card_bottom: TextureRect = $StackContainer/CardBottom

# Contenedores de texto y flechas
@onready var text_label: RichTextLabel = $TextContainer/RichTextLabel
@onready var page_title: Label = $TextContainer/PageTitle
@onready var pointer_arrow: Sprite2D = $PointerArrow

# Etiquetas internas de las fichas para depuración visual
@onready var label_top: Label = $StackContainer/CardTop/Label
@onready var label_middle: Label = $StackContainer/CardMiddle/Label
@onready var label_bottom: Label = $StackContainer/CardBottom/Label

# Referencias a contenedores gráficos específicos dentro de la ficha activa
@onready var diagram_classic: Control = $StackContainer/CardTop/Diagrams/Classic
@onready var diagram_samurai: Control = $StackContainer/CardTop/Diagrams/Samurai
@onready var diagram_knight: Control = $StackContainer/CardTop/Diagrams/Knight
@onready var diagram_killer: Control = $StackContainer/CardTop/Diagrams/Killer
@onready var diagram_thermo: Control = $StackContainer/CardTop/Diagrams/Thermo
@onready var diagram_arrow: Control = $StackContainer/CardTop/Diagrams/Arrow
@onready var diagrams_parent: Control = $StackContainer/CardTop/Diagrams

# Botones de navegación
@onready var btn_next: Button = $Navigation/BtnNext
@onready var btn_prev: Button = $Navigation/BtnPrev
@onready var btn_back: Button = $Navigation/BtnBack

# Pila de nodos para rotar dinámicamente las referencias
var card_stack: Array[TextureRect] = []

# Posiciones y rotaciones base de la pila para simular profundidad
var stack_positions = [
	Vector2(0, 0),       # Top (Frente)
	Vector2(12, 10),     # Middle (Centro)
	Vector2(-15, 18)     # Bottom (Atrás)
]

var stack_rotations = [
	0.0,   # Top
	3.5,   # Middle
	-4.0   # Bottom
]

var current_page: int = 0
var is_animating: bool = false
var arrow_tween: Tween

# Textos e información de cada página del libro de reglas
var pages_data = [
	{
		"title": "1. Reglas Basicas",
		"text": "[font_size=20][color=dark_red][b]SUDOKU ESTANDAR[/b][/color][/font_size]\n\nEl objetivo es rellenar las celdas vacias con numeros del [color=blue][b]1 al 9[/b][/color].\n\nNo se puede repetir ningun digito dentro de una misma [b]fila[/b], [b]columna[/b] o cuadricula o bloque de [b]3x3[/b].\n\n[color=#444444]* Mira la ficha a la izquierda: muestra un bloque 3x3 de ejemplo.[/color]",
		"arrow_pos": Vector2(490, 240),
		"arrow_rot": 180.0,
		"diagram_node": "Classic"
	},
	{
		"title": "2. Solapamiento Samurai",
		"text": "[font_size=20][color=dark_red][b]SUDOKU EN CADENA[/b][/color][/font_size]\n\nLos tableros estan conectados en sus esquinas por un bloque de [color=blue][b]3x3 compartido, celdas vinculadas[/b][/color].\n\nLos numeros que coloques ahi afectan las restricciones de [b]ambos[/b] tableros.\n\nAl resolver un [color=green][b]70 porciento[/b][/color] del tablero actual, se generara y desbloqueara el siguiente en diagonal.",
		"arrow_pos": Vector2(480, 180),
		"arrow_rot": 140.0,
		"diagram_node": "Samurai"
	},
	{
		"title": "3. Variante Anti-Knight",
		"text": "[font_size=20][color=dark_red][b]MOVIMIENTO DE CABALLO[/b][/color][/font_size]\n\nNingun numero igual puede estar a distancia de un [color=purple][b]movimiento de caballo de ajedrez[/b][/color] - L: 2 celdas en una direccion y 1 en perpendicular.\n\n[color=#444444]* En el ejemplo: la celda con el caballo restringe a todas las celdas marcadas con una cruz X.[/color]",
		"arrow_pos": Vector2(510, 310),
		"arrow_rot": 190.0,
		"diagram_node": "Knight"
	},
	{
		"title": "4. Variante Killer Sudoku",
		"text": "[font_size=20][color=dark_red][b]JAULAS SUMATORIAS[/b][/color][/font_size]\n\nLas lineas punteadas delimitan [color=brown][b]Jaulas o Cages[/b][/color].\n\nEl numero pequeno indica la [b]suma exacta[/b] que deben dar los digitos de su interior.\n\n[b]Regla clave:[/b] los numeros no se pueden repetir dentro de una misma jaula.",
		"arrow_pos": Vector2(470, 170),
		"arrow_rot": 150.0,
		"diagram_node": "Killer"
	},
	{
		"title": "5. Variante Thermo Sudoku",
		"text": "[font_size=20][color=dark_red][b]TERMOMETROS LOGICOS[/b][/color][/font_size]\n\nLos numeros en un termometro deben ser [color=orange][b]estrictamente crecientes[/b][/color] partiendo desde el bulbo, circulo grande, hasta el extremo de la cola.\n\n[color=#444444]* Ejemplo: 2 -> 4 -> 7 cumple la regla, pero 2 -> 4 -> 3 fallaria inmediatamente.[/color]",
		"arrow_pos": Vector2(500, 270),
		"arrow_rot": 175.0,
		"diagram_node": "Thermo"
	},
	{
		"title": "6. Variante Arrow Sudoku",
		"text": "[font_size=20][color=dark_red][b]FLECHAS DE SUMA[/b][/color][/font_size]\n\nEl digito en el circulo inicial debe ser la [color=green][b]suma exacta[/b][/color] de los numeros situados a lo largo de la linea o eje de la flecha.\n\n[color=#444444]* En el ejemplo: 9 es igual a la suma de 5 y 4.[/color]",
		"arrow_pos": Vector2(500, 330),
		"arrow_rot": 200.0,
		"diagram_node": "Arrow"
	}
]

func _ready() -> void:
	# Inicializar el stack de nodos
	card_stack = [card_top, card_middle, card_bottom]
	
	# Establecer posiciones iniciales de forma directa
	_apply_stack_states_immediate()
	
	# Aplicar los bordes originales dibujados a mano de las celdas
	_apply_original_borders()
	
	# Conectar señales
	btn_next.pressed.connect(_on_next_pressed)
	btn_prev.pressed.connect(_on_prev_pressed)
	btn_back.pressed.connect(_on_back_pressed)
	
	# Mostrar primera página
	_show_page(0, false)
	
	# Iniciar animación de la flecha
	_start_arrow_animation()
	
	_update_fonts()
	Global.tutorial_font_changed.connect(func(_use_neutral): _update_fonts())

func _exit_tree() -> void:
	if arrow_tween:
		arrow_tween.kill()

# Coloca las fichas en su posición física por defecto según su jerarquía en card_stack
func _apply_stack_states_immediate() -> void:
	for i in range(card_stack.size()):
		var card = card_stack[i]
		card.position = stack_positions[i]
		card.rotation_degrees = stack_rotations[i]
		card.z_index = 10 - i
		card.modulate.a = 1.0

# Muestra el contenido de la página actual en la UI
func _show_page(page_idx: int, animate_content: bool = true) -> void:
	current_page = page_idx
	var data = pages_data[page_idx]
	
	# Actualizar textos
	page_title.text = data["title"]
	text_label.text = data["text"]
	
	# Actualizar botones de navegación
	btn_prev.disabled = (page_idx == 0)
	if page_idx == pages_data.size() - 1:
		btn_next.text = "Finalizar"
	else:
		btn_next.text = "Siguiente"
		
	# Actualizar nombres en las fichas para depuración visual del stack
	_update_card_labels()
	
	# Mostrar el diagrama correspondiente en la ficha del frente (card_stack[0])
	_update_diagrams(data["diagram_node"])
	
	# Colocar la flecha indicadora en su posición objetivo
	if pointer_arrow:
		var target_pos = data["arrow_pos"]
		var target_rot = data["arrow_rot"]
		if animate_content:
			var t = create_tween().set_parallel(true)
			t.tween_property(pointer_arrow, "position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_property(pointer_arrow, "rotation_degrees", target_rot, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			pointer_arrow.position = target_pos
			pointer_arrow.rotation_degrees = target_rot

# Hace visible el diagrama indicado y oculta los demás en la ficha frontal
func _update_diagrams(active_name: String) -> void:
	# Ocultar todos
	diagram_classic.visible = false
	diagram_samurai.visible = false
	diagram_knight.visible = false
	diagram_killer.visible = false
	diagram_thermo.visible = false
	diagram_arrow.visible = false
	
	# Mostrar el activo
	match active_name:
		"Classic": diagram_classic.visible = true
		"Samurai": diagram_samurai.visible = true
		"Knight": diagram_knight.visible = true
		"Killer": diagram_killer.visible = true
		"Thermo": diagram_thermo.visible = true
		"Arrow": diagram_arrow.visible = true

func _update_card_labels() -> void:
	# Card_stack[0] es la que está al frente, card_stack[1] al medio y card_stack[2] al fondo.
	# Les asignamos textos explicativos de su posición en la pila
	for i in range(card_stack.size()):
		var label = card_stack[i].get_node("Label") as Label
		if label:
			if i == 0:
				label.text = "Ficha Activa"
			elif i == 1:
				label.text = "Ficha Siguiente"
			else:
				label.text = "Fila de Fichas"

# Animación continua de balanceo/rebote para la flecha indicadora
func _start_arrow_animation() -> void:
	if not pointer_arrow:
		return
		
	if arrow_tween:
		arrow_tween.kill()
		
	arrow_tween = create_tween().set_loops()
	# La flecha se mueve ligeramente adelante y atrás en su eje local
	arrow_tween.tween_property(pointer_arrow, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrow_tween.tween_property(pointer_arrow, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_next_pressed() -> void:
	if is_animating:
		return
		
	if current_page == pages_data.size() - 1:
		_on_back_pressed()
		return
		
	_discard_card_forward()

func _on_prev_pressed() -> void:
	if is_animating or current_page == 0:
		return
		
	_pull_card_backward()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenas/Menus/menu.tscn")

# ANIMACIÓN DE DESCARTE (Pasar a la siguiente página)
# La ficha del frente se desliza a la izquierda y se va al fondo de la pila.
func _discard_card_forward() -> void:
	is_animating = true
	
	# Identificar la ficha que sale
	var exiting_card = card_stack[0]
	
	# 1. Animación de deslizamiento hacia la izquierda de la ficha frontal
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Deslizar y rotar la ficha saliente hacia afuera
	var target_slide_pos = exiting_card.position + Vector2(-380, -50)
	tween.tween_property(exiting_card, "position", target_slide_pos, 0.35)
	tween.tween_property(exiting_card, "rotation_degrees", -25.0, 0.35)
	tween.tween_property(exiting_card, "modulate:a", 0.0, 0.35)
	
	# 2. Las fichas restantes en la pila se desplazan suavemente al frente
	var card_middle_node = card_stack[1]
	var card_bottom_node = card_stack[2]
	
	# Mover la del medio al frente
	tween.tween_property(card_middle_node, "position", stack_positions[0], 0.3)
	tween.tween_property(card_middle_node, "rotation_degrees", stack_rotations[0], 0.3)
	
	# Mover la del fondo al medio
	tween.tween_property(card_bottom_node, "position", stack_positions[1], 0.35)
	tween.tween_property(card_bottom_node, "rotation_degrees", stack_rotations[1], 0.35)
	
	# Esperar a que concluyan los movimientos
	await tween.finished
	
	# 3. Reordenar el array lógico de la pila:
	# El elemento 0 pasa a ser el último (2).
	card_stack.remove_at(0)
	card_stack.append(exiting_card)
	
	# Reparentar el contenedor de diagramas a la nueva ficha del frente
	if is_instance_valid(diagrams_parent) and diagrams_parent.get_parent() != card_stack[0]:
		diagrams_parent.get_parent().remove_child(diagrams_parent)
		card_stack[0].add_child(diagrams_parent)
	
	# Ajustar Z-Index físicos para reflejar el nuevo orden de capas
	for i in range(card_stack.size()):
		card_stack[i].z_index = 10 - i
		
	# 4. Actualizar la información de la página actual
	_show_page(current_page + 1, true)
	
	# 5. La ficha saliente (ahora al fondo) regresa flotando desde atrás
	exiting_card.position = stack_positions[2] + Vector2(100, -20)
	exiting_card.rotation_degrees = stack_rotations[2]
	
	var return_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(exiting_card, "position", stack_positions[2], 0.25)
	return_tween.tween_property(exiting_card, "modulate:a", 1.0, 0.2)
	
	await return_tween.finished
	is_animating = false

# ANIMACIÓN INVERSA (Volver a la página anterior)
# La ficha del fondo se desliza por la izquierda y aterriza al frente de la pila.
func _pull_card_backward() -> void:
	is_animating = true
	
	# La ficha que está al fondo del array (2) es la que se deslizará al frente
	var entering_card = card_stack[2]
	
	# Reparentar el contenedor de diagramas a la ficha que va a entrar antes de moverla
	if is_instance_valid(diagrams_parent) and diagrams_parent.get_parent() != entering_card:
		diagrams_parent.get_parent().remove_child(diagrams_parent)
		entering_card.add_child(diagrams_parent)
	
	# 1. Deslizar la ficha del fondo hacia la izquierda de forma invisible
	entering_card.position = stack_positions[2] + Vector2(-380, -50)
	entering_card.rotation_degrees = -25.0
	entering_card.modulate.a = 0.0
	
	# Ajustar Z-Index para que quede al frente antes de aparecer
	entering_card.z_index = 11
	
	# 2. Las fichas actuales se desplazan hacia atrás
	var card_top_node = card_stack[0]
	var card_middle_node = card_stack[1]
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Mover del frente al medio
	tween.tween_property(card_top_node, "position", stack_positions[1], 0.3)
	tween.tween_property(card_top_node, "rotation_degrees", stack_rotations[1], 0.3)
	
	# Mover del medio al fondo
	tween.tween_property(card_middle_node, "position", stack_positions[2], 0.35)
	tween.tween_property(card_middle_node, "rotation_degrees", stack_rotations[2], 0.35)
	
	# Deslizar la carta que entra hacia el frente y desvanecerla hacia visible
	tween.tween_property(entering_card, "position", stack_positions[0], 0.35)
	tween.tween_property(entering_card, "rotation_degrees", stack_rotations[0], 0.35)
	tween.tween_property(entering_card, "modulate:a", 1.0, 0.25)
	
	# Actualizar contenido antes de que termine de posicionarse al frente
	_show_page(current_page - 1, true)
	
	await tween.finished
	
	# 3. Reordenar el array lógico de la pila:
	# El último elemento (2) pasa a ser el primero (0)
	card_stack.pop_back()
	card_stack.insert(0, entering_card)
	
	# Restablecer los Z-index definitivos
	for i in range(card_stack.size()):
		card_stack[i].z_index = 10 - i
		
	is_animating = false

func _apply_original_borders() -> void:
	# Cargar la textura original de spritesheet del juego
	var spritesheet = load("res://assets/spritesheet.png") as Texture2D
	if not spritesheet:
		return
	
	# Aplicar recursivamente a todos los paneles dentro de la ficha de diagramas
	if is_instance_valid(diagrams_parent):
		_recursive_apply_borders(diagrams_parent, spritesheet)

func _recursive_apply_borders(node: Node, spritesheet: Texture2D) -> void:
	if node is Panel:
		_add_border_to_panel(node, spritesheet)
	for child in node.get_children():
		_recursive_apply_borders(child, spritesheet)

func _add_border_to_panel(panel: Panel, spritesheet: Texture2D) -> void:
	var parent = panel.get_parent()
	var texture: Texture2D = null
	
	if parent is GridContainer:
		# Encontrar el índice de este panel entre los hijos Panel del parent
		var panel_children = []
		for child in parent.get_children():
			if child is Panel:
				panel_children.append(child)
		
		var idx = panel_children.find(panel)
		if idx != -1:
			var cols = parent.columns
			var col = idx % cols
			var row = idx / cols
			
			var x = col % 3
			var y = row % 3
			
			var anim_name = "All"
			if y == 0:
				if x < 2:
					anim_name = "LeftUpDown"
				else:
					anim_name = "All"
			else:
				if x < 2:
					anim_name = "LeftDown"
				else:
					anim_name = "SidesDown"
			
			texture = _get_border_texture(anim_name, spritesheet)
			
	if not texture:
		# Fallback por defecto si no está en un GridContainer
		texture = _get_border_texture("All", spritesheet)
		
	# Crear el nodo que renderizará la textura de borde original
	var tex_rect = TextureRect.new()
	tex_rect.texture = texture
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Si no es un panel resaltado (ej. las casillas rojas o verdes de Knight), ocultamos el fondo plano gris
	var has_highlight = panel.name == "CenterHorse" or panel.name in ["P2", "P4", "P6", "P10", "P16", "P20", "P22", "P24"]
	if not has_highlight:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		
	# Agregar detrás del texto y otros elementos del panel
	panel.add_child(tex_rect)
	panel.move_child(tex_rect, 0)

func _get_border_texture(anim_name: String, spritesheet: Texture2D) -> AtlasTexture:
	var atlas_tex = AtlasTexture.new()
	atlas_tex.atlas = spritesheet
	
	match anim_name:
		"All":
			atlas_tex.region = Rect2(0, 3584, 512, 512)
		"LeftDown":
			atlas_tex.region = Rect2(0, 512, 512, 512)
		"LeftUpDown":
			atlas_tex.region = Rect2(0, 2560, 512, 512)
		"RightDown":
			atlas_tex.region = Rect2(2048, 1536, 512, 512)
		"RightUpDown":
			atlas_tex.region = Rect2(0, 2048, 512, 512)
		"SidesDown":
			atlas_tex.region = Rect2(2048, 4096, 512, 512)
		_:
			atlas_tex.region = Rect2(0, 3584, 512, 512)
			
	return atlas_tex

func _update_fonts() -> void:
	var font: Font
	if Global.use_neutral_tutorial_font:
		var sf = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial", "Helvetica", "sans-serif", "Segoe UI"])
		font = sf
	else:
		font = load("res://extra/fuentes/ShonenPunk custom bold.ttf")
		
	if is_instance_valid(text_label):
		text_label.add_theme_font_override("normal_font", font)
		text_label.add_theme_font_override("bold_font", font)
		text_label.add_theme_font_override("italics_font", font)
		text_label.add_theme_font_override("bold_italics_font", font)
		text_label.add_theme_font_override("mono_font", font)
