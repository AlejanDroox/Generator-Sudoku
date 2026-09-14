extends Camera2D

@export var zoom_speed: float = 0.05
@export var pan_speed: float = 1.5
@export var rotation_speed: float = 0.02

@export var can_zoom: bool = true
@export var can_pan: bool = true
@export var can_rotation: bool = true

@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0

var touch_points: Dictionary = {}
var start_distance: float = 0.0
var start_zoom: Vector2
var start_angle: float = 0.0
var start_rotation: float = 0.0
var is_mouse_dragging: bool = false

func _ready():
	# Asegurar que la cámara está activa
	# Configurar procesamiento de input
	set_process_input(true)

func _input(event):
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_mouse_dragging = true
			else:
				is_mouse_dragging = false
		elif event.pressed and can_zoom:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var new_zoom = zoom + Vector2(zoom_speed, zoom_speed)
				zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
				zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var new_zoom = zoom - Vector2(zoom_speed, zoom_speed)
				zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
				zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	elif event is InputEventMouseMotion and is_mouse_dragging:
		if can_pan:
			position -= event.relative * pan_speed / zoom.x

func handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		# Dedo toca la pantalla
		touch_points[event.index] = event.position
	else:
		# Dedo levanta
		touch_points.erase(event.index)
	
	# Cuando tenemos exactamente 2 puntos, guardamos valores iniciales
	if touch_points.size() == 2:
		var points = touch_points.values()
		start_distance = points[0].distance_to(points[1])
		start_zoom = zoom
		
		if can_rotation:
			start_angle = points[0].angle_to_point(points[1])
			start_rotation = rotation
	else:
		# Resetear valores cuando no hay 2 dedos
		start_distance = 0.0
		start_angle = 0.0

func handle_drag(event: InputEventScreenDrag):
	# Actualizar la posición del punto táctil
	touch_points[event.index] = event.position
	
	match touch_points.size():
		1:  # Un dedo - Pan (mover cámara)
			if can_pan:
				position -= event.relative * pan_speed / zoom.x
		
		2:  # Dos dedos - Zoom y/o Rotación
			var points = touch_points.values()
			var current_distance = points[0].distance_to(points[1])
			
			# Zoom con dos dedos
			if can_zoom and start_distance > 0:
				var zoom_factor = current_distance / start_distance
				var new_zoom = start_zoom * zoom_factor
				
				# Limitar zoom
				new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
				new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
				
				zoom = new_zoom
			
			# Rotación con dos dedos (opcional)
			if can_rotation:
				var current_angle = points[0].angle_to_point(points[1])
				var rotation_delta = current_angle - start_angle
				rotation = start_rotation + rotation_delta

func _process(delta):
	# Opcional: Límites de la cámara si los necesitas
	# limit_camera_movement()
	pass

func limit_camera_movement():
	# Función opcional para limitar el movimiento de la cámara
	# Ejemplo: limitar a un área específica
	var map_limits = Rect2(-500, -500, 1000, 1000)
	position.x = clamp(position.x, map_limits.position.x, map_limits.position.x + map_limits.size.x)
	position.y = clamp(position.y, map_limits.position.y, map_limits.position.y + map_limits.size.y)

func reset_camera():
	# Función para resetear la cámara a sus valores iniciales
	position = Vector2.ZERO
	zoom = Vector2.ONE
	rotation = 0.0
	touch_points.clear()
	start_distance = 0.0
