extends Control

func _draw() -> void:
	var grid = get_node_or_null("../Grid")
	if not grid:
		return
		
	# Queremos dibujar el termómetro en las celdas de la fila del medio (Panel4, Panel5, Panel6)
	# que corresponden a los índices 3, 4, 5
	var panels = []
	for child in grid.get_children():
		if child is Panel:
			panels.append(child)
			
	if panels.size() < 6:
		return
		
	# Obtener los centros locales de las celdas en el espacio de coordenadas de Overlay
	var grid_pos = grid.position
	var p1 = grid_pos + panels[3].position + panels[3].size / 2.0
	var p2 = grid_pos + panels[4].position + panels[4].size / 2.0
	var p3 = grid_pos + panels[5].position + panels[5].size / 2.0
	
	# Usar colores y proporciones idénticas al del juego (tablero_v_3.gd)
	var thermo_color = Color(0.7, 0.7, 0.7, 0.45)
	var cell_size = panels[3].size.x
	
	# Dibujar el tubo (ancho 0.2 * cell_size)
	draw_line(p1, p2, thermo_color, cell_size * 0.2, true)
	draw_line(p2, p3, thermo_color, cell_size * 0.2, true)
	
	# Dibujar la bombilla (radio 0.35 * cell_size)
	draw_circle(p1, cell_size * 0.35, thermo_color)
