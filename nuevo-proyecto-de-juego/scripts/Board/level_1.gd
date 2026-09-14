extends Node2D

var generator: SudokuGenerator
var mapa_solucion_secreta: Dictionary = {}

@onready var tablero_visual = $BoardV3

func _ready() -> void:
	
	generator = SudokuGenerator.new()
	iniciar_nuevo_piso()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var clave = event.keycode
		# Verificar si es una tecla numérica (número principal del teclado)
		if clave >= KEY_0 and clave <= KEY_9:
			#print("Tecleaste el número: ", OS.get_keycode_string(clave))
			var numero = clave - KEY_0  # Convertir a entero (0-9)
			#print("Número entero: ", numero)
			if Global._previus_cell:
				if Global.pencil_mode_active:
					Global._previus_cell.toggle_pencil_mark(numero)
				else:
					Global._previus_cell.verify_number(numero)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			Global.pencil_mode_active = not Global.pencil_mode_active
			get_viewport().set_input_as_handled()
func iniciar_nuevo_piso() -> void:
	var tiempo_inicio = Time.get_ticks_msec()
	# 1. Mandamos a generar el nivel empaquetado
	@warning_ignore("int_as_enum_without_cast", "int_as_enum_without_match")
	var datos_nivel = generator.create_level({}, 10)
	
	# 2. Guardamos la solución en el "Nivel" para cuando el jugador intente escribir
	mapa_solucion_secreta = datos_nivel["solution"]
	
	# 3. Le pasamos únicamente el tablero con las pistas ("puzzles") a la vista
	# Las casillas que el generador borró irán con valor 0 y se pintarán vacías automáticamente
	tablero_visual.build_board(datos_nivel["puzzle"], datos_nivel["solution"], datos_nivel)
	var tiempo_total = Time.get_ticks_msec() - tiempo_inicio
	print("Tiempo de ejecución: ", tiempo_total, " ms")
