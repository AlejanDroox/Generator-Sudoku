export const getMockStudentData = (usuario = "juan.perez26", grupo = "9no Grado Sección B") => {
  return {
    id: `mock-est-${usuario}`,
    student: {
      nombre: usuario.replace('.', ' ').replace(/\b\w/g, c => c.toUpperCase()),
      usuario: usuario,
      grupo: grupo
    },
    stats: {
      totalScore: 24850,
      gamesPlayed: 18,
      avgTimeSeconds: 432,
      avgErrors: 1.2
    },
    games: [
      { fecha: '2026-07-10T14:32:00Z', dificultad: 'Dificil', modo: 'challenge', variantes_activas: ['killer'], puntuacion: 2450, tiempo: 520, tableros_completados: 1 },
      { fecha: '2026-07-09T18:15:00Z', dificultad: 'Medio', modo: 'practice', variantes_activas: [], puntuacion: 1250, tiempo: 340, tableros_completados: 1 },
      { fecha: '2026-07-08T11:05:00Z', dificultad: 'Extremo', modo: 'challenge', variantes_activas: ['thermo', 'anti_knight'], puntuacion: 4800, tiempo: 980, tableros_completados: 3 }
    ],
    chartData: {
      scores: [850, 980, 1250, 1100, 1650, 2100, 2450, 2200, 3100, 4800],
      difficulties: {
        'Facil': 4,
        'Medio': 8,
        'Dificil': 4,
        'Extremo': 2
      }
    }
  };
};

export const getMockTeachersData = () => {
  return {
    generatedAt: new Date().toISOString(),
    institution: { nombre: "Instituto Nacional San Martín" },
    teachers: [
      { nombre: "Dra. María Eugenia Rojas", email: "mrojas@colegio.edu", grupos: [ { codigo_grupo: "9A", estudiantes_count: 24 }, { codigo_grupo: "9B", estudiantes_count: 22 } ] },
      { nombre: "Lic. Carlos Alberto Gómez", email: "cgomez@colegio.edu", grupos: [ { codigo_grupo: "10A", estudiantes_count: 28 } ] },
      { nombre: "Prof. Ana Lucía Torres", email: "atorres@colegio.edu", grupos: [ { codigo_grupo: "11A", estudiantes_count: 18 }, { codigo_grupo: "11B", estudiantes_count: 15 } ] }
    ]
  };
};

export const getMockStudentsListData = (grupo_codigo) => {
  const mockStudents = [
    { usuario: "alumno.01", grupo_codigo: "9A", estadisticas: { total_partidas: 15, total_tableros_completados: 12, total_puntos: 18500, total_tiempo: 5400, promedio_errores: 1.2 } },
    { usuario: "alumno.02", grupo_codigo: "9A", estadisticas: { total_partidas: 18, total_tableros_completados: 15, total_puntos: 24800, total_tiempo: 6800, promedio_errores: 0.8 } },
    { usuario: "alumno.03", grupo_codigo: "9B", estadisticas: { total_partidas: 10, total_tableros_completados: 8, total_puntos: 9200, total_tiempo: 3800, promedio_errores: 2.1 } },
    { usuario: "alumno.04", grupo_codigo: "10A", estadisticas: { total_partidas: 22, total_tableros_completados: 20, total_puntos: 35000, total_tiempo: 8900, promedio_errores: 0.5 } }
  ];
  const filtered = grupo_codigo ? mockStudents.filter(s => s.grupo_codigo === grupo_codigo) : mockStudents;
  return {
    generatedAt: new Date().toISOString(),
    filterGroup: grupo_codigo || null,
    students: filtered
  };
};

export const getMockLeaderboardData = (modo, dificultad, grupo_codigo, variantes_activas, ordenacion) => {
  const mockLeaderboard = [
    { nombre: "Andrea Sofía Méndez", grupo_codigo: "9A", modo: "challenge", dificultad: "Medio", variantes_activas: ["thermo"], tableros_completados: 2, puntuacion: 3100, tiempo: 420 },
    { nombre: "Juan Esteban Pérez", grupo_codigo: "9A", modo: "challenge", dificultad: "Dificil", variantes_activas: ["killer"], tableros_completados: 1, puntuacion: 2450, tiempo: 520 },
    { nombre: "Lucas Daniel Rivas", grupo_codigo: "9B", modo: "practice", dificultad: "Facil", variantes_activas: [], tableros_completados: 1, puntuacion: 1250, tiempo: 320 }
  ];

  let filtered = mockLeaderboard;
  if (modo) filtered = filtered.filter(e => e.modo === modo);
  if (dificultad) filtered = filtered.filter(e => e.dificultad.toLowerCase() === dificultad.toLowerCase());
  if (grupo_codigo) filtered = filtered.filter(e => e.grupo_codigo === grupo_codigo);
  if (variantes_activas && variantes_activas.length > 0) {
    filtered = filtered.filter(e => variantes_activas.every(v => e.variantes_activas.includes(v)));
  }

  if (ordenacion === 'boards') {
    filtered.sort((a, b) => b.tableros_completados - a.tableros_completados || b.puntuacion - a.puntuacion || a.tiempo - b.tiempo);
  } else {
    filtered.sort((a, b) => b.puntuacion - a.puntuacion || a.tableros_completados - b.tableros_completados || a.tiempo - b.tiempo);
  }

  return {
    generatedAt: new Date().toISOString(),
    filters: { modo, dificultad, grupo_codigo, variantes_activas, ordenacion },
    leaderboard: filtered
  };
};
