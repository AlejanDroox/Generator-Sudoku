extends RefCounted
class_name SudokuGenerator

## Generador y modulador de tableros de Sudoku.
##
## Gestiona la creación de tableros resueltos, excavación de pistas y 
## orquestación de variantes. También provee soporte para tableros
## encadenados en cadena progresiva y Sudokus Samurái.

#region 1. Señales y Enums

## Emitida cuando un intento de generación de nivel falla por contradicciones lógicas.
signal attempt_failed(attempt_num: int)
## Emitida cuando un intento de generación de nivel tiene éxito.
signal attempt_succeeded(attempt_num: int)

## Límites de pasos de backtracking para definir dificultades base
enum Difficulty {
	EASY = 0,    
	MEDIUM = 3,
	HARD = 150
}

## Direcciones físicas para el solape y transición de esquinas
enum ExitCorner {
	TOP_RIGHT,
	TOP_LEFT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT
}

## Tipos de variante soportados por el motor
enum VariantType {
	CLASSIC,
	ANTI_KNIGHT,
	KILLER,
	THERMO,
	ARROW
}

#endregion

#region 2. Variables de Estado

## Referencia activa al solucionador CSP
var solver: SudokuLogic

## Almacenamiento temporal para restricciones inyectadas externamente antes de la generación
var _pending_killer_cages: Array = []
var _pending_thermo_chains: Array = []
var _pending_arrow_constraints: Array = []

#endregion

#region 3. Inicialización

func _init() -> void:
	solver = SudokuLogic.new()

#endregion

#region 4. API Pública de Generación (Pisos & Samurai)

## Función principal para generar un nivel completo.
## [param seed_grid]: Esquina heredada (3x3) de tablero anterior si está en cadena progresiva.
## [param target_difficulty]: Dificultad lógica objetivo.
## [param variants]: Array con los tipos de variantes a aplicar.
## [param clue_grid]: Pistas del tablero anterior para blindaje avanzado.
## [param knight_restricted_number]: Número al que se limita el Anti-Knight (0 para todos).
func create_level(seed_grid: Dictionary, target_difficulty: int, variants: Array = [VariantType.CLASSIC], clue_grid: Dictionary = {}, knight_restricted_number: int = 0) -> Dictionary:
	var variants_array: Array = []
	variants_array = variants
		
	var shield_grid: Dictionary = clue_grid if not clue_grid.is_empty() else seed_grid
	
	var best_puzzle: Dictionary
	var best_solution: Dictionary
	var best_score: int = -1
	var max_attempts: int = 30
	var full_board: Dictionary = {}
	
	var thermo_count: int = 0
	var thermo_len: int = 3
	var arrow_count: int = 0
	var arrow_len: int = 2
	var killer_ratio: float = 0.0
	var killer_size: int = 2
	
	# Establecer parámetros de generación procedimental según dificultad objetivo
	if target_difficulty <= 2:
		thermo_count = randi_range(1, 2)
		thermo_len = 3
		arrow_count = randi_range(1, 2)
		arrow_len = 2
		killer_ratio = randf_range(0.15, 0.25)
		killer_size = 2
	elif target_difficulty <= 49:
		thermo_count = randi_range(2, 3)
		thermo_len = randi_range(3, 4)
		arrow_count = randi_range(2, 3)
		arrow_len = randi_range(2, 3)
		killer_ratio = randf_range(0.35, 0.50)
		killer_size = randi_range(2, 3)
	else:
		thermo_count = randi_range(3, 5)
		thermo_len = randi_range(3, 5)
		arrow_count = randi_range(3, 4)
		arrow_len = randi_range(2, 3)
		killer_ratio = randf_range(0.60, 0.75)
		killer_size = randi_range(2, 4)
		
	var current_thermo_count: int = thermo_count
	var current_arrow_count: int = arrow_count
	var current_killer_ratio: float = killer_ratio
	
	var knight_restricted_number_actual: int = knight_restricted_number
	if VariantType.ANTI_KNIGHT in variants_array and knight_restricted_number_actual == 0:
		knight_restricted_number_actual = randi_range(1, 9)
		
	print("SudokuGenerator: Iniciando create_level. Dificultad: ", target_difficulty, ", Variantes: ", variants_array, ", Caballo: ", knight_restricted_number_actual)
	
	for attempt in range(max_attempts):
		# Fallback escalonado a partir del intento 15
		if attempt == 15:
			@warning_ignore("integer_division")
			current_thermo_count = int(thermo_count / 2)
			@warning_ignore("integer_division")
			current_arrow_count = int(arrow_count / 2)
			current_killer_ratio = killer_ratio * 0.5
			print("SudokuGenerator: Intento 15. Reduciendo restricciones procedimentales.")
			
		solver.use_knight_constraint = VariantType.ANTI_KNIGHT in variants_array
		solver.knight_restricted_number = knight_restricted_number_actual
		
		# Delegar la generación procedimental al script helper SudokuVariantGenerator
		if _pending_killer_cages.is_empty() and VariantType.KILLER in variants_array:
			solver.killer_cages = SudokuVariantGenerator.generate_procedural_killer_cages(seed_grid, current_killer_ratio, killer_size)
		else:
			solver.killer_cages = _pending_killer_cages.duplicate(true)
			
		var used_cells: Dictionary = {}
		if _pending_thermo_chains.is_empty() and VariantType.THERMO in variants_array:
			solver.thermo_chains = SudokuVariantGenerator.generate_procedural_thermo_chains(current_thermo_count, thermo_len, used_cells)
		else:
			solver.thermo_chains = _pending_thermo_chains.duplicate(true)
			for chain in solver.thermo_chains:
				for c in chain:
					used_cells[c] = true
			
		if _pending_arrow_constraints.is_empty() and VariantType.ARROW in variants_array:
			solver.arrow_constraints = SudokuVariantGenerator.generate_procedural_arrow_constraints(current_arrow_count, arrow_len, used_cells)
		else:
			solver.arrow_constraints = _pending_arrow_constraints.duplicate(true)
			
		solver.rebuild_constraints()
		
		# Intentar resolver el tablero sujeto a las restricciones generadas
		full_board = _generate_full_board(seed_grid)
		if full_board.is_empty():
			print("SudokuGenerator: Intento ", attempt, " falló por contradicción física.")
			attempt_failed.emit(attempt)
			continue
			
		print("SudokuGenerator: Intento ", attempt, " exitoso. Estructura matemática construida.")
		attempt_succeeded.emit(attempt)
		break
		
	# Fallback absoluto a Sudoku clásico si todo falla
	if full_board.is_empty():
		print("SudokuGenerator: ADVERTENCIA: Fallback de emergencia a CLASSIC.")
		solver.killer_cages.clear()
		solver.thermo_chains.clear()
		solver.arrow_constraints.clear()
		solver.use_knight_constraint = false
		solver.knight_restricted_number = 0
		knight_restricted_number_actual = 0
		solver.rebuild_constraints()
		full_board = _generate_full_board(seed_grid)
		variants_array = [VariantType.CLASSIC]

	# Asignar sumas a las jaulas Killer basándose en la solución calculada
	if VariantType.KILLER in variants_array:
		for cage in solver.killer_cages:
			var s: int = 0
			for c in cage["cells"]:
				s += full_board[c]
			cage["sum"] = s
		solver.rebuild_constraints()
		
	var variant_count: int = 0
	for v in variants_array:
		if v != VariantType.CLASSIC: 
			variant_count += 1
		
	var excavation: Dictionary = _excavate_board(full_board, target_difficulty, shield_grid, variant_count)
	var puzzle_pistas: Dictionary = excavation["puzzle"]
	
	# Forzar que la intersección compartida (seed_grid) empiece vacía en el puzzle hijo
	if not seed_grid.is_empty():
		for pos in seed_grid.keys():
			puzzle_pistas[pos] = 0
	
	return {
		'puzzle': puzzle_pistas,
		'solution': full_board,
		'variant': variants_array[0] if not variants_array.is_empty() else VariantType.CLASSIC,
		'variants': variants_array,
		'killer_cages': solver.killer_cages.duplicate(true),
		'thermo_chains': solver.thermo_chains.duplicate(true),
		'arrow_constraints': solver.arrow_constraints.duplicate(true),
		'knight_restricted_number': knight_restricted_number_actual
	}

## Genera el siguiente tablero de una cadena progresiva a partir de las coordenadas del anterior.
func generate_chain_next(previous_solution: Dictionary, previous_puzzle: Dictionary, exit_corner: ExitCorner, 
						  difficulty: int, variants: Array = [VariantType.CLASSIC], knight_restricted_number: int = 0) -> Dictionary:
	var seed_grid: Dictionary = get_seed_for_next_floor(previous_solution, exit_corner)
	var clue_grid: Dictionary = get_seed_for_next_floor(previous_puzzle, exit_corner)
	return create_level(seed_grid, difficulty, variants, clue_grid, knight_restricted_number)

## Genera un Sudoku Samurái completo de 5 tableros solapados.
func generate_samurai(central_difficulty: Difficulty = Difficulty.MEDIUM, corner_difficulty: Difficulty = Difficulty.MEDIUM) -> Dictionary:
	var central_data: Dictionary = create_level({}, central_difficulty)
	var central_solution: Dictionary = central_data["solution"]
	
	var result: Dictionary = {
		"central": central_data,
		"top_left": null,
		"top_right": null,
		"bottom_left": null,
		"bottom_right": null
	}
	
	var corner_map: Dictionary = {
		ExitCorner.TOP_LEFT: "top_left",
		ExitCorner.TOP_RIGHT: "top_right",
		ExitCorner.BOTTOM_LEFT: "bottom_left",
		ExitCorner.BOTTOM_RIGHT: "bottom_right"
	}
	
	for corner in corner_map.keys():
		var _seed: Dictionary = get_seed_for_next_floor(central_solution, corner)
		var corner_data: Dictionary = create_level(_seed, corner_difficulty)
		result[corner_map[corner]] = corner_data
	
	return result

#endregion

#region 5. Gestión Interna de Restricciones del Solver

## Inyecta las restricciones dinámicas en el solver de acuerdo a los tipos activos.
func _apply_variants_to_solver(variants: Array) -> void:
	solver.use_knight_constraint = false
	solver.knight_restricted_number = 0
	solver.killer_cages.clear()
	solver.thermo_chains.clear()
	solver.arrow_constraints.clear()
	
	for variant in variants:
		match variant:
			VariantType.ANTI_KNIGHT:
				solver.use_knight_constraint = true
			VariantType.KILLER:
				solver.killer_cages = _pending_killer_cages.duplicate(true)
			VariantType.THERMO:
				solver.thermo_chains = _pending_thermo_chains.duplicate(true)
			VariantType.ARROW:
				solver.arrow_constraints = _pending_arrow_constraints.duplicate(true)
				
	solver.rebuild_constraints()

## Configura las jaulas Killer pendientes.
func set_killer_cages(cages: Array) -> void:
	_pending_killer_cages = cages

## Configura los termómetros pendientes.
func set_thermo_chains(chains: Array) -> void:
	_pending_thermo_chains = chains

## Configura las flechas pendientes.
func set_arrow_constraints(arrows: Array) -> void:
	_pending_arrow_constraints = arrows

## Limpia toda la cola de variantes inyectadas.
func clear_variant_data() -> void:
	_pending_killer_cages.clear()
	_pending_thermo_chains.clear()
	_pending_arrow_constraints.clear()

#endregion

#region 6. Lógica de Relleno y Excavación Controlada

## Rellena un tablero hasta completar una solución matemática válida sujeto a restricciones.
func _generate_full_board(seed_grid: Dictionary) -> Dictionary:
	var board: Dictionary = seed_grid.duplicate()
	solver.randomize_values = true
	
	# Caso clásico: barajar fila 0 para mayor variabilidad espacial
	if board.is_empty() and solver.killer_cages.is_empty() and solver.thermo_chains.is_empty() and solver.arrow_constraints.is_empty():
		var primera_fila: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9]
		primera_fila.shuffle()
		for x in range(9):
			board[Vector2i(x, 0)] = primera_fila[x]
			
	var res: Dictionary = solver.solve(board)
	solver.randomize_values = false
	return res

## Remueve pistas de un tablero resuelto para excavar el puzzle definitivo,
## garantizando la unicidad lógica e inyectando blindajes de transición.
func _excavate_board(full_board: Dictionary, target_difficulty: int, seed_grid: Dictionary, variant_count: int = 0) -> Dictionary:
	var puzzle: Dictionary = full_board.duplicate()
	var incognitas: int = 0
	var last_difficulty: int = 0
	
	var target_empty_cells: int
	var max_backtracks: int
	
	if target_difficulty <= 2:
		target_empty_cells = 30
		max_backtracks = 0
	elif target_difficulty <= 49:
		target_empty_cells = randi_range(48, 53) + (variant_count * 3)
		max_backtracks = 50
	elif target_difficulty >= 100:
		target_empty_cells = 81
		max_backtracks = 2000
	else:
		target_empty_cells = randi_range(55, 62) + (variant_count * 4)
		max_backtracks = 1000
		
	target_empty_cells = min(target_empty_cells, 81)
	
	print("SudokuGenerator: Iniciando excavación. Target vacías: ", target_empty_cells, " (max_backtracks: ", max_backtracks, ")")
	var time_start: float = Time.get_ticks_msec()
	
	# Fase 1: Garantizar que cada grupo de restricción de variante tenga al menos una celda vacía
	var constraint_groups: Array = []
	for cage in solver.killer_cages:
		constraint_groups.append(cage["cells"])
	for chain in solver.thermo_chains:
		constraint_groups.append(chain)
	for arrow in solver.arrow_constraints:
		var arrow_cells: Array = [arrow["circle"]]
		arrow_cells.append_array(arrow["shaft"])
		constraint_groups.append(arrow_cells)
		
	constraint_groups.shuffle()
	
	for group in constraint_groups:
		if incognitas >= target_empty_cells:
			break
			
		var ya_tiene_vacia: bool = false
		for cell in group:
			if puzzle[cell] == 0:
				ya_tiene_vacia = true
				break
		if ya_tiene_vacia:
			continue
			
		var group_cells: Array = group.duplicate()
		group_cells.shuffle()
		for cell in group_cells:
			if seed_grid.has(cell) and seed_grid[cell] != 0:
				continue
				
			var valor_original: int = puzzle[cell]
			puzzle[cell] = 0
			
			var current_difficulty: int = solver.evaluate_removal(puzzle, cell, valor_original)
			if current_difficulty == -1 or current_difficulty > max_backtracks:
				puzzle[cell] = valor_original
				continue
			else:
				incognitas += 1
				last_difficulty = current_difficulty
				break
				
	# Fase 2: Excavación general del resto del tablero
	var posiciones: Array[Vector2i] = solver.variables.duplicate() 
	posiciones.shuffle()
	
	for pos in posiciones:
		if incognitas >= target_empty_cells:
			break
			
		if puzzle[pos] == 0:
			continue
			
		var valor_original: int = puzzle[pos]
		
		# Blindaje de la esquina de intersección
		if seed_grid.has(pos) and seed_grid[pos] != 0:
			continue 
 
		puzzle[pos] = 0 
		
		var current_difficulty: int = solver.evaluate_removal(puzzle, pos, valor_original)
		
		if current_difficulty == -1 or current_difficulty > max_backtracks:
			puzzle[pos] = valor_original
			continue
			
		incognitas += 1
		last_difficulty = current_difficulty
		
		if incognitas % 10 == 0 or incognitas == target_empty_cells:
			print("SudokuGenerator: Excavadas ", incognitas, "/", target_empty_cells, " celdas vacías (tiempo: ", Time.get_ticks_msec() - time_start, " ms)")
			
	return {
		"puzzle": puzzle,
		"difficulty": last_difficulty + incognitas
	}

#endregion

#region 7. Métricas de Dificultad y Unicidad

## Mide la dificultad total del puzzle desde cero usando los pasos de resolución (backtracks).
func _measure_puzzle_difficulty(puzzle_to_test: Dictionary) -> int:
	var was_randomized: bool = solver.randomize_values
	solver.randomize_values = false
	solver.step_resolve = 0
	solver._build_domains(puzzle_to_test)
	
	var has_variants: bool = (not solver.killer_cages.is_empty()) or (not solver.thermo_chains.is_empty()) or (not solver.arrow_constraints.is_empty())
	if has_variants:
		if not solver._prune_variant_domains():
			solver.randomize_values = was_randomized
			return -1
			
	if solver._ac3_propagation():
		var asignacion_real: Dictionary = solver._get_current_assignment()
		solver._backtrack_search(asignacion_real)
		
	solver.randomize_values = was_randomized
	return solver.step_resolve

## Mide si hay múltiples soluciones al forzar la exclusión del valor actual en un casillero.
func _has_multiple_solutions(puzzle_test: Dictionary, changed_pos: Vector2i, forbidden_value: int) -> bool:
	var use_safe_version: bool = false
	
	if use_safe_version:
		return solver.has_multiple_solutions_safe(puzzle_test, changed_pos, forbidden_value)
	else:
		solver._build_domains(puzzle_test)
		solver.domains[changed_pos] = solver._clear_bit(solver.domains[changed_pos], forbidden_value)
		
		if not solver._ac3_propagation():
			return false
			
		var asignacion_inicial: Dictionary = solver._get_current_assignment()
		var alternative_solution: Dictionary = solver._backtrack_search(asignacion_inicial)
		return not alternative_solution.is_empty()

#endregion

#region 8. Utilidades de Coordenadas y Semilla

## Extrae un cuadrante 3x3 de un tablero de origen y desplaza sus coordenadas
## para que actúe de semilla en el lado opuesto del tablero destino.
func get_seed_for_next_floor(old_board: Dictionary, exit: ExitCorner) -> Dictionary:
	var new_seed: Dictionary = {}
	
	var start_x: int
	var start_y: int
	var offset_x: int
	var offset_y: int
	
	match exit:
		ExitCorner.TOP_RIGHT:
			start_x = 6; start_y = 0; offset_x = -6; offset_y = 6
		ExitCorner.TOP_LEFT:
			start_x = 0; start_y = 0; offset_x = 6; offset_y = 6
		ExitCorner.BOTTOM_RIGHT:
			start_x = 6; start_y = 6; offset_x = -6; offset_y = -6
		ExitCorner.BOTTOM_LEFT:
			start_x = 0; start_y = 6; offset_x = 6; offset_y = -6

	for x in range(start_x, start_x + 3):
		for y in range(start_y, start_y + 3):
			var old_pos: Vector2i = Vector2i(x, y)
			var new_pos: Vector2i = Vector2i(x + offset_x, y + offset_y)
			
			if old_board.has(old_pos) and old_board[old_pos] != 0:
				new_seed[new_pos] = old_board[old_pos]
				
	return new_seed

#endregion
