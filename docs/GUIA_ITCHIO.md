# 🎮 Guía de Publicación en itch.io — Sudoku Samurái++

Esta guía describe los pasos necesarios para exportar el juego desde **Godot Engine 4.x** y publicarlo en **itch.io** de manera limpia, optimizada y profesional.

---

## 1. Modos de Publicación Recomendados

Para publicar en itch.io, te recomendamos ofrecer dos opciones a tus jugadores:
1. **Juego en el Navegador (HTML5 / WebGL)**: Permite a los usuarios jugar inmediatamente sin descargar nada.
2. **Descargables (Windows Desktop & APK Android)**: Excelente para jugadores que prefieren la versión de escritorio o instalar el juego en sus celulares.

---

## 2. Pasos para Exportar en Godot 4.x

### Paso 1: Configurar los Presets de Exportación
1. Abre el proyecto en Godot Engine (`nuevo-proyecto-de-juego/project.godot`).
2. Ve al menú superior **Proyecto** → **Exportar...**.
3. Verás los presets ya configurados:
   - **Web (HTML5)** *(Si no está, haz clic en "Añadir..." → "Web")*.
   - **Windows Desktop**.
   - **Android**.

### Paso 2: Exportar a Web (HTML5)
1. Selecciona el preset **Web (HTML5)**.
2. Asegúrate de desactivar temporalmente las opciones de depuración si no son necesarias.
3. Haz clic en **Exportar proyecto...**.
4. Crea una carpeta vacía llamada `build_web` y exporta el archivo como `index.html`.
5. Comprime todo el contenido de la carpeta `build_web` (donde están `index.html`, `index.pck`, `index.wasm`, etc.) en un archivo `.zip` llamado `sudoku_samurai_web.zip`.

> [!IMPORTANT]
> El archivo HTML principal DEBE llamarse obligatoriamente `index.html` para que el reproductor de itch.io lo reconozca automáticamente.

### Paso 3: Exportar a Windows Desktop
1. Selecciona el preset **Windows Desktop**.
2. Haz clic en **Exportar proyecto...** y guarda los archivos en una carpeta `build_windows` como `SudokuSamurai.exe`.
3. Comprime el archivo `.exe` junto a sus archivos acompañantes en `sudoku_samurai_windows.zip`.

---

## 3. Crear y Configurar la Página en itch.io

1. Inicia sesión en [itch.io](https://itch.io/) y ve a tu Panel de Control (**Dashboard**).
2. Haz clic en **Create new project** (Crear nuevo proyecto).
3. Completa la información del juego:
   - **Title**: *Sudoku Samurái++*
   - **Project URL**: `https://tu-usuario.itch.io/sudoku-samurai`
   - **Classification**: *Games*
   - **Kind of project**: Selecciona **HTML** (si subes la versión Web) o **Downloadable**.
   - **Pricing**: *No payments / Free* (o donaciones opcionales si lo deseas).
4. **Subir Archivos (Uploads)**:
   - Sube `sudoku_samurai_web.zip` y marca la casilla **"This file will be played inside the browser"**.
   - Sube `sudoku_samurai_windows.zip` y marca **"Executable"** para Windows.
   - Sube la APK de Android (si la exportaste) y marca **"Android"**.
5. **Configuración del Embed (Navegador)**:
   - **Embed options**: Selecciona *Embed in page*.
   - **Viewport dimensions**: `1024` x `768` (o activa la casilla *Mobile friendly* / *Fullscreen button*).
6. **Detalles y Descripción**:
   - Agrega capturas de pantalla atractivas.
   - Redacta una descripción destacando que el juego utiliza algoritmos CSP/AC-3 para garantizar soluciones únicas y que incluye integración escolar y ranking en tiempo real.
   - Añade etiquetas (Tags): `Sudoku`, `Puzzle`, `Godot Engine`, `Open Source`, `Educational`, `Artificial Intelligence`.
7. **Visibilidad**:
   - Cambia el estado a **Public** cuando estés listo y guarda los cambios.

---

## 4. Verificación Post-Lanzamiento

- Abre la página de itch.io en una ventana de incógnito y prueba jugar la versión HTML5 en el navegador.
- Verifica que el juego conecte correctamente a la base de datos de Supabase.
- Enlace tu repositorio de GitHub en la descripción de itch.io para que la comunidad pueda explorar el código Open Source.
