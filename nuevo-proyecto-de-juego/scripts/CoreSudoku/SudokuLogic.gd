extends RefCounted
class_name SudokuLogic

## Motor CSP y Solucionador Híbrido de Sudoku.
##
## Implementa la resolución de tableros mediante un motor CSP (Constraint Satisfaction Problem)
## altamente optimizado. Utiliza bitmasks para dominios, AC-3 para propagación rápida de arcos,
## ordenamiento dinámico por MRV (Minimum Remaining Values), y poda matemática de variantes.

#region 1. Definición de Clase & Constantes

## Desplazamientos espaciales relativos para el movimiento del caballo de ajedrez (Anti-Knight)
const KNIGHT_MOVES: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(2, -1),
	Vector2i(-2, 1), Vector2i(-2, -1),
	Vector2i(1, 2), Vector2i(1, -2),
	Vector2i(-1, 2), Vector2i(-1, -2)
]

#endregion

#region 2. Variables de Estado Core

## Lista ordenada de las 81 celdas representadas como variables CSP
var variables: Array[Vector2i] = []

## Red de restricciones (vecinos con prohibición de no-igualdad): Vector2i -> Array[Vector2i]
var constraints: Dictionary = {}

## Dominios de búsqueda (valores disponibles representados como máscaras de bits): Vector2i -> int
var domains: Dictionary = {}

## Contador de pasos o retrocesos (backtracks) realizados en la resolución actual
var step_resolve: int = 0

## Límite de soluciones a encontrar durante la búsqueda (0 = buscar ilimitado)
var stop_after_solutions: int = 0

## Contador de soluciones encontradas durante la fase activa de búsqueda
var solutions_found: int = 0

## Si es verdadero, baraja los valores disponibles para introducir variedad en los tableros
var randomize_values: bool = false

## Tabla de consulta (Lookup Table) para el conteo instantáneo de bits activos (MRV rápido)
var bit_counts_lut: PackedByteArray = PackedByteArray()

#endregion

#region 3. Variables de Restricciones & Variantes

## Determina si se aplica la regla de Anti-Knight (Anti-Caballo)
var use_knight_constraint: bool = false

## Número específico al que se limita el Anti-Knight (0 si aplica a todos)
var knight_restricted_number: int = 0

## Jaulas de la variante Killer: Array de Dictionary { "sum": int, "cells": Array[Vector2i] }
var killer_cages: Array = []

## Termómetros de la variante Thermo: Array de Array[Vector2i] (de frío a caliente)
var thermo_chains: Array = []

## Flechas de la variante Arrow: Array de Dictionary { "circle": Vector2i, "shaft": Array[Vector2i] }
var arrow_constraints: Array = []

## Mapa inverso para Killer: Vector2i -> Dictionary
var cell_to_cage: Dictionary = {}

## Mapa inverso para Thermo: Vector2i -> Array[Dictionary]
var cell_to_thermo: Dictionary = {}

## Mapa inverso para Arrow: Vector2i -> Array[Dictionary]
var cell_to_arrow: Dictionary = {}

#endregion

#region 4. Inicialización & Caché

func _init(puzzle: Dictionary = dictionary_grid()) -> void:
	_init_variables()
	_build_constraint_network()
	_build_domains(puzzle)

## Inicializa la lista de variables e indexa la tabla LUT para conteo de bits
func _init_variables() -> void:
	variables.clear()
	for x in range(9):
		for y in range(9):
			variables.append(Vector2i(x, y))
			
	# Inicializar la Lookup Table (LUT) para el conteo de bits del 0 al 511
	bit_counts_lut.resize(512)
	for i in range(512):
		var count: int = 0
		var m: int = i
		while m > 0:
			m &= m - 1
			count += 1
		bit_counts_lut[i] = count

## Retorna una grilla limpia y vacía (todos los casilleros en 0)
func dictionary_grid() -> Dictionary:
	var puzzle: Dictionary = {}
	for y in range(9):
		for x in range(9):
			puzzle[Vector2i(x, y)] = 0
	return puzzle

## Construye la red de arcos del CSP estándar (filas, columnas y bloques 3x3)
func _build_constraint_network() -> void:
	constraints.clear()
	for v in variables:
		var v_neighbors: Array[Vector2i] = []
		
		# Vecinos en fila y columna
		for i in range(9):
			if i != v.x: 
				v_neighbors.append(Vector2i(i, v.y))
			if i != v.y: 
				v_neighbors.append(Vector2i(v.x, i))
		
		# Vecinos en el cuadrante 3x3
		@warning_ignore("integer_division")
		var start_x: int = (v.x / 3) * 3
		@warning_ignore("integer_division")
		var start_y: int = (v.y / 3) * 3
		
		for i in range(start_x, start_x + 3):
			for j in range(start_y, start_y + 3):
				var neighbor: Vector2i = Vector2i(i, j)
				if neighbor != v and not neighbor in v_neighbors:
					v_neighbors.append(neighbor)
					
		constraints[v] = v_neighbors

## Reconstruye toda la red y mapas inversos (llamar tras cambiar configuraciones de variante)
func rebuild_constraints() -> void:
	_build_constraint_network()
	_build_cell_maps()

## Construye los dominios CSP a partir del estado de un puzzle inicial
func _build_domains(puzzle: Dictionary) -> void:
	domains.clear()
	for coords in variables:
		var valor_inicial: int = puzzle.get(coords, 0)
		if typeof(valor_inicial) != TYPE_INT:
			valor_inicial = int(valor_inicial)
			
		if valor_inicial != 0:
			domains[coords] = _value_to_mask(valor_inicial)
		else:
			domains[coords] = _get_full_mask()

#endregion

#region 5. Helpers de Bitmask (Optimización de Dominios)

## Convierte un dígito (1-9) en su correspondiente bit (1-256)
func _value_to_mask(value: int) -> int:
	return 1 << (value - 1)

## Retorna la máscara con todos los dígitos disponibles (511 = 9 bits en 1)
func _get_full_mask() -> int:
	return 511

## Cuenta cuántos bits están encendidos en una máscara usando la tabla LUT
func _count_bits(mask: int) -> int:
	return bit_counts_lut[mask]

## Retorna verdadero si el dígito está disponible en la máscara
func _is_bit_set(mask: int, value: int) -> bool:
	return (mask & _value_to_mask(value)) != 0

## Desactiva el bit de un dígito en la máscara
func _clear_bit(mask: int, value: int) -> int:
	return mask & ~_value_to_mask(value)

## Obtiene el primer dígito disponible en una máscara unitaria (Single)
func _get_first_value_from_mask(mask: int) -> int:
	for i in range(1, 10):
		if (mask & (1 << (i - 1))) != 0:
			return i
	return 0

## Convierte una máscara en un Array de enteros legibles
func _mask_to_array(mask: int) -> Array[int]:
	var array: Array[int] = []
	for i in range(1, 10):
		if (mask & (1 << (i - 1))) != 0:
			array.append(i)
	return array

## Retorna el estado actual de las celdas ya resueltas (con dominio de tamaño 1)
func _get_current_assignment() -> Dictionary:
	var assignment: Dictionary = {}
	for v in variables:
		if bit_counts_lut[domains[v]] == 1:
			assignment[v] = _get_first_value_from_mask(domains[v])
	return assignment

## Crea un duplicado superficial veloz de los dominios actuales
func _save_domains() -> Dictionary:
	return domains.duplicate()

## Restaura los dominios a un estado guardado previamente
func _restore_domains(saved_domains: Dictionary) -> void:
	domains = saved_domains

#endregion

#region 6. API de Consulta de Variantes (Capa Visual)

## Construye los mapas inversos Vector2i -> Restricción para consultas instantáneas O(1)
func _build_cell_maps() -> void:
	cell_to_cage.clear()
	cell_to_thermo.clear()
	cell_to_arrow.clear()
	
	# Killer Cages
	for ci in range(killer_cages.size()):
		var cage = killer_cages[ci]
		for cell in cage["cells"]:
			cell_to_cage[cell] = {
				"cage_index": ci,
				"sum": cage["sum"],
				"cells": cage["cells"]
			}
	
	# Thermo Chains
	for ti in range(thermo_chains.size()):
		var chain = thermo_chains[ti]
		for pos in range(chain.size()):
			var cell = chain[pos]
			if not cell_to_thermo.has(cell):
				cell_to_thermo[cell] = []
			cell_to_thermo[cell].append({
				"chain_index": ti,
				"position": pos,
				"chain": chain
			})
	
	# Arrow Constraints
	for ai in range(arrow_constraints.size()):
		var arrow = arrow_constraints[ai]
		var circle = arrow["circle"]
		if not cell_to_arrow.has(circle):
			cell_to_arrow[circle] = []
		cell_to_arrow[circle].append({
			"arrow_index": ai,
			"role": &"circle",
			"arrow": arrow
		})
		for shaft_cell in arrow["shaft"]:
			if not cell_to_arrow.has(shaft_cell):
				cell_to_arrow[shaft_cell] = []
			cell_to_arrow[shaft_cell].append({
				"arrow_index": ai,
				"role": &"shaft",
				"arrow": arrow
			})

## Obtiene la jaula Killer correspondiente a una celda
func get_cage_for_cell(cell: Vector2i) -> Dictionary:
	return cell_to_cage.get(cell, {})

## Obtiene el termómetro correspondiente a una celda
func get_thermo_for_cell(cell: Vector2i) -> Dictionary:
	var list: Array = cell_to_thermo.get(cell, [])
	return list[0] if not list.is_empty() else {}

## Obtiene la flecha Arrow correspondiente a una celda
func get_arrow_for_cell(cell: Vector2i) -> Dictionary:
	var list: Array = cell_to_arrow.get(cell, [])
	return list[0] if not list.is_empty() else {}

## Obtiene todas las flechas asociadas a una celda
func get_arrows_for_cell(cell: Vector2i) -> Array:
	var result: Array = []
	var list: Array = cell_to_arrow.get(cell, [])
	for info in list:
		result.append({"arrow_index": info["arrow_index"], "arrow": info["arrow"]})
	return result

## Retorna verdadero si la celda está asociada a alguna restricción física de variante
func has_variant_constraint(cell: Vector2i) -> bool:
	return cell_to_cage.has(cell) or cell_to_thermo.has(cell) or cell_to_arrow.has(cell)

#endregion

#region 7. Algoritmo AC-3 & Poda de Dominios

## Obtiene todos los arcos de restricción
func _get_constraint_arc() -> Array:
	var arcs: Array = []
	for Xi in variables:
		for Xj in constraints[Xi]:
			arcs.append([Xi, Xj])
	return arcs

## Revisa la consistencia entre Xi y Xj. Si Xj es un Single, remueve su valor del dominio de Xi.
func _revise(Xi: Vector2i, Xj: Vector2i) -> bool:
	var revised: bool = false
	var mask_x_j: int = domains[Xj]
	
	# Truco binario: un valor tiene un solo bit si es distinto de cero y (n & (n - 1)) == 0
	if mask_x_j != 0 and (mask_x_j & (mask_x_j - 1)) == 0:
		if (domains[Xi] & mask_x_j) != 0:
			domains[Xi] = domains[Xi] & ~mask_x_j
			revised = true
	return revised

## Algoritmo Arc Consistency 3 con cursor de lectura plano para evitar pop_front() lento.
func _ac3_propagation(initial_queue: Array = []) -> bool:
	var queue: Array = initial_queue
	if queue.is_empty():
		queue = []
		for Y in variables:
			var mask_y: int = domains[Y]
			if mask_y != 0 and (mask_y & (mask_y - 1)) == 0:
				for X in constraints[Y]:
					queue.append(X)
					queue.append(Y)
					
	for v in variables:
		if domains[v] == 0:
			return false
			
	var head: int = 0
	
	while head < queue.size():
		var Xi: Vector2i = queue[head]
		var Xj: Vector2i = queue[head + 1]
		head += 2
		
		if _revise(Xi, Xj):
			if domains[Xi] == 0:
				return false 
			
			for i in _get_neighbors(Xi):
				if i != Xj:
					queue.append(i)
					queue.append(Xi)
					
	return true

## Reduce matemáticamente el dominio de las celdas asociadas a variantes antes de resolver.
func _prune_variant_domains() -> bool:
	# 1. Poda de Thermo (estrictamente creciente)
	for chain in thermo_chains:
		var n: int = chain.size()
		for i in range(n):
			var cell: Vector2i = chain[i]
			if not domains.has(cell):
				continue
			var min_val: int = i + 1
			var max_val: int = 9 - (n - 1 - i)
			if min_val > max_val:
				return false
			for v in range(1, 10):
				if v < min_val or v > max_val:
					domains[cell] = _clear_bit(domains[cell], v)
			if domains[cell] == 0:
				return false
	
	# 2. Poda de Killer Cages (sumas viables)
	for cage in killer_cages:
		var cage_cells: Array = cage["cells"]
		var cage_sum: int = cage["sum"]
		if cage_sum == 0:
			continue
		var n: int = cage_cells.size()
		if n > 9:
			return false
			
		var others_count: int = n - 1
		for v in range(1, 10):
			var min_others: int
			if v <= others_count:
				min_others = (others_count + 1) * (others_count + 2) / 2 - v
			else:
				min_others = others_count * (others_count + 1) / 2
				
			var max_others: int
			var limit_val: int = 10 - others_count
			if v >= limit_val:
				max_others = 45 - (8 - others_count) * (9 - others_count) / 2 - v
			else:
				max_others = 45 - (9 - others_count) * (10 - others_count) / 2
				
			for cell in cage_cells:
				if not domains.has(cell):
					continue
				if v + min_others > cage_sum or v + max_others < cage_sum:
					domains[cell] = _clear_bit(domains[cell], v)
				if domains[cell] == 0:
					return false
	
	# 3. Poda de Arrow (suma de círculo)
	for arrow in arrow_constraints:
		var circle: Vector2i = arrow["circle"]
		var shaft: Array = arrow["shaft"]
		if not domains.has(circle):
			continue
		var min_sum: int = shaft.size()
		var max_sum: int = shaft.size() * 9
		for v in range(1, 10):
			if v < min_sum or v > max_sum:
				domains[circle] = _clear_bit(domains[circle], v)
		if domains[circle] == 0:
			return false
	
	return true

#endregion

#region 8. Comprobación de Consistencia (Filtro CSP)

## Verifica que la asignación de un valor a una celda sea consistente con todas las reglas
func _is_consistent(coords: Vector2i, value: int, assignment: Dictionary) -> bool:
	# 1. Restricción clásica de Sudoku
	for neighbor in constraints[coords]:
		if neighbor in assignment and assignment[neighbor] == value:
			return false
	
	# 2. Restricción de Anti-Knight
	if use_knight_constraint and (knight_restricted_number == 0 or value == knight_restricted_number):
		for move in KNIGHT_MOVES:
			var knight_neighbor: Vector2i = coords + move
			if knight_neighbor.x >= 0 and knight_neighbor.x < 9 and knight_neighbor.y >= 0 and knight_neighbor.y < 9:
				if knight_neighbor in assignment and assignment[knight_neighbor] == value:
					return false
	
	# 3. Restricción de Thermo
	if cell_to_thermo.has(coords):
		for info in cell_to_thermo[coords]:
			var chain: Array = info["chain"]
			var idx: int = info["position"]
			for i in range(idx):
				if chain[i] in assignment and assignment[chain[i]] >= value:
					return false
			for i in range(idx + 1, chain.size()):
				if chain[i] in assignment and assignment[chain[i]] <= value:
					return false
	
	# 4. Restricción de Arrow
	if cell_to_arrow.has(coords):
		for info in cell_to_arrow[coords]:
			var arrow: Dictionary = info["arrow"]
			var circle: Vector2i = arrow["circle"]
			var shaft: Array = arrow["shaft"]
			
			var circle_val: int = value if circle == coords else assignment.get(circle, 0)
			var all_assigned: bool = (circle_val > 0)
			
			for sc in shaft:
				var sc_val: int = value if sc == coords else assignment.get(sc, 0)
				if sc_val == 0:
					all_assigned = false
					break
			
			if all_assigned:
				var shaft_sum: int = 0
				for sc in shaft:
					var sc_val: int = value if sc == coords else assignment.get(sc, 0)
					shaft_sum += sc_val
				if circle_val != shaft_sum:
					return false
			else:
				var partial_sum: int = 0
				var unassigned: int = 0
				for sc in shaft:
					var sc_val: int = value if sc == coords else assignment.get(sc, 0)
					if sc_val > 0:
						partial_sum += sc_val
					else:
						unassigned += 1
				
				if circle_val > 0:
					if partial_sum + unassigned > circle_val:
						return false
				else:
					if partial_sum + unassigned > 9:
						return false
	
	# 5. Restricción de Killer Cages
	if cell_to_cage.has(coords):
		var info: Dictionary = cell_to_cage[coords]
		var cage_cells: Array = info["cells"]
		var cage_sum: int = info["sum"]
		for other in cage_cells:
			if other != coords:
				var other_val: int = assignment.get(other, 0)
				if other_val == value:
					return false
		if cage_sum > 0:
			var partial_sum: int = 0
			var unassigned: int = 0
			for cc in cage_cells:
				var cc_val: int = value if cc == coords else assignment.get(cc, 0)
				if cc_val > 0:
					partial_sum += cc_val
				else:
					unassigned += 1
			if partial_sum > cage_sum: 
				return false
			if unassigned == 0 and partial_sum != cage_sum: 
				return false
			if partial_sum + unassigned > cage_sum: 
				return false
	
	return true

#endregion

#region 9. Algoritmo Backtracking & Solucionador

## Heurística MRV para elegir la siguiente mejor variable a evaluar
func _get_best_variable(assignment: Dictionary) -> Vector2i:
	var best_v: Vector2i
	var min_remaining_value: int = 10
	for v in variables:
		if assignment.has(v): 
			continue
		
		var current_domain_size: int = bit_counts_lut[domains[v]]
		if current_domain_size == 1:
			return v # Retorno rápido (Single)
			
		if current_domain_size < min_remaining_value:
			min_remaining_value = current_domain_size
			best_v = v
	return best_v

## Retorna los vecinos de restricción directa de la celda
func _get_neighbors(coords: Vector2i) -> Array:
	return constraints[coords]

## Algoritmo Backtracking recursivo estándar con restauración de dominios
func _backtrack_search(assignment: Dictionary) -> Dictionary:
	if step_resolve > 5000:
		return {}
		
	if stop_after_solutions > 0 and solutions_found >= stop_after_solutions:
		return {}
	
	if assignment.size() == variables.size():
		solutions_found += 1
		if stop_after_solutions > 0 and solutions_found >= stop_after_solutions:
			return assignment
		return assignment
	
	var var_elegida: Vector2i = _get_best_variable(assignment)
	var mask: int = domains[var_elegida]
	
	var valores_disponibles: Array[int] = []
	for valor in range(1, 10):
		if (mask & (1 << (valor - 1))) != 0:
			valores_disponibles.append(valor)
			
	if randomize_values:
		valores_disponibles.shuffle()
	
	for valor in valores_disponibles:
		if _is_consistent(var_elegida, valor, assignment):
			assignment[var_elegida] = valor
			var saved: Dictionary = _save_domains()
			domains[var_elegida] = _value_to_mask(valor)
			
			var initial_queue: Array = []
			for X in constraints[var_elegida]:
				initial_queue.append(X)
				initial_queue.append(var_elegida)
				
			if _ac3_propagation(initial_queue):
				var result: Dictionary = _backtrack_search(assignment)
				if not result.is_empty():
					if stop_after_solutions > 0 and solutions_found >= stop_after_solutions:
						_restore_domains(saved)
						return result
					_restore_domains(saved)
					return result
			
			assignment.erase(var_elegida)
			_restore_domains(saved)
			step_resolve += 1
	
	return {}

## Función pública para resolver un Sudoku dado. Retorna la grilla resuelta o {} si es inválida.
func solve(puzzle_inicial: Dictionary) -> Dictionary:
	step_resolve = 0
	_build_domains(puzzle_inicial)
	
	var has_variants: bool = (not killer_cages.is_empty()) or (not thermo_chains.is_empty()) or (not arrow_constraints.is_empty())
	if has_variants:
		if not _prune_variant_domains():
			return {}
	
	if not _ac3_propagation():
		return {}
	var asignacion_inicial: Dictionary = _get_current_assignment()
	var solucion_final: Dictionary = _backtrack_search(asignacion_inicial)

	return solucion_final

#endregion

#region 10. Métricas de Dificultad & Unicidad

## Verifica de forma segura si existen múltiples soluciones al remover un valor
func has_multiple_solutions_safe(puzzle: Dictionary, forbidden_pos: Vector2i, forbidden_value: int) -> bool:
	step_resolve = 0
	stop_after_solutions = 2
	solutions_found = 0
	
	_build_domains(puzzle)
	
	var has_variants: bool = (not killer_cages.is_empty()) or (not thermo_chains.is_empty()) or (not arrow_constraints.is_empty())
	if has_variants:
		if not _prune_variant_domains():
			stop_after_solutions = 0
			return false
	
	if domains.has(forbidden_pos):
		domains[forbidden_pos] = _clear_bit(domains[forbidden_pos], forbidden_value)
		if domains[forbidden_pos] == 0:
			stop_after_solutions = 0
			return false
	
	if not _ac3_propagation():
		stop_after_solutions = 0
		return false
	
	var asignacion_inicial: Dictionary = _get_current_assignment()
	var _solution: Dictionary = _backtrack_search(asignacion_inicial)
	var result: bool = solutions_found >= 2
	
	stop_after_solutions = 0
	solutions_found = 0
	
	return result

## Evalúa la dificultad al remover un casillero y comprueba si la solución sigue siendo única
func evaluate_removal(puzzle: Dictionary, pos: Vector2i, original_value: int) -> int:
	var was_randomized: bool = randomize_values
	randomize_values = false
	step_resolve = 0
	
	var has_variants: bool = (not killer_cages.is_empty()) or (not thermo_chains.is_empty()) or (not arrow_constraints.is_empty())
	
	_build_domains(puzzle)
	if has_variants:
		if not _prune_variant_domains():
			randomize_values = was_randomized
			return -1
	
	var clean_domains: Dictionary = domains.duplicate()
	
	# 1. Comprobar unicidad: prohibir el valor original en pos
	domains[pos] = _clear_bit(domains[pos], original_value)
	if _ac3_propagation():
		var asignacion_test: Dictionary = _get_current_assignment()
		if not _backtrack_search(asignacion_test).is_empty():
			randomize_values = was_randomized
			return -1
	
	# 2. Medir dificultad restaurando el estado limpio
	step_resolve = 0
	domains = clean_domains
	if _ac3_propagation():
		var asignacion_real: Dictionary = _get_current_assignment()
		_backtrack_search(asignacion_real)
	
	randomize_values = was_randomized
	return step_resolve

#endregion
