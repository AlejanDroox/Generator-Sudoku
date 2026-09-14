# 🧩 Sudoku Samurái++ (RLS)

![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6+-478CBF?logo=godotengine&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Backend](https://img.shields.io/badge/Backend-Supabase_Cloud-3ECF8E?logo=supabase&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Web_%7C_Windows_%7C_Android-blue)

**Sudoku Samurái++** es una aplicación lúdica y educativa desarrollada en **Godot Engine 4.x**. El proyecto combina un motor de Inteligencia Artificial Clásica con resolutores CSP (Constraint Satisfaction Problem), algoritmo AC-3 y máscaras de bits (bitmasking), integrando un sistema de persistencia híbrido (local y remota con **Supabase Cloud**) orientado al entorno escolar y competitivo.

---

## 🚀 Características Principales

- **Tableros Samurái Dinámicos**: Geometría interactiva en zigzag con 5 sub-tableros solapados y propagación de restricciones en tiempo real.
- **Motor de IA y Generación Adaptativa**: 
  - Resolutor CSP con **Backtracking Heurístico** y **AC-3**.
  - Garantía matemática de unicidad de solución en tiempo real.
  - Generación adaptativa por niveles de dificultad (*Fácil, Medio, Difícil, Samurái*).
- **Entorno Multirrol Escolar & Autenticación RLS**:
  - Autenticación institucional/profesores mediante **Supabase Auth (GoTrue)**.
  - Autenticación ligera para estudiantes mediante **Usuario + PIN de 6 dígitos** (RPC seguro).
  - Control de acceso por filas (**Row-Level Security / RLS**) que aísla datos de grupos y alumnos.
- **Servicio de Reportes en la Nube (`report-service-api`)**:
  - API en Node.js para la generación y filtrado de reportes en PDF.
- **Multiplataforma**: Listo para ser exportado a **HTML5 Web**, **Windows Desktop** y **Android**.

---

## 📁 Estructura del Repositorio

```text
RLS/
├── docs/                        # Documentación técnica, diagramas y reportes
│   ├── ANALISIS_TECNICO.md
│   ├── DIAGRAMAS_ARQUITECTURA.md
│   ├── GUIA_ITCHIO.md           # 👈 Guía paso a paso para publicar en itch.io
│   ├── explicacion_api_reportes.md
│   └── test_reports/            # Muestras de reportes PDF generados
├── nuevo-proyecto-de-juego/     # Código fuente del cliente Godot 4
│   ├── BD/                      # Scripts SQL para configuración de Supabase
│   ├── UI/ & scenas/            # Escenas de interfaz y tableros
│   ├── scripts/                 # Lógica de juego, IA (CSP/AC-3) y fachada Supabase
│   ├── tests/                   # Escenas y scripts de pruebas de estrés e IA
│   └── report-service-api/      # Microservicio Node.js para generación de PDFs
└── README.md                    # Documento principal del repositorio
```

---

## 🛠️ Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-usuario/sudoku-samurai.git
cd sudoku-samurai
```

### 2. Abrir en Godot Engine

1. Descarga e instala **Godot Engine 4.x** (versión Standard de 64-bits).
2. Abre Godot, selecciona **Importar** y busca el archivo `project.godot` dentro de la carpeta `nuevo-proyecto-de-juego/`.
3. Presiona **F5** o haz clic en **Ejecutar Proyecto**.

### 3. Configurar la Base de Datos (Supabase)

1. Crea un proyecto en [Supabase Cloud](https://supabase.com/).
2. Dirígete al **SQL Editor** de Supabase y ejecuta el script de base de datos ubicado en:
   `nuevo-proyecto-de-juego/BD/setup_database_v2.sql`
3. En el cliente Godot, puedes definir tus propias credenciales en `user://env.cfg` o mediante variables de entorno del sistema (`SUPABASE_URL` y `SUPABASE_ANON_KEY`).

---

## 🎮 Publicación en itch.io

Para preparar los ejecutables y subir el juego a **itch.io**, consulta nuestra [Guía de Publicación en itch.io](docs/GUIA_ITCHIO.md).

---

## 📜 Licencia

Este proyecto está distribuido bajo la licencia **MIT**. Consulta el archivo `LICENSE` para más información.
