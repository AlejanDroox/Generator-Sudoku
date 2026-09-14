# Documentación Gráfica de Arquitectura: Proyecto "Sudoku Samurai++"

Este documento contiene las especificaciones formales y el código fuente en formato Mermaid.js para los 7 diagramas arquitectónicos del videojuego. Cada diagrama está rotulado bajo formato institucional, optimizado para su inclusión en la tesis.

---

## 1. Diagrama Entidad-Relación (DER / Modelo de Datos)

### TÍTULO: DIAGRAMA DE MODELO DE DATOS Y PERSISTENCIA (DER)
```mermaid
erDiagram
    instituciones {
        uuid id PK "auth.users(id) - Identificador único de la institución"
        varchar nombre "Nombre de la institución educativa"
        timestamp_tz created_at "Fecha y hora de registro"
    }
    profesores {
        uuid id PK "auth.users(id) - Identificador único del profesor"
        uuid institucion_id FK "instituciones.id - Institución de pertenencia"
        varchar nombre "Nombre del docente"
        varchar email "Email único del profesor"
        jsonb estadisticas "Estadísticas acumuladas como jugador"
        timestamp_tz ultima_sincronizacion "Última fecha de sincronización en nube"
        integer sincronizaciones_hoy "Sincronizaciones manuales hoy"
        timestamp_tz created_at "Fecha de registro"
    }
    grupos {
        uuid id PK "Identificador único de sección/grupo"
        uuid institucion_id FK "instituciones.id - Institución propietaria"
        uuid profesor_encargado_id FK "profesores.id - Profesor a cargo"
        varchar codigo_grupo "Código único del grupo (sección/grado)"
        timestamp_tz created_at "Fecha de creación"
    }
    estudiantes {
        uuid id PK "Identificador único del estudiante (UUID)"
        uuid grupo_id FK "grupos.id - Grupo al que pertenece"
        varchar usuario "Nombre de usuario único para login"
        varchar pin "PIN numérico de 6 dígitos"
        jsonb estadisticas "Estadísticas acumuladas de juego"
        timestamp_tz ultima_sincronizacion "Última fecha de sincronización en nube"
        integer sincronizaciones_hoy "Sincronizaciones manuales hoy"
        integer intentos_fallidos "Contador de login fallidos (fuerza bruta)"
        timestamp_tz bloqueado_hasta "Fin de bloqueo temporal por fuerza bruta"
        timestamp_tz created_at "Fecha de registro"
    }
    sesiones_estudiantes {
        uuid id PK "Identificador de sesión (UUID)"
        uuid estudiante_id FK "estudiantes.id - Estudiante asociado"
        uuid token "Token de sesión único (cabecera HTTP) - UNIQUE"
        timestamp_tz created_at "Fecha de inicio de sesión"
        timestamp_tz expires_at "Fecha de expiración (24 horas)"
    }
    leaderboards {
        uuid id PK "Identificador único del récord (UUID)"
        uuid estudiante_id FK "estudiantes.id - Récord de estudiante (exclusivo) - UNIQUE"
        uuid profesor_id FK "profesores.id - Récord de profesor (exclusivo) - UNIQUE"
        varchar dificultad "Dificultad de la partida (Fácil, Medio, etc.)"
        varchar modo "Modo de juego (Samurái, Clásico, etc.)"
        jsonb variantes_activas "Variantes activas (Knight, Killer, Thermo, Arrow)"
        integer puntuacion "Mejor puntaje histórico obtenido"
        integer tableros_completados "Tableros resueltos en la partida"
        integer tiempo "Tiempo de resolución en segundos"
        timestamp_tz created_at "Fecha de obtención del récord"
    }

    instituciones ||--o{ profesores : "registra (1:N)"
    instituciones ||--o{ grupos : "posee (1:N)"
    profesores ||--o{ grupos : "dirige (1:N)"
    grupos ||--o{ estudiantes : "contiene (1:N)"
    estudiantes ||--o{ sesiones_estudiantes : "inicia (1:N)"
    estudiantes ||--o| leaderboards : "tiene (1:0..1)"
    profesores ||--o| leaderboards : "tiene (1:0..1)"
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Datos:** El modelo de datos v2 estructura la persistencia relacional en Supabase para dar soporte al entorno escolar multirrol. `instituciones` y `profesores` enlazan 1:1 con la tabla interna de usuarios de Supabase (`auth.users`), controlando sus permisos de inserción y lectura de forma directa. Los `estudiantes` no usan Supabase Auth, sino usuario y PIN de 6 dígitos validados mediante RPC de base de datos (`login_estudiante`), el cual genera un token en `sesiones_estudiantes` que expira en 24 horas para validar políticas RLS en la sesión del cliente. La tabla `leaderboards` almacena los récords de partidas mediante relaciones de exclusión de un único poseedor por fila, controlado a través de un trigger BEFORE INSERT (`evaluar_mejor_partida`) que actualiza la puntuación si esta es superior bajo jerarquía de puntuación, tableros y tiempo. En local, `LocalDB.gd` persiste los datos acumulados y runs en formato JSON bajo archivos dinámicos aislados por usuario (`user://player_stats_<user_id>.json`).

---

## 2. Diagrama de Casos de Uso (UML)

### TÍTULO: DIAGRAMA DE CASOS DE USO Y LÍMITES DEL SISTEMA
```mermaid
graph TD
    %% Estilo General
    classDef actor fill:#f9f,stroke:#333,stroke-width:2px;
    classDef uc fill:#dff,stroke:#333,stroke-width:1.5px;
    
    %% Actores
    Jugador[("Actor: Jugador")]:::actor
    
    %% Casos de Uso
    UC1(["Iniciar Partida<br>(Modo Samurái en Cadena)"]):::uc
    UC2(["Introducir Dígito en Celda"]):::uc
    UC3(["Visualizar Tabla de Clasificación Global"]):::uc
    UC4(["Validar Restricción Dinámica (CSP)<br>(Anti-Knight, Killer, Thermo, Arrow)"]):::uc
    UC5(["Pintar Número en Rojo<br>(Feedback de Conflicto Lúdico)"]):::uc
    UC6(["Completar Tablero"]):::uc
    UC7(["Desbloquear Siguiente Tablero<br>(Umbral de Completitud > 70-80%)"]):::uc

    %% Relaciones
    Jugador --> UC1
    Jugador --> UC2
    Jugador --> UC3

    UC2 -.->|"<<include>>"| UC4
    UC4 -.->|"<<extend>>"| UC5
    UC2 -.->|"<<extend>>"| UC6
    UC6 -.->|"<<include>>"| UC7
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Casos de Uso:** El caso de uso principal "Introducir Dígito" invoca de manera forzada (`<<include>>`) la validación del motor CSP. En caso de que el valor no pertenezca a la solución consistente, se extiende el flujo (`<<extend>>`) para pintar la celda en rojo. La resolución paulatina extiende el flujo a "Completar Tablero", lo cual desencadena la verificación del umbral para instanciar asíncronamente el siguiente tablero de la cadena.

---

## 3. Diagrama de Componentes (UML)

### TÍTULO: DIAGRAMA DE COMPONENTES DE SOFTWARE Y DEPENDENCIAS
```mermaid
graph TB
    subgraph UI ["Capa de Interfaz de Usuario (SceneTree Nodes)"]
        CellUI["cellv_2.gd (Celda Visual)"]
        BoardUI["tablero_v_3.gd (Tablero Visual)"]
        LeaderboardUI["leaderboard.gd (Ranking Visual)"]
        SchoolMgmtUI["UI de Gestión Escolar"]
    end

    subgraph Core ["Cálculo y Resolución Algorítmica (CSP)"]
        SudokuLogic["SudokuLogic.gd (Resolvedor y Poda AC-3)"]
        SudokuGenerator["SudokuGenerator.gd (Motor de Excavación)"]
    end

    subgraph Singletons ["Orquestación y Flujo Lúdico (Autoloads)"]
        Global["Global.gd (Estado General y Foco)"]
        ScoreManager["ScoreManager.gd (Puntajes y Arbitraje)"]
        AuthManager["AuthManager.gd (Gestor de Sesión)"]
    end

    subgraph Persistence ["Capa de Persistencia de Datos"]
        LocalDB["LocalDB.gd (JSON local cifrado por usuario)"]
        subgraph RemoteFacade ["Módulo Remoto (Fachada Supabase)"]
            RemoteDB["RemoteDB.gd (Controlador de Red HTTP)"]
            RemoteAuth["RemoteAuth.gd (Autenticación RPC / GoTrue)"]
            RemoteSync["RemoteSync.gd (Sincronización de Perfiles)"]
            RemoteLeaderboard["RemoteLeaderboard.gd (Ranking Global)"]
            RemoteCrud["RemoteCrud.gd (Gestión Escolar)"]
        end
    end

    subgraph External ["Servicios Cloud de Terceros"]
        Supabase["Supabase Cloud (API REST PostgREST / GoTrue Auth)"]
    end

    %% Relaciones y Dependencias
    CellUI -->|Consulta Foco| Global
    BoardUI -->|Registra Tablero| ScoreManager
    CellUI -->|Notifica Cambio de Celda| ScoreManager
    LeaderboardUI -->|Solicita Listado| RemoteLeaderboard
    SchoolMgmtUI -->|Llamadas de CRUD| RemoteCrud
    
    SudokuGenerator -->|Resuelve / Evalúa Unicidad| SudokuLogic
    BoardUI -.->|Instancia Datos de Puzzle| SudokuGenerator
    
    ScoreManager -->|Registra Sesión| LocalDB
    ScoreManager -->|Sube Puntuación| RemoteLeaderboard
    
    AuthManager -->|Inicializa Perfil / Sincroniza| LocalDB
    AuthManager -->|Peticiones de Acceso| RemoteAuth
    AuthManager -->|Ordena Sync de Datos| RemoteSync
    
    RemoteDB -->|Delegación de Llamadas| RemoteAuth & RemoteSync & RemoteLeaderboard & RemoteCrud
    RemoteDB -->|HTTPS/REST (Puerto 443)| Supabase
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Componentes:** El diseño desacopla la vista de Godot (UI Layer) del resolvedor de restricciones (Core Solvers). La coordinación de flujos de datos en el cliente se realiza a través de los administradores globales (Singletons/Autoloads) añadiendo a `AuthManager.gd` para la gestión escolar y de logins. La persistencia remota adopta un patrón **Fachada (Facade)** en `RemoteDB.gd` que delega las operaciones HTTP especializadas a `RemoteAuth.gd`, `RemoteSync.gd`, `RemoteLeaderboard.gd` y `RemoteCrud.gd`, separando la persistencia offline (`LocalDB.gd` con estadísticas JSON segmentadas por usuario) de la online en Supabase.

---

## 4. Diagrama de Actividades (UML)

### TÍTULO: DIAGRAMA DE ACTIVIDADES PARA LA GENERACIÓN Y EXCAVACIÓN DE PUZZLES
```mermaid
graph TD
    Start([Inicio: Disparo de Generación del Piso]) --> Dec1{¿Es tablero encadenado?}
    
    Dec1 -- Sí --> OpSemilla[Heredar bloque sectorial 3x3<br>de la esquina semilla del predecesor<br>Corner Shielding / Blindaje]
    Dec1 -- No --> OpRandom[Inicializar primera fila aleatoria]
    
    OpSemilla --> OpSolve[Resolver tablero completo usando SudokuLogic.solve]
    OpRandom --> OpSolve
    
    OpSolve --> OpVar[Generar restricciones dinámicas procedurales<br>- Cages Killer via BFS<br>- Thermos y Arrows via DFS]
    
    OpVar --> StartLoop[Bucle de Excavación Controlada: _excavate_board]
    
    StartLoop --> PickCell[Seleccionar celda candidata aleatoria]
    PickCell --> CheckShield{¿Pertenece a la zona blindada de la esquina?}
    
    CheckShield -- Sí --> PickCell
    CheckShield -- No --> RemoveNum[Remover número de la celda temporalmente<br>y ejecutar solver CSP]
    
    RemoveNum --> CheckUnique{¿Conserva solución única?}
    
    CheckUnique -- Sí --> ConfirmRemoval[Confirmar remoción<br>Evaluar complejidad: contar Backtracks]
    CheckUnique -- No --> UndoRemoval[Deshacer remoción / Restaurar pista]
    
    ConfirmRemoval --> CheckLimit{¿Alcanzó límite de seguridad?<br>- Máx 62 vacíos / 19 pistas}
    UndoRemoval --> CheckLimit
    
    CheckLimit -- No --> PickCell
    CheckLimit -- Sí --> EndLoop[Fin del Bucle de Excavación]
    
    EndLoop --> EndAction[Emitir tablero al hilo principal con call_deferred]
    EndAction --> EndNode([Fin: Tablero instanciado en SceneTree])
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Actividades:** Este diagrama modela el algoritmo del generador en segundo plano. La decisión crítica es el blindaje de la esquina (Corner Shielding), que previene que la zona de solape pierda pistas resueltas, asegurando que la interconexión entre tableros no se corrompa en el proceso de excavación.

---

## 5. Diagrama de Secuencia (UML)

### TÍTULO: DIAGRAMA DE SECUENCIA PARA VALIDACIÓN Y PUNTUACIÓN EN TIEMPO REAL
```mermaid
sequenceDiagram
    autonumber
    actor Jugador as Jugador
    participant Cell as CellUI (cellv_2.gd)
    participant SM as ScoreManager (Autoload)
    participant Global as Global (Autoload)

    Jugador->>Cell: Introduce número (Teclado 1-9)
    activate Cell
    Cell->>SM: _on_cell_changed(board_id, coords, value, is_correct)
    activate SM
    Note over SM: Comprueba restricciones de vecindad y variables dinámicas en CSP
    SM-->>Cell: Retorna validación (is_correct)
    deactivate SM
    
    alt is_correct es True
        Cell->>Cell: Actualiza valor visual (Color gris oscuro)
        opt Celda es compartida (is_shared)
            Cell->>Cell: linked_cell.set_value_from_link(value)
            Note over Cell: Activa semáforo _syncing = true para romper bucle circular
        end
        Cell->>SM: Suma puntos por acierto (+10 pts)
        activate SM
        SM->>SM: Comprueba multiplicadores estructurales (fila/columna/bloque completos)
        SM->>Global: Notifica cambio de Score total
        deactivate SM
        Global->>Jugador: Actualiza UI del Score total en pantalla
    else is_correct es False
        Cell->>Cell: Pinta dígito en Rojo (feedback de error)
    end
    deactivate Cell
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Secuencia:** Modela la cronología de eventos cuando una celda recibe una entrada numérica. La sincronización lateral con la celda compartida (`linked_cell`) es bidireccional y se ejecuta inmediatamente de forma asíncrona, usando el semáforo `_syncing = true` para evitar desbordamientos de pila por recursividad cíclica.

---

## 6. Diagrama de Despliegue (UML)

### TÍTULO: DIAGRAMA DE DESPLIEGUE ARQUITECTÓNICO FÍSICO Y RED
```mermaid
graph TB
    subgraph ClientDevice ["Dispositivo Cliente (PC / Móvil)"]
        subgraph Runtime ["Godot Engine Runtime (GL Compatibility)"]
            App["SudokuSamurai++ (Artefacto Ejecutable)"]
        end
        subgraph FileSystem ["Almacenamiento Físico Local (User Directory)"]
            JSONDB["user://player_stats_&lt;user_id&gt;.json<br>(Estadísticas y mejores marcas JSON)"]
            CfgDB["user://player.cfg (Configuración de Invitado)"]
            LockoutCfg["user://auth_lockouts.cfg (Bloqueo local por Fuerza Bruta)"]
        end
    end

    subgraph SupabaseCloud ["Backend en la Nube (Supabase Cloud)"]
        subgraph APIService ["API Gateway & Middleware"]
            PostgREST["PostgREST Engine (API de Datos REST)"]
            GoTrue["GoTrue Auth Service (Autenticación JWT)"]
        end
        subgraph DBNode ["Servidor de Base de Datos relacional"]
            PostgreSQL[("PostgreSQL Database (Esquemas auth y public)")]
        end
    end

    %% Conexiones
    App <-->|Lectura/Escritura Local| FileSystem
    App ==>|Peticiones de Datos HTTPS/REST : 443| PostgREST
    App ==>|Autenticación y Registro HTTPS/Auth : 443| GoTrue
    PostgREST <-->|Consulta SQL Interna| PostgreSQL
    GoTrue <-->|Validación y Roles de Usuario| PostgreSQL
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación de Despliegue:** Mapea el entorno físico de ejecución y la topología de red. La comunicación externa se realiza desde el cliente Godot directamente hacia Supabase Cloud sobre HTTPS (puerto 443). El cliente interactúa con **GoTrue Auth** para iniciar sesión como docente/institución y con **PostgREST** para persistir datos y ejecutar RPCs de estudiante o de sincronización. A nivel local, los archivos de almacenamiento persistente (`user://`) se aíslan por usuario para permitir la compartición del dispositivo entre múltiples estudiantes sin conflicto de datos.

---

## 7. Diagrama Esquemático (No UML)

### TÍTULO: DIAGRAMA ESQUEMÁTICO DEL SISTEMA SAMURÁI DINÁMICO Y GEOMETRÍA DE SOLAPE
```mermaid
graph LR
    subgraph Tablero1 ["Tablero N (Predecesor)"]
        direction TB
        Grid1["Cuadrícula 9x9"]
        Exit1["Sector Solapado de Salida (3x3)<br>(p.ej., TOP_RIGHT)"]
        Grid1 -.-> Exit1
    end

    subgraph Overlap ["Zona de Solapamiento Físico (Coincidencia 3x3)"]
        SharedCells["9 Celdas Compartidas en Pantalla<br>(cell.link_to)"]
    end

    subgraph Tablero2 ["Tablero N+1 (Sucesor)"]
        direction TB
        Entrance2["Sector Solapado de Entrada (3x3)<br>(p.ej., BOTTOM_LEFT)"]
        Grid2["Cuadrícula 9x9"]
        Entrance2 -.-> Grid2
    end

    %% Transición Geométrica
    Exit1 ===|Coincide con| SharedCells
    SharedCells ===|Coincide con| Entrance2

    %% Desplazamiento Vectorial
    Tablero1 ===>|Desfase Matemático: CHAIN_OFFSET = 384px| Tablero2

    %% Leyenda
    Note[Visualización:<br>Ancho de Tablero: 576px (9 celdas)<br>Ancho de Solape: 192px (3 celdas)<br>Offset de Cadena = 576px - 192px = 384px]
```
### FUENTE: Elaboración propia del autor (2026).

*   **Explicación Esquemática:** Ilustración geométrica de la coincidencia física y traslación matemática de coordenadas locales entre el Tablero N (Salida) y el Tablero N+1 (Entrada). El desplazamiento de renderizado se calcula restando el área de coincidencia del ancho total del tablero, guiado por la dirección de solape seleccionada.
