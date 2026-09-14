extends Control

func _draw() -> void:
	var grid = get_node_or_null("../Grid")
	if not grid:
		return
		
	# Queremos dibujar la flecha en la fila del medio (Panel4, Panel5, Panel6)
	# que corresponden a los índices 3, 4, 5
	var panels = []
	for child in grid.get_children():
		if child is Panel:
			panels.append(child)
			
	if panels.size() < 6:
		return
		
	# Obtener los centros locales de las celdas en el espacio de coordenadas de Overlay
	var grid_pos = grid.position
	var p1 = grid_pos + panels[3].position + panels[3].size / 2.0  # Círculo
	var p2 = grid_pos + panels[4].position + panels[4].size / 2.0  # Cuerpo
	var p3 = grid_pos + panels[5].position + panels[5].size / 2.0  # Punta
	
	# Usar colores y proporciones idénticas al del juego (tablero_v_3.gd)
	var arrow_color = Color(0.1, 0.5, 0.8, 0.6)
	var cell_size = panels[3].size.x
	
	# Dibujar el círculo
	draw_arc(p1, cell_size * 0.35, 0, TAU, 32, arrow_color, 4.0, true)
	
	# Dibujar el cuerpo de la flecha
	draw_line(p1, p2, arrow_color, 4.0, true)
	draw_line(p2, p3, arrow_color, 4.0, true)
	
	# Dibujar la punta de flecha en el extremo p3
	var direction = (p3 - p2).normalized()
	var arrow_head_size = cell_size * 0.25
	var left_wing = p3 - direction.rotated(PI / 6) * arrow_head_size
	var right_wing = p3 - direction.rotated(-PI / 6) * arrow_head_size
	
	draw_line(p3, left_wing, arrow_color, 4.0, true)
	draw_line(p3, right_wing, arrow_color, 4.0, true)
