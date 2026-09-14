extends Node2D
var solucion: Dictionary
func _build_matrix() -> void:
	print("--- INICIANDO PRUEBA DE SUDOKU ---")
	
	# 1. Creamos el tablero de prueba en el formato correcto {Vector2i: int}
	# El 0 representa las casillas vacías.
	var tablero_matriz = [
  [0, 0, 5, 3, 0, 0, 0, 0, 0],
  [8, 0, 0, 0, 0, 0, 0, 2, 0],
  [0, 7, 0, 0, 1, 0, 5, 0, 0],
  [4, 0, 0, 0, 0, 5, 3, 0, 0],
  [0, 1, 0, 0, 7, 0, 0, 0, 6],
  [0, 0, 3, 2, 0, 0, 0, 8, 0],
  [0, 6, 0, 5, 0, 0, 0, 0, 9],
  [0, 0, 4, 0, 0, 0, 0, 3, 0],
  [0, 0, 0, 0, 0, 9, 7, 0, 0]
]
	# Convertimos la matriz tradicional a nuestro formato de diccionario con Vector2i
	var puzzle_inicial: Dictionary = {}
	for r in range(9):
		for c in range(9):
			puzzle_inicial[Vector2i(r, c)] = tablero_matriz[r][c]
	
	# 2. Instanciamos el motor lógico
	var solver = SudokuLogic.new()
	
	# 3. Ejecutamos el algoritmo y medimos el tiempo (en microsegundos)
	var tiempo_inicio = Time.get_ticks_usec()
	solucion = solver.solve(puzzle_inicial)
	var tiempo_fin = Time.get_ticks_usec()
	
	# 4. Mostramos el resultado en la consola de Godot
	if not solucion.is_empty():
		var tiempo_total_ms = (tiempo_fin - tiempo_inicio) / 1000.0
		print("¡Sudoku Resuelto con éxito en ", tiempo_total_ms, " ms!")
		_imprimir_tablero_consola()
	else:
		print("Error: Este Sudoku no tiene solución válida o el algoritmo falló.")

## Función auxiliar para dibujar el Sudoku bonito en la consola
func _imprimir_tablero_consola() -> void:
	print("-----------------------------")
	for r in range(9):
		var fila_texto = ""
		for c in range(9):
			var coord = Vector2i(r, c)
			fila_texto += " " + str(solucion[coord]) + " "
			
			# Líneas divisorias verticales de bloques 3x3
			if (c + 1) % 3 == 0 and c < 8:
				fila_texto += "|"
		print(fila_texto)
		
		# Líneas divisorias horizontales de bloques 3x3
		if (r + 1) % 3 == 0 and r < 8:
			print("---------+---------+---------")
	print("-----------------------------")
	board_ready()

func board_ready() -> Dictionary:
	return solucion
