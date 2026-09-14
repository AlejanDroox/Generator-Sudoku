extends Node2D
class_name SamuraiManager

## Orquestador principal del sistema de cadena progresiva.
## Gestiona la generación, posicionamiento y vinculación de múltiples boards
## en una cadena zigzag hacia la derecha.

## Emitida cuando se genera y posiciona un nuevo board en la cadena
signal new_board_spawned(board_id: StringName, board_index: int)
## Emitida cuando todos los boards del nivel están completados
signal level_completed(level_number: int)
## Emitida si la generación de un board falla después de varios intentos
signal generation_failed(board_index: int)

## Emitida cuando se inicia la generación de un board en segundo plano
signal generation_started(board_index: int)
## Emitida cuando finaliza la generación de un board en segundo plano (sea exitosa o no)
signal generation_finished(board_index: int)

## Escena del board individual (reutilizable)
const board_scene: PackedScene = preload("res://scenas/Board/board_v_3.tscn")

## Tamaño de cada celda en píxeles (debe coincidir con Board.cell_size)
const CELL_SIZE: float = 64.0
## Tamaño de un board completo en píxeles (9 celdas × cell_size)
const BOARD_SIZE: float = 9.0 * CELL_SIZE  # 144px
## Tamaño del solapamiento (3 celdas × cell_size = un sector 3×3)
const OVERLAP_SIZE: float = 3.0 * CELL_SIZE  # 48px
## Offset entre boards consecutivos (board_size - overlap)
const CHAIN_OFFSET: float = BOARD_SIZE - OVERLAP_SIZE  # 96px

## Configuración del nivel actual
@export var level_config: LevelConfig
@export var game_mode: Global.GameMode = Global.GameMode.PRACTICE

@onready var _btn_verify: Button = $CanvasLayer/Control/Verificar
@onready var _lbl_streak: Label = $CanvasLayer/Control/Panel/HBoxContainer/StreakLabel

## Generador de puzzles (usado en hilo principal para inicialización)
var generator: SudokuGenerator
## Número del nivel actual
var current_level: int = 1

## Diccionario de todos los boards activos: {StringName → Board}
var boards: Dictionary = {}
## Array ordenado de las soluciones de cada board (para extraer semillas)
var board_solutions: Array[Dictionary] = []
## Array de los board_ids en orden de creación
var board_ids: Array[StringName] = []
## Array de los rincones de salida reales elegidos para cada tablero
var board_exit_corners: Array[int] = []
## Array de las posiciones de cuadrícula de cada tablero
var board_grid_positions: Array[Vector2i] = []
## Índice del próximo board a generar en la cadena
var next_board_index: int = 0
## Número de boards completados
var completed_boards: int = 0
## Número restringido por caballero compartido por todo el nivel (0 significa sin definir)
var level_knight_restricted_number: int = 0

## Semilla actual utilizada para la generación aleatoria de este nivel
var rng_seed: int = 0

## Indica si hay un hilo de generación activo en este momento
var is_generating: bool = false

## Nodo contenedor donde se instancian los boards
@onready var board_container: Node2D = $BoardContainer
## Referencia a la cámara para seguir la cadena
@onready var camera: Camera2D = $Camera2D
## Timer para medir el tiempo de la partida
@onready var _game_timer: Timer = $GameTimer
@onready var _btn_back: Button = $CanvasLayer/Control/Volver
@onready var _btn_pencil: CheckButton = $CanvasLayer/Control/BoxContainer2/VBoxContainer/Mode_pencil
@onready var _btn_borrar: Button = $CanvasLayer/Control/BoxContainer2/VBoxContainer/Borrar
@onready var _num_buttons: Array[CheckButton] = [
	$CanvasLayer/Control/Buttom_numbers/Button,
	$CanvasLayer/Control/Buttom_numbers/Button2,
	$CanvasLayer/Control/Buttom_numbers/Button3,
	$CanvasLayer/Control/Buttom_numbers/Button4,
	$CanvasLayer/Control/Buttom_numbers/Button5,
	$CanvasLayer/Control/Buttom_numbers/Button6,
	$CanvasLayer/Control/Buttom_numbers/Button7,
	$CanvasLayer/Control/Buttom_numbers/Button8,
	$CanvasLayer/Control/Buttom_numbers/Button9
]

## Segundos transcurridos desde que empezó el nivel
var _elapsed_seconds: float = 0.0

## Máximo de intentos de generación antes de emitir generation_failed
const MAX_GENERATION_ATTEMPTS: int = 5

# Manejo interno de hilos
var _thread: Thread = null
var _queued_board_index: int = -1
var _pending_board_data: Dictionary = {}

## Referencia a la escena del panel de carga y estado
const loading_panel_scene: PackedScene = preload("res://scenas/UI/loading_panel.tscn")
var loading_panel_instance: Panel = null
var game_started: bool = false
var current_loading_progress: float = 0.0
var simulated_progress_timer: Timer = null

## Retardo en segundos antes de escribir a disco tras el último cambio (debounce).
## Configurable desde el Inspector de la escena samurai_level.tscn.
@export var save_debounce_time: float = 1.0

## Timer interno para el debounce de guardado.
var _save_debounce_timer: Timer = null

func _ready() -> void:
	# Registrar este manager en el administrador de puntuación
	ScoreManager.register_manager(self)
	
	generator = SudokuGenerator.new()
	
	# Instanciar dinámicamente el feed de puntuación (Twitch-like chat)
	var score_feed_script = load("res://scripts/UI/ScoreFeed.gd")
	if score_feed_script:
		var feed = VBoxContainer.new()
		feed.set_script(score_feed_script)
		feed.name = "ScoreFeed"
		
		# Agregarlo al Control del CanvasLayer
		var control = get_node_or_null("CanvasLayer/Control")
		if control:
			control.add_child(feed)
			
			# Buscar el marcador de posicionamiento FeedScore
			var marker = find_child("FeedScore")
			if marker:
				# Si el marker existe, posicionamos el feed usando su coordenada
				# como la esquina inferior derecha del feed (con un alto de 350px)
				var marker_pos = marker.position
				feed.offset_left = marker_pos.x - 300.0
				feed.offset_top = marker_pos.y - 350.0
				feed.offset_right = marker_pos.x
				feed.offset_bottom = marker_pos.y
			else:
				# Posicionamiento por defecto a la derecha de la pantalla (área libre)
				feed.offset_left = 920.0
				feed.offset_top = 150.0
				feed.offset_right = 1180.0
				feed.offset_bottom = 500.0
				
			feed.alignment = BoxContainer.ALIGNMENT_END
	
	# Usar la configuración dinámica global si se seleccionó en la UI
	if Global.custom_level_config != null:
		level_config = Global.custom_level_config
		print("SamuraiManager: Usando configuración dinámica de nivel desde Global")
	
	# Crear configuración por defecto si no se proporcionó una
	if level_config == null:
		level_config = LevelConfig.new()
		level_config.total_boards = 3
		level_config.initial_difficulty = 3
		level_config.chain_difficulty_range = Vector2i(3, 50)
		level_config.valid_variants = [
			SudokuGenerator.VariantType.CLASSIC, 
			SudokuGenerator.VariantType.ANTI_KNIGHT
		]
		
	# Si la configuración tiene el método para aplicar la dificultad, la aplicamos.
	# Esto es especialmente útil en niveles personalizados dinámicos.
	if level_config.has_method("apply_difficulty_level"):
		level_config.apply_difficulty_level()
		print("SamuraiManager: Dificultad configurada: ", level_config.difficulty_level,
			" | Inicial: ", level_config.initial_difficulty,
			" | Rango cadena: ", level_config.chain_difficulty_range)

	# Configurar el modo de juego según la configuración si se especifica
	if "game_mode" in level_config:
		game_mode = level_config.game_mode
		print("SamuraiManager: Modo de juego sobreescrito por la configuración: ", game_mode)

	# Configurar la semilla RNG
	var custom_seed = 0
	if "custom_rng_seed" in level_config:
		custom_seed = level_config.custom_rng_seed

	if custom_seed != 0:
		rng_seed = custom_seed
		seed(rng_seed)
		print("SamuraiManager: Iniciado con semilla personalizada = ", rng_seed)
	else:
		rng_seed = randi()
		seed(rng_seed)
		print("SamuraiManager: Iniciado con semilla aleatoria generada = ", rng_seed)
		
	# Si tenemos custom_boards cargados, total_boards debe ser exactamente la cantidad de custom_boards
	if not level_config.custom_boards.is_empty():
		level_config.total_boards = level_config.custom_boards.size()
		print("SamuraiManager: Usando ", level_config.total_boards, " tableros de la configuración manual")

	# ── Timer de debounce para auto-guardado ──────────────────────────────────
	_save_debounce_timer = Timer.new()
	_save_debounce_timer.name       = "SaveDebounceTimer"
	_save_debounce_timer.wait_time  = save_debounce_time
	_save_debounce_timer.one_shot   = true
	_save_debounce_timer.autostart  = false
	_save_debounce_timer.timeout.connect(_on_save_debounce_timeout)
	add_child(_save_debounce_timer)

	# ── Conectar nivel completado ANTES de decidir qué flujo usar ─────────────
	level_completed.connect(_on_level_completed_save)
	_btn_back.pressed.connect(_on_back_pressed)

	# ── Decidir: reanudar o iniciar nuevo nivel ───────────────────────────────
	if not Global.active_save_to_resume.is_empty():
		var save_data := Global.active_save_to_resume
		Global.active_save_to_resume = {}  # Limpiar para evitar re-entradas
		resume_level(save_data)
	else:
		start_level()
	
	# Crear un grupo de botones unificado y permitir deseleccionar (allow_unpress)
	var button_group: ButtonGroup = ButtonGroup.new()
	button_group.allow_unpress = true
	
	# Configurar todos los botones numéricos
	for i in range(_num_buttons.size()):
		var btn = _num_buttons[i]
		if is_instance_valid(btn):
			btn.toggle_mode = true
			btn.button_group = null # Evitamos el ButtonGroup para que no interfiera al forzar el estado de apagado
			var num = i + 1
			# Desconectar conexiones previas externas (sin quitar la conexión interna del script del botón a su propio método _on_toggled)
			for conn in btn.toggled.get_connections():
				if conn.callable.get_object() != btn:
					btn.toggled.disconnect(conn.callable)
			btn.toggled.connect(func(pressed_state):
				if pressed_state:
					_on_number_pressed(num)
					# Esperar 0.25s (la duración exacta del Tween) para que se complete la animación antes de bajar
					await get_tree().create_timer(0.25).timeout
					if is_instance_valid(btn):
						btn.button_pressed = false
			)
			
	# Configurar el botón de borrar
	if is_instance_valid(_btn_borrar):
		_btn_borrar.toggle_mode = true
		_btn_borrar.button_group = null
		# Desconectar conexiones previas externas
		for conn in _btn_borrar.toggled.get_connections():
			if conn.callable.get_object() != _btn_borrar:
				_btn_borrar.toggled.disconnect(conn.callable)
		_btn_borrar.toggled.connect(func(pressed_state):
			if pressed_state:
				_on_erase_pressed()
				await get_tree().create_timer(0.25).timeout
				if is_instance_valid(_btn_borrar):
					_btn_borrar.button_pressed = false
		)

	# Conectar el modo lápiz
	if is_instance_valid(_btn_pencil):
		# Quitarlo del button_group para que no sea excluyente con los números
		_btn_pencil.button_group = null
		_btn_pencil.toggled.connect(_on_pencil_toggled)
		Global.pencil_mode_active = _btn_pencil.button_pressed
	
	Global.cell_focus_changed.connect(func(_cell): update_knight_restricted_buttons())

	# Configurar HUD para modos de juego
	if is_instance_valid(_btn_verify):
		_btn_verify.visible = (game_mode == Global.GameMode.CHALLENGE)
		if not _btn_verify.pressed.is_connected(_on_verify_pressed):
			_btn_verify.pressed.connect(_on_verify_pressed)
			
	# Escuchar cambios de racha
	if not ScoreManager.streak_changed.is_connected(_on_streak_multiplier_changed):
		ScoreManager.streak_changed.connect(_on_streak_multiplier_changed)
	_update_streak_label(ScoreManager.streak_multiplier)

	# Crear y configurar el temporizador de decaimiento de racha
	var streak_decay_timer = Timer.new()
	streak_decay_timer.name = "StreakDecayTimer"
	streak_decay_timer.wait_time = 15.0 if game_mode == Global.GameMode.CHALLENGE else 20.0
	streak_decay_timer.autostart = true
	streak_decay_timer.one_shot = false
	streak_decay_timer.timeout.connect(func(): ScoreManager.decay_streak())
	add_child(streak_decay_timer)



	# Conectar actualización de fuente del HUD
	_update_hud_fonts()
	Global.font_changed.connect(func(_use_neutral): _update_hud_fonts())

func _on_number_pressed(num: int) -> void:
	if Global._previus_cell and is_instance_valid(Global._previus_cell):
		if Global.pencil_mode_active:
			Global._previus_cell.toggle_pencil_mark(num)
		else:
			Global._previus_cell.verify_number(num)

func _on_erase_pressed() -> void:
	if Global._previus_cell and is_instance_valid(Global._previus_cell):
		Global._previus_cell.verify_number(0)

func _on_pencil_toggled(button_pressed: bool) -> void:
	Global.pencil_mode_active = button_pressed
	print("Pencil mode toggled: ", Global.pencil_mode_active)


func _on_back_pressed() -> void:
	_stop_simulated_progress()
	# Guardar partida en curso antes de volver al menú
	if game_started and not boards.is_empty():
		SaveGameManager.save_active_game(self)
	ScoreManager.reset()
	get_tree().change_scene_to_file("res://scenas/Levels/niveles_list.tscn")

## Inicia el nivel: inicia la generación del primer board (clásico) en segundo plano
func start_level() -> void:
	_cleanup_thread()
	_clear_all_boards()
	ScoreManager.reset()
	next_board_index = 0
	completed_boards = 0
	# Elegir un número aleatorio para la restricción de caballo a nivel de toda la partida/run
	level_knight_restricted_number = randi_range(1, 9)
	update_knight_restricted_buttons()
	board_solutions.clear()
	board_ids.clear()
	_initialize_exit_corners()
	_pending_board_data.clear()
	_elapsed_seconds = 0.0
	
	game_started = false
	current_loading_progress = 0.0
	
	# Instanciar el panel de carga
	if is_instance_valid(loading_panel_instance):
		loading_panel_instance.queue_free()
		
	loading_panel_instance = loading_panel_scene.instantiate()
	$CanvasLayer.add_child(loading_panel_instance)
	
	# Ocultar o mostrar aclaración según dificultad
	# La alerta debe aparecer cuando se seleccione dificil y extremo
	var is_hard_or_extreme = false
	if level_config:
		is_hard_or_extreme = (level_config.difficulty_level == LevelConfig.DifficultyLevel.HARD or 
							  level_config.difficulty_level == LevelConfig.DifficultyLevel.EXTREME)
	loading_panel_instance.show_aclaracion(is_hard_or_extreme)
	
	# Asignar un consejo aleatorio
	loading_panel_instance.set_tip(_get_random_tip_for_loading())
	
	# Conectar señal de inicio
	loading_panel_instance.start_pressed.connect(_on_loading_start_pressed)
	
	# Empezar la generación del primer board en hilo secundario
	var first_variants = _get_variants_for_board(0)
	var first_diff = _get_difficulty_for_board(0)
	_start_background_generation(0, first_variants, first_diff)

func _get_random_tip_for_loading() -> String:
	var tips = [
		"Si quieres poder ver las clasificaciones globales,\n debes pertenecer a alguna de las instituciones participantes.",
		"En el Modo Practica\npuedes cometer errores\nsin penalizaciones fuertes en puntuacion.\n¡Es ideal para aprender!",
		"En el Modo Desafio\n cometer errores reinicia\ntu racha y descuenta puntos,\npero tus aciertos valen mas si \nmantienes una racha alta.",
		"Usa el modo lapiz\npara anotar\nposibles candidatos en las casillas vacias.",
		"Puedes presionar el boton central\ndel raton (rueda) para alternar\nrapidamente el modo lapiz.",
		"En tableros grandes\n concentrate\nen resolver las celdas de\ninterseccion primero,\nya que afectan a ambos sudokus.",
		"Aprovecha las marcas que dejes con\nel lapiz para descartar numeros\nen filas y columnas\nsimultaneamente."
	]
	
	if level_config:
		if SudokuGenerator.VariantType.ANTI_KNIGHT in level_config.valid_variants:
			tips.append("Consejo Anti-Caballo: Ninguna casilla a un movimiento de caballo de ajedrez puede tener el mismo numero.")
		if SudokuGenerator.VariantType.KILLER in level_config.valid_variants:
			tips.append("Consejo Killer: Los numeros en cada jaula punteada deben sumar el valor indicado y no pueden repetirse.")
		if SudokuGenerator.VariantType.THERMO in level_config.valid_variants:
			tips.append("Consejo Termometro: Los digitos deben aumentar estrictamente a lo largo de cada termometro, empezando desde el bulbo circular.")
		if SudokuGenerator.VariantType.ARROW in level_config.valid_variants:
			tips.append("Consejo Flecha: Los digitos en el cuerpo de la flecha deben sumar exactamente el valor indicado en su circulo.")
			
	return tips[randi() % tips.size()]

func _on_loading_start_pressed() -> void:
	game_started = true
	if _game_timer:
		_game_timer.start()
	
	if is_instance_valid(loading_panel_instance):
		var tween = create_tween()
		tween.tween_property(loading_panel_instance, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.finished.connect(func():
			if is_instance_valid(loading_panel_instance):
				loading_panel_instance.queue_free()
				loading_panel_instance = null
		)

func _on_generator_attempt_failed(attempt_num: int) -> void:
	if is_instance_valid(loading_panel_instance) and not game_started:
		current_loading_progress = min(74.0, current_loading_progress + 3.0)
		loading_panel_instance.update_progress(current_loading_progress)
		print("SamuraiManager [MAIN THREAD]: Generación intento ", attempt_num, " falló. Progreso: ", current_loading_progress, "%")

func _on_generator_attempt_succeeded(attempt_num: int) -> void:
	if is_instance_valid(loading_panel_instance) and not game_started:
		current_loading_progress = max(75.0, current_loading_progress)
		loading_panel_instance.update_progress(current_loading_progress)
		print("SamuraiManager [MAIN THREAD]: Generación intento ", attempt_num, " exitoso. Progreso saltó a ", current_loading_progress, "%")
		_start_simulated_progress()

func _start_simulated_progress() -> void:
	_stop_simulated_progress()
	
	simulated_progress_timer = Timer.new()
	simulated_progress_timer.name = "SimulatedProgressTimer"
	simulated_progress_timer.wait_time = 0.05
	simulated_progress_timer.one_shot = false
	simulated_progress_timer.timeout.connect(func():
		if is_instance_valid(loading_panel_instance) and not game_started:
			current_loading_progress = min(99.0, current_loading_progress + 1.0)
			loading_panel_instance.update_progress(current_loading_progress)
		else:
			_stop_simulated_progress()
	)
	add_child(simulated_progress_timer)
	simulated_progress_timer.start()

func _stop_simulated_progress() -> void:
	if is_instance_valid(simulated_progress_timer):
		simulated_progress_timer.stop()
		simulated_progress_timer.queue_free()
		simulated_progress_timer = null

## Captura input de teclado y ratón para enviar números, borrar y alternar modo lápiz
func _input(event: InputEvent) -> void:
	if not game_started:
		return
	if event is InputEventKey and event.pressed:
		var clave = event.keycode
		# Verificar si es una tecla numérica (número principal del teclado)
		if clave >= KEY_0 and clave <= KEY_9:
			var numero = clave - KEY_0  # Convertir a entero (0-9)
			if Global._previus_cell:
				if Global.pencil_mode_active:
					Global._previus_cell.toggle_pencil_mark(numero)
				else:
					Global._previus_cell.verify_number(numero)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if is_instance_valid(_btn_pencil):
				_btn_pencil.button_pressed = not _btn_pencil.button_pressed
				get_viewport().set_input_as_handled()

## Inicia la generación asíncrona de un board
func _start_background_generation(board_index: int, variants: Array, difficulty: int) -> void:
	if is_generating:
		push_warning("SamuraiManager: Ya hay una generación en curso para board_%d. Esperando..." % _queued_board_index)
		return
		
	is_generating = true
	_queued_board_index = board_index
	_pending_board_data.clear()
	
	generation_started.emit(board_index)
	
	var previous_solution = {}
	var previous_puzzle = {}
	if board_index > 0:
		previous_solution = board_solutions[board_index - 1]
		var prev_board: Board = boards[board_ids[board_index - 1]]
		previous_puzzle = prev_board.get_puzzle_state()
		
	var candidates = _get_valid_candidate_corners(board_index)

	print("SamuraiManager [MAIN THREAD]: Iniciando generación de board_%d. Dificultad: %d, Variantes: %s" % [board_index, difficulty, str(variants)])
	if board_index > 0:
		print("SamuraiManager [MAIN THREAD]: Tableros previos ya colocados: %s" % str(board_grid_positions))
		print("SamuraiManager [MAIN THREAD]: Candidatos viables (sin solapamientos): %s" % str(candidates))
		
	var thread_args = {
		"board_index": board_index,
		"difficulty": difficulty,
		"variants": variants,
		"previous_solution": previous_solution,
		"previous_puzzle": previous_puzzle,
		"candidates": candidates,
		"default_corner": board_exit_corners[board_index - 1] if board_index > 0 else SudokuGenerator.ExitCorner.TOP_RIGHT,
		"previous_grid_pos": board_grid_positions[board_index - 1] if board_index > 0 else Vector2i.ZERO,
		"seed": rng_seed,
		"knight_restricted_number": level_knight_restricted_number
	}
	
	# Si hay configuraciones manuales para este nivel y contienen jaulas/termómetros/flechas predefinidas,
	# las asignamos en el generador antes de iniciar el hilo de generación.
	if not level_config.custom_boards.is_empty() and board_index < level_config.custom_boards.size():
		var custom_board = level_config.custom_boards[board_index]
		generator.clear_variant_data()
		if not custom_board.killer_cages.is_empty():
			generator.set_killer_cages(custom_board.killer_cages)
		if not custom_board.thermo_chains.is_empty():
			generator.set_thermo_chains(custom_board.thermo_chains)
		if not custom_board.arrow_constraints.is_empty():
			generator.set_arrow_constraints(custom_board.arrow_constraints)
	else:
		generator.clear_variant_data()
	
	_thread = Thread.new()
	var err = _thread.start(Callable(self, "_thread_generate_board").bind(thread_args))
	if err != OK:
		push_error("SamuraiManager: Error al iniciar el hilo de generación: %d" % err)
		is_generating = false
		generation_failed.emit(board_index)

## Función ejecutada en el hilo secundario (segura para hilos, no toca el SceneTree)
func _thread_generate_board(args: Dictionary) -> void:
	var board_index = args["board_index"]
	var difficulty = args["difficulty"]
	var variants = args["variants"]
	var previous_solution = args["previous_solution"]
	var previous_puzzle = args["previous_puzzle"]
	var candidates = args["candidates"]
	var default_corner = args["default_corner"]
	var previous_grid_pos = args.get("previous_grid_pos", Vector2i.ZERO)
	var thread_seed = args.get("seed", 0)
	var knight_restricted_number = args.get("knight_restricted_number", 0)
	
	if thread_seed != 0:
		seed(thread_seed + board_index)
	
	print("SamuraiManager [THREAD]: Generando board_%d con semilla %d, Caballo: %d..." % [board_index, thread_seed + board_index, knight_restricted_number])
	var gen = SudokuGenerator.new()
	if board_index == 0:
		gen.attempt_failed.connect(Callable(self, "_on_generator_attempt_failed"), CONNECT_DEFERRED)
		gen.attempt_succeeded.connect(Callable(self, "_on_generator_attempt_succeeded"), CONNECT_DEFERRED)
	
	# Sincronizar jaulas/termómetros/flechas preconfiguradas si existen
	if not level_config.custom_boards.is_empty() and board_index < level_config.custom_boards.size():
		var custom_board = level_config.custom_boards[board_index]
		if not custom_board.killer_cages.is_empty():
			gen.set_killer_cages(custom_board.killer_cages)
		if not custom_board.thermo_chains.is_empty():
			gen.set_thermo_chains(custom_board.thermo_chains)
		if not custom_board.arrow_constraints.is_empty():
			gen.set_arrow_constraints(custom_board.arrow_constraints)
			
	var datos_nivel: Dictionary = {}
	var attempts = 0
	
	var final_corner = default_corner
	if board_index > 0 and not candidates.is_empty():
		final_corner = candidates[0]["corner"]
	
	# Tier 1: Intentar generar recorriendo los candidatos válidos no superpuestos
	var generated_ok = false
	if board_index == 0:
		print("SamuraiManager [THREAD]: Generando tablero inicial (board_0)...")
		while attempts < MAX_GENERATION_ATTEMPTS:
			@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
			datos_nivel = gen.create_level({}, difficulty, variants, {}, knight_restricted_number)
			if not datos_nivel["puzzle"].is_empty():
				generated_ok = true
				print("SamuraiManager [THREAD]: board_0 generado con éxito en el intento %d" % attempts)
				break
			attempts += 1
	else:
		print("SamuraiManager [THREAD]: Iniciando Tier 1 (Variantes en candidatos válidos). Candidatos: %d" % candidates.size())
		for cand in candidates:
			var cand_corner = cand["corner"]
			var cand_pos = cand["grid_pos"]
			print("SamuraiManager [THREAD]: Probando candidato: Esquina=%s, Pos=%s" % [str(cand_corner), str(cand_pos)])
			attempts = 0
			while attempts < MAX_GENERATION_ATTEMPTS:
				@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
				datos_nivel = gen.generate_chain_next(
					previous_solution, previous_puzzle, cand_corner, difficulty, variants, knight_restricted_number
				)
				if not datos_nivel["puzzle"].is_empty():
					final_corner = cand_corner
					generated_ok = true
					print("SamuraiManager [THREAD]: Generado con éxito en Esquina=%s (intento %d)" % [str(cand_corner), attempts])
					break
				attempts += 1
			if generated_ok:
				break
			else:
				print("SamuraiManager [THREAD]: Falló candidato Esquina=%s tras %d intentos" % [str(cand_corner), MAX_GENERATION_ATTEMPTS])
				
	# Tier 2: Si falla con variantes, fallback a CLASSIC en los mismos candidatos válidos
	if not generated_ok:
		print("SamuraiManager [THREAD]: Tier 1 falló. Iniciando Tier 2 (Fallback a CLASSIC en candidatos válidos)...")
		var fallback_variants = [SudokuGenerator.VariantType.CLASSIC]
		if board_index == 0:
			attempts = 0
			while attempts < MAX_GENERATION_ATTEMPTS:
				datos_nivel = gen.create_level({}, difficulty, fallback_variants, {}, knight_restricted_number)
				if not datos_nivel["puzzle"].is_empty():
					variants = fallback_variants
					generated_ok = true
					print("SamuraiManager [THREAD]: board_0 (Classic) generado con éxito (intento %d)" % attempts)
					break
				attempts += 1
		else:
			for cand in candidates:
				var cand_corner = cand["corner"]
				var cand_pos = cand["grid_pos"]
				print("SamuraiManager [THREAD]: Probando candidato Classic: Esquina=%s, Pos=%s" % [str(cand_corner), str(cand_pos)])
				attempts = 0
				while attempts < MAX_GENERATION_ATTEMPTS:
					datos_nivel = gen.generate_chain_next(
						previous_solution, previous_puzzle, cand_corner, difficulty, fallback_variants, knight_restricted_number
					)
					if not datos_nivel["puzzle"].is_empty():
						final_corner = cand_corner
						variants = fallback_variants
						generated_ok = true
						print("SamuraiManager [THREAD]: Generado Classic con éxito en Esquina=%s (intento %d)" % [str(cand_corner), attempts])
						break
					attempts += 1
				if generated_ok:
					break
				else:
					print("SamuraiManager [THREAD]: Falló candidato Classic en Esquina=%s" % str(cand_corner))
					
	# Tier 3: Caso de emergencia (si todo falla, forzar Classic en rincón por defecto ignorando colisiones)
	if datos_nivel.is_empty() or datos_nivel["puzzle"].is_empty():
		print("SamuraiManager [THREAD]: Tier 2 falló. Iniciando Tier 3 (Emergencia: Forzar CLASSIC en rincón por defecto)...")
		attempts = 0
		var fallback_variants = [SudokuGenerator.VariantType.CLASSIC]
		while attempts < MAX_GENERATION_ATTEMPTS:
			if board_index == 0:
				datos_nivel = gen.create_level({}, difficulty, fallback_variants, {}, knight_restricted_number)
			else:
				print("SamuraiManager [THREAD]: Intentando rincón por defecto: %s" % str(default_corner))
				datos_nivel = gen.generate_chain_next(
					previous_solution, previous_puzzle, default_corner, difficulty, fallback_variants, knight_restricted_number
				)
			if not datos_nivel["puzzle"].is_empty():
				variants = fallback_variants
				final_corner = default_corner
				print("SamuraiManager [THREAD]: Emergencia exitosa en rincón por defecto: %s" % str(default_corner))
				break
			attempts += 1
		if datos_nivel.is_empty() or datos_nivel["puzzle"].is_empty():
			print("SamuraiManager [THREAD]: ¡CRÍTICO! Generación falló por completo incluso en Tier 3.")
		
	var final_grid_pos = Vector2i.ZERO
	if board_index > 0:
		var offsets = {
			SudokuGenerator.ExitCorner.TOP_RIGHT: Vector2i(1, -1),
			SudokuGenerator.ExitCorner.BOTTOM_RIGHT: Vector2i(1, 1),
			SudokuGenerator.ExitCorner.BOTTOM_LEFT: Vector2i(-1, 1),
			SudokuGenerator.ExitCorner.TOP_LEFT: Vector2i(-1, -1)
		}
		final_grid_pos = previous_grid_pos + offsets[final_corner]

	print("SamuraiManager [THREAD]: Finalizado. Esquina elegida: %s. Posición lógica elegida: %s" % [str(final_corner), str(final_grid_pos)])

	call_deferred("_on_generation_completed", {
		"board_index": board_index,
		"difficulty": difficulty,
		"variants": variants,
		"exit_corner": final_corner,
		"grid_pos": final_grid_pos,
		"datos_nivel": datos_nivel
	})

## Callback en el hilo principal cuando la generación termina
func _on_generation_completed(result: Dictionary) -> void:
	_cleanup_thread()
	
	var board_index = result["board_index"]
	var datos_nivel = result["datos_nivel"]
	var used_corner = result["exit_corner"]
	var grid_pos = result["grid_pos"]
	
	generation_finished.emit(board_index)
	
	if datos_nivel.is_empty() or datos_nivel["puzzle"].is_empty():
		push_error("SamuraiManager: La generación falló para board_%d" % board_index)
		generation_failed.emit(board_index)
		return
		
	# Actualizar las esquinas y posiciones lógicas de solape confirmadas
	if board_index > 0:
		board_exit_corners[board_index - 1] = used_corner
		if board_grid_positions.size() > board_index:
			board_grid_positions[board_index] = grid_pos
		else:
			board_grid_positions.append(grid_pos)
		print("SamuraiManager: Confirmado rincón de solape ", used_corner, " y posición de cuadrícula ", grid_pos, " para board_", board_index)
		
	_pending_board_data = result
	
	if board_index == 0:
		_stop_simulated_progress()
		if is_instance_valid(loading_panel_instance):
			loading_panel_instance.update_progress(100.0)
			loading_panel_instance.set_ready()
	
	# Verificar si podemos mostrarlo de una vez (ej. el primer board, o si ya se cumplen condiciones)
	_check_and_spawn_if_ready()

## Verifica si se cumplen las condiciones y, de ser así, spawnea el board pendiente
func _check_and_spawn_if_ready() -> void:
	if _pending_board_data.is_empty():
		return
		
	var next_idx = _pending_board_data["board_index"]
	if _should_spawn_next_board(next_idx):
		var variants = _pending_board_data["variants"]
		var difficulty = _pending_board_data["difficulty"]
		var datos_nivel = _pending_board_data["datos_nivel"]
		
		# Limpiar datos pendientes antes de instanciar para evitar re-entradas
		_pending_board_data.clear()
		
		_spawn_board_visual(next_idx, variants, difficulty, datos_nivel)

## Retorna true si se cumplen las condiciones para mostrar el nuevo board
func _should_spawn_next_board(board_index: int) -> bool:
	if board_index == 0:
		return true
		
	var prev_idx = board_index - 1
	if prev_idx >= board_ids.size():
		return false
		
	var prev_board_id = board_ids[prev_idx]
	var prev_board: Board = boards[prev_board_id]
	if not is_instance_valid(prev_board):
		return false
		
	# Condición A: El board actual debe estar al menos al 80% resuelto
	var solved_percent = prev_board.get_solved_percentage()
	if solved_percent < 0.70: #debug simplemente forzar la generacion

		return false
		
	# Condición B: La esquina de solape debe estar completamente resuelta
	#var exit_corner = _get_exit_corner(prev_idx)
	#if not _is_corner_solved(prev_board, exit_corner):
	#	return false
		
	return true

## Retorna true si las 9 celdas del sector de solape están correctamente resueltas
func _is_corner_solved(board: Board, exit_corner: int) -> bool:
	var start_x: int
	var start_y: int
	
	match exit_corner:
		SudokuGenerator.ExitCorner.TOP_RIGHT:
			start_x = 6
			start_y = 0
		SudokuGenerator.ExitCorner.BOTTOM_RIGHT:
			start_x = 6
			start_y = 6
		SudokuGenerator.ExitCorner.TOP_LEFT:
			start_x = 0
			start_y = 0
		SudokuGenerator.ExitCorner.BOTTOM_LEFT:
			start_x = 0
			start_y = 6
		_:
			return false
			
	for dx in range(3):
		for dy in range(3):
			var coords = Vector2i(start_x + dx, start_y + dy)
			var cell = board.get_cell(coords)
			if cell == null or cell.value == 0 or cell.value != cell.true_value:
				return false
	return true

## Instancia y configura visualmente el board en el SceneTree
func _spawn_board_visual(board_index: int, variants: Array, _difficulty: int, datos_nivel: Dictionary) -> void:
	var board_id = StringName("board_%d" % board_index)
	
	# Instanciar el board visual
	var board: Board = board_scene.instantiate()
	board.board_id = board_id
	board.game_mode = game_mode
	
	# Variante principal
	var primary_variant = variants[0] if not variants.is_empty() else SudokuGenerator.VariantType.CLASSIC
	board.variant_type = primary_variant
	
	# Si la variante contiene ANTI_KNIGHT, nos aseguramos de que comparta el mismo número del nivel
	if SudokuGenerator.VariantType.ANTI_KNIGHT in variants:
		if level_knight_restricted_number == 0:
			level_knight_restricted_number = randi_range(1, 9)
			print("--- NUEVO NIVEL --- El caballo del nivel tiene la restricción para el número: ", level_knight_restricted_number)
		board.knight_restricted_number = level_knight_restricted_number
		board.knight_move = true
	else:
		board.knight_move = false
		
	if SudokuGenerator.VariantType.KILLER in variants:
		board.killer = true
	if SudokuGenerator.VariantType.THERMO in variants:
		board.thermo = true
	if SudokuGenerator.VariantType.ARROW in variants:
		board.arrow = true
		
	board.cell_size = CELL_SIZE
	board.sector_gap = 0.0
	
	board_container.add_child(board)
	
	# Posicionar el board según su índice en la cadena
	board.position = _calculate_board_position(board_index)
	
	# Construir el tablero visual
	board.build_board(datos_nivel["puzzle"], datos_nivel["solution"], datos_nivel)
	
	# Conectar señales
	board.board_completed.connect(_on_board_completed)
	board.cell_changed.connect(_on_board_cell_changed)
	board.invisible_error_detected.connect(_on_board_invisible_error)
	
	# Registrar en nuestras estructuras de datos
	boards[board_id] = board
	board_solutions.append(datos_nivel["solution"])
	board_ids.append(board_id)
	
	# Vincular celdas compartidas con el board anterior
	if board_index > 0:
		var prev_board_id = board_ids[board_index - 1]
		var prev_board: Board = boards[prev_board_id]
		var exit_corner = board_exit_corners[board_index - 1]
		_link_shared_cells(prev_board, board, exit_corner)
	
	next_board_index = board_index + 1
	
	# Mover cámara suavemente hacia el nuevo board
	_update_camera_target(board.position)
	
	new_board_spawned.emit(board_id, board_index)
	
	update_knight_restricted_buttons()

	# Conectar señal de pencil_marks_changed de cada celda para el auto-guardado
	for cell in board.cells_dict.values():
		if not cell.is_fixed:
			cell.pencil_marks_changed.connect(_on_cell_pencil_changed)

	# Auto-guardar inmediato al añadir un nuevo tablero a la cadena
	if game_started:
		SaveGameManager.save_active_game(self)
	
	# Lanzar de inmediato la generación del siguiente en segundo plano
	if next_board_index < level_config.total_boards:
		var next_variants = _get_variants_for_board(next_board_index)
		var next_difficulty = _get_difficulty_for_board(next_board_index)
		_start_background_generation(next_board_index, next_variants, next_difficulty)

## Devuelve el array de variantes correspondientes para un índice de tablero
func _get_variants_for_board(board_index: int) -> Array:
	if not level_config.custom_boards.is_empty():
		var board_cfg = level_config.custom_boards[board_index]
		var combined_variants = [board_cfg.variant_type]
		for v in board_cfg.extra_variants:
			if not v in combined_variants:
				combined_variants.append(v)
		return combined_variants
		
	if board_index == 0 and not level_config.first_board_has_variants:
		return [SudokuGenerator.VariantType.CLASSIC]
		
	if level_config.is_custom:
		var pool = level_config.valid_variants.duplicate()
		pool.erase(SudokuGenerator.VariantType.CLASSIC)
		
		var pool_size = pool.size()
		if pool_size == 0:
			return [SudokuGenerator.VariantType.CLASSIC]
			
		var min_vars = max(1, pool_size / 2) # Mínimo la mitad redondeado hacia abajo, pero al menos 1
		var max_vars = pool_size
		
		# Sesgar el número de variantes para hacer más común que compartan tablero (valores más altos)
		var range_size = max_vars - min_vars
		var num_variants = min_vars
		if range_size > 0:
			var offset = int(sqrt(randf()) * (range_size + 1))
			offset = clampi(offset, 0, range_size)
			num_variants = min_vars + offset
			
		pool.shuffle()
		var selected_variants = []
		for i in range(min(num_variants, pool_size)):
			selected_variants.append(pool[i])
			
		if selected_variants.is_empty():
			return [SudokuGenerator.VariantType.CLASSIC]
		return selected_variants
		
	if level_config.progressive_complexity:
		# Interpolación para obtener el número de variantes de forma progresiva
		var t = float(board_index) / float(level_config.total_boards - 1) if level_config.total_boards > 1 else 0.0
		var current_min = int(lerp(float(level_config.min_variants_per_board), float(level_config.max_variants_per_board), t))
		var num_variants = randi_range(current_min, level_config.max_variants_per_board)
		
		if num_variants <= 0:
			return [SudokuGenerator.VariantType.CLASSIC]
			
		var pool = level_config.valid_variants.duplicate()
		pool.erase(SudokuGenerator.VariantType.CLASSIC)
		pool.shuffle()
		
		var selected_variants = []
		for i in range(min(num_variants, pool.size())):
			selected_variants.append(pool[i])
			
		if selected_variants.is_empty():
			return [SudokuGenerator.VariantType.CLASSIC]
		return selected_variants
	else:
		return [level_config.get_random_variant()]

## Devuelve la dificultad correspondiente para un índice de tablero
func _get_difficulty_for_board(board_index: int) -> int:
	if not level_config.custom_boards.is_empty():
		return level_config.custom_boards[board_index].difficulty
	if board_index == 0:
		return level_config.initial_difficulty
	return level_config.get_random_chain_difficulty()

## Handler: ejecutado cuando el jugador cambia el valor de una celda
func _on_board_cell_changed(_board_id: StringName, _coords: Vector2i, _value: int, _is_correct: bool) -> void:
	_check_and_spawn_if_ready()
	_trigger_save_debounce()

## Inicializa los rincones de salida y posiciones de cuadrícula por defecto
func _initialize_exit_corners() -> void:
	board_exit_corners.clear()
	board_grid_positions.clear()
	
	# El primer tablero siempre está en la posición central de la cuadrícula (0, 0)
	board_grid_positions.append(Vector2i.ZERO)
	
	for i in range(level_config.total_boards):
		# Inicializar exit corners por defecto en zigzag
		if i % 2 == 0:
			board_exit_corners.append(SudokuGenerator.ExitCorner.TOP_RIGHT)
		else:
			board_exit_corners.append(SudokuGenerator.ExitCorner.BOTTOM_RIGHT)
			
		# Pre-calcular posiciones estimadas
		if i > 0:
			var prev_pos = board_grid_positions[i - 1]
			var corner = board_exit_corners[i - 1]
			var offset = Vector2i(1, -1) if corner == SudokuGenerator.ExitCorner.TOP_RIGHT else Vector2i(1, 1)
			board_grid_positions.append(prev_pos + offset)

## Devuelve una lista de las esquinas de salida y posiciones candidatas no superpuestas
## Verifica si la posición del tablero no colisiona/solapa con tableros anteriores
func _is_position_valid(target_grid_pos: Vector2i, board_index: int) -> bool:
	if board_index <= 0:
		return true
	
	# No puede estar en la misma posición exacta que el tablero inmediatamente anterior
	if target_grid_pos == board_grid_positions[board_index - 1]:
		return false
		
	# Para todos los tableros anteriores (excluyendo el inmediatamente anterior con el que solapa a propósito):
	# No debe haber solapamiento físico en pantalla (es decir, la distancia en cada eje debe ser > 1)
	for i in range(board_index - 1):
		var dx = abs(target_grid_pos.x - board_grid_positions[i].x)
		var dy = abs(target_grid_pos.y - board_grid_positions[i].y)
		if dx <= 1 and dy <= 1:
			return false
			
	return true


func _get_valid_candidate_corners(board_index: int) -> Array:
	var candidates = []
	if board_index == 0:
		return candidates
		
	var curr_grid_pos = board_grid_positions[board_index - 1]
	
	var corner_offsets = {
		SudokuGenerator.ExitCorner.TOP_RIGHT: Vector2i(1, -1),
		SudokuGenerator.ExitCorner.BOTTOM_RIGHT: Vector2i(1, 1),
		SudokuGenerator.ExitCorner.BOTTOM_LEFT: Vector2i(-1, 1),
		SudokuGenerator.ExitCorner.TOP_LEFT: Vector2i(-1, -1)
	}
	
	# Orden de preferencia: mezclamos aleatoriamente para una generación libre en cualquier dirección
	var preferred_order = [
		SudokuGenerator.ExitCorner.TOP_RIGHT,
		SudokuGenerator.ExitCorner.BOTTOM_RIGHT,
		SudokuGenerator.ExitCorner.BOTTOM_LEFT,
		SudokuGenerator.ExitCorner.TOP_LEFT
	]
	preferred_order.shuffle()

	
	for corner in preferred_order:
		var target_grid_pos = curr_grid_pos + corner_offsets[corner]
		if _is_position_valid(target_grid_pos, board_index):
			candidates.append({
				"corner": corner,
				"grid_pos": target_grid_pos
			})
	return candidates

## Calcula la posición en píxeles de un board según su posición en la cuadrícula de tableros.
func _calculate_board_position(board_index: int) -> Vector2:
	if board_index >= board_grid_positions.size():
		return Vector2.ZERO
	var grid_pos = board_grid_positions[board_index]
	var x = grid_pos.x * CHAIN_OFFSET
	var y = grid_pos.y * CHAIN_OFFSET
	return Vector2(x, y)

## Determina la esquina de salida por defecto según el índice del board.
func _get_exit_corner(board_index: int) -> SudokuGenerator.ExitCorner:
	if board_index % 2 == 0:
		return SudokuGenerator.ExitCorner.TOP_RIGHT
	else:
		return SudokuGenerator.ExitCorner.BOTTOM_RIGHT

## Vincula las 9 celdas compartidas entre dos boards consecutivos.
func _link_shared_cells(prev_board: Board, new_board: Board, 
						exit_corner: SudokuGenerator.ExitCorner) -> void:
	# Determinar qué sector 3×3 se solapa en cada board
	var prev_start: Vector2i  # Esquina del sector en el board anterior (x, y)
	var new_start: Vector2i   # Esquina del sector correspondiente en el nuevo board (x, y)
	
	match exit_corner:
		SudokuGenerator.ExitCorner.TOP_RIGHT:
			prev_start = Vector2i(6, 0)
			new_start = Vector2i(0, 6)
		SudokuGenerator.ExitCorner.BOTTOM_RIGHT:
			prev_start = Vector2i(6, 6)
			new_start = Vector2i(0, 0)
		SudokuGenerator.ExitCorner.TOP_LEFT:
			prev_start = Vector2i(0, 0)
			new_start = Vector2i(6, 6)
		SudokuGenerator.ExitCorner.BOTTOM_LEFT:
			prev_start = Vector2i(0, 6)
			new_start = Vector2i(6, 0)
	
	# Vincular las 9 celdas del sector solapado
	for dx in range(3):
		for dy in range(3):
			var prev_coords = Vector2i(prev_start.x + dx, prev_start.y + dy)
			var new_coords = Vector2i(new_start.x + dx, new_start.y + dy)
			
			var prev_cell = prev_board.get_cell(prev_coords)
			var new_cell = new_board.get_cell(new_coords)
			
			if prev_cell and new_cell:
				prev_cell.link_to(new_cell)
				if prev_cell.value != 0:
					new_cell.value = prev_cell.value
					new_cell.is_fixed = prev_cell.is_fixed
					new_cell._refresh()

func _process(delta: float) -> void:
	if _game_timer and not _game_timer.is_stopped():
		_elapsed_seconds += delta

## Handler: un board fue completado
func _on_board_completed(board_id: StringName) -> void:
	completed_boards += 1
	print("Board completado: %s (%d/%d)" % [board_id, completed_boards, level_config.total_boards])
	
	if completed_boards >= level_config.total_boards:
		print("¡Nivel %d completado!" % current_level)
		level_completed.emit(current_level)

## Guarda la partida en LocalDB al completar el nivel
func _on_level_completed_save(_level_number: int) -> void:
	_game_timer.stop()
	game_started = false
	if is_instance_valid(_save_debounce_timer):
		_save_debounce_timer.stop()
	
	var modo_str = "challenge" if level_config.game_mode == Global.GameMode.CHALLENGE else "practice"
	
	var diff_str = "medio"
	match level_config.difficulty_level:
		LevelConfig.DifficultyLevel.EASY: diff_str = "facil"
		LevelConfig.DifficultyLevel.MEDIUM: diff_str = "medio"
		LevelConfig.DifficultyLevel.HARD: diff_str = "dificil"
		LevelConfig.DifficultyLevel.EXTREME: diff_str = "extremo"
		
	var active_variants = []
	for board in boards.values():
		var var_type = board.variant_type if "variant_type" in board else 0
		var var_str = "classic"
		match var_type:
			0: var_str = "classic"
			1: var_str = "anti_knight"
			2: var_str = "killer"
			3: var_str = "thermo"
			4: var_str = "arrow"
		if not var_str in active_variants:
			active_variants.append(var_str)
			
	var score: int = ScoreManager.total_score
	var tableros: int = completed_boards
	var tiempo: float = _elapsed_seconds
	var errores: int = ScoreManager.total_errors_in_game
	var ganada: bool = true
	
	AuthManager.save_and_sync_game(modo_str, diff_str, active_variants, score, tableros, tiempo, errores, ganada)
	print("Partida guardada - Score: %d | Tiempo: %.1fs | Errores: %d" % [score, _elapsed_seconds, errores])

	# Borrar el archivo de partida en curso: ya no es necesario porque el nivel terminó
	SaveGameManager.delete_save_file()

	# Instanciar y mostrar la tarjeta de partida completada
	var card_scene = load("res://scenas/Menus/PartidaCompletada.tscn")
	if card_scene:
		var card_instance = card_scene.instantiate()
		var canvas = get_node_or_null("CanvasLayer")
		if canvas:
			canvas.add_child(card_instance)
			card_instance.setup(score, errores, tiempo, tableros, rng_seed, diff_str, modo_str)
			card_instance.play_enter_animation()

## Mueve la cámara suavemente hacia la posición del nuevo board
func _update_camera_target(target_pos: Vector2) -> void:
	if camera:
		var center = target_pos + Vector2(BOARD_SIZE / 2.0, BOARD_SIZE / 2.0)
		var tween = create_tween()
		tween.tween_property(camera, "position", center, 0.5)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_CUBIC)

## Limpia de manera segura el hilo de generación activo
func _cleanup_thread() -> void:
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
	_thread = null
	is_generating = false

## Limpia todos los boards existentes
func _clear_all_boards() -> void:
	for bid in boards:
		var board: Board = boards[bid]
		if is_instance_valid(board):
			board.queue_free()
	boards.clear()
	board_solutions.clear()
	board_ids.clear()
	next_board_index = 0
	completed_boards = 0

## Limpieza al salir de la escena o destruir el nodo
func _exit_tree() -> void:
	_cleanup_thread()

func _on_board_invisible_error(coords: Vector2i, val: int) -> void:
	_on_invisible_error(coords, val)

func _on_invisible_error(_coords: Vector2i, _val: int) -> void:
	# Lógica para mostrar la ventana emergente didáctica
	print("ERROR INVISIBLE DETECTADO EN: ", _coords, " VALOR: ", _val)
	# (Aquí el usuario añadirá su nodo emergente dinámico o modal)

func _on_streak_multiplier_changed(new_streak: float) -> void:
	_update_streak_label(new_streak)

func _update_streak_label(streak: float) -> void:
	if is_instance_valid(_lbl_streak):
		_lbl_streak.text = "x%.1f" % streak #racha

func _update_hud_fonts() -> void:
	var font: Font = Global.get_current_font()
	if is_instance_valid(_lbl_streak) and _lbl_streak.label_settings:
		var ls = _lbl_streak.label_settings.duplicate()
		ls.font = font
		_lbl_streak.label_settings = ls

func _on_verify_pressed() -> void:
	var total_errors = 0
	var error_cells_by_board = {}
	
	for board_id in boards:
		var board = boards[board_id]
		error_cells_by_board[board_id] = []
		
		for coords in board.cells_dict:
			var cell = board.cells_dict[coords]
			if cell.value != 0 and cell.value != cell.true_value:
				total_errors += 1
				error_cells_by_board[board_id].append(coords)
				
	# Aplicar penalización porcentual en el ScoreManager pasando el desglose de errores
	ScoreManager.apply_challenge_validation_penalties(total_errors, error_cells_by_board)
	
	# Resaltar errores visuales en todos los tableros
	for board_id in boards:
		var board = boards[board_id]
		var errors = error_cells_by_board[board_id]
		
		board.clear_highlights()
		
		for coords in board.cells_dict:
			var cell = board.cells_dict[coords]
			if errors.has(coords):
				cell.highlight_cell_state(true, false)

func get_active_board() -> Board:
	if Global._previus_cell and is_instance_valid(Global._previus_cell) and Global._previus_cell.board:
		return Global._previus_cell.board
	# Fallback al último board instanciado si existe
	if not board_ids.is_empty():
		var last_id = board_ids.back()
		if boards.has(last_id) and is_instance_valid(boards[last_id]):
			return boards[last_id]
	return null

func update_knight_restricted_buttons() -> void:
	var has_anti_knight = false
	var restricted_num = 0
	var active_board = get_active_board()
	if active_board:
		has_anti_knight = active_board.knight_move
		restricted_num = active_board.knight_restricted_number

	for i in range(_num_buttons.size()):
		var btn = _num_buttons[i]
		if is_instance_valid(btn):
			var is_restricted = has_anti_knight and (restricted_num == (i + 1))
			if btn.has_method("set_knight_visible"):
				btn.set_knight_visible(is_restricted)
			else:
				var knight_node = btn.get_node_or_null("knight")
				if knight_node:
					knight_node.visible = is_restricted


# ── Auto-Guardado con Debounce ─────────────────────────────────────────────────

## Reinicia el temporizador de debounce de guardado. Si ya está corriendo, lo reinicia.
func _trigger_save_debounce() -> void:
	if not game_started:
		return
	if is_instance_valid(_save_debounce_timer):
		_save_debounce_timer.wait_time = save_debounce_time
		_save_debounce_timer.start()


## Llamado cuando el debounce expira: ejecuta el guardado real en disco.
func _on_save_debounce_timeout() -> void:
	if not boards.is_empty():
		SaveGameManager.save_active_game(self)


## Handler de pencil_marks_changed: dispara el debounce de guardado.
func _on_cell_pencil_changed(_coords: Vector2i, _number: int, _is_visible: bool) -> void:
	_trigger_save_debounce()


# ── Reanudación de Partida ─────────────────────────────────────────────────────

## Rehidrata el nivel completo desde los datos del archivo de guardado.
## Se llama desde _ready() si Global.active_save_to_resume no está vacío.
func resume_level(save_data: Dictionary) -> void:
	_cleanup_thread()
	_clear_all_boards()
	ScoreManager.reset()

	# ── 1. Restaurar variables de estado general ──────────────────────────────
	rng_seed                       = save_data.get("rng_seed", 0)
	current_level                  = save_data.get("current_level", 1)
	_elapsed_seconds               = save_data.get("elapsed_seconds", 0.0)
	level_knight_restricted_number = save_data.get("level_knight_restricted_number", 0)
	next_board_index               = save_data.get("next_board_index", 0)
	completed_boards               = save_data.get("completed_boards", 0)
	game_mode                      = save_data.get("game_mode", Global.GameMode.PRACTICE) as Global.GameMode

	if rng_seed != 0:
		seed(rng_seed)

	# ── 2. Restaurar configuración de nivel ───────────────────────────────────
	var lc_data: Dictionary = save_data.get("level_config", {})
	if not lc_data.is_empty():
		var res_path: String = lc_data.get("resource_path", "")
		if res_path != "" and ResourceLoader.exists(res_path):
			level_config = load(res_path)
		else:
			# Reconstruir LevelConfig desde los datos serializados
			level_config = LevelConfig.new()
			level_config.total_boards             = lc_data.get("total_boards", 3)
			level_config.initial_difficulty        = lc_data.get("initial_difficulty", 3)
			var cr: Array                          = lc_data.get("chain_difficulty_range", [3, 50])
			level_config.chain_difficulty_range    = Vector2i(cr[0], cr[1])
			level_config.difficulty_level          = lc_data.get("difficulty_level", 0) as LevelConfig.DifficultyLevel
			level_config.game_mode                 = lc_data.get("game_mode", 0) as Global.GameMode
			level_config.is_custom                 = lc_data.get("is_custom", false)
			var vv_raw = lc_data.get("valid_variants", [0])
			var vv: Array[int] = []
			vv.assign(vv_raw)
			level_config.valid_variants            = vv
			level_config.first_board_has_variants  = lc_data.get("first_board_has_variants", false)
			level_config.progressive_complexity    = lc_data.get("progressive_complexity", true)
			level_config.min_variants_per_board    = lc_data.get("min_variants_per_board", 0)
			level_config.max_variants_per_board    = lc_data.get("max_variants_per_board", 1)

	# ── 3. Restaurar geometría de la cadena ───────────────────────────────────
	board_exit_corners.clear()
	for c in save_data.get("board_exit_corners", []):
		board_exit_corners.append(c as SudokuGenerator.ExitCorner)

	board_grid_positions.clear()
	for gp in save_data.get("board_grid_positions", []):
		board_grid_positions.append(Vector2i(gp[0], gp[1]))

	# ── 4. Hidratar ScoreManager ──────────────────────────────────────────────
	var score_data: Dictionary = save_data.get("score_manager", {})
	if not score_data.is_empty():
		ScoreManager.hydrate_state(score_data)

	# ── 5. Reconstruir cada tablero ───────────────────────────────────────────
	var boards_state: Array = save_data.get("boards_state", [])
	for i in range(boards_state.size()):
		var bdata: Dictionary = boards_state[i]

		# Deserializar solución y puzzle (strings "x,y" → Vector2i)
		var solution: Dictionary = {}
		for key in bdata.get("solution", {}):
			var parts: PackedStringArray = (key as String).split(",")
			solution[Vector2i(int(parts[0]), int(parts[1]))] = bdata["solution"][key]

		var puzzle: Dictionary = {}
		for key in bdata.get("puzzle", {}):
			var parts: PackedStringArray = (key as String).split(",")
			puzzle[Vector2i(int(parts[0]), int(parts[1]))] = bdata["puzzle"][key]

		# Deserializar extra_data (restricciones de variantes)
		var ed_raw: Dictionary = bdata.get("extra_data", {})
		var extra_data := {
			"killer_cages":              _deserialize_killer(ed_raw.get("killer_cages", [])),
			"thermo_chains":             _deserialize_thermo(ed_raw.get("thermo_chains", [])),
			"arrow_constraints":         _deserialize_arrows(ed_raw.get("arrow_constraints", [])),
			"knight_restricted_number":  bdata.get("knight_restricted_number", 0),
		}

		# Instanciar y configurar el Board
		var board_id := StringName(bdata.get("board_id", "board_%d" % i))
		var board: Board = board_scene.instantiate()
		board.board_id   = board_id
		board.game_mode  = game_mode

		var v_type: int = bdata.get("variant_type", 0)
		board.variant_type = v_type
		if v_type == SudokuGenerator.VariantType.ANTI_KNIGHT:
			board.knight_move = true
			board.knight_restricted_number = bdata.get("knight_restricted_number", 0)
		elif v_type == SudokuGenerator.VariantType.KILLER:
			board.killer = true
		elif v_type == SudokuGenerator.VariantType.THERMO:
			board.thermo = true
		elif v_type == SudokuGenerator.VariantType.ARROW:
			board.arrow = true

		board.cell_size   = CELL_SIZE
		board.sector_gap  = 0.0

		board_container.add_child(board)
		board.position = _calculate_board_position(i)
		board.build_board(puzzle, solution, extra_data)

		# Conectar señales del tablero
		board.board_completed.connect(_on_board_completed)
		board.cell_changed.connect(_on_board_cell_changed)
		board.invisible_error_detected.connect(_on_board_invisible_error)

		# Registrar en las estructuras de datos internas
		boards[board_id]    = board
		board_solutions.append(solution)
		board_ids.append(board_id)

		# Restaurar el estado de las celdas del jugador (valores, notas de lápiz, errores)
		var cells_player: Dictionary = bdata.get("cells_player_state", {})
		for coord_str in cells_player:
			var parts: PackedStringArray = (coord_str as String).split(",")
			var coords := Vector2i(int(parts[0]), int(parts[1]))
			var cell_data: Dictionary = cells_player[coord_str]
			var cell: CellUI = board.get_cell(coords)
			if cell == null or cell.is_fixed:
				continue

			cell.value             = cell_data.get("value", 0)
			cell.mistake_count     = cell_data.get("mistake_count", 0)
			cell.has_been_incorrect = cell_data.get("has_been_incorrect", false)

			# Restaurar marcas de lápiz
			var marks: Array = cell_data.get("pencil_marks", [])
			for m in range(min(marks.size(), cell.pencil_labels.size())):
				if is_instance_valid(cell.pencil_labels[m]):
					cell.pencil_labels[m].visible = marks[m]

			# Refrescar visual de la celda
			cell._refresh()

		# Conectar pencil_marks_changed para el auto-guardado continuo
		for cell in board.cells_dict.values():
			if not cell.is_fixed:
				cell.pencil_marks_changed.connect(_on_cell_pencil_changed)

		# Vincular celdas compartidas con el tablero anterior
		if i > 0:
			var prev_id := board_ids[i - 1]
			var prev_board: Board = boards[prev_id]
			var corner := board_exit_corners[i - 1]
			_link_shared_cells(prev_board, board, corner)

		ScoreManager.register_manager(self)
		new_board_spawned.emit(board_id, i)

	# ── 6. Posicionar cámara en el último tablero ─────────────────────────────
	if not board_ids.is_empty():
		var last_board: Board = boards[board_ids.back()]
		if is_instance_valid(last_board):
			_update_camera_target(last_board.position)

	update_knight_restricted_buttons()

	# ── 7. Activar temporizador del juego ─────────────────────────────────────
	game_started = true
	if _game_timer:
		_game_timer.start()

	print("SamuraiManager: Partida reanudada. Tableros: %d | Tiempo previo: %.1fs" % [boards.size(), _elapsed_seconds])


# ── Deserialización de variantes ───────────────────────────────────────────────

func _deserialize_thermo(chains_raw: Array) -> Array:
	var result := []
	for chain_raw in chains_raw:
		var chain := []
		for pt in chain_raw:
			if pt is String:
				var s: String = pt.replace("Vector2i", "").replace("(", "").replace(")", "").replace(" ", "")
				var parts: PackedStringArray = s.split(",")
				if parts.size() == 2:
					chain.append(Vector2i(int(parts[0]), int(parts[1])))
			elif pt is Array and pt.size() == 2:
				chain.append(Vector2i(int(pt[0]), int(pt[1])))
		result.append(chain)
	return result


func _deserialize_arrows(constraints_raw: Array) -> Array:
	var result := []
	for c in constraints_raw:
		var circle_raw = c.get("circle", [0, 0])
		var circle: Vector2i
		if circle_raw is String:
			var s: String = circle_raw.replace("Vector2i", "").replace("(", "").replace(")", "").replace(" ", "")
			var parts: PackedStringArray = s.split(",")
			if parts.size() == 2:
				circle = Vector2i(int(parts[0]), int(parts[1]))
		elif circle_raw is Array and circle_raw.size() == 2:
			circle = Vector2i(int(circle_raw[0]), int(circle_raw[1]))
		
		var shaft := []
		for pt in c.get("shaft", []):
			if pt is String:
				var s: String = pt.replace("Vector2i", "").replace("(", "").replace(")", "").replace(" ", "")
				var parts: PackedStringArray = s.split(",")
				if parts.size() == 2:
					shaft.append(Vector2i(int(parts[0]), int(parts[1])))
			elif pt is Array and pt.size() == 2:
				shaft.append(Vector2i(int(pt[0]), int(pt[1])))
				
		result.append({
			"circle": circle,
			"shaft":  shaft,
		})
	return result


func _deserialize_killer(cages_raw: Array) -> Array:
	var result := []
	for cage_raw in cages_raw:
		var cells := []
		for pt in cage_raw.get("cells", []):
			if pt is String:
				var s: String = pt.replace("Vector2i", "").replace("(", "").replace(")", "").replace(" ", "")
				var parts: PackedStringArray = s.split(",")
				if parts.size() == 2:
					cells.append(Vector2i(int(parts[0]), int(parts[1])))
			elif pt is Array and pt.size() == 2:
				cells.append(Vector2i(int(pt[0]), int(pt[1])))
		result.append({
			"sum": cage_raw.get("sum", 0),
			"cells": cells,
		})
	return result
