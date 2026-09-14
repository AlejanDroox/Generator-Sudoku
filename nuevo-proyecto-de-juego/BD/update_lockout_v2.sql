-- =============================================================================
-- MIGRACIÓN: PROTECCIÓN CONTRA FUERZA BRUTA (RATE LIMIT / LOCKOUT)
-- Plataforma Educativa Sudoku Samurai++
-- =============================================================================
-- Instrucciones: Ejecutar este script completo en el SQL Editor de Supabase.
-- Agrega columnas de control e implementa bloqueo temporal en login_estudiante.

-- 1. Agregar columnas para control de intentos a la tabla 'estudiantes'
ALTER TABLE public.estudiantes ADD COLUMN IF NOT EXISTS intentos_fallidos INT DEFAULT 0;
ALTER TABLE public.estudiantes ADD COLUMN IF NOT EXISTS bloqueado_hasta TIMESTAMP WITH TIME ZONE;

-- 2. Recrear la función login_estudiante para incorporar el bloqueo temporal
CREATE OR REPLACE FUNCTION public.login_estudiante(
    p_usuario   TEXT,
    p_pin       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_est           public.estudiantes%ROWTYPE;
    v_token     UUID;
    v_expires   TIMESTAMP WITH TIME ZONE;
    v_bloqueo_min INT := 1; -- Duración del bloqueo temporal en minutos (ajustable)
    v_max_intentos INT := 5; -- Intentos fallidos máximos antes de aplicar el bloqueo
BEGIN
    -- Validación de formato de PIN en capa de aplicación (coincide con check del cliente)
    IF p_pin !~ '^[0-9]{6}$' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Formato de PIN inválido.');
    END IF;

    -- Buscar estudiante por usuario. Consulta parametrizada.
    SELECT * INTO v_est
    FROM   public.estudiantes
    WHERE  usuario = p_usuario;

    -- Si no existe, retornamos error genérico de credenciales incorrectas para evitar enumeración de usuarios
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Credenciales incorrectas.');
    END IF;

    -- Verificar si la cuenta está bloqueada temporalmente
    IF v_est.bloqueado_hasta IS NOT NULL AND v_est.bloqueado_hasta > now() THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Cuenta bloqueada temporalmente por demasiados intentos. Inténtalo de nuevo más tarde.',
            'bloqueado', true
        );
    END IF;

    -- Comparación del PIN como texto literal
    IF v_est.pin <> p_pin THEN
        -- Incrementar intentos fallidos
        UPDATE public.estudiantes
        SET intentos_fallidos = COALESCE(intentos_fallidos, 0) + 1,
            bloqueado_hasta = CASE 
                WHEN COALESCE(intentos_fallidos, 0) + 1 >= v_max_intentos THEN now() + (v_bloqueo_min || ' minute')::INTERVAL 
                ELSE NULL 
            END
        WHERE id = v_est.id;

        IF COALESCE(v_est.intentos_fallidos, 0) + 1 >= v_max_intentos THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Demasiados intentos incorrectos. Cuenta bloqueada por 1 minuto.',
                'bloqueado', true
            );
        ELSE
            -- Retornamos el mensaje genérico estándar. La cuenta regresiva se gestiona del lado del cliente.
            RETURN jsonb_build_object('success', false, 'error', 'Credenciales incorrectas.');
        END IF;
    END IF;

    -- Si las credenciales son correctas, resetear contador de intentos y bloqueo
    UPDATE public.estudiantes
    SET intentos_fallidos = 0,
        bloqueado_hasta = NULL
    WHERE id = v_est.id;

    -- Generar token criptográficamente seguro
    v_token   := gen_random_uuid();
    v_expires := now() + INTERVAL '24 hours';

    -- Registrar sesión activa
    INSERT INTO public.sesiones_estudiantes (estudiante_id, token, expires_at)
    VALUES (v_est.id, v_token, v_expires);

    -- Devolver datos completos al cliente (incluye estadísticas de nube para sincronizar)
    RETURN jsonb_build_object(
        'success',       true,
        'student_id',    v_est.id,
        'usuario',       v_est.usuario,
        'grupo_id',      v_est.grupo_id,
        'session_token', v_token,
        'expires_at',    v_expires,
        'estadisticas',  v_est.estadisticas
    );
END;
$$;

COMMENT ON FUNCTION public.login_estudiante(TEXT, TEXT) IS
    'RPC de autenticación de estudiantes. Retorna token de sesión UUID y estadísticas del jugador con bloqueo de fuerza bruta.';
