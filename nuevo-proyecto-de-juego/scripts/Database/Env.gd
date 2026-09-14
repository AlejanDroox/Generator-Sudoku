class_name Env
extends RefCounted
## Env — Gestor de configuración y variables de entorno para Supabase y Servicios.
##
## Permite desacoplar las credenciales del código fuente para facilitar la
## reutilización en proyectos Open Source y despliegues en itch.io.
##
## Prioridad de carga:
##   1. Variables de entorno del sistema (SUPABASE_URL, SUPABASE_ANON_KEY).
##   2. Archivo de configuración local 'user://env.cfg' (si existe).
##   3. Valores de respaldo (Default Instance).

# ── Valores por Defecto (Instancia de Producción / Desarrollo) ─────────
const DEFAULT_SUPABASE_URL: String = "https://rwuypczmdedlofghkpeh.supabase.co"
const DEFAULT_ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ3dXlwY3ptZGVkbG9mZ2hrcGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2NjI5NTksImV4cCI6MjA5NzIzODk1OX0.VyoHSsw8Bfb0hbW17DEVmIlgQBCrmgdYmHX6Ppk2WtY"

## Obtiene la URL base de Supabase.
static func get_supabase_url() -> String:
	var env_url = OS.get_environment("SUPABASE_URL")
	if not env_url.is_empty():
		return env_url
	
	var cfg_url = _read_cfg_value("SUPABASE_URL")
	if not cfg_url.is_empty():
		return cfg_url
		
	return DEFAULT_SUPABASE_URL

## Obtiene la clave pública anónima (ANON_KEY) de Supabase.
static func get_supabase_anon_key() -> String:
	var env_key = OS.get_environment("SUPABASE_ANON_KEY")
	if not env_key.is_empty():
		return env_key
		
	var cfg_key = _read_cfg_value("SUPABASE_ANON_KEY")
	if not cfg_key.is_empty():
		return cfg_key
		
	return DEFAULT_ANON_KEY

## Lógica auxiliar para leer llaves desde user://env.cfg si el desarrollador decide crearlo.
static func _read_cfg_value(key_name: String) -> String:
	var config_file = ConfigFile.new()
	var err = config_file.load("user://env.cfg")
	if err == OK:
		return config_file.get_value("supabase", key_name, "")
	return ""
