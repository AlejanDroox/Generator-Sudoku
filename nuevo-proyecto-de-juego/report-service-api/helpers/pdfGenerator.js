import puppeteer from 'puppeteer';
import fs from 'fs';

export const getBrowserExecutablePath = () => {
  if (process.env.PUPPETEER_EXECUTABLE_PATH) {
    return process.env.PUPPETEER_EXECUTABLE_PATH;
  }
  
  if (process.platform === 'win32') {
    const paths = [
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      `${process.env.LOCALAPPDATA}\\Google\\Chrome\\Application\\chrome.exe`,
      'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
      'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'
    ];
    for (const p of paths) {
      if (fs.existsSync(p)) {
        console.log(`[PDF Server] Usando navegador local encontrado en: ${p}`);
        return p;
      }
    }
    console.warn("[PDF Server] ADVERTENCIA: No se encontró una instalación local de Chrome o Edge en Windows.");
  }
  return undefined;
};

export async function generatePDFResponse(html, filename, res) {
  let browser;
  try {
    browser = await puppeteer.launch({
      headless: 'shell',
      executablePath: getBrowserExecutablePath(),
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--font-render-hinting=none'
      ]
    });

    const page = await browser.newPage();
    await page.setContent(html, { waitUntil: 'networkidle0' });
    
    // Esperar 600ms para asegurar que los gráficos de Chart.js y las fuentes terminen de renderizarse
    await page.evaluate(() => new Promise(resolve => setTimeout(resolve, 600)));

    const pdfBuffer = await page.pdf({
      format: 'A4',
      printBackground: true,
      margin: {
        top: '20px',
        bottom: '20px',
        left: '20px',
        right: '20px'
      }
    });

    await browser.close();

    res.contentType("application/pdf");
    res.setHeader("Content-Disposition", `attachment; filename=${filename}`);
    res.send(pdfBuffer);
  } catch (err) {
    console.error("[PDF Server] Error al generar PDF:", err);
    if (browser) await browser.close();
    res.status(500).send("Error interno del servidor al generar el archivo PDF.");
  }
}
