import express from 'express';
import cors from 'cors';
import reportsRouter from './routes/reports.js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Registrar las rutas de reportes
app.use('/api', reportsRouter);

// Iniciar servidor
app.listen(PORT, () => {
  console.log(`==================================================`);
  console.log(`Servidor de reportes corriendo en http://localhost:${PORT}`);
  console.log(`Prueba visual de plantilla: http://localhost:${PORT}/api/test-report`);
  console.log(`==================================================`);
});
