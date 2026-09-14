extends Node

## Sistema de puntuación centralizado.
## Conectar manualmente al SamuraiManager con: ScoreManager.register_manager(samurai_manager_node)
## o conectar tableros individuales con: ScoreManager.register_board(board_node)

# ─────────────────────────────────────────────────────────────────────────────
# Señales
# ─────────────────────────────────────────────────────────────────────────────
## Emitida cada vez que la puntuación cambia (pasa el total acumulado)
signal score_changed(new_score: int)
## Emitida cuando se completa un logro notable (con parámetros detallados para UI)
signal achievement_unlocked(type: StringName, base_points: int, multiplier: float, final_points: int)
## Emitida cuando la racha/multiplicador cambia
signal streak_changed(new_streak: float)

# ─────────────────────────────────────────────────────────────────────────────
# Tabla de puntos configurables
# ─────────────────────────────────────────────────────────────────────────────
const POINTS_CORRECT_CELL:       int = 10   ## Casilla colocada correctamente
const POINTS_ROW_COMPLETE:       int = 50   ## Fila completada
const POINTS_COL_COMPLETE:       int = 50   ## Columna completada
const POINTS_SECTOR_COMPLETE:    int = 75   ## Sector 3×3 completado
const POINTS_VARIANT_CONSTRAINT: int = 25   ## Casilla con restricción de variante correcta (no Samurai)
const POINTS_SUDOKU_COMPLETE:    int = 500  ## Sudoku (board) completado
const POINTS_PERFECT_BOARD:     int = 500  ## Sudoku completado sin errores

# ─────────────────────────────────────────────────────────────────────────────
# Estado interno
# ─────────────────────────────────────────────────────────────────────────────
var total_score: int = 0
var streak_multiplier: float = 1.0
var total_errors_in_game: int = 0
var active_manager: Node = null
var _board_errors: Dictionary = {}


## Referencia al label UI que muestra la puntuación.
## Asignar desde el exterior con ScoreManager.score_label = $label_points
var score_label: Label = null

## Cache de estado de filas, columnas y sectores por board_id.
## Estructura: { board_id → { "rows": [bool×9], "cols": [bool×9], "sectors": [bool×9] } }
var _board_states: Dictionary = {}

## Cache de referencias Board para poder consultar celdas.
## Estructura: { board_id → Board }
var _boards: Dictionary = {}

## Tipo de variante activo por board_id { board_id → int (VariantType) }
var _board_variants: Dictionary = {}

## Registro de celdas resueltas correctamente para evitar duplicados de puntos: { board_id → { coords → bool } }
var _solved_cells_per_board: Dictionary = {}


# ─────────────────────────────────────────────────────────────────────────────
# API pública
# ─────────────────────────────────────────────────────────────────────────────

## Registra un SamuraiManager: conecta sus señales automáticamente.
func register_manager(manager: Node) -> void:
	active_manager = manager
	if manager.has_signal("new_board_spawned"):
		# Usamos lambda para capturar 'manager' sin alterar la firma de la señal
		manager.new_board_spawned.connect(
			func(board_id: StringName, board_index: int) -> void:
				_on_new_board_spawned(board_id, board_index, manager)
		)
	if manager.has_signal("level_completed"):
		if not manager.level_completed.is_connected(_on_level_completed):
			manager.level_completed.connect(_on_level_completed)

## Registra un Board individual (sin SamuraiManager).
func register_board(board: Node, variant_type: int = 0) -> void:
	_setup_board(board, variant_type)

## Reinicia la puntuación a cero.
func reset() -> void:
	total_score = 0
	streak_multiplier = 1.0
	total_errors_in_game = 0
	active_manager = null
	streak_changed.emit(streak_multiplier)
	_board_states.clear()
	_boards.clear()
	_board_variants.clear()
	_solved_cells_per_board.clear()
	_board_errors.clear()
	_refresh_label()


## Restaura el estado de puntuación desde los datos cargados del guardado.
## [param data] Diccionario con claves: total_score, streak_multiplier,
##              total_errors_in_game, solved_cells_per_board.
func hydrate_state(data: Dictionary) -> void:
	total_score          = data.get("total_score", 0)
	streak_multiplier    = data.get("streak_multiplier", 1.0)
	total_errors_in_game = data.get("total_errors_in_game", 0)
	streak_changed.emit(streak_multiplier)

	# Reconstruir _solved_cells_per_board desde strings "x,y" → Vector2i
	_solved_cells_per_board.clear()
	var raw: Dictionary = data.get("solved_cells_per_board", {})
	for board_id_str in raw:
		var bid := StringName(board_id_str)
		_solved_cells_per_board[bid] = {}
		for coord_str in raw[board_id_str]:
			var parts: PackedStringArray = (coord_str as String).split(",")
			if parts.size() == 2:
				var v := Vector2i(int(parts[0]), int(parts[1]))
				_solved_cells_per_board[bid][v] = raw[board_id_str][coord_str]

	_refresh_label()

# ─────────────────────────────────────────────────────────────────────────────
# Handlers de señales externas
# ─────────────────────────────────────────────────────────────────────────────

## Llamado cuando SamuraiManager crea un nuevo board
func _on_new_board_spawned(board_id: StringName, _board_index: int, manager: Node) -> void:
	if not manager.boards.has(board_id):
		return
	var board: Node = manager.boards[board_id]
	# Leer variant_type directamente del Board (ya asignado en _spawn_board_visual)
	var variant: int = board.variant_type if "variant_type" in board else 0
	_setup_board(board, variant)

## Llamado cuando todos los boards del nivel están completados (bonus de nivel)
func _on_level_completed(_level_number: int) -> void:
	# El bonus de nivel se maneja en _on_board_completed por board.
	# Aquí se puede añadir un bonus extra global si se desea.
	pass

# ─────────────────────────────────────────────────────────────────────────────
# Setup interno de board
# ─────────────────────────────────────────────────────────────────────────────

func _setup_board(board: Node, variant_type: int) -> void:
	var bid: StringName = board.board_id
	_boards[bid] = board
	_board_variants[bid] = variant_type
	_board_states[bid] = {
		"rows":    _make_bool_array(9),
		"cols":    _make_bool_array(9),
		"sectors": _make_bool_array(9)
	}
	_solved_cells_per_board[bid] = {}
	_board_errors[bid] = 0
	# Conectar señales del board
	if board.has_signal("cell_changed") and not board.cell_changed.is_connected(_on_cell_changed):
		board.cell_changed.connect(_on_cell_changed)
	if board.has_signal("board_completed") and not board.board_completed.is_connected(_on_board_completed):
		board.board_completed.connect(_on_board_completed)

func _make_bool_array(size: int) -> Array:
	var arr = []
	arr.resize(size)
	arr.fill(false)
	return arr

# ─────────────────────────────────────────────────────────────────────────────
# Lógica principal de puntuación
# ─────────────────────────────────────────────────────────────────────────────

## Ejecutado cada vez que una celda cambia de valor en cualquier board registrado.
func _on_cell_changed(board_id: StringName, coords: Vector2i, _value: int, is_correct: bool) -> void:
	if not _boards.has(board_id):
		return
		
	# Si la celda fue borrada, no se penaliza ni se premia
	if _value == 0:
		return

	if not _solved_cells_per_board.has(board_id):
		_solved_cells_per_board[board_id] = {}

	if is_correct:
		# Si la celda ya estaba marcada como resuelta, evitamos volver a sumarle puntos
		if _solved_cells_per_board[board_id].has(coords):
			return
		_solved_cells_per_board[board_id][coords] = true
	else:
		# Si el nuevo valor es incorrecto, la quitamos de las resueltas para que vuelva a dar puntos al corregirse
		_solved_cells_per_board[board_id].erase(coords)

	var board: Node = _boards[board_id]
	var state: Dictionary = _board_states[board_id]
	var current_mode = board.game_mode if board and "game_mode" in board else Global.GameMode.PRACTICE

	if current_mode == Global.GameMode.CHALLENGE:
		if is_correct:
			# ── 1. Puntos por casilla correcta y racha ──────────────────────────────
			_add_points(POINTS_CORRECT_CELL, &"correct_cell")
			increase_streak(0.2)

			# ── 2. Puntos por restricción de variante ───────────────────────────────
			_check_variant_constraint(board, board_id, coords)

			# ── 3. Verificar fila, columna y sector (con soporte de combos estructurales) ────────
			var row_pts = _check_row(board, board_id, coords.y, state)
			var col_pts = _check_col(board, board_id, coords.x, state)
			var sec_pts = _check_sector(board, board_id, coords, state)
			
			var structures_completed = 0
			if row_pts > 0: structures_completed += 1
			if col_pts > 0: structures_completed += 1
			if sec_pts > 0: structures_completed += 1
			
			if structures_completed > 0:
				var base_completions_points = row_pts + col_pts + sec_pts
				if structures_completed == 1:
					if row_pts > 0: _add_points(row_pts, &"row_complete")
					elif col_pts > 0: _add_points(col_pts, &"col_complete")
					elif sec_pts > 0: _add_points(sec_pts, &"sector_complete")
				elif structures_completed == 2:
					var combo_points = int(round(base_completions_points * 1.5))
					_add_points(combo_points, &"combo_double")
				elif structures_completed == 3:
					var combo_points = int(round(base_completions_points * 2.0))
					_add_points(combo_points, &"combo_triple")
	else:
		# Modo Práctica
		if is_correct:
			var cell = board.get_cell(coords) if board.has_method("get_cell") else null
			var had_error = cell.has_been_incorrect if cell else false
			
			# ── 1. Puntos por casilla correcta ──────────────────────────────────────
			_add_points(POINTS_CORRECT_CELL, &"correct_cell")
			
			# Bono de redención: solo recupera los puntos del primer fallo (-5 pts)
			if had_error:
				_add_points(5, &"redemption_bonus")
				if cell:
					cell.has_been_incorrect = false
					cell.mistake_count = 0
			
			increase_streak(0.2)

			# ── 2. Puntos por restricción de variante ───────────────────────────────
			_check_variant_constraint(board, board_id, coords)

			# ── 3. Verificar fila, columna y sector (con soporte de combos estructurales) ────────
			var row_pts = _check_row(board, board_id, coords.y, state)
			var col_pts = _check_col(board, board_id, coords.x, state)
			var sec_pts = _check_sector(board, board_id, coords, state)
			
			var structures_completed = 0
			if row_pts > 0: structures_completed += 1
			if col_pts > 0: structures_completed += 1
			if sec_pts > 0: structures_completed += 1
			
			if structures_completed > 0:
				var base_completions_points = row_pts + col_pts + sec_pts
				if structures_completed == 1:
					if row_pts > 0: _add_points(row_pts, &"row_complete")
					elif col_pts > 0: _add_points(col_pts, &"col_complete")
					elif sec_pts > 0: _add_points(sec_pts, &"sector_complete")
				elif structures_completed == 2:
					var combo_points = int(round(base_completions_points * 1.5))
					_add_points(combo_points, &"combo_double")
				elif structures_completed == 3:
					var combo_points = int(round(base_completions_points * 2.0))
					_add_points(combo_points, &"combo_triple")
		else:
			# Es incorrecto y no es borrado
			var cell = board.get_cell(coords) if board.has_method("get_cell") else null
			if cell:
				cell.mistake_count += 1
				total_errors_in_game += 1
				_board_errors[board_id] = _board_errors.get(board_id, 0) + 1
				
				# Penalización progresiva
				var penalty = 5
				if cell.mistake_count == 2:
					penalty = 15
				elif cell.mistake_count >= 3:
					penalty = 30
					
				deduct_points(penalty)
				
				# Reseteamos racha
				streak_multiplier = 1.0
				streak_changed.emit(streak_multiplier)

## Verifica si la celda pertenece a una restricción de variante (Killer, Thermo, Arrow, Anti-Knight).
## La variante "Samurai" (celdas compartidas entre boards) NO otorga puntos aquí.
func _check_variant_constraint(board: Node, board_id: StringName, coords: Vector2i) -> void:
	# Solo aplica si el board tiene variante activa (no CLASSIC=0)
	var variant: int = _board_variants.get(board_id, 0)
	# CLASSIC sin flags extra no tiene restricción de variante
	if variant == 0 and not board.get("knight_move") and not board.get("killer") \
			and not board.get("arrow") and not board.get("thermo"):
		return

	# Consultar si la celda tiene restricción de variante en la lógica del solver.
	# Board expone el SudokuLogic indirectamente; buscamos por duck-typing.
	# Como Board no expone el logic directamente, usamos los flags del propio Board.
	var has_variant_cell: bool = false

	# Anti-Knight: toda celda con has_knight_restriction es la celda restringida
	if board.get("knight_move") or variant == 1: # VariantType.ANTI_KNIGHT = 1
		var cell = board.get_cell(coords) if board.has_method("get_cell") else null
		if cell and cell.get("has_knight_restriction"):
			has_variant_cell = true

	# Killer / Thermo / Arrow: no tenemos acceso directo al solver desde Board.
	# Usamos la presencia de los flags en Board como indicador general.
	# Si el board tiene killer/thermo/arrow activo, todas las celdas correctas cuentan.
	if not has_variant_cell:
		if board.get("killer") or variant == 2: # KILLER
			has_variant_cell = true
		elif board.get("thermo") or variant == 3: # THERMO
			has_variant_cell = true
		elif board.get("arrow") or variant == 4: # ARROW
			has_variant_cell = true

	if has_variant_cell:
		_add_points(POINTS_VARIANT_CONSTRAINT, &"variant_constraint")

## Verifica si la fila 'row_idx' está completamente correcta.
func _check_row(board: Node, board_id: StringName, row_idx: int, state: Dictionary) -> int:
	if state["rows"][row_idx]:
		return 0  # Ya completada anteriormente

	if not board.has_method("get_cell"):
		return 0

	for x in range(9):
		var cell = board.get_cell(Vector2i(x, row_idx))
		if cell == null or cell.value == 0 or cell.value != cell.true_value:
			return 0  # Fila incompleta

	# Fila completada por primera vez
	state["rows"][row_idx] = true
	return POINTS_ROW_COMPLETE

## Verifica si la columna 'col_idx' está completamente correcta.
func _check_col(board: Node, board_id: StringName, col_idx: int, state: Dictionary) -> int:
	if state["cols"][col_idx]:
		return 0

	if not board.has_method("get_cell"):
		return 0

	for y in range(9):
		var cell = board.get_cell(Vector2i(col_idx, y))
		if cell == null or cell.value == 0 or cell.value != cell.true_value:
			return 0

	state["cols"][col_idx] = true
	return POINTS_COL_COMPLETE

## Verifica si el sector 3×3 al que pertenece 'coords' está completamente correcto.
func _check_sector(board: Node, board_id: StringName, coords: Vector2i, state: Dictionary) -> int:
	@warning_ignore("integer_division")
	var block_x: int = (coords.x / 3) * 3
	@warning_ignore("integer_division")
	var block_y: int = (coords.y / 3) * 3
	@warning_ignore("integer_division")
	var sector_idx: int = (coords.y / 3) * 3 + (coords.x / 3)

	if state["sectors"][sector_idx]:
		return 0

	if not board.has_method("get_cell"):
		return 0

	for dx in range(3):
		for dy in range(3):
			var cell = board.get_cell(Vector2i(block_x + dx, block_y + dy))
			if cell == null or cell.value == 0 or cell.value != cell.true_value:
				return 0

	state["sectors"][sector_idx] = true
	return POINTS_SECTOR_COMPLETE

## Ejecutado cuando un board completo se resuelve correctamente.
func _on_board_completed(board_id: StringName) -> void:
	_add_points(POINTS_SUDOKU_COMPLETE, &"sudoku_complete")
	
	# Propuesta 3: Bono de Perfección si se completó con 0 errores
	var errors = _board_errors.get(board_id, 0)
	if errors == 0:
		_add_points(POINTS_PERFECT_BOARD, &"perfect_board")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _add_points(amount: int, achievement: StringName) -> void:
	var base_with_diff = amount
	
	# Propuesta 1: Multiplicador por dificultad
	if active_manager and active_manager.get("level_config"):
		var level_config = active_manager.level_config
		if level_config:
			match level_config.difficulty_level:
				0: base_with_diff = int(round(amount * 1.0)) # EASY
				1: base_with_diff = int(round(amount * 1.5)) # MEDIUM
				2: base_with_diff = int(round(amount * 2.0)) # HARD
				3: base_with_diff = int(round(amount * 3.0)) # EXTREME

	var modified_amount = int(round(base_with_diff * streak_multiplier))
	total_score += modified_amount
	score_changed.emit(total_score)
	achievement_unlocked.emit(achievement, base_with_diff, streak_multiplier, modified_amount)
	_refresh_label()

func _refresh_label() -> void:
	if score_label != null and is_instance_valid(score_label):
		score_label.text = str(total_score)

func increase_streak(amount: float = 0.2) -> void:
	streak_multiplier += amount
	streak_multiplier = round(streak_multiplier * 10.0) / 10.0
	streak_changed.emit(streak_multiplier)

func decay_streak() -> void:
	streak_multiplier = max(1.0, streak_multiplier - 0.1)
	streak_multiplier = round(streak_multiplier * 10.0) / 10.0
	streak_changed.emit(streak_multiplier)

func deduct_points(amount: int) -> void:
	total_score = max(0, total_score - amount)
	score_changed.emit(total_score)
	achievement_unlocked.emit(&"penalty", -amount, 1.0, -amount)
	_refresh_label()

func apply_challenge_validation_penalties(incorrect_cells_count: int, error_cells_by_board: Dictionary = {}) -> void:
	total_errors_in_game += incorrect_cells_count
	var old_score = total_score
	
	for i in range(incorrect_cells_count):
		total_score = int(round(total_score * 0.95))
	
	# Registrar errores por tablero si se pasaron
	for bid in error_cells_by_board:
		var errors_list = error_cells_by_board[bid]
		if errors_list is Array and errors_list.size() > 0:
			_board_errors[bid] = _board_errors.get(bid, 0) + errors_list.size()
	
	if incorrect_cells_count > 0:
		streak_multiplier = 1.0
		streak_changed.emit(streak_multiplier)
		var deduction = old_score - total_score
		achievement_unlocked.emit(&"validation_penalty", -deduction, 1.0, -deduction)
		
	score_changed.emit(total_score)
	_refresh_label()
