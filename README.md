# 🧩 Sudoku Samurai++

![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6+-478CBF?logo=godotengine&logoColor=white)
![License](https://img.shields.io/badge/License-GNU_GPLv3-blue.svg)
![Backend](https://img.shields.io/badge/Backend-Supabase_Cloud-3ECF8E?logo=supabase&logoColor=white)

---

## 📌 Project Context

This software was originally created as a university project. Due to academic requirements and evaluation criteria, the project had to be presented as a tool for an educational/school environment. For this reason, it includes features such as a **user authentication system** (for institutions, teachers, and students) and a **PDF report generator**.

These features were implemented with **just what was strictly necessary** to satisfy the academic submission, so they might not be fully polished.

> [!NOTE]
> **Language Notice**: I am a native Spanish speaker, so all code comments within GDScript and project documentation files are written in Spanish.

### 💡 Primary Goal & Future Plans
My main personal goal for this project was to build a **real-time Sudoku generator supporting variants**, which was successfully achieved!

In the future, I plan to add new Sudoku variants, but only after evaluating and implementing performance optimizations to lower generation times.

---

## ⚙️ How the Core Sudoku Engine Works

The core game and algorithmic logic is written in GDScript and optimized to solve and generate boards in real time:

1. **CSP & AC-3 (Constraint Satisfaction Problem)**:
   - Treats each Sudoku cell as a variable with a domain of values `[1..9]`.
   - Uses **Arc Consistency (AC-3)** to propagate constraints across rows, columns, 3x3 regions, and special variant rules (such as overlapping regions).
2. **Backtracking with Heuristic & Bitmasking**:
   - Uses bitmasks to accelerate validation and candidate checking.
   - The solver employs backtracking search prioritized by the **Minimum Remaining Values (MRV)** heuristic (selecting cells with the fewest valid options left).
3. **Uniqueness Guarantee & Clue Digging**:
   - After generating a fully valid solved board, clues are progressively carved out while verifying at each step that the puzzle retains a unique valid solution.
4. **Samurai Overlapping Geometry**:
   - Connects 5 sub-boards of 9x9 in a cross/zigzag structure where the 4 corner boards share 3x3 sub-regions with the central board. Constraint propagation automatically updates shared cells in real time.

---

## 📁 Repository Structure

```text
RLS/
├── docs/                        # Technical documentation, diagrams, and sample reports
│   ├── ANALISIS_TECNICO.md
│   ├── DIAGRAMAS_ARQUITECTURA.md
│   └── test_reports/            # Generated PDF report samples
├── nuevo-proyecto-de-juego/     # Godot 4 game source code
│   ├── BD/                      # SQL setup scripts for Supabase
│   ├── UI/ & scenas/            # UI scenes and game boards
│   ├── scripts/                 # Core game logic, AI solvers, and backend integration
│   ├── tests/                   # Stress test scenes and scripts
│   └── report-service-api/      # Node.js microservice for PDF generation
└── README.md
```

---

## 🛠️ How to Run and Develop

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/sudoku-samurai.git
   cd sudoku-samurai
   ```
2. **Open in Godot 4**:
   - Download and install **Godot Engine 4.x**.
   - Import the project by selecting `nuevo-proyecto-de-juego/project.godot`.
   - Run by pressing **F5**.

*(Optional: If you want to test the Supabase backend or PDF report generator, SQL scripts are located in `nuevo-proyecto-de-juego/BD/setup_database_v2.sql` and the Node.js microservice is in `nuevo-proyecto-de-juego/report-service-api/`).*

---

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GNU GPLv3)**. See the [`LICENSE`](LICENSE) file for details.
