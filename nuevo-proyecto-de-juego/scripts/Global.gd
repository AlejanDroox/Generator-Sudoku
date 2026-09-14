extends Node

enum GameMode { PRACTICE, CHALLENGE }

const RANGE_DIFICULTY = {
	10: 'dificil'
}
var _previus_cell: CellUI
var pencil_mode_active: bool = false
var active_number: int = -1

## Si true, se usa una fuente neutra (sans-serif del sistema) para los números del juego
var use_neutral_font: bool = false:
	set(val):
		use_neutral_font = val
		_save_settings()
		font_changed.emit(val)

## Señal emitida cuando cambia la preferencia de fuente
signal font_changed(use_neutral: bool)

## Si true, se usa una fuente neutra en el tutorial de como jugar
var use_neutral_tutorial_font: bool = false:
	set(val):
		use_neutral_tutorial_font = val
		_save_settings()
		tutorial_font_changed.emit(val)

## Señal emitida cuando cambia la preferencia de fuente del tutorial
signal tutorial_font_changed(use_neutral: bool)

## Configuración dinámica de nivel configurada desde la UI
var custom_level_config: LevelConfig = null

## Datos del guardado activo para reanudar la partida (vacío si no hay nada que reanudar).
var active_save_to_resume: Dictionary = {}

## Identificador del board que tiene el foco actualmente
var current_board_id: StringName = &""

signal cell_focus_changed(cell: CellUI)

const _SETTINGS_PATH = "user://settings.cfg"
const _SHONEN_FONT_PATH = "res://extra/fuentes/ShonenPunk custom bold.ttf"

func _ready() -> void:
	_load_settings()

## Devuelve la fuente activa según la preferencia actual.
func get_current_font() -> Font:
	if use_neutral_font:
		var sf = SystemFont.new()
		sf.font_names = PackedStringArray(["Arial", "Helvetica", "sans-serif", "Segoe UI"])
		return sf
	return load(_SHONEN_FONT_PATH)

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("display", "use_neutral_font", use_neutral_font)
	cfg.set_value("display", "use_neutral_tutorial_font", use_neutral_tutorial_font)
	cfg.save(_SETTINGS_PATH)

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) == OK:
		use_neutral_font = cfg.get_value("display", "use_neutral_font", false)
		use_neutral_tutorial_font = cfg.get_value("display", "use_neutral_tutorial_font", false)

func change_focus(current: CellUI):
	if _previus_cell == current:
		# Si se vuelve a presionar la celda ya seleccionada, se deselecciona
		if _previus_cell:
			_previus_cell.animted_sprite.visible = false
			_previus_cell.animted_sprite.stop()
		_previus_cell = null
		current_board_id = &""
	else:
		if _previus_cell:
			_previus_cell.animted_sprite.visible = false
			_previus_cell.animted_sprite.stop()
		_previus_cell = current
		if current:
			current_board_id = current.board_id
		else:
			current_board_id = &""
	
	cell_focus_changed.emit(_previus_cell)
