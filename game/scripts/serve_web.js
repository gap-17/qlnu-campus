#!/usr/bin/env node
/**
 * 极简静态服务器：预览 Godot Web 导出。
 * 关键点：
 *   - .wasm 必须返回 application/wasm，否则浏览器拒绝流式编译；
 *   - 单线程导出不需要 COOP/COEP，这里刻意不发送；
 *   - 只读，禁止路径穿越。
 *
 * 用法：node game/scripts/serve_web.js [port]
 */

const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const url = require('node:url');

const ROOT = path.resolve(__dirname, '..', 'build', 'web');
const PORT = Number(process.argv[2] || process.env.PORT || 5174);
const HOST = process.env.HOST || '127.0.0.1';

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.data': 'application/octet-stream',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
};

function safeJoin(root, requestPath) {
  const decoded = decodeURIComponent(requestPath.split('?')[0]);
  const normalized = path.normalize(decoded).replace(/^([/\\])+/, '');
  const target = path.resolve(root, normalized);
  const prefix = root.endsWith(path.sep) ? root : root + path.sep;
  if (target !== root && !target.startsWith(prefix)) return null;
  return target;
}

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    'Cache-Control': 'no-cache',
    'X-Content-Type-Options': 'nosniff',
    ...headers,
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    send(res, 405, 'Method Not Allowed', { 'Content-Type': 'text/plain; charset=utf-8' });
    return;
  }

  let target = safeJoin(ROOT, req.url || '/');
  if (!target) {
    send(res, 403, 'Forbidden', { 'Content-Type': 'text/plain; charset=utf-8' });
    return;
  }

  fs.stat(target, (err, stat) => {
    if (!err && stat.isDirectory()) {
      target = path.join(target, 'index.html');
      stat = fs.existsSync(target) ? fs.statSync(target) : null;
    }
    if (!stat || !stat.isFile()) {
      send(res, 404, 'Not found: ' + (req.url || '/'), {
        'Content-Type': 'text/plain; charset=utf-8',
      });
      return;
    }

    const ext = path.extname(target).toLowerCase();
    const type = MIME[ext] || 'application/octet-stream';
    const headers = {
      'Content-Type': type,
      'Content-Length': stat.size,
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=60',
    };
    if (req.method === 'HEAD') {
      res.writeHead(200, headers);
      res.end();
      return;
    }
    res.writeHead(200, headers);
    fs.createReadStream(target).pipe(res);
  });
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[serve] 端口 ${PORT} 已被占用，换一个：node game/scripts/serve_web.js 5175`);
  } else {
    console.error('[serve]', err);
  }
  process.exit(1);
});

if (!fs.existsSync(path.join(ROOT, 'index.html'))) {
  console.warn(`[serve] 还没有找到导出产物：${path.join(ROOT, 'index.html')}`);
  console.warn('[serve] 请先运行 export_web.bat。');
}

server.listen(PORT, HOST, () => {
  console.log('[serve] 根目录 :', ROOT);
  console.log(`[serve] 访问   : http://${HOST}:${PORT}/`);
  console.log('[serve] Ctrl+C 停止');
});