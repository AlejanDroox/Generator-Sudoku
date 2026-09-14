extends Node
## SaveGameManager — Persistencia de partida activa aislada por usuario.
##
## Guarda y recupera el estado de una partida en curso para permitir
## reanudarla al volver al nivel. Aislado por user_id igual que LocalDB.
## El archivo se guarda en: user://active_game_[user_id].json

# ── Constantes ─────────────────────────────────────────────────────────────────
const _SAVE_TEMPLATE: String = "user://active_game_%s.json"

# ── API Pública ────────────────────────────────────────────────────────────────

## Retorna true si existe un guardado activo para el usuario actual.
func has_saved_game() -> bool:
	var path := _save_path()
	return FileAccess.file_exists(path)


## Guarda el estado completo de la partida activa a disco.
## Llamado por SamuraiManager con self como parámetro.
func save_active_game(samurai: Node) -> void:
	var user_id := _get_user_id()

	# ── Nivel ──
	var level_cfg: Dictionary = {}
	var lc = samurai.level_config
	if lc != null:
		# Determinar si proviene de un recurso precargado (.tres)
		var res_path: String = lc.resource_path if lc.resource_path != "" else ""
		level_cfg = {
			"is_predefined": res_path != "",
			"resource_path": res_path,
			# Datos brutos para nivel personalizado (por si no hay .tres)
			"total_boards":          lc.total_boards,
			"initial_difficulty":    lc.initial_difficulty,
			"chain_difficulty_range": [lc.chain_difficulty_range.x, lc.chain_difficulty_range.y],
			"difficulty_level":      int(lc.difficulty_level),
			"game_mode":             int(lc.game_mode),
			"is_custom":             lc.is_custom,
			"custom_rng_seed":       lc.custom_rng_seed,
			"valid_variants":        lc.valid_variants,
			"first_board_has_variants": lc.first_board_has_variants,
			"progressive_complexity":  lc.progressive_complexity,
			"min_variants_per_board":   lc.min_variants_per_board,
			"max_variants_per_board":   lc.max_variants_per_board,
		}

	# ── Puntuación ──
	var score_data: Dictionary = {
		"total_score":             ScoreManager.total_score,
		"streak_multiplier":       ScoreManager.streak_multiplier,
		"total_errors_in_game":    ScoreManager.total_errors_in_game,
		"solved_cells_per_board":  _serialize_solved_cells(ScoreManager._solved_cells_per_board),
	}

	# ── Tableros ──
	var boards_state: Array = []
	for i in range(samurai.board_ids.size()):
		var bid: StringName = samurai.board_ids[i]
		var board: Node = samurai.boards.get(bid)
		if not is_instance_valid(board):
			continue

		var cells_player: Dictionary = {}
		for coords in board.cells_dict:
			var cell = board.cells_dict[coords]
			if cell.is_fixed:
				continue
			var marks: Array = []
			for lbl in cell.pencil_labels:
				marks.append(lbl.visible if is_instance_valid(lbl) else false)
			cells_player["%d,%d" % [coords.x, coords.y]] = {
				"value":             cell.value,
				"pencil_marks":      marks,
				"mistake_count":     cell.mistake_count,
				"has_been_incorrect": cell.has_been_incorrect,
			}

		# Serializar datos de variante (solution, puzzle original, restricciones)
		var solution_serial: Dictionary = {}
		for coords in board._solution:
			solution_serial["%d,%d" % [coords.x, coords.y]] = board._solution[coords]

		var puzzle_serial: Dictionary = {}
		var puzzle_state = board.get_puzzle_state()
		for coords in puzzle_state:
			puzzle_serial["%d,%d" % [coords.x, coords.y]] = puzzle_state[coords]

		var grid_pos: Vector2i = samurai.board_grid_positions[i] if i < samurai.board_grid_positions.size() else Vector2i.ZERO
		boards_state.append({
			"board_id":      str(bid),
			"variant_type":  board.variant_type,
			"knight_restricted_number": board.knight_restricted_number,
			"grid_pos":      [grid_pos.x, grid_pos.y],
			"solution":      solution_serial,
			"puzzle":        puzzle_serial,
			"extra_data": {
				"killer_cages":       _serialize_killer(board.killer_cages),
				"thermo_chains":      _serialize_thermo(board.thermo_chains),
				"arrow_constraints":  _serialize_arrows(board.arrow_constraints),
			},
			"cells_player_state": cells_player,
		})

	# ── Documento raíz ──
	var corners_int: Array = []
	for c in samurai.board_exit_corners:
		corners_int.append(int(c))

	var grid_positions_serial: Array = []
	for gp in samurai.board_grid_positions:
		grid_positions_serial.append([gp.x, gp.y])

	var data := {
		"user_id":                     user_id,
		"timestamp":                   Time.get_unix_time_from_system(),
		"game_mode":                   int(samurai.game_mode),
		"current_level":               samurai.current_level,
		"rng_seed":                    samurai.rng_seed,
		"level_knight_restricted_number": samurai.level_knight_restricted_number,
		"elapsed_seconds":             samurai._elapsed_seconds,
		"next_board_index":            samurai.next_board_index,
		"completed_boards":            samurai.completed_boards,
		"board_exit_corners":          corners_int,
		"board_grid_positions":        grid_positions_serial,
		"level_config":                level_cfg,
		"score_manager":               score_data,
		"boards_state":                boards_state,
	}

	var file := FileAccess.open(_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("SaveGameManager: no se pudo escribir en '%s'." % _save_path())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Carga el guardado activo y retorna el diccionario. Vacío si no existe o está corrupto.
func load_active_game() -> Dictionary:
	var path := _save_path()
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	push_warning("SaveGameManager: archivo '%s' corrupto, se ignorará." % path)
	delete_save_file()
	return {}


## Elimina el archivo de guardado activo.
func delete_save_file() -> void:
	var path := _save_path()
	if not FileAccess.file_exists(path):
		return
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove(path.get_file())


# ── Privados ───────────────────────────────────────────────────────────────────

func _get_user_id() -> String:
	if AuthManager.is_logged_in and AuthManager.user_id != "":
		return AuthManager.user_id
	return "guest"


func _save_path() -> String:
	return _SAVE_TEMPLATE % _get_user_id()


func _serialize_solved_cells(data: Dictionary) -> Dictionary:
	var result := {}
	for board_id in data:
		var per_board: Dictionary = {}
		for coords in data[board_id]:
			per_board["%d,%d" % [coords.x, coords.y]] = data[board_id][coords]
		result[str(board_id)] = per_board
	return result


## Serializa thermo_chains (Array de Array de Vector2i) a JSON-safe.
func _serialize_thermo(chains: Array) -> Array:
	var result := []
	for chain in chains:
		var chain_serial := []
		for coords in chain:
			chain_serial.append([coords.x, coords.y])
		result.append(chain_serial)
	return result


## Serializa arrow_constraints (Array de {circle: Vector2i, shaft: Array[Vector2i]}) a JSON-safe.
func _serialize_arrows(constraints: Array) -> Array:
	var result := []
	for c in constraints:
		var shaft_serial := []
		for coords in c["shaft"]:
			shaft_serial.append([coords.x, coords.y])
		var circle = c["circle"]
		result.append({
			"circle": [circle.x, circle.y],
			"shaft":  shaft_serial,
		})
	return result


## Serializa killer_cages (Array de {sum: int, cells: Array[Vector2i]}) a JSON-safe.
func _serialize_killer(cages: Array) -> Array:
	var result := []
	for cage in cages:
		var cells_serial := []
		for coords in cage.get("cells", []):
			cells_serial.append([coords.x, coords.y])
		result.append({
			"sum": cage.get("sum", 0),
			"cells": cells_serial,
		})
	return result
