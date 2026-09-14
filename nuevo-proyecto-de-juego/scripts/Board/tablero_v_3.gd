extends Node2D
class_name Board

## Emitida cuando todas las celdas del board están correctamente completadas
signal board_completed(board_id: StringName)
## Emitida cuando una celda cambia de valor
signal cell_changed(board_id: StringName, coords: Vector2i, value: int, is_correct: bool)
## Emitida cuando se comete un error silencioso/invisible en Modo Práctica
signal invisible_error_detected(coords: Vector2i, val: int)

const  cell_scene: PackedScene = preload("res://scenas/Board/cellv_2.tscn")
@export var cell_size: float = 32.0
@export var sector_gap: float = 12.0
var cells_dict: Dictionary = {}

## Identificador único de este board en el sistema de cadena
var board_id: StringName = &""
var game_mode: int = Global.GameMode.PRACTICE
## Tipo de variante aplicada a este board (índice de SudokuGenerator.VariantType)
var variant_type: int = 0  # CLASSIC por defecto

## El número específico que tiene la restricción de caballo (0 si ninguno/elegido al azar)
var knight_restricted_number: int = 0
## Solución completa para verificación
var _solution: Dictionary = {}
## Número de celdas no-fijas (que el jugador debe llenar)
var _total_empty_cells: int = 0
## Número de celdas no-fijas que ya están correctas
var _correct_cells: int = 0
## Flag para evitar emitir board_completed más de una vez
var _is_completed: bool = false

@export_category('Constrains')
@export var samurai: bool = true
@export var knight_move: bool
@export var killer: bool
@export var arrow: bool
@export var thermo: bool


# Array de jaulas Killer y su mapa de acceso rápido
var killer_cages: Array = []
var cell_to_cage: Dictionary = {}

# Cadenas de termómetros y flechas para dibujar
var thermo_chains: Array = []
var arrow_constraints: Array = []

# Array de 9 grupos para almacenar las celdas por su sector 3x3
var sectors: Array[Array] = [[], [], [], [], [], [], [], [], []]

func _ready() -> void:
	pass

func build_board(puzzle: Dictionary, solution: Dictionary, extra_data: Dictionary = {}) -> void:
	_clear_board()
	_solution = solution
	_total_empty_cells = 0
	_correct_cells = 0
	_is_completed = false
	
	# Extraer datos de jaulas si existen
	killer_cages = extra_data.get("killer_cages", [])
	cell_to_cage.clear()
	for ci in range(killer_cages.size()):
		var cage = killer_cages[ci]
		for cell_coords in cage["cells"]:
			cell_to_cage[cell_coords] = {
				"cage_index": ci,
				"sum": cage["sum"],
				"cells": cage["cells"]
			}

	# Extraer otros datos de variantes
	thermo_chains = extra_data.get("thermo_chains", [])
	arrow_constraints = extra_data.get("arrow_constraints", [])

	# Leer el número con restricción de caballo asignado en la generación
	knight_restricted_number = extra_data.get("knight_restricted_number", 0)
	# Si no viene en los datos y el tablero la requiere, elegimos uno aleatorio
	if (variant_type == 1 or knight_move) and knight_restricted_number == 0:
		knight_restricted_number = randi_range(1, 9)
		
	if knight_restricted_number != 0:
		print("Tablero ", board_id, " usando restricción de caballo para el número: ", knight_restricted_number)

	var text_value = ''
	for x in range(9):
		for y in range(9):
			var coords = Vector2i(x, y)
			
			# Instanciamos la celda
			var cell:CellUI = cell_scene.instantiate()
			
			add_child(cell)
			cell.true_value = solution[coords]
			cell.board_id = board_id
			cell.board = self
			
			# Conectamos señales de la celda al board
			cell.cell_value_changed.connect(_on_cell_value_changed)
			
			# --- LA MATEMÁTICA DEL POSICIONAMIENTO ---
			# Usamos división entera para saber en qué "bloque" (0, 1 o 2) estamos
			@warning_ignore("integer_division")
			var block_x = x / 3
			@warning_ignore("integer_division")
			var block_y = y / 3
			
			# Posición = (Coordenada * Tamaño) + (Bloque * Espaciado)
			var pos_x = (x * cell_size) + (block_x * sector_gap)
			var pos_y = (y * cell_size) + (block_y * sector_gap)
			
			cell.position = Vector2(pos_x, pos_y)
			
			# Usamos tu función setup para inicializar los datos
			var value = puzzle.get(coords, 0)
			cell.setup(value, coords)
			
			# Si el tablero tiene la restricción de caballo y la celda contiene ese número en la solución
			if (variant_type == 1 or knight_move) and cell.true_value == knight_restricted_number:
				cell.set_knight_restriction(true)
			else:
				cell.set_knight_restriction(false)
				
			text_value += str(value)
			# --- GUARDAMOS LAS REFERENCIAS ---
			cells_dict[coords] = cell
			
			# Contamos celdas vacías para detección de completitud
			if value == 0:
				_total_empty_cells += 1
			
			# Calculamos a cuál de los 9 sectores pertenece (Índice del 0 al 8)
			var sector_index = (block_y * 3) + block_x
			sectors[sector_index].append(cell)
	print(text_value)

	# --- CALCULAR BORDES Y SUMAS DE LAS JAULAS KILLER ---
	if killer or variant_type == 2: # 2 = KILLER
		# Primero asignar sumas en las celdas root (superior-izquierda) de cada jaula
		for cage in killer_cages:
			var cells_in_cage = cage["cells"]
			if cells_in_cage.is_empty():
				continue
			# Encontrar la celda superior-izquierda
			var root_cell = cells_in_cage[0]
			for c in cells_in_cage:
				if c.y < root_cell.y or (c.y == root_cell.y and c.x < root_cell.x):
					root_cell = c
			
			var cell_ui: CellUI = cells_dict.get(root_cell)
			if cell_ui:
				cell_ui.cage_sum = cage["sum"]
		
		# Calcular bordes de jaula
		for coords in cells_dict:
			var cell: CellUI = cells_dict[coords]
			if cell_to_cage.has(coords):
				var cage_idx = cell_to_cage[coords]["cage_index"]
				cell.killer_cell = true
				cell.cage_borders["top"] = not cell_to_cage.has(coords + Vector2i(0, -1)) or cell_to_cage[coords + Vector2i(0, -1)]["cage_index"] != cage_idx
				cell.cage_borders["bottom"] = not cell_to_cage.has(coords + Vector2i(0, 1)) or cell_to_cage[coords + Vector2i(0, 1)]["cage_index"] != cage_idx
				cell.cage_borders["left"] = not cell_to_cage.has(coords + Vector2i(-1, 0)) or cell_to_cage[coords + Vector2i(-1, 0)]["cage_index"] != cage_idx
				cell.cage_borders["right"] = not cell_to_cage.has(coords + Vector2i(1, 0)) or cell_to_cage[coords + Vector2i(1, 0)]["cage_index"] != cage_idx
			
			cell.update_cage_visuals()

	# Forzar el redibujado de la capa de fondo (termómetros y flechas)
	queue_redraw()

func get_cell_pixel_position(coords: Vector2i) -> Vector2:
	@warning_ignore("integer_division")
	var block_x = coords.x / 3
	@warning_ignore("integer_division")
	var block_y = coords.y / 3
	var pos_x = (coords.x * cell_size) + (block_x * sector_gap)
	var pos_y = (coords.y * cell_size) + (block_y * sector_gap)
	return Vector2(pos_x, pos_y)

func get_cell_center(coords: Vector2i) -> Vector2:
	return get_cell_pixel_position(coords)

func _draw() -> void:
	# 1. Dibujar termómetros (Thermo)
	if thermo or variant_type == 3: # 3 = THERMO
		for chain in thermo_chains:
			if chain.is_empty():
				continue
			
			var center_start = get_cell_center(chain[0])
			
			# Dibujar la bombilla (círculo gris semi-transparente)
			draw_circle(center_start, cell_size * 0.35, Color(0.7, 0.7, 0.7, 0.45))
			
			# Dibujar el tubo (líneas que conectan los centros)
			for i in range(chain.size() - 1):
				var p1 = get_cell_center(chain[i])
				var p2 = get_cell_center(chain[i + 1])
				draw_line(p1, p2, Color(0.7, 0.7, 0.7, 0.45), cell_size * 0.2, true)
				
	# 2. Dibujar flechas (Arrow)
	if arrow or variant_type == 4: # 4 = ARROW
		for arr in arrow_constraints:
			var circle_cell = arr["circle"]
			var shaft = arr["shaft"]
			if shaft.is_empty():
				continue
				
			var center_circle = get_cell_center(circle_cell)
			
			# Dibujar el círculo (outline azul semi-transparente)
			draw_arc(center_circle, cell_size * 0.35, 0, TAU, 32, Color(0.1, 0.5, 0.8, 0.6), 4.0, true)
			
			# Dibujar las líneas del shaft
			var prev_point = center_circle
			for i in range(shaft.size()):
				var next_point = get_cell_center(shaft[i])
				draw_line(prev_point, next_point, Color(0.1, 0.5, 0.8, 0.6), 4.0, true)
				prev_point = next_point
				
			# Dibujar la punta de flecha en el extremo
			var last_point = get_cell_center(shaft[-1])
			var penultimate_point = center_circle if shaft.size() == 1 else get_cell_center(shaft[-2])
			var direction = (last_point - penultimate_point).normalized()
			
			var arrow_head_size = cell_size * 0.25
			var left_wing = last_point - direction.rotated(PI / 6) * arrow_head_size
			var right_wing = last_point - direction.rotated(-PI / 6) * arrow_head_size
			
			draw_line(last_point, left_wing, Color(0.1, 0.5, 0.8, 0.6), 4.0, true)
			draw_line(last_point, right_wing, Color(0.1, 0.5, 0.8, 0.6), 4.0, true)


## Handler interno: una celda cambió su valor
func _on_cell_value_changed(coords: Vector2i, new_value: int, is_correct: bool) -> void:
	# Propagar la señal al nivel superior (SamuraiManager)
	cell_changed.emit(board_id, coords, new_value, is_correct)
	
	if game_mode == Global.GameMode.PRACTICE:
		update_board_highlights()
		# Si es incorrecto y no está vacío, verificar si hay conflictos visibles
		if not is_correct and new_value != 0:
			var conflicts = find_conflicts(coords, new_value)
			if conflicts.is_empty():
				# Error invisible detected! Emit signal
				invisible_error_detected.emit(coords, new_value)
	
	# Verificar completitud
	if not _is_completed:
		check_completion()

## Verifica si todas las celdas no-fijas tienen el valor correcto
func check_completion() -> void:
	if _is_completed:
		return
	
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		if not cell.is_fixed:
			if cell.value != cell.true_value:
				return  # Hay al menos una celda incorrecta o vacía
	
	# Todas las celdas están correctas
	_is_completed = true
	board_completed.emit(board_id)

## Devuelve la celda en las coordenadas indicadas (o null si no existe)
func get_cell(coords: Vector2i) -> CellUI:
	return cells_dict.get(coords, null)

## Devuelve true si este board ya fue completado
func is_completed() -> bool:
	return _is_completed

## Devuelve el porcentaje de celdas resueltas correctamente (0.0 a 1.0)
func get_solved_percentage() -> float:
	var correct_count = 0
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		if cell.value != 0 and cell.value == cell.true_value:
			correct_count += 1
	return float(correct_count) / 81.0

## Extrae el estado actual de las pistas fijas del tablero para usar como semilla de excavación.
func get_puzzle_state() -> Dictionary:
	var puzzle = {}
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		if cell.is_fixed:
			puzzle[coords] = cell.value
		else:
			puzzle[coords] = 0
	return puzzle

# Utilidad para limpiar el tablero por si generamos uno nuevo en el mismo nodo
func _clear_board() -> void:
	for child in get_children():
		child.queue_free()
	cells_dict.clear()
	for i in range(9):
		sectors[i].clear()

func clear_highlights() -> void:
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		cell.highlight_cell_state(false, false)

func update_board_highlights() -> void:
	clear_highlights()
	
	var error_cells: Array[Vector2i] = []
	var conflict_cells: Array[Vector2i] = []
	
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		if cell.is_fixed or cell.value == 0:
			continue
			
		if cell.value != cell.true_value:
			error_cells.append(coords) # Siempre marcar en rojo el valor erróneo
			var conflicts = find_conflicts(coords, cell.value)
			for c_coords in conflicts:
				if not conflict_cells.has(c_coords):
					conflict_cells.append(c_coords)
					
	for coords in cells_dict:
		var cell: CellUI = cells_dict[coords]
		var is_err = error_cells.has(coords)
		var is_conf = conflict_cells.has(coords)
		cell.highlight_cell_state(is_err, is_conf)

func find_conflicts(coords: Vector2i, val: int) -> Array[Vector2i]:
	var conflicts: Array[Vector2i] = []
	if val == 0:
		return conflicts

	# 1. Restricciones clásicas (Fila, Columna, Sector)
	for x in range(9):
		if x != coords.x:
			var cell = get_cell(Vector2i(x, coords.y))
			if cell and cell.value == val:
				conflicts.append(Vector2i(x, coords.y))
				
	for y in range(9):
		if y != coords.y:
			var cell = get_cell(Vector2i(coords.x, y))
			if cell and cell.value == val:
				conflicts.append(Vector2i(coords.x, y))
				
	@warning_ignore("integer_division")
	var block_x = coords.x / 3
	@warning_ignore("integer_division")
	var block_y = coords.y / 3
	for dx in range(3):
		for dy in range(3):
			var sx = block_x * 3 + dx
			var sy = block_y * 3 + dy
			if sx != coords.x or sy != coords.y:
				var cell = get_cell(Vector2i(sx, sy))
				if cell and cell.value == val:
					conflicts.append(Vector2i(sx, sy))

	# 2. Restricción Anti-Knight
	if knight_move or variant_type == 1:
		if val == knight_restricted_number:
			var knight_offsets = [
				Vector2i(-2, -1), Vector2i(-2, 1),
				Vector2i(-1, -2), Vector2i(-1, 2),
				Vector2i(1, -2), Vector2i(1, 2),
				Vector2i(2, -1), Vector2i(2, 1)
			]
			for offset in knight_offsets:
				var target = coords + offset
				if target.x >= 0 and target.x < 9 and target.y >= 0 and target.y < 9:
					var cell = get_cell(target)
					if cell and cell.value == val:
						conflicts.append(target)

	# 3. Restricción Thermo
	if thermo or variant_type == 3:
		for chain in thermo_chains:
			if coords in chain:
				var last_val = -1
				var chain_violated = false
				for cell_coords in chain:
					var cell = get_cell(cell_coords)
					if cell and cell.value != 0:
						if cell.value <= last_val:
							chain_violated = true
							break
						last_val = cell.value
					else:
						last_val = 0
				if chain_violated:
					for cell_coords in chain:
						if cell_coords != coords:
							var cell = get_cell(cell_coords)
							if cell and cell.value != 0:
								conflicts.append(cell_coords)

	# 4. Restricción Killer Cage
	if cell_to_cage.has(coords):
		var cage_info = cell_to_cage[coords]
		var cage_cells = cage_info["cells"]
		var target_sum = cage_info["sum"]
		
		var seen_vals = {}
		var duplicate_found = false
		for c_coords in cage_cells:
			var cell = get_cell(c_coords)
			if cell and cell.value != 0:
				if seen_vals.has(cell.value):
					duplicate_found = true
				seen_vals[cell.value] = true
				
		var current_sum = 0
		var all_filled = true
		for c_coords in cage_cells:
			var cell = get_cell(c_coords)
			if cell:
				current_sum += cell.value
				if cell.value == 0:
					all_filled = false
					
		if duplicate_found or current_sum > target_sum or (all_filled and current_sum != target_sum):
			for c_coords in cage_cells:
				if c_coords != coords:
					var cell = get_cell(c_coords)
					if cell and cell.value != 0:
						conflicts.append(c_coords)

	# 5. Restricción Arrow
	if arrow or variant_type == 4:
		for constraint in arrow_constraints:
			var circle = constraint["circle"]
			var shaft = constraint["shaft"]
			if coords == circle or coords in shaft:
				var circle_cell = get_cell(circle)
				var circle_val = circle_cell.value if circle_cell else 0
				
				var shaft_sum = 0
				var shaft_all_filled = true
				for s_coords in shaft:
					var s_cell = get_cell(s_coords)
					if s_cell:
						shaft_sum += s_cell.value
						if s_cell.value == 0:
							shaft_all_filled = false
							
				if (shaft_sum > circle_val and circle_val != 0) or (shaft_all_filled and circle_val != 0 and shaft_sum != circle_val):
					if coords != circle and circle_cell and circle_cell.value != 0:
						conflicts.append(circle)
					for s_coords in shaft:
						if s_coords != coords:
							var s_cell = get_cell(s_coords)
							if s_cell and s_cell.value != 0:
								conflicts.append(s_coords)
								
	return conflicts
