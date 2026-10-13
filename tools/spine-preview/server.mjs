import http from 'node:http';
import fs from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(await fs.readFile(path.join(here, 'config.json'), 'utf8'));
export const root = await fs.realpath(process.env.SPINE_ROOT || config.root);
const publicRoot = path.join(here, 'public');
const port = Number(process.env.PORT || config.port);
const collator = new Intl.Collator('zh-CN', { numeric: true });
const slash = p => p.split(path.sep).join('/');
export function atlasPages(text) {
  return text.trim().split(/\r?\n\s*\r?\n/).map(block => block.trim().split(/\r?\n/)[0].trim());
}
export async function scan() {
  const items = [];
  async function walk(dir) {
    for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) await walk(file);
      else if (entry.isFile() && /\.json$/i.test(entry.name)) {
        const relative = slash(path.relative(root, file));
        const item = { id: relative, name: path.basename(file, '.json'), folder: slash(path.relative(root, dir)), path: file };
        try {
          const json = JSON.parse((await fs.readFile(file, 'utf8')).replace(/^\uFEFF/, ''));
          if (!json.skeleton || !json.bones) continue;
          item.version = json.skeleton.spine || '未知';
          item.animations = Object.keys(json.animations || {});
          item.skins = Object.keys(json.skins || {});
          item.atlas = relative.replace(/\.json$/i, '.atlas');
          const atlas = await fs.readFile(path.join(root, item.atlas), 'utf8');
          item.pages = atlasPages(atlas).map(page => slash(path.join(path.dirname(item.atlas), page)));
          for (const page of item.pages) await safeFile(root, page);
          if (!/^(2\.1\.|3\.6\.)/.test(item.version)) throw new Error(`暂不支持 Spine ${item.version}`);
        } catch (error) { item.error = error.message; }
        items.push(item);
      }
    }
  }
  await walk(root);
  items.sort((a, b) => collator.compare(a.folder, b.folder) || collator.compare(a.name, b.name));
  return { root, items, scannedAt: new Date().toISOString() };
}
export async function safeFile(base, relative) {
  const file = await fs.realpath(path.resolve(base, relative));
  const rel = path.relative(base, file);
  if (rel.startsWith('..') || path.isAbsolute(rel) || !(await fs.stat(file)).isFile()) {
    throw Object.assign(new Error('文件不在允许目录内'), { status: 403 });
  }
  return file;
}
let catalog;
let refreshing;
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8', '.atlas': 'text/plain; charset=utf-8', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml' };
function sendJson(res, data, status = 200) { res.writeHead(status, { 'Content-Type': mime['.json'], 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); }
export function createServer() {
  return http.createServer(async (req, res) => {
    try {
      if (!['127.0.0.1', 'localhost'].includes((req.headers.host || '').split(':')[0])) return sendJson(res, { error: '仅接受本机访问' }, 403);
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
      res.setHeader('Content-Security-Policy', "default-src 'self'; img-src 'self' blob:; style-src 'self'; script-src 'self'; frame-ancestors 'none'; base-uri 'none'");
      const url = new URL(req.url, `http://127.0.0.1:${port}`);
      if (req.method !== 'GET' && req.method !== 'HEAD') return sendJson(res, { error: '只读服务' }, 405);
      if (url.pathname === '/api/health') return sendJson(res, { app: 'local-spine-preview', root, pid: process.pid });
      if (url.pathname === '/api/catalog') {
        if (!catalog || url.searchParams.has('refresh')) {
          refreshing ||= scan().then(value => catalog = value).finally(() => refreshing = null);
          await refreshing;
        }
        return sendJson(res, catalog);
      }
      let file;
      if (url.pathname.startsWith('/asset/')) {
        const rel = decodeURIComponent(url.pathname.slice(7));
        if (!/\.(json|atlas|png|webp)$/i.test(rel)) return sendJson(res, { error: '不支持的素材格式' }, 403);
        file = await safeFile(root, rel);
      } else file = await safeFile(publicRoot, url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname.slice(1)));
      const stat = await fs.stat(file);
      res.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Content-Length': stat.size, 'Cache-Control': file.startsWith(publicRoot) ? 'no-cache' : 'private, max-age=300' });
      if (req.method === 'HEAD') return res.end();
      const stream = createReadStream(file);
      stream.on('error', () => res.destroy());
      res.on('close', () => stream.destroy());
      stream.pipe(res);
    } catch (error) { if (!res.headersSent) sendJson(res, { error: error.message }, error.status || (error.code === 'ENOENT' ? 404 : 500)); else res.destroy(); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const server = createServer();
  server.on('error', error => { console.error(error.code === 'EADDRINUSE' ? `端口 ${port} 已占用，请修改 config.json 的 port。` : error); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`Spine 特效预览  http://127.0.0.1:${port}\n素材：${root}\n按 Ctrl+C 停止服务。`));
}
