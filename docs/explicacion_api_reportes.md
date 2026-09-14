# Documentación del Servidor de Reportes PDF (Modularizado)

Este documento contiene la explicación de la arquitectura modularizada del microservicio de reportes y la guía de referencia para cada uno de los endpoints de la API REST, incluyendo enlaces directos a sus plantillas y ejemplos de uso.

---

## 1. Estructura de Archivos Modularizada

El código de la API se dividió en partes enfocadas para facilitar su mantenimiento y escalabilidad:

*   **Punto de Entrada ([server.js](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/server.js)):** Inicializa Express, aplica middlewares (CORS y parser JSON) y registra las rutas.
*   **Configuración ([config/supabase.js](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/config/supabase.js)):** Concentra los parámetros y claves del cliente de Supabase.
*   **Generador PDF ([helpers/pdfGenerator.js](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/helpers/pdfGenerator.js)):** Contiene la lógica de automatización de Puppeteer (headless browser) para renderizar HTML y exportar a PDF en formato A4 con márgenes y retraso preventivo para Chart.js.
*   **Datos de Simulación ([helpers/mockData.js](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/helpers/mockData.js)):** Centraliza los generadores de Mock Data para realizar pruebas independientes de base de datos.
*   **Enrutador ([routes/reports.js](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/routes/reports.js)):** Define todos los endpoints y maneja las consultas reales de Supabase (integrando RLS).

---

## 2. Detalle de Endpoints y Reportes

A continuación se detallan los endpoints disponibles en el prefijo `/api` (corriendo en `http://localhost:3000` por defecto):

---

### 1. Vista de Prueba en Navegador
*   **Método:** `GET`
*   **Ruta:** `/api/test-report`
*   **Descripción:** Renderiza directamente el HTML en el navegador usando datos de simulación. Es ideal para validar cambios visuales en caliente.
*   **Plantilla Relacionada:** [student_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/student_report.html)
*   **Enlace de Prueba Local:** [http://localhost:3000/api/test-report](http://localhost:3000/api/test-report)

---

### 2. Reporte de Estadísticas Individuales de Estudiante
*   **Método:** `POST`
*   **Ruta:** `/api/reportes/estudiantes`
*   **Descripción:** Genera el reporte de rendimiento escolar de un estudiante específico en formato PDF, mostrando estadísticas generales y su mejor partida en el leaderboard.
*   **Plantilla Relacionada:** [student_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/student_report.html)
*   **Cuerpo de la Petición (Request Body):**
    ```json
    {
      "auth_token": "TOKEN_JWT_DE_SESION",
      "estudiante_id": "UUID_DEL_ESTUDIANTE",
      "mock": false
    }
    ```
*   **Ejemplo de Comando de Prueba (PowerShell):**
    ```powershell
    Invoke-RestMethod -Uri "http://localhost:3000/api/reportes/estudiantes" -Method Post -ContentType "application/json" -Body '{"mock":true}' -OutFile "test_estudiante.pdf"
    ```

---

### 3. Reporte de Personal Docente (Profesores)
*   **Método:** `POST`
*   **Ruta:** `/api/reportes/profesores`
*   **Descripción:** Genera un reporte PDF con la lista de profesores de la institución educativa, detallando sus grupos asignados y la matrícula de estudiantes de cada grupo.
*   **Plantilla Relacionada:** [teachers_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/teachers_report.html)
*   **Cuerpo de la Petición:**
    ```json
    {
      "auth_token": "TOKEN_JWT_DE_SESION_INSTITUCION",
      "mock": false
    }
    ```
*   **Ejemplo de Comando de Prueba (PowerShell):**
    ```powershell
    Invoke-RestMethod -Uri "http://localhost:3000/api/reportes/profesores" -Method Post -ContentType "application/json" -Body '{"mock":true}' -OutFile "test_profesores.pdf"
    ```

---

### 4. Reporte de Listado de Estudiantes
*   **Método:** `POST`
*   **Ruta:** `/api/reportes/estudiantes/listado`
*   **Descripción:** Exporta un reporte con la lista de estudiantes registrados. Se puede filtrar por un grupo específico o generar la lista global. Muestra estadísticas acumuladas principales.
*   **Plantilla Relacionada:** [students_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/students_report.html)
*   **Cuerpo de la Petición:**
    ```json
    {
      "auth_token": "TOKEN_JWT_DE_SESION",
      "grupo_codigo": "9A", 
      "mock": false
    }
    ```
    *(Nota: `grupo_codigo` es opcional; si se omite, se genera el listado general).*
*   **Ejemplo de Comando de Prueba (PowerShell):**
    ```powershell
    Invoke-RestMethod -Uri "http://localhost:3000/api/reportes/estudiantes/listado" -Method Post -ContentType "application/json" -Body '{"mock":true, "grupo_codigo":"9A"}' -OutFile "test_estudiantes.pdf"
    ```

---

### 5. Reporte de Estadísticas en Lote (Batch)
*   **Método:** `POST`
*   **Ruta:** `/api/reportes/estudiantes/lote`
*   **Descripción:** Genera en un único PDF multipágina los reportes individuales y detallados de todos los estudiantes de un grupo o de la institución completa.
*   **Plantilla Relacionada:** [student_batch_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/student_batch_report.html)
*   **Cuerpo de la Petición:**
    ```json
    {
      "auth_token": "TOKEN_JWT_DE_SESION",
      "grupo_codigo": "9A",
      "mock": false
    }
    ```
    *(Nota: `grupo_codigo` es opcional; si se omite, procesa el lote completo de la institución).*
*   **Ejemplo de Comando de Prueba (PowerShell):**
    ```powershell
    Invoke-RestMethod -Uri "http://localhost:3000/api/reportes/estudiantes/lote" -Method Post -ContentType "application/json" -Body '{"mock":true}' -OutFile "test_lote_estudiantes.pdf"
    ```

---

### 6. Reporte de Leaderboard con Filtros Avanzados
*   **Método:** `POST`
*   **Ruta:** `/api/reportes/leaderboard`
*   **Descripción:** Genera el reporte del ranking de posiciones. Integra los mismos filtros y opciones del juego, ordenando dinámicamente por puntaje o por más tableros completados.
*   **Plantilla Relacionada:** [leaderboard_report.html](file:///c:/Users/USER/Documents/godot/RLS/nuevo-proyecto-de-juego/report-service-api/templates/leaderboard_report.html)
*   **Cuerpo de la Petición:**
    ```json
    {
      "auth_token": "TOKEN_JWT_DE_SESION",
      "modo": "challenge",               
      "dificultad": "dificil",            
      "grupo_codigo": "9A",               
      "variantes_activas": ["anti_knight"],
      "ordenacion": "score",              
      "mock": false
    }
    ```
    *(Nota: Todos los parámetros de filtrado son opcionales. El parámetro `ordenacion` acepta `"score"` o `"boards"`).*
*   **Ejemplo de Comando de Prueba (PowerShell):**
    ```powershell
    Invoke-RestMethod -Uri "http://localhost:3000/api/reportes/leaderboard" -Method Post -ContentType "application/json" -Body '{"mock":true, "modo":"challenge", "dificultad":"dificil", "variantes_activas":["anti_knight"], "ordenacion":"score"}' -OutFile "test_leaderboard.pdf"
    ```
