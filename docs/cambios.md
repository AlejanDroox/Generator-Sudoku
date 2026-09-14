# Plan de Implementación: Actualización de Documentación y Diagramas de la Base de Datos (v2)

Este plan describe las modificaciones necesarias en el archivo de la tesis ([proyecto 2026 informática.md](file:///c:/Users/USER/Documents/godot/RLS/proyecto%202026%20inform%C3%A1tica.md)), en el archivo de especificaciones de diagramas ([DIAGRAMAS_ARQUITECTURA.md](file:///c:/Users/USER/Documents/godot/RLS/DIAGRAMAS_ARQUITECTURA.md)) y en la guía técnica ([ANALISIS_TECNICO.md](file:///c:/Users/USER/Documents/godot/RLS/ANALISIS_TECNICO.md)) para alinearlos con los cambios recientes de la base de datos (v2).

## Resumen del Estado de la Base de Datos Actual (v2)

Al evaluar el estado actual del proyecto, se identificaron los siguientes aspectos clave de la base de datos:
1. **Esquema Relacional Multirrol:** Se pasó de una estructura simple (`usuarios` y `clasificacion`) a un modelo escolar robusto con 6 tablas en Supabase:
   - `instituciones`: Perfil 1:1 con `auth.users` administrado por Supabase Auth.
   - `profesores`: Perfil 1:1 con `auth.users`, incluye estadísticas de juego acumuladas en formato `JSONB`.
   - `grupos`: Secciones o grados a cargo de un profesor en una institución.
   - `estudiantes`: Autenticación personalizada (RPC con usuario + PIN de 6 dígitos) y control de bloqueo por fuerza bruta.
   - `sesiones_estudiantes`: Tokens de sesión temporales (expiran en 24h) válidos para evaluar políticas RLS.
   - `leaderboards`: Tabla de posiciones global parametrizada por dificultad, modo y variantes, gestionada por un trigger que mantiene un único récord por jugador siguiendo la jerarquía: `puntuacion DESC -> tableros_completados DESC -> tiempo ASC`.
2. **Protección contra Fuerza Bruta (Lockout):** Se implementaron columnas `intentos_fallidos` y `bloqueado_hasta` en la tabla de `estudiantes` y lógica de negocio tanto en la base de datos (`login_estudiante`) como en el cliente de Godot (`AuthManager.gd`) para aplicar un bloqueo temporal de 1 minuto tras 5 intentos fallidos consecutivos.
3. **Control de Sincronización Manual:** Las funciones `sincronizar_estudiante` y `sincronizar_profesor` limitan a un máximo de 2 sincronizaciones manuales por día, permitiendo sincronizaciones automáticas ilimitadas (por ejemplo, en el logout).
4. **Seguridad Avanzada con RLS:** Políticas granulares en Supabase que aíslan y segmentan la visualización del ranking y datos escolares de acuerdo con el rol (las instituciones administran sus profesores/grupos, los profesores ven sus grupos/estudiantes y los estudiantes solo ven su propio perfil y el ranking interno de su grupo).

---

## Cambios Propuestos

### 1. Documento de la Tesis
#### [MODIFY] [proyecto 2026 informática.md](file:///c:/Users/USER/Documents/godot/RLS/proyecto%202026%20inform%C3%A1tica.md)
* **Actualización de la Figura N° 2 (Diagrama Entidad-Relación - DER):**
  - Reemplazar el diagrama Mermaid antiguo (`usuarios`, `clasificacion`, `historial_local`) con el nuevo modelo relacional completo de 6 tablas.
  - Actualizar la **Explicación de Datos** debajo de la Figura N° 2 para detallar formalmente el rol de cada tabla, las claves foráneas, las restricciones de unicidad, el almacenamiento JSONB y la persistencia local de estadísticas en archivos `user://player_stats_<user_id>.json` (en lugar de `player_history.json`).
* **Actualización de la Figura N° 4 (Diagrama de Componentes):**
  - Actualizar el bloque de la capa de persistencia para incluir `AuthManager.gd` como Singleton de control de sesión y detallar la delegación de `RemoteDB.gd` en los sub-servicios (`RemoteAuth`, `RemoteSync`, `RemoteLeaderboard` y `RemoteCrud`).
  - Ajustar el texto descriptivo del diagrama.
* **Actualización de la Figura N° 7 (Diagrama de Despliegue):**
  - Actualizar el almacenamiento físico local del cliente para reflejar los archivos `player_stats_<user_id>.json`, `player.cfg` y `auth_lockouts.cfg`.
  - Agregar el servicio `GoTrue Auth Service` en la nube al lado del motor `PostgREST Engine` para la autenticación de staff (institución/profesores).
  - Ajustar el texto explicativo del despliegue.
* **Corrección de Referencias de Archivos Locales:**
  - Actualizar la referencia de `user://player_history.json` a `user://player_stats_<user_id>.json` en la Sección 3.5 (Recolección de Datos) para mantener la consistencia metodológica.

### 2. Especificación de Diagramas
#### [MODIFY] [DIAGRAMAS_ARQUITECTURA.md](file:///c:/Users/USER/Documents/godot/RLS/DIAGRAMAS_ARQUITECTURA.md)
* Actualizar el Mermaid del **Diagrama Entidad-Relación (1. DER / Modelo de Datos)**.
* Actualizar el Mermaid del **Diagrama de Componentes (3. Componentes)**.
* Actualizar el Mermaid del **Diagrama de Despliegue (6. Despliegue)**.

### 3. Análisis Técnico
#### [MODIFY] [ANALISIS_TECNICO.md](file:///c:/Users/USER/Documents/godot/RLS/ANALISIS_TECNICO.md)
* **Actualización de la Sección 6 (Persistencia y Cloud API):**
  - Reemplazar el diagrama de secuencia de sincronización con el nuevo flujo que pasa por `AuthManager.gd` e invoca las RPCs (`sincronizar_estudiante`/`sincronizar_profesor`) y los envíos de puntuación correspondientes.
  - Eliminar la lógica obsoleta de "Upsert en Dos Fases" (que correspondía al antiguo leaderboard público) y reemplazarla con la explicación técnica de la autenticación escolar en Supabase (GoTrue para staff, PIN + token para estudiantes), el control de lockout y la limitación diaria de sincronizaciones manuales.
  - Cambiar el recuadro "Estado de Seguridad del Proyecto y RLS" (que indicaba que todo era público y transitorio) por una sección formal que valide que las políticas de seguridad RLS ya están completamente activadas e implementadas en producción, garantizando la privacidad de los datos escolares.

---

## Plan de Verificación

Dado que este requerimiento consiste en la actualización de documentos de diseño y especificaciones teóricas en Markdown (tesis y guías), la verificación se centrará en:
1. **Validación Sintáctica de Mermaid:** Comprobar que todos los bloques de código `mermaid` modificados se rendericen correctamente y no contengan errores de sintaxis (uso correcto de comillas, saltos de línea y nombres de nodos).
2. **Consistencia de Nombres e Identificadores:** Asegurar que los nombres de las tablas y campos coincidan exactamente con lo declarado en los archivos de base de datos (`setup_database_v2.sql`).
3. **Revisión Ortográfica y Estilo:** Mantener el lenguaje académico, técnico y formal en español empleado a lo largo de toda la tesis.
