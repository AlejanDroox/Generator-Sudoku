extends Resource
class_name BoardConfig

## Variante principal del tablero
@export var variant_type: SudokuGenerator.VariantType = SudokuGenerator.VariantType.CLASSIC

## Variantes adicionales combinadas (excluyendo la principal)
@export var extra_variants: Array[SudokuGenerator.VariantType] = []

## Dificultad para este tablero (0 a 100)
@export var difficulty: int = 10

## Restricciones personalizadas (se usan si se rellenan en modo manual)
## Array de jaulas. Cada jaula = { "sum": int, "cells": Array[Vector2i] }
@export var killer_cages: Array[Dictionary] = []

## Array de termómetros. Cada termómetro = Array[Vector2i]
@export var thermo_chains: Array = []

## Array de flechas. Cada flecha = { "circle": Vector2i, "shaft": Array[Vector2i] }
@export var arrow_constraints: Array[Dictionary] = []
