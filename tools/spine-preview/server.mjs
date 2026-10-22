import http from 'node:http';
import fs from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { binaryVersion, parseSkeleton } from './public/runtime.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(await fs.readFile(path.join(here, 'config.json'), 'utf8'));
const configured = process.env.SPINE_ROOT ? [{ id: 'custom', name: '自定义素材库', root: process.env.SPINE_ROOT }] : config.libraries || [{ id: 'classic', name: 'Spine 特效', root: config.root }];
export const libraries = configured.map(library => ({ ...library, root: path.resolve(library.root) }));
if (new Set(libraries.map(library => library.id)).size !== libraries.length || libraries.some(library => !/^[a-z0-9_-]+$/i.test(library.id))) throw new Error('素材库ID必须唯一，仅含英文字母、数字、短横线或下划线');
export const root = libraries[0].root;
const publicRoot = path.join(here, 'public');
const port = Number(process.env.PORT || config.port);
const collator = new Intl.Collator('zh-CN', { numeric: true });
const slash = p => p.split(path.sep).join('/');
export function atlasPages(text) {
  return text.trim().split(/\r?\n\s*\r?\n/).map(block => block.trim().split(/\r?\n/)[0].trim());
}
export async function scan() {
  const items = [];
  const scannedLibraries = [];
  async function walk(dir, library) {
    for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
      const file = path.join(dir, entry.name);
      if (entry.isDirectory()) await walk(file, library);
      else if (entry.isFile() && /\.(json|skel)$/i.test(entry.name)) {
        const relative = slash(path.relative(library.root, file));
        const format = path.extname(file).slice(1).toLowerCase();
        const prefix = library.id + '/';
        const item = { id: prefix + relative, relative, libraryId: library.id, libraryName: library.name, format, name: path.basename(file, path.extname(file)), folder: slash(path.relative(library.root, dir)), path: file, version: '未知', animations: [], skins: [] };
        try {
          const source = format === 'skel' ? new Uint8Array(await fs.readFile(file)) : JSON.parse((await fs.readFile(file, 'utf8')).replace(/^\uFEFF/, ''));
          if (format === 'json' && (!source.skeleton || !source.bones)) continue;
          item.version = format === 'skel' ? binaryVersion(source) : source.skeleton.spine || '未知';
          if (!/^(2\.1\.|3\.6\.|3\.8\.)/.test(item.version)) throw new Error(`暂不支持 Spine ${item.version}`);
          const atlasRelative = relative.replace(/\.(json|skel)$/i, '.atlas');
          item.atlas = prefix + atlasRelative;
          const atlas = await fs.readFile(await safeFile(library.root, atlasRelative), 'utf8');
          item.pages = [];
          const images = new Map();
          for (const name of atlasPages(atlas)) {
            const pageRelative = slash(path.join(path.dirname(atlasRelative), name));
            const pageFile = await safeFile(library.root, pageRelative);
            item.pages.push(prefix + pageRelative);
            if (format === 'skel') {
              const handle = await fs.open(pageFile, 'r');
              try {
                const bytes = Buffer.alloc(24);
                await handle.read(bytes, 0, 24, 0);
                if (bytes.subarray(1, 4).toString() !== 'PNG') throw new Error(`图集不是PNG：${name}`);
                images.set(name, { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) });
              } finally { await handle.close(); }
            }
          }
          if (format === 'skel') {
            const { data } = parseSkeleton(source, atlas, images, item.version);
            item.animations = data.animations.map(animation => animation.name);
            item.skins = data.skins.map(skin => skin.name);
          } else {
            item.animations = Object.keys(source.animations || {});
            item.skins = Array.isArray(source.skins) ? source.skins.map(skin => skin.name) : Object.keys(source.skins || {});
          }
        } catch (error) { item.error = error.message; }
        items.push(item);
      }
    }
  }
  for (const library of libraries) {
    const before = items.length;
    const result = { ...library };
    try { await walk(library.root, library); } catch (error) { result.error = error.message; }
    result.count = items.length - before;
    scannedLibraries.push(result);
  }
  items.sort((a, b) => libraries.findIndex(lib => lib.id === a.libraryId) - libraries.findIndex(lib => lib.id === b.libraryId) || collator.compare(a.folder, b.folder) || collator.compare(a.name, b.name));
  return { root, libraries: scannedLibraries, items, scannedAt: new Date().toISOString() };
}
export async function safeFile(base, relative) {
  base = await fs.realpath(base);
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
      if (url.pathname === '/api/health') return sendJson(res, { app: 'local-spine-preview', root, libraries, pid: process.pid });
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
        if (!/\.(json|skel|atlas|png|webp)$/i.test(rel)) return sendJson(res, { error: '不支持的素材格式' }, 403);
        const separator = rel.indexOf('/');
        const library = libraries.find(library => library.id === rel.slice(0, separator));
        if (!library || separator < 0) return sendJson(res, { error: '未知素材库' }, 404);
        file = await safeFile(library.root, rel.slice(separator + 1));
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
  server.listen(port, '127.0.0.1', () => console.log(`Spine 特效预览  http://127.0.0.1:${port}\n素材：${libraries.map(library => library.root).join(' / ')}\n按 Ctrl+C 停止服务。`));
}
