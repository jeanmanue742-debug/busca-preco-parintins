import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import handler from './search.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.join(__dirname, '..');
const webDir = path.join(rootDir, 'build', 'web');

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream'
};

const server = http.createServer(async (req, res) => {
  // CORS e isolamento de contexto para Godot 4 Web
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');

  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);

  // Rota da API
  if (parsedUrl.pathname.startsWith('/api/search')) {
    const queryObj = Object.fromEntries(parsedUrl.searchParams);
    req.query = queryObj;
    return handler(req, res);
  }

  // Arquivos estáticos do Godot Web
  let filePath = path.join(webDir, parsedUrl.pathname === '/' ? 'index.html' : parsedUrl.pathname);

  fs.stat(filePath, (err, stats) => {
    if (err || !stats.isFile()) {
      filePath = path.join(webDir, 'index.html');
    }

    const ext = path.extname(filePath).toLowerCase();
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';

    res.writeHead(200, { 'Content-Type': contentType });
    fs.createReadStream(filePath).pipe(res);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Servidor Busca Preço Parintins rodando em: http://localhost:${PORT}`);
});
