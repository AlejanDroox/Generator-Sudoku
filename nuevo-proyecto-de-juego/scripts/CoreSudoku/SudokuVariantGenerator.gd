extends RefCounted
class_name SudokuVariantGenerator

## Generador de restricciones procedimentales para variantes de Sudoku.
##
## Contiene funciones auxiliares estáticas para definir jaulas Killer, termómetros
## y flechas que no se solapen con semillas y sigan reglas lógicas espaciales.

#region Generación Procedimental de Variantes

## Divide de forma procedimental el tablero en jaulas Killer (sumas sin dígitos repetidos).
## Evita generar jaulas en la esquina de intersección (seed_grid) del sudoku hijo para no interferir.
static func generate_procedural_killer_cages(seed_grid: Dictionary, target_coverage_ratio: float, max_size: int) -> Array:
	var cages: Array = []
	var visited: Dictionary = {}
	
	var entrance_corner_start: Vector2i = Vector2i(-1, -1)
	if not seed_grid.is_empty():
		var first_key: Vector2i = seed_grid.keys()[0]
		if first_key.x < 3 and first_key.y < 3:
			entrance_corner_start = Vector2i(0, 0)
		elif first_key.x >= 6 and first_key.y < 3:
			entrance_corner_start = Vector2i(6, 0)
		elif first_key.x < 3 and first_key.y >= 6:
			entrance_corner_start = Vector2i(0, 6)
		elif first_key.x >= 6 and first_key.y >= 6:
			entrance_corner_start = Vector2i(6, 6)
			
	var exclude_cells: Dictionary = {}
	if entrance_corner_start != Vector2i(-1, -1):
		for dx in range(3):
			for dy in range(3):
				exclude_cells[entrance_corner_start + Vector2i(dx, dy)] = true
				
	var cells_pool: Array[Vector2i] = []
	for x in range(9):
		for y in range(9):
			var cell: Vector2i = Vector2i(x, y)
			if not exclude_cells.has(cell):
				cells_pool.append(cell)
	
	cells_pool.shuffle()
	
	var target_coverage: int = int(cells_pool.size() * target_coverage_ratio)
	var covered_count: int = 0
	
	for start_cell in cells_pool:
		if covered_count >= target_coverage:
			break
		if visited.has(start_cell):
			continue
		
		var target_size: int = randi_range(2, max_size)
		var cage_cells: Array[Vector2i] = [start_cell]
		
		var temp_visited: Dictionary = {start_cell: true}
		var queue: Array[Vector2i] = [start_cell]
		
		while queue.size() > 0 and cage_cells.size() < target_size:
			var curr: Vector2i = queue.pop_front()
			var neighbors: Array[Vector2i] = [
				curr + Vector2i(0, -1),
				curr + Vector2i(0, 1),
				curr + Vector2i(-1, 0),
				curr + Vector2i(1, 0)
			]
			neighbors.shuffle()
			for n in neighbors:
				if n.x >= 0 and n.x < 9 and n.y >= 0 and n.y < 9:
					if not visited.has(n) and not temp_visited.has(n) and not exclude_cells.has(n) and cage_cells.size() < target_size:
						temp_visited[n] = true
						cage_cells.append(n)
						queue.append(n)
		
		if cage_cells.size() >= 2:
			for c in cage_cells:
				visited[c] = true
			
			cages.append({
				"sum": 0,
				"cells": cage_cells
			})
			covered_count += cage_cells.size()
	
	return cages

## Genera de forma procedimental termómetros (cadenas de celdas estrictamente crecientes) sin solapamientos.
static func generate_procedural_thermo_chains(target_count: int, max_length: int, used_cells: Dictionary) -> Array:
	var chains: Array = []
	var attempts: int = 0
	
	while chains.size() < target_count and attempts < 300:
		attempts += 1
		var start_cell: Vector2i = Vector2i(randi_range(0, 8), randi_range(0, 8))
		if used_cells.has(start_cell):
			continue
			
		var chain: Array[Vector2i] = [start_cell]
		var target_len: int = randi_range(3, max_length)
		var curr: Vector2i = start_cell
		
		for step in range(target_len - 1):
			var neighbors: Array[Vector2i] = [
				curr + Vector2i(0, -1),
				curr + Vector2i(0, 1),
				curr + Vector2i(-1, 0),
				curr + Vector2i(1, 0)
			]
			neighbors.shuffle()
			var next_cell = null
			for n in neighbors:
				if n.x >= 0 and n.x < 9 and n.y >= 0 and n.y < 9:
					if not n in chain and not used_cells.has(n):
						next_cell = n
						break
			if next_cell == null:
				break
			chain.append(next_cell)
			curr = next_cell
			
		if chain.size() >= 3:
			chains.append(chain)
			for c in chain:
				used_cells[c] = true
	return chains

## Busca un camino continuo (eje) a partir del círculo de la flecha usando DFS de forma recursiva.
static func _find_arrow_shaft_path_empty(curr: Vector2i, target_len: int, current_path: Array, used_cells: Dictionary) -> Array:
	if current_path.size() == target_len:
		return current_path
		
	var dirs: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	dirs.shuffle()
	
	for d in dirs:
		var n: Vector2i = curr + d
		if n.x >= 0 and n.x < 9 and n.y >= 0 and n.y < 9:
			if not n in current_path and not used_cells.has(n):
				var new_path: Array = current_path.duplicate()
				new_path.append(n)
				var res: Array = _find_arrow_shaft_path_empty(n, target_len, new_path, used_cells)
				if not res.is_empty():
					return res
	return []

## Genera de forma procedimental flechas (círculo = suma del cuerpo/shaft) sin solapamientos.
static func generate_procedural_arrow_constraints(target_count: int, max_shaft_len: int, used_cells: Dictionary) -> Array:
	var arrows: Array = []
	var attempts: int = 0
	
	while arrows.size() < target_count and attempts < 150:
		attempts += 1
		var circle: Vector2i = Vector2i(randi_range(0, 8), randi_range(0, 8))
		if used_cells.has(circle):
			continue
			
		var shaft_len: int = randi_range(2, max_shaft_len)
		var shaft: Array = _find_arrow_shaft_path_empty(circle, shaft_len + 1, [circle], used_cells)
		
		if shaft.size() > 1:
			shaft.pop_front()
			arrows.append({
				"circle": circle,
				"shaft": shaft
			})
			used_cells[circle] = true
			for s in shaft:
				used_cells[s] = true
	return arrows

#endregion
