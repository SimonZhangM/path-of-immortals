import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import http from 'node:http';
import { scan, root, atlasPages, createServer } from './server.mjs';
import { createEffect } from './public/runtime.js';

const catalog = await scan();
const failures = [];
let animations = 0, triangles = 0;
for (const item of catalog.items) {
  try {
    assert.ok(!item.error, item.error);
    const json = JSON.parse(await fs.readFile(item.path, 'utf8'));
    const atlasText = await fs.readFile(path.join(root, item.atlas), 'utf8');
    const images = new Map();
    const names = atlasPages(atlasText);
    for (let i = 0; i < item.pages.length; i++) {
      const bytes = await fs.readFile(path.join(root, item.pages[i]));
      assert.equal(bytes.subarray(1, 4).toString(), 'PNG');
      images.set(names[i], { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) });
    }
    const effect = createEffect(json, atlasText, images);
    for (const animation of item.animations) {
      assert.ok(Number.isFinite(effect.data.animations.find(a => a.name === animation).duration), 'invalid animation duration');
      effect.reset(animation); effect.fit(); animations++;
      for (let frame = 0; frame < 12; frame++) {
        effect.advance(effect.duration / 11);
        effect.geometry(({ vertices, indices, uvs, color, image }) => {
          assert.ok(vertices.every(Number.isFinite), 'non-finite vertices');
          assert.equal(vertices.length, uvs.length);
          assert.ok([...indices].every(index => index >= 0 && index < vertices.length / 2), 'invalid triangle index');
          assert.ok([...uvs, ...color].every(Number.isFinite));
          assert.ok(image.width > 0 && image.height > 0);
          triangles += indices.length / 3;
        });
      }
    }
  } catch (error) { failures.push({ item: item.id, error: String(error.stack || error) }); }
}
const server = createServer();
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
try {
  const base = `http://127.0.0.1:${server.address().port}`;
  assert.equal((await fetch(base)).status, 200);
  assert.equal((await (await fetch(base + '/api/catalog')).json()).items.length, catalog.items.length);
  const sample = catalog.items[0];
  assert.equal((await fetch(base + '/asset/' + sample.id.split('/').map(encodeURIComponent).join('/'))).status, 200);
  assert.equal((await fetch(base + '/asset/%2e%2e%5cpath-of-immortals%5cREADME.md')).status, 403);
  assert.equal((await fetch(base + '/%2e%2e%5cconfig.json')).status, 403);
  assert.equal((await fetch(base + '/asset/%2e%2e%5c%2e%2e%5cpath-of-immortals%5ctools%5cspine-preview%5cconfig.json')).status, 403);
  assert.equal((await fetch(base + '/api/catalog', { method: 'POST' })).status, 405);
  const hostStatus = await new Promise((resolve, reject) => {
    http.get(base, { headers: { Host: 'untrusted.example' } }, response => { response.resume(); resolve(response.statusCode); }).on('error', reject);
  });
  assert.equal(hostStatus, 403);
} finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
console.log(JSON.stringify({ items: catalog.items.length, animations, sampledTriangles: triangles, failures }, null, 2));
if (failures.length) process.exitCode = 1;
