-- =============================================================================
-- SETUP DATABASE V2 â€” Plataforma Educativa Sudoku Samurai++
-- =============================================================================
-- Ejecutar en el Editor SQL de Supabase en el orden indicado.
-- Requiere permisos de superusuario (el editor SQL de Supabase los tiene por defecto).

-- Asegurar que la extensión pgcrypto existe en el esquema 'extensions' (estándar de Supabase)
-- o en su defecto en el esquema 'public'.
DO $$
BEGIN
    -- Si la extensión está en public, intentar moverla a extensions
    IF EXISTS (
        SELECT 1 FROM pg_extension e 
        JOIN pg_namespace n ON e.extnamespace = n.oid 
        WHERE e.extname = 'pgcrypto' AND n.nspname = 'public'
    ) THEN
        ALTER EXTENSION pgcrypto SET SCHEMA extensions;
    ELSE
        -- Si no existe, crearla en extensions
        CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Fallback: intentar creación simple si hay restricciones de permisos o entorno
        CREATE EXTENSION IF NOT EXISTS pgcrypto;
END $$;


-- =============================================================================
-- SECCIÃ“N 1: TABLAS PRINCIPALES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 Instituciones
-- RelaciÃ³n 1:1 con auth.users. El UUID es asignado por Supabase Auth.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.instituciones (
    id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    nombre      VARCHAR(255) NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.instituciones IS
    'Perfil pÃºblico de cada instituciÃ³n educativa. Vinculada 1:1 a auth.users.';

-- -----------------------------------------------------------------------------
-- 1.2 Profesores
-- RelaciÃ³n 1:1 con auth.users. Creados por la instituciÃ³n con contraseÃ±a temporal.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profesores (
    id                  UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    institucion_id      UUID        NOT NULL REFERENCES public.instituciones(id) ON DELETE CASCADE,
    nombre              VARCHAR(255) NOT NULL,
    email               VARCHAR(255) UNIQUE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    -- EstadÃ­sticas acumuladas del profesor como jugador (sincronizadas desde local)
    estadisticas        JSONB       NOT NULL DEFAULT '{
        "total_partidas": 0,
        "total_tableros_completados": 0,
        "total_puntos": 0,
        "total_tiempo": 0,
        "total_errores": 0,
        "promedio_errores": 0.0,
        "partidas_ganadas": 0
    }'::jsonb,
    ultima_sincronizacion   TIMESTAMP WITH TIME ZONE,
    sincronizaciones_hoy    INT NOT NULL DEFAULT 0
);

COMMENT ON TABLE public.profesores IS
    'Perfil de profesor vinculado a auth.users. Incluye estadÃ­sticas de juego acumuladas.';
COMMENT ON COLUMN public.profesores.estadisticas IS
    'Blob JSONB con estadÃ­sticas de juego acumuladas del profesor como jugador.';
COMMENT ON COLUMN public.profesores.sincronizaciones_hoy IS
    'Contador de sincronizaciones manuales del dÃ­a actual. Se resetea al detectar nuevo dÃ­a.';

-- -----------------------------------------------------------------------------
-- 1.3 Grupos
-- Agrupaciones flexibles de la instituciÃ³n (grados, secciones, carreras, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.grupos (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    institucion_id          UUID        NOT NULL REFERENCES public.instituciones(id) ON DELETE CASCADE,
    profesor_encargado_id   UUID        NOT NULL REFERENCES public.profesores(id)   ON DELETE RESTRICT,
    codigo_grupo            VARCHAR(10) NOT NULL,
    created_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now())
);

COMMENT ON TABLE public.grupos IS
    'AgrupaciÃ³n de estudiantes (grado, secciÃ³n, etc.) con un profesor encargado obligatorio.';
COMMENT ON COLUMN public.grupos.codigo_grupo IS
    'Identificador definido por la instituciÃ³n. MÃ¡ximo 10 caracteres.';
COMMENT ON COLUMN public.grupos.profesor_encargado_id IS
    'ON DELETE RESTRICT: un grupo no puede quedar sin profesor encargado.';

-- -----------------------------------------------------------------------------
-- 1.4 Estudiantes
-- No usan Supabase Auth. AutenticaciÃ³n propia mediante usuario + PIN numÃ©rico.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.estudiantes (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    grupo_id    UUID        NOT NULL REFERENCES public.grupos(id) ON DELETE RESTRICT,
    usuario     VARCHAR(100) NOT NULL,
    pin         VARCHAR(6)  NOT NULL
        CONSTRAINT ck_pin_seis_digitos CHECK (pin ~ '^[0-9]{6}$'),
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    -- EstadÃ­sticas acumuladas del estudiante como jugador
    estadisticas        JSONB NOT NULL DEFAULT '{
        "total_partidas": 0,
        "total_tableros_completados": 0,
        "total_puntos": 0,
        "total_tiempo": 0,
        "total_errores": 0,
        "promedio_errores": 0.0,
        "partidas_ganadas": 0
    }'::jsonb,
    ultima_sincronizacion   TIMESTAMP WITH TIME ZONE,
    sincronizaciones_hoy    INT NOT NULL DEFAULT 0,
    intentos_fallidos       INT NOT NULL DEFAULT 0,
    bloqueado_hasta         TIMESTAMP WITH TIME ZONE,
    CONSTRAINT uq_estudiantes_usuario UNIQUE (usuario)
);

COMMENT ON TABLE public.estudiantes IS
    'Jugador-estudiante. No usa Supabase Auth; autenticaciÃ³n custom via funciÃ³n RPC.';
COMMENT ON COLUMN public.estudiantes.pin IS
    'PIN numÃ©rico de exactamente 6 dÃ­gitos. Guardado en texto plano (no sensible como contraseÃ±a).';

-- -----------------------------------------------------------------------------
-- 1.5 Sesiones de Estudiantes
-- Tabla de tokens temporales que reemplazan el JWT de Supabase Auth para estudiantes.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sesiones_estudiantes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    estudiante_id   UUID NOT NULL REFERENCES public.estudiantes(id) ON DELETE CASCADE,
    token           UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    expires_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT ck_token_expiry CHECK (expires_at > created_at)
);

COMMENT ON TABLE public.sesiones_estudiantes IS
    'Tokens UUID aleatorios para sesiones de estudiante. Expiran a las 24h. Usados en RLS via cabecera x-student-token.';

-- -----------------------------------------------------------------------------
-- 1.6 Leaderboard
-- Un Ãºnico registro por jugador (estudiante o profesor). El trigger mantiene
-- solo la mejor partida histÃ³rica usando jerarquÃ­a: puntos > tableros > tiempo.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.leaderboards (
    id                  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Solo uno de los dos puede ser NOT NULL (restricciÃ³n de exclusividad)
    estudiante_id       UUID    UNIQUE REFERENCES public.estudiantes(id) ON DELETE CASCADE,
    profesor_id         UUID    UNIQUE REFERENCES public.profesores(id)  ON DELETE CASCADE,
    dificultad          VARCHAR(50)  NOT NULL,
    modo                VARCHAR(50)  NOT NULL,
    variantes_activas   JSONB        NOT NULL DEFAULT '[]'::jsonb,
    puntuacion          INT          NOT NULL CHECK (puntuacion >= 0),
    tableros_completados INT         NOT NULL CHECK (tableros_completados >= 0),
    tiempo              INT          NOT NULL CHECK (tiempo >= 0),  -- En segundos
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT timezone('utc', now()),
    -- Exactamente uno de los dos IDs debe ser NOT NULL
    CONSTRAINT ck_leaderboard_owner CHECK (
        (estudiante_id IS NOT NULL AND profesor_id IS NULL) OR
        (estudiante_id IS NULL     AND profesor_id IS NOT NULL)
    )
);

COMMENT ON TABLE public.leaderboards IS
    'Un registro por jugador (estudiante o profesor) con su mejor partida histÃ³rica. El trigger evalÃºa y actualiza si la nueva partida es superior.';
COMMENT ON COLUMN public.leaderboards.dificultad IS
    'ActÃºa como filtro de consulta, no afecta el orden del ranking.';
COMMENT ON COLUMN public.leaderboards.variantes_activas IS
    'Array JSON de strings con las variantes activas durante la mejor partida. ActÃºa como filtro.';

-- =============================================================================
-- SECCIÃ“N 2: ÃNDICES DE RENDIMIENTO
-- =============================================================================

-- Ãndice compuesto jerÃ¡rquico de ranking (prioridad exacta del requerimiento)
CREATE INDEX IF NOT EXISTS idx_leaderboards_ranking
    ON public.leaderboards (puntuacion DESC, tableros_completados DESC, tiempo ASC);

-- Ãndice para filtrar leaderboard solo de estudiantes (rank estudiantil)
CREATE INDEX IF NOT EXISTS idx_leaderboards_estudiantes
    ON public.leaderboards (estudiante_id)
    WHERE estudiante_id IS NOT NULL;

-- Ãndice para filtrar leaderboard solo de profesores (rank docente)
CREATE INDEX IF NOT EXISTS idx_leaderboards_profesores
    ON public.leaderboards (profesor_id)
    WHERE profesor_id IS NOT NULL;

-- Ãndices de claves forÃ¡neas (optimizan JOINs en consultas RLS)
CREATE INDEX IF NOT EXISTS idx_profesores_institucion
    ON public.profesores (institucion_id);

CREATE INDEX IF NOT EXISTS idx_grupos_institucion
    ON public.grupos (institucion_id);

CREATE INDEX IF NOT EXISTS idx_grupos_profesor
    ON public.grupos (profesor_encargado_id);

CREATE INDEX IF NOT EXISTS idx_estudiantes_grupo
    ON public.estudiantes (grupo_id);

CREATE INDEX IF NOT EXISTS idx_sesiones_estudiante
    ON public.sesiones_estudiantes (estudiante_id);

-- Ãndice para bÃºsqueda y expiraciÃ³n de tokens de sesiÃ³n
CREATE INDEX IF NOT EXISTS idx_sesiones_token_expiry
    ON public.sesiones_estudiantes (token, expires_at);

-- =============================================================================
-- SECCIÃ“N 3: FUNCIONES DE UTILIDAD Y AUTENTICACIÃ“N
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 get_current_student_id()
-- Lee el token del encabezado HTTP personalizado 'x-student-token' y devuelve
-- el UUID del estudiante autenticado. Devuelve NULL si el token es invÃ¡lido o expirÃ³.
-- SECURITY DEFINER: se ejecuta con los permisos del dueÃ±o, no del llamador.
-- No usa SQL dinÃ¡mico: inmune a inyecciÃ³n de SQL.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_student_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_token_raw  TEXT;
    v_token_uuid UUID;
    v_student_id UUID;
BEGIN
    -- Leer cabecera HTTP personalizada (Supabase la expone como setting)
    v_token_raw := current_setting('request.headers', true)::json->>'x-student-token';

    IF v_token_raw IS NULL OR v_token_raw = '' THEN
        RETURN NULL;
    END IF;

    -- Convertir a UUID con manejo de error: si el valor no es UUID vÃ¡lido, retornar NULL
    BEGIN
        v_token_uuid := v_token_raw::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN NULL;
    END;

    -- Consulta estÃ¡tica parametrizada. Sin concatenaciÃ³n de texto: inmune a SQLi.
    SELECT estudiante_id
    INTO   v_student_id
    FROM   public.sesiones_estudiantes
    WHERE  token      = v_token_uuid
      AND  expires_at > now();

    RETURN v_student_id;
END;
$$;

COMMENT ON FUNCTION public.get_current_student_id() IS
    'Resuelve el token de sesiÃ³n de estudiante desde la cabecera HTTP x-student-token. Usada por las polÃ­ticas RLS.';

-- -----------------------------------------------------------------------------
-- 3.2 login_estudiante(p_usuario, p_pin)
-- RPC segura de autenticaciÃ³n de estudiantes.
-- Devuelve el token de sesiÃ³n y las estadÃ­sticas en la nube al cliente Godot.
-- Usa consultas estÃ¡ticas parametrizadas. El PIN se compara como literal de texto.
-- -----------------------------------------------------------------------------
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
    v_est       public.estudiantes%ROWTYPE;
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
    'RPC de autenticaciÃ³n de estudiantes. Retorna token de sesiÃ³n UUID y estadÃ­sticas del jugador.';

-- -----------------------------------------------------------------------------
-- 3.3 logout_estudiante(p_token)
-- Invalida el token de sesiÃ³n (eliminaciÃ³n fÃ­sica). Llamada por el cliente Godot
-- antes de hacer el borrado del archivo local.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.logout_estudiante(
    p_token TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_token_uuid UUID;
BEGIN
    BEGIN
        v_token_uuid := p_token::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        RETURN FALSE;
    END;

    DELETE FROM public.sesiones_estudiantes
    WHERE  token = v_token_uuid;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.logout_estudiante(TEXT) IS
    'Invalida el token de sesiÃ³n de un estudiante. Debe llamarse tras sincronizar estadÃ­sticas.';

-- -----------------------------------------------------------------------------
-- 3.4 registrar_profesor(...)
-- Permite que una instituciÃ³n autenticada cree un profesor directamente en
-- auth.users con contraseÃ±a temporal confirmada. Sin correo de invitaciÃ³n.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.registrar_profesor(
    p_email         TEXT,
    p_password_temp TEXT,
    p_nombre        TEXT,
    p_institucion_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_caller_id  UUID;
    v_new_id     UUID;
BEGIN
    -- Verificar que el llamador es exactamente la instituciÃ³n indicada
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL OR v_caller_id <> p_institucion_id THEN
        RAISE EXCEPTION 'No autorizado. Solo la instituciÃ³n propietaria puede registrar profesores.'
            USING ERRCODE = 'P0003';
    END IF;

    -- Validar que la instituciÃ³n existe en public.instituciones
    IF NOT EXISTS (SELECT 1 FROM public.instituciones WHERE id = v_caller_id) THEN
        RAISE EXCEPTION 'La instituciÃ³n solicitante no estÃ¡ registrada.'
            USING ERRCODE = 'P0004';
    END IF;

    -- Generar UUID para el nuevo usuario
    v_new_id := gen_random_uuid();

    -- Inserción directa y confirmada en auth.users (sin email de invitación)
    -- crypt() con Blowfish (bcrypt) garantiza que la contraseña no se almacene en texto plano
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        aud,
        role,
        created_at,
        updated_at
    ) VALUES (
        v_new_id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        p_email,
        crypt(p_password_temp, gen_salt('bf', 12)),  -- bcrypt, factor de coste 12
        now(),                                          -- Email confirmado directamente
        jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
        jsonb_build_object(
            'nombre',         p_nombre,
            'rol',            'profesor',
            'institucion_id', p_institucion_id,
            'temp_password',  true              -- Flag para forzar cambio en primer login
        ),
        'authenticated',
        'authenticated',
        now(),
        now()
    );

    -- Sanitizar columnas nullable de auth.users para evitar errores de escaneo (GoTrue "Database error querying schema")
    -- 1. Columnas de Texto / Varchar -> '' (excluyendo columnas únicas como email y phone)
    FOR v_col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND data_type IN ('character varying', 'text')
          AND column_name NOT IN ('phone', 'email', 'phone_change')
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = COALESCE(%I, '''') WHERE id = $1', v_col.column_name, v_col.column_name)
        USING v_new_id;
    END LOOP;

    -- 2. Columnas Booleanas -> false
    FOR v_col IN 
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'auth' 
          AND table_name = 'users' 
          AND data_type = 'boolean'
    LOOP
        EXECUTE format('UPDATE auth.users SET %I = COALESCE(%I, false) WHERE id = $1', v_col.column_name, v_col.column_name)
        USING v_new_id;
    END LOOP;

    -- El trigger on_auth_user_created creará automáticamente la fila en public.profesores
    RETURN v_new_id;
END;
$$;

COMMENT ON FUNCTION public.registrar_profesor(TEXT, TEXT, TEXT, UUID) IS
    'Registra un profesor en auth.users con contraseÃ±a temporal confirmada. Usada por la instituciÃ³n.';

-- -----------------------------------------------------------------------------
-- 3.5 cambiar_contrasena_profesor(p_nueva_password)
-- Cambia la contraseÃ±a del profesor autenticado y desactiva el flag temp_password.
-- Solo puede ejecutarla un profesor con temp_password = true en sus metadatos.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cambiar_contrasena_profesor(
    p_nueva_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_uid          UUID;
    v_es_temporal  BOOLEAN;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'No hay sesiÃ³n activa.' USING ERRCODE = 'P0005';
    END IF;

    -- Verificar que la contraseÃ±a actual es temporal
    SELECT (raw_user_meta_data->>'temp_password')::boolean
    INTO   v_es_temporal
    FROM   auth.users
    WHERE  id = v_uid;

    IF NOT FOUND OR NOT COALESCE(v_es_temporal, false) THEN
        RAISE EXCEPTION 'Este usuario no requiere cambio de contraseÃ±a obligatorio.'
            USING ERRCODE = 'P0006';
    END IF;

    -- Actualizar contraseÃ±a con bcrypt y desactivar flag
    UPDATE auth.users
    SET
        encrypted_password = crypt(p_nueva_password, gen_salt('bf', 12)),
        raw_user_meta_data = raw_user_meta_data || jsonb_build_object('temp_password', false),
        updated_at         = now()
    WHERE id = v_uid;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.cambiar_contrasena_profesor(TEXT) IS
    'Cambia la contraseÃ±a temporal del profesor y desactiva el flag de primer login obligatorio.';

-- =============================================================================
-- SECCIÃ“N 4: FUNCIONES DE SINCRONIZACIÃ“N DE ESTADÃSTICAS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 sincronizar_estudiante(p_estadisticas, p_es_manual)
-- Recibe el blob JSONB de estadÃ­sticas desde Godot y lo persiste en Supabase.
-- LÃ­mite: 2 sincronizaciones MANUALES por dÃ­a. Sincronizaciones automÃ¡ticas
-- (cierre de sesiÃ³n / cambio de usuario) no consumen el cupo diario.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sincronizar_estudiante(
    p_estadisticas  JSONB,
    p_es_manual     BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_est_id    UUID;
    v_est       public.estudiantes%ROWTYPE;
    v_hoy       DATE := current_date;
    v_sinc_hoy  INT;
BEGIN
    -- Resolver identidad del estudiante desde el token de sesiÃ³n
    v_est_id := public.get_current_student_id();
    IF v_est_id IS NULL THEN
        RAISE EXCEPTION 'SesiÃ³n de estudiante no vÃ¡lida o expirada.' USING ERRCODE = 'P0007';
    END IF;

    SELECT * INTO v_est FROM public.estudiantes WHERE id = v_est_id;

    IF p_es_manual THEN
        -- Calcular cuÃ¡ntas sincronizaciones manuales lleva hoy
        IF v_est.ultima_sincronizacion IS NOT NULL AND
           v_est.ultima_sincronizacion::date = v_hoy THEN
            v_sinc_hoy := v_est.sincronizaciones_hoy;
        ELSE
            -- Primer uso del dÃ­a: reiniciar contador
            v_sinc_hoy := 0;
        END IF;

        IF v_sinc_hoy >= 2 THEN
            RAISE EXCEPTION 'LÃ­mite de sincronizaciones manuales alcanzado (2/dÃ­a). IntÃ©ntalo maÃ±ana.'
                USING ERRCODE = 'P0008';
        END IF;

        v_sinc_hoy := v_sinc_hoy + 1;
    ELSE
        -- SincronizaciÃ³n automÃ¡tica: no modifica el contador manual
        IF v_est.ultima_sincronizacion IS NOT NULL AND
           v_est.ultima_sincronizacion::date = v_hoy THEN
            v_sinc_hoy := v_est.sincronizaciones_hoy;
        ELSE
            v_sinc_hoy := 0;
        END IF;
    END IF;

    -- Persistir estadÃ­sticas. Consulta estÃ¡tica: sin concatenaciÃ³n ni dynamic SQL.
    UPDATE public.estudiantes
    SET
        estadisticas          = p_estadisticas,
        sincronizaciones_hoy  = v_sinc_hoy,
        ultima_sincronizacion = now()
    WHERE id = v_est_id;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.sincronizar_estudiante(JSONB, BOOLEAN) IS
    'Guarda el blob JSONB de estadÃ­sticas del estudiante. Limita a 2 syncs manuales/dÃ­a. Los automÃ¡ticos (logout) son ilimitados.';

-- -----------------------------------------------------------------------------
-- 4.2 sincronizar_profesor(p_estadisticas, p_es_manual)
-- AnÃ¡logo para profesores, usando auth.uid() en lugar de token.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sincronizar_profesor(
    p_estadisticas  JSONB,
    p_es_manual     BOOLEAN
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_prof_id   UUID;
    v_prof      public.profesores%ROWTYPE;
    v_hoy       DATE := current_date;
    v_sinc_hoy  INT;
BEGIN
    v_prof_id := auth.uid();
    IF v_prof_id IS NULL THEN
        RAISE EXCEPTION 'No hay sesiÃ³n de profesor activa.' USING ERRCODE = 'P0007';
    END IF;

    SELECT * INTO v_prof FROM public.profesores WHERE id = v_prof_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profesor no encontrado en el sistema.' USING ERRCODE = 'P0009';
    END IF;

    IF p_es_manual THEN
        IF v_prof.ultima_sincronizacion IS NOT NULL AND
           v_prof.ultima_sincronizacion::date = v_hoy THEN
            v_sinc_hoy := v_prof.sincronizaciones_hoy;
        ELSE
            v_sinc_hoy := 0;
        END IF;

        IF v_sinc_hoy >= 2 THEN
            RAISE EXCEPTION 'LÃ­mite de sincronizaciones manuales alcanzado (2/dÃ­a). IntÃ©ntalo maÃ±ana.'
                USING ERRCODE = 'P0008';
        END IF;

        v_sinc_hoy := v_sinc_hoy + 1;
    ELSE
        IF v_prof.ultima_sincronizacion IS NOT NULL AND
           v_prof.ultima_sincronizacion::date = v_hoy THEN
            v_sinc_hoy := v_prof.sincronizaciones_hoy;
        ELSE
            v_sinc_hoy := 0;
        END IF;
    END IF;

    UPDATE public.profesores
    SET
        estadisticas          = p_estadisticas,
        sincronizaciones_hoy  = v_sinc_hoy,
        ultima_sincronizacion = now()
    WHERE id = v_prof_id;

    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION public.sincronizar_profesor(JSONB, BOOLEAN) IS
    'Guarda el blob JSONB de estadÃ­sticas del profesor. Limita a 2 syncs manuales/dÃ­a. Los automÃ¡ticos (logout) son ilimitados.';

-- =============================================================================
-- SECCIÃ“N 5: TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1 handle_new_auth_user()
-- Al crear un usuario en auth.users, inserta automÃ¡ticamente su perfil en
-- public.instituciones o public.profesores segÃºn el metadato 'rol'.
-- SECURITY DEFINER: necesario para escribir en tablas protegidas por RLS.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_rol       TEXT;
    v_nombre    TEXT;
    v_inst_id   UUID;
BEGIN
    v_rol    := NEW.raw_user_meta_data->>'rol';
    v_nombre := COALESCE(NEW.raw_user_meta_data->>'nombre', NEW.email);

    IF v_rol = 'institucion' THEN
        INSERT INTO public.instituciones (id, nombre, created_at)
        VALUES (NEW.id, v_nombre, now())
        ON CONFLICT (id) DO NOTHING;

    ELSIF v_rol = 'profesor' THEN
        v_inst_id := (NEW.raw_user_meta_data->>'institucion_id')::uuid;

        IF v_inst_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere institucion_id en los metadatos del usuario profesor.'
                USING ERRCODE = 'P0010';
        END IF;

        INSERT INTO public.profesores (id, institucion_id, nombre, email, created_at)
        VALUES (NEW.id, v_inst_id, v_nombre, NEW.email, now())
        ON CONFLICT (id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_auth_user();

COMMENT ON FUNCTION public.handle_new_auth_user() IS
    'Trigger de auth.users: crea perfil en instituciones o profesores segÃºn metadato rol.';

-- -----------------------------------------------------------------------------
-- 5.1.b handle_update_profesor()
-- Sincroniza las actualizaciones de email de public.profesores hacia auth.users.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_update_profesor()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS \$\$
BEGIN
    IF NEW.email IS DISTINCT FROM OLD.email THEN
        UPDATE auth.users
        SET    email = NEW.email
        WHERE  id = NEW.id;
    END IF;
    RETURN NEW;
END;
\$\$;

DROP TRIGGER IF EXISTS on_profesor_updated ON public.profesores;
CREATE TRIGGER on_profesor_updated
    BEFORE UPDATE ON public.profesores
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_update_profesor();

COMMENT ON FUNCTION public.handle_update_profesor() IS
    'Sincroniza el cambio de correo de profesor con la tabla auth.users.';

-- 5.2 evaluar_mejor_partida()
-- Intercepta cada INSERT en public.leaderboards.
-- Si ya existe un registro del jugador, evalÃºa la jerarquÃ­a de prioridad:
--   1. puntuacion DESC  2. tableros_completados DESC  3. tiempo ASC
-- Si el nuevo resultado supera al anterior, actualiza la fila existente.
-- Si no supera, descarta el INSERT devolviendo NULL (sin insertar nueva fila).
-- Garantiza un Ãºnico registro por jugador.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.evaluar_mejor_partida()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existente public.leaderboards%ROWTYPE;
    v_es_mejor  BOOLEAN := FALSE;
BEGIN
    -- Buscar el registro existente segÃºn el tipo de jugador
    IF NEW.estudiante_id IS NOT NULL THEN
        SELECT * INTO v_existente
        FROM   public.leaderboards
        WHERE  estudiante_id = NEW.estudiante_id;
    ELSE
        SELECT * INTO v_existente
        FROM   public.leaderboards
        WHERE  profesor_id = NEW.profesor_id;
    END IF;

    IF NOT FOUND THEN
        -- No existe registro previo â†’ permitir inserciÃ³n
        RETURN NEW;
    END IF;

    -- Evaluar jerarquÃ­a de prioridad (sin branch extra, orden estricto)
    IF NEW.puntuacion > v_existente.puntuacion THEN
        v_es_mejor := TRUE;
    ELSIF NEW.puntuacion = v_existente.puntuacion THEN
        IF NEW.tableros_completados > v_existente.tableros_completados THEN
            v_es_mejor := TRUE;
        ELSIF NEW.tableros_completados = v_existente.tableros_completados THEN
            IF NEW.tiempo < v_existente.tiempo THEN
                v_es_mejor := TRUE;
            END IF;
        END IF;
    END IF;

    IF v_es_mejor THEN
        -- Actualizar la fila existente con la nueva mejor marca
        UPDATE public.leaderboards
        SET
            dificultad           = NEW.dificultad,
            modo                 = NEW.modo,
            variantes_activas    = NEW.variantes_activas,
            puntuacion           = NEW.puntuacion,
            tableros_completados = NEW.tableros_completados,
            tiempo               = NEW.tiempo,
            created_at           = now()
        WHERE id = v_existente.id;
    END IF;

    -- Cancelar el INSERT en cualquier caso (ya sea que hayamos actualizado o descartado)
    -- El UPDATE arriba ya habrÃ¡ aplicado el cambio si correspondÃ­a.
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_mejor_partida_leaderboard ON public.leaderboards;
CREATE TRIGGER trg_mejor_partida_leaderboard
    BEFORE INSERT ON public.leaderboards
    FOR EACH ROW
    EXECUTE FUNCTION public.evaluar_mejor_partida();

COMMENT ON FUNCTION public.evaluar_mejor_partida() IS
    'Trigger BEFORE INSERT en leaderboards. Mantiene un Ãºnico registro por jugador con la mejor partida histÃ³rica.';

-- =============================================================================
-- SECCIÃ“N 6: ROW LEVEL SECURITY (RLS)
-- =============================================================================

ALTER TABLE public.instituciones        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profesores           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grupos               ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estudiantes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sesiones_estudiantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboards         ENABLE ROW LEVEL SECURITY;

-- ------------------------------------
-- PolÃ­ticas: public.instituciones
-- ------------------------------------
-- Una instituciÃ³n solo ve y modifica su propio perfil.
DROP POLICY IF EXISTS "inst_select_own"  ON public.instituciones;
DROP POLICY IF EXISTS "inst_update_own"  ON public.instituciones;

CREATE POLICY "inst_select_own"
    ON public.instituciones FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "inst_update_own"
    ON public.instituciones FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ------------------------------------
-- PolÃ­ticas: public.profesores
-- ------------------------------------
DROP POLICY IF EXISTS "prof_select" ON public.profesores;
DROP POLICY IF EXISTS "prof_all_by_inst" ON public.profesores;

-- Profesor ve su propio perfil; instituciÃ³n ve todos sus profesores
CREATE POLICY "prof_select"
    ON public.profesores FOR SELECT
    USING (
        id = auth.uid()
        OR institucion_id = auth.uid()
    );

-- Solo la instituciÃ³n puede insertar, actualizar o eliminar profesores de su cuenta
CREATE POLICY "prof_all_by_inst"
    ON public.profesores FOR ALL
    USING (institucion_id = auth.uid())
    WITH CHECK (institucion_id = auth.uid());

-- ------------------------------------
-- PolÃ­ticas: public.grupos
-- ------------------------------------
DROP POLICY IF EXISTS "grupos_select"      ON public.grupos;
DROP POLICY IF EXISTS "grupos_all_by_inst" ON public.grupos;

-- InstituciÃ³n ve todos sus grupos; el profesor encargado ve los suyos
CREATE POLICY "grupos_select"
    ON public.grupos FOR SELECT
    USING (
        institucion_id        = auth.uid()
        OR profesor_encargado_id = auth.uid()
    );

-- Solo la instituciÃ³n gestiona grupos (CRUD completo)
CREATE POLICY "grupos_all_by_inst"
    ON public.grupos FOR ALL
    USING  (institucion_id = auth.uid())
    WITH CHECK (institucion_id = auth.uid());

-- ------------------------------------
-- PolÃ­ticas: public.estudiantes
-- ------------------------------------
DROP POLICY IF EXISTS "est_select" ON public.estudiantes;
DROP POLICY IF EXISTS "est_all_inst_prof" ON public.estudiantes;

-- El estudiante ve solo su propio perfil (via token)
-- El profesor encargado del grupo ve los estudiantes de ese grupo
-- La instituciÃ³n ve todos los estudiantes de sus grupos
CREATE POLICY "est_select"
    ON public.estudiantes FOR SELECT
    USING (
        id = public.get_current_student_id()
        OR EXISTS (
            SELECT 1 FROM public.grupos g
            WHERE  g.id = grupo_id
              AND  (g.institucion_id = auth.uid() OR g.profesor_encargado_id = auth.uid())
        )
    );

-- InstituciÃ³n y profesor encargado pueden insertar/actualizar/eliminar estudiantes
CREATE POLICY "est_all_inst_prof"
    ON public.estudiantes FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.grupos g
            WHERE  g.id = grupo_id
              AND  (g.institucion_id = auth.uid() OR g.profesor_encargado_id = auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.grupos g
            WHERE  g.id = grupo_id
              AND  (g.institucion_id = auth.uid() OR g.profesor_encargado_id = auth.uid())
        )
    );

-- ------------------------------------
-- PolÃ­ticas: public.sesiones_estudiantes
-- ------------------------------------
-- Las funciones RPC de login/logout usan SECURITY DEFINER, asÃ­ que las polÃ­ticas
-- de esta tabla solo necesitan proteger contra lectura directa no autorizada.
DROP POLICY IF EXISTS "sesiones_deny_direct" ON public.sesiones_estudiantes;

CREATE POLICY "sesiones_deny_direct"
    ON public.sesiones_estudiantes FOR SELECT
    USING (
        -- Solo el propio estudiante puede ver su sesiÃ³n (via token ya validado)
        estudiante_id = public.get_current_student_id()
    );

-- ------------------------------------
-- PolÃ­ticas: public.leaderboards
-- ------------------------------------
DROP POLICY IF EXISTS "lb_select"        ON public.leaderboards;
DROP POLICY IF EXISTS "lb_insert_own"    ON public.leaderboards;
DROP POLICY IF EXISTS "lb_all_by_inst"   ON public.leaderboards;

-- Lectura segÃºn rol:
--   - Estudiante: solo ve el ranking de su propio grupo
--   - Profesor: ve el ranking de los estudiantes de sus grupos Y el ranking de profesores de su instituciÃ³n
--   - InstituciÃ³n: ve todo el leaderboard de su instituciÃ³n
CREATE POLICY "lb_select"
    ON public.leaderboards FOR SELECT
    USING (
        -- Fila de estudiante: acceso segÃºn rol del consultante
        (estudiante_id IS NOT NULL AND (
            -- InstituciÃ³n: ve todos los estudiantes de su instituciÃ³n
            EXISTS (
                SELECT 1 FROM public.estudiantes e
                JOIN   public.grupos g ON g.id = e.grupo_id
                WHERE  e.id = estudiante_id AND g.institucion_id = auth.uid()
            )
            OR
            -- Profesor: ve estudiantes de sus grupos
            EXISTS (
                SELECT 1 FROM public.estudiantes e
                JOIN   public.grupos g ON g.id = e.grupo_id
                WHERE  e.id = estudiante_id AND g.profesor_encargado_id = auth.uid()
            )
            OR
            -- Estudiante: ve solo estudiantes de su mismo grupo
            EXISTS (
                SELECT 1 FROM public.estudiantes e1
                JOIN   public.estudiantes e2 ON e1.grupo_id = e2.grupo_id
                WHERE  e1.id = estudiante_id
                  AND  e2.id = public.get_current_student_id()
            )
        ))
        OR
        -- Fila de profesor: acceso solo para instituciÃ³n y profesores de la misma instituciÃ³n
        (profesor_id IS NOT NULL AND (
            -- InstituciÃ³n: ve todos sus profesores en el ranking
            EXISTS (
                SELECT 1 FROM public.profesores p
                WHERE  p.id = profesor_id AND p.institucion_id = auth.uid()
            )
            OR
            -- Profesores: ven el ranking de profesores de su misma instituciÃ³n
            EXISTS (
                SELECT 1 FROM public.profesores p_target
                JOIN   public.profesores p_caller ON p_caller.institucion_id = p_target.institucion_id
                WHERE  p_target.id = profesor_id AND p_caller.id = auth.uid()
            )
        ))
    );

-- InserciÃ³n: cada jugador inserta su propio registro
CREATE POLICY "lb_insert_own"
    ON public.leaderboards FOR INSERT
    WITH CHECK (
        estudiante_id = public.get_current_student_id()
        OR profesor_id = auth.uid()
    );

-- GestiÃ³n completa para la instituciÃ³n (UPDATE/DELETE en sus registros)
CREATE POLICY "lb_all_by_inst"
    ON public.leaderboards FOR ALL
    USING (
        (estudiante_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.estudiantes e
            JOIN   public.grupos g ON g.id = e.grupo_id
            WHERE  e.id = estudiante_id AND g.institucion_id = auth.uid()
        ))
        OR
        (profesor_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.profesores p
            WHERE  p.id = profesor_id AND p.institucion_id = auth.uid()
        ))
    )
    WITH CHECK (
        (estudiante_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.estudiantes e
            JOIN   public.grupos g ON g.id = e.grupo_id
            WHERE  e.id = estudiante_id AND g.institucion_id = auth.uid()
        ))
        OR
        (profesor_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.profesores p
            WHERE  p.id = profesor_id AND p.institucion_id = auth.uid()
        ))
    );

-- =============================================================================
-- FIN DEL SCRIPT
-- =============================================================================

