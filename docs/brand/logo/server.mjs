import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { extname } from 'node:path';
const types = { '.html': 'text/html', '.svg': 'image/svg+xml', '.png': 'image/png' };
createServer((req, res) => {
  try {
    const p = '.' + (req.url === '/' ? '/preview.html' : req.url.split('?')[0]);
    res.writeHead(200, { 'Content-Type': types[extname(p)] || 'text/plain' });
    res.end(readFileSync(p));
  } catch { res.writeHead(404); res.end('404'); }
}).listen(8131, '127.0.0.1', () => console.log('serving on http://127.0.0.1:8131'));
