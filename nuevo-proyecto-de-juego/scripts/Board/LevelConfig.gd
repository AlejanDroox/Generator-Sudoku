extends Resource
class_name LevelConfig

## Configuración de un nivel del juego.
## Define cuántos sudokus hay que completar y qué variantes están disponibles.

enum DifficultyLevel { EASY, MEDIUM, HARD, EXTREME }

@export_group("General")
## Nivel de dificultad preconfigurado para la UI
@export var difficulty_level: DifficultyLevel = DifficultyLevel.MEDIUM

## Si es true, este nivel fue configurado a medida por el usuario (Modo Personalizado)
@export var is_custom: bool = false

## Modo de juego
@export var game_mode: Global.GameMode = Global.GameMode.PRACTICE

## Semilla personalizada para el generador aleatorio. Si es 0, es aleatoria.
@export var custom_rng_seed: int = 0

## Número total de sudokus a completar en este nivel
@export var total_boards: int = 3

## Dificultad para el primer board (central/inicial)
@export var initial_difficulty: int = 3

## Rango de dificultad para los boards subsiguientes [min, max]
@export var chain_difficulty_range: Vector2i = Vector2i(3, 50)

## Si es true, el primer tablero del nivel también puede contener variantes
@export var first_board_has_variants: bool = false


@export_group("Modo Procedimental Complejo")
## Si es true, la complejidad del nivel (cantidad de variantes) aumenta progresivamente
@export var progressive_complexity: bool = true

## Cantidad mínima de variantes por tablero (excluyendo el primero)
@export var min_variants_per_board: int = 0

## Cantidad máxima de variantes por tablero
@export var max_variants_per_board: int = 1

## Pool de variantes válidas para este nivel (índices del enum VariantType)
## 0=CLASSIC, 1=ANTI_KNIGHT, 2=KILLER, 3=THERMO, 4=ARROW
@export var valid_variants: Array[int] = [0]  # [CLASSIC]

@export_group("Modo Manual (Maquetado)")
## Lista opcional de tableros preconfigurados.
## Si contiene elementos, se usarán estos tableros fijos en lugar de la generación aleatoria.
@export var custom_boards: Array[BoardConfig] = []


## Devuelve una variante aleatoria del pool de variantes válidas
func get_random_variant() -> int:
	if valid_variants.is_empty():
		return 0  # CLASSIC
	return valid_variants[randi() % valid_variants.size()]

## Devuelve una dificultad aleatoria dentro del rango configurado
func get_random_chain_difficulty() -> int:
	return randi_range(chain_difficulty_range.x, chain_difficulty_range.y)

## Aplica los rangos de dificultad interna (initial_difficulty y chain_difficulty_range)
## basados en el nivel de dificultad seleccionado (difficulty_level).
func apply_difficulty_level() -> void:
	match difficulty_level:
		DifficultyLevel.EASY:
			initial_difficulty = 2
			chain_difficulty_range = Vector2i(0, 2)
		DifficultyLevel.MEDIUM:
			initial_difficulty = 15
			chain_difficulty_range = Vector2i(3, 40)
		DifficultyLevel.HARD:
			initial_difficulty = 60
			chain_difficulty_range = Vector2i(50, 99)
		DifficultyLevel.EXTREME:
			initial_difficulty = 150
			chain_difficulty_range = Vector2i(100, 250)
