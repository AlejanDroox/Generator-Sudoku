import express from 'express';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from '../config/supabase.js';
import { generatePDFResponse } from '../helpers/pdfGenerator.js';
import {
  getMockStudentData,
  getMockTeachersData,
  getMockStudentsListData,
  getMockLeaderboardData
} from '../helpers/mockData.js';

const router = express.Router();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const templatesPath = path.join(__dirname, '..', 'templates');

// 1. Ruta de Prueba: Devuelve el HTML renderizado directamente en el navegador con Mock Data
router.get('/test-report', (req, res) => {
  try {
    const templatePath = path.join(templatesPath, 'student_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');
    
    const mockData = getMockStudentData();
    
    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(mockData)});
        });
      </script>
    `;
    
    html = html.replace('</body>', `${scriptToInject}</body>`);
    res.send(html);
  } catch (error) {
    console.error("Error al cargar la plantilla:", error);
    res.status(500).send("Error al cargar la plantilla del reporte.");
  }
});

// 2. Endpoint POST: Genera y descarga el reporte individual de estudiante en formato PDF
router.post('/reportes/estudiantes', async (req, res) => {
  const { auth_token, estudiante_id, mock } = req.body;
  
  let reportData;

  if (mock || !estudiante_id) {
    reportData = getMockStudentData();
  } else {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${auth_token}` } }
      });

      // 1. Obtener datos del estudiante
      const { data: student, error: studentErr } = await supabase
        .from('estudiantes')
        .select('id, usuario, estadisticas, grupo:grupos(codigo_grupo)')
        .eq('id', estudiante_id)
        .single();

      if (studentErr || !student) throw new Error("Estudiante no encontrado o sin permisos.");

      // 2. Obtener su mejor partida del leaderboard
      const { data: games, error: gamesErr } = await supabase
        .from('leaderboards')
        .select('created_at, dificultad, modo, variantes_activas, puntuacion, tableros_completados, tiempo')
        .eq('estudiante_id', estudiante_id);

      if (gamesErr) throw new Error("Error al obtener el ranking del estudiante.");

      const statsBlob = student.estadisticas || {};
      const totalScore = statsBlob.total_puntos || 0;
      const gamesPlayed = statsBlob.total_partidas || 0;
      const avgTimeSeconds = gamesPlayed > 0 ? (statsBlob.total_tiempo || 0) / gamesPlayed : 0;
      const avgErrors = statsBlob.promedio_errores || 0;

      const difficulties = { 'Facil': 0, 'Medio': 0, 'Dificil': 0, 'Extremo': 0 };
      const scoreHistory = [];

      (games || []).forEach(g => {
        let diff = g.dificultad || 'Medio';
        diff = diff.charAt(0).toUpperCase() + diff.slice(1).toLowerCase();
        if (diff === 'Facil') diff = 'Facil';
        else if (diff === 'Medio') diff = 'Medio';
        else if (diff === 'Dificil') diff = 'Dificil';
        else if (diff === 'Extremo') diff = 'Extremo';

        if (difficulties[diff] !== undefined) {
          difficulties[diff]++;
        }
        scoreHistory.push(g.puntuacion || 0);
      });

      if (scoreHistory.length === 0) {
        scoreHistory.push(0);
      }

      reportData = {
        generatedAt: new Date().toISOString(),
        student: {
          nombre: student.usuario,
          usuario: student.usuario,
          grupo: student.grupo?.codigo_grupo || 'Sin Grupo'
        },
        stats: {
          totalScore,
          gamesPlayed,
          avgTimeSeconds,
          avgErrors
        },
        games: games || [],
        chartData: {
          scores: scoreHistory,
          difficulties
        }
      };
    } catch (dbError) {
      console.error("Error al consultar base de datos:", dbError);
      return res.status(500).json({ error: dbError.message });
    }
  }

  try {
    const templatePath = path.join(templatesPath, 'student_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');

    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(reportData)});
        });
      </script>
    `;
    html = html.replace('</body>', `${scriptToInject}</body>`);

    await generatePDFResponse(html, `reporte_${reportData.student.usuario}.pdf`, res);
  } catch (err) {
    res.status(500).send("Error al cargar la plantilla.");
  }
});

// 3. Endpoint POST: Genera el reporte de la lista de profesores de la institución
router.post('/reportes/profesores', async (req, res) => {
  const { auth_token, mock } = req.body;
  
  let reportData;

  if (mock) {
    reportData = getMockTeachersData();
  } else {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${auth_token}` } }
      });

      // Obtener la institución
      const { data: instData, error: instErr } = await supabase
        .from('instituciones')
        .select('nombre')
        .single();

      if (instErr || !instData) throw new Error("No se pudo obtener el perfil de la institución.");

      // Obtener profesores y contar sus alumnos
      const { data: teachers, error: teachersErr } = await supabase
        .from('profesores')
        .select('id, nombre, email, grupos(codigo_grupo, estudiantes(id))');

      if (teachersErr) throw new Error("Error al obtener la lista de profesores.");

      const formattedTeachers = (teachers || []).map(t => {
        const grupos = (t.grupos || []).map(g => ({
          codigo_grupo: g.codigo_grupo,
          estudiantes_count: g.estudiantes ? g.estudiantes.length : 0
        }));
        return {
          nombre: t.nombre,
          email: t.email,
          grupos
        };
      });

      reportData = {
        generatedAt: new Date().toISOString(),
        institution: instData,
        teachers: formattedTeachers
      };
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: err.message });
    }
  }

  try {
    const templatePath = path.join(templatesPath, 'teachers_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');

    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(reportData)});
        });
      </script>
    `;
    html = html.replace('</body>', `${scriptToInject}</body>`);

    await generatePDFResponse(html, 'reporte_profesores.pdf', res);
  } catch (err) {
    res.status(500).send("Error al cargar la plantilla.");
  }
});

// 4. Endpoint POST: Genera el listado de estudiantes (con o sin filtro por grupo)
router.post('/reportes/estudiantes/listado', async (req, res) => {
  const { auth_token, grupo_codigo, mock } = req.body;
  
  let reportData;

  if (mock) {
    reportData = getMockStudentsListData(grupo_codigo);
  } else {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${auth_token}` } }
      });

      const { data: students, error: studentsErr } = await supabase
        .from('estudiantes')
        .select('id, usuario, estadisticas, grupo:grupos(codigo_grupo)');

      if (studentsErr) throw new Error("Error al obtener la lista de estudiantes.");

      let filteredStudents = students || [];
      if (grupo_codigo) {
        filteredStudents = filteredStudents.filter(s => s.grupo?.codigo_grupo === grupo_codigo);
      }

      const formatted = filteredStudents.map(s => ({
        usuario: s.usuario,
        grupo_codigo: s.grupo?.codigo_grupo || 'Sin Grupo',
        estadisticas: s.estadisticas || {}
      }));

      reportData = {
        generatedAt: new Date().toISOString(),
        filterGroup: grupo_codigo || null,
        students: formatted
      };
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: err.message });
    }
  }

  try {
    const templatePath = path.join(templatesPath, 'students_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');

    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(reportData)});
        });
      </script>
    `;
    html = html.replace('</body>', `${scriptToInject}</body>`);

    await generatePDFResponse(html, 'listado_estudiantes.pdf', res);
  } catch (err) {
    res.status(500).send("Error al cargar la plantilla.");
  }
});

// 5. Endpoint POST: Generación en lote (un solo PDF multipágina para todos los estudiantes)
router.post('/reportes/estudiantes/lote', async (req, res) => {
  const { auth_token, grupo_codigo, mock } = req.body;
  
  let reportData;

  if (mock) {
    reportData = {
      generatedAt: new Date().toISOString(),
      students: [
        getMockStudentData("juan.perez26", "9no Grado Sección A"),
        getMockStudentData("andrea.mendez", "9no Grado Sección A")
      ]
    };
  } else {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${auth_token}` } }
      });

      // Obtener listado de estudiantes
      const { data: students, error: studentsErr } = await supabase
        .from('estudiantes')
        .select('id, usuario, estadisticas, grupo:grupos(codigo_grupo)');

      if (studentsErr) throw new Error("Error al obtener la lista de estudiantes.");

      let filteredStudents = students || [];
      if (grupo_codigo) {
        filteredStudents = filteredStudents.filter(s => s.grupo?.codigo_grupo === grupo_codigo);
      }

      if (filteredStudents.length === 0) {
        throw new Error("No se encontraron estudiantes para los criterios seleccionados.");
      }

      const studentIds = filteredStudents.map(s => s.id);

      // Obtener mejores partidas de leaderboards en una sola consulta
      const { data: leaderboardGames, error: lbErr } = await supabase
        .from('leaderboards')
        .select('estudiante_id, created_at, dificultad, modo, variantes_activas, puntuacion, tableros_completados, tiempo')
        .in('estudiante_id', studentIds);

      if (lbErr) throw new Error("Error al obtener clasificaciones de estudiantes.");

      const gamesByStudent = {};
      (leaderboardGames || []).forEach(g => {
        gamesByStudent[g.estudiante_id] = [g];
      });

      // Mapear cada estudiante a su bloque de reporte completo
      const batchStudents = filteredStudents.map(s => {
        const statsBlob = s.estadisticas || {};
        const gamesPlayed = statsBlob.total_partidas || 0;
        const totalScore = statsBlob.total_puntos || 0;
        const avgTimeSeconds = gamesPlayed > 0 ? (statsBlob.total_tiempo || 0) / gamesPlayed : 0;
        const avgErrors = statsBlob.promedio_errores || 0;

        const studentGames = gamesByStudent[s.id] || [];
        const difficulties = { 'Facil': 0, 'Medio': 0, 'Dificil': 0, 'Extremo': 0 };
        const scoreHistory = [];

        studentGames.forEach(g => {
          let diff = g.dificultad || 'Medio';
          diff = diff.charAt(0).toUpperCase() + diff.slice(1).toLowerCase();
          if (diff === 'Facil') diff = 'Facil';
          else if (diff === 'Medio') diff = 'Medio';
          else if (diff === 'Dificil') diff = 'Dificil';
          else if (diff === 'Extremo') diff = 'Extremo';

          if (difficulties[diff] !== undefined) {
            difficulties[diff]++;
          }
          scoreHistory.push(g.puntuacion || 0);
        });

        if (scoreHistory.length === 0) scoreHistory.push(0);

        return {
          id: s.id,
          student: {
            nombre: s.usuario,
            usuario: s.usuario,
            grupo: s.grupo?.codigo_grupo || 'Sin Grupo'
          },
          stats: {
            totalScore,
            gamesPlayed,
            avgTimeSeconds,
            avgErrors
          },
          games: studentGames,
          chartData: {
            scores: scoreHistory,
            difficulties
          }
        };
      });

      reportData = {
        generatedAt: new Date().toISOString(),
        students: batchStudents
      };
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: err.message });
    }
  }

  try {
    const templatePath = path.join(templatesPath, 'student_batch_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');

    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(reportData)});
        });
      </script>
    `;
    html = html.replace('</body>', `${scriptToInject}</body>`);

    await generatePDFResponse(html, 'reportes_lote_estudiantes.pdf', res);
  } catch (err) {
    res.status(500).send("Error al cargar la plantilla.");
  }
});

// 6. Endpoint POST: Generación del Leaderboard con todos los filtros del juego
router.post('/reportes/leaderboard', async (req, res) => {
  const { auth_token, modo, dificultad, grupo_codigo, variantes_activas, ordenacion, mock } = req.body;
  
  let reportData;

  if (mock) {
    reportData = getMockLeaderboardData(modo, dificultad, grupo_codigo, variantes_activas, ordenacion);
  } else {
    try {
      const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        global: { headers: { Authorization: `Bearer ${auth_token}` } }
      });

      // Obtener clasificaciones
      const { data: leaderboard, error: lbErr } = await supabase
        .from('leaderboards')
        .select(`
          dificultad, modo, variantes_activas, puntuacion, tableros_completados, tiempo, created_at,
          estudiante_id, estudiantes(usuario, grupo:grupos(codigo_grupo)),
          profesor_id, profesores(nombre)
        `);

      if (lbErr) throw new Error("Error al obtener la tabla de clasificaciones.");

      // Filtrar localmente en JS de forma robusta
      let filtered = leaderboard || [];

      if (modo) {
        filtered = filtered.filter(e => e.modo === modo);
      }
      if (dificultad) {
        filtered = filtered.filter(e => e.dificultad?.toLowerCase() === dificultad.toLowerCase());
      }
      if (grupo_codigo) {
        filtered = filtered.filter(e => {
          if (e.estudiante_id) {
            return e.estudiantes?.grupo?.codigo_grupo === grupo_codigo;
          }
          return false;
        });
      }
      if (variantes_activas && Array.isArray(variantes_activas) && variantes_activas.length > 0) {
        filtered = filtered.filter(e => {
          const active = e.variantes_activas || [];
          return variantes_activas.every(v => active.includes(v));
        });
      }

      // Ordenación según la lógica exacta de leaderboard.gd
      if (ordenacion === 'boards') {
        filtered.sort((a, b) => {
          const tabA = a.tableros_completados || 0;
          const tabB = b.tableros_completados || 0;
          if (tabA !== tabB) return tabB - tabA; // Más tableros primero
          
          const scoreA = a.puntuacion || 0;
          const scoreB = b.puntuacion || 0;
          if (scoreA !== scoreB) return scoreB - scoreA;
          
          return (a.tiempo || 0) - (b.tiempo || 0);
        });
      } else {
        // Ordenación por score (defecto)
        filtered.sort((a, b) => {
          const scoreA = a.puntuacion || 0;
          const scoreB = b.puntuacion || 0;
          if (scoreA !== scoreB) return scoreB - scoreA;
          
          const tabA = a.tableros_completados || 0;
          const tabB = b.tableros_completados || 0;
          if (tabA !== tabB) return tabA - tabB;
          
          return (a.tiempo || 0) - (b.tiempo || 0);
        });
      }

      const formatted = filtered.map(e => ({
        nombre: e.profesor_id ? e.profesores?.nombre : e.estudiantes?.usuario,
        grupo_codigo: e.profesor_id ? 'Profesor' : (e.estudiantes?.grupo?.codigo_grupo || 'Sin Grupo'),
        modo: e.modo,
        dificultad: e.dificultad,
        variantes_activas: e.variantes_activas || [],
        tableros_completados: e.tableros_completados || 0,
        puntuacion: e.puntuacion || 0,
        tiempo: e.tiempo || 0
      }));

      reportData = {
        generatedAt: new Date().toISOString(),
        filters: { modo, dificultad, grupo_codigo, variantes_activas, ordenacion },
        leaderboard: formatted
      };
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: err.message });
    }
  }

  try {
    const templatePath = path.join(templatesPath, 'leaderboard_report.html');
    let html = fs.readFileSync(templatePath, 'utf8');

    const scriptToInject = `
      <script>
        document.addEventListener('DOMContentLoaded', () => {
          initReport(${JSON.stringify(reportData)});
        });
      </script>
    `;
    html = html.replace('</body>', `${scriptToInject}</body>`);

    await generatePDFResponse(html, 'reporte_leaderboard.pdf', res);
  } catch (err) {
    res.status(500).send("Error al cargar la plantilla.");
  }
});

export default router;
