import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import http from 'node:http';
import { scan, libraries, atlasPages, createServer } from './server.mjs';
import { createEffect } from './public/runtime.js';

const catalog = await scan();
const failures = [];
const attachmentTypes = {};
const clippedFiles = [];
const targetLibrary = process.argv.includes('--library') ? process.argv[process.argv.indexOf('--library') + 1] : null;
const checkedItems = catalog.items.filter(item => !targetLibrary || item.libraryId === targetLibrary);
assert.ok(checkedItems.length, 'no items selected for checks');
let animations = 0, triangles = 0;
for (const item of checkedItems) {
  try {
    assert.ok(!item.error, item.error);
    const library = libraries.find(library => library.id === item.libraryId);
    const localPath = relative => path.join(library.root, relative.slice(item.libraryId.length + 1));
    const json = item.format === 'skel' ? new Uint8Array(await fs.readFile(item.path)) : JSON.parse(await fs.readFile(item.path, 'utf8'));
    const atlasText = await fs.readFile(localPath(item.atlas), 'utf8');
    const images = new Map();
    const names = atlasPages(atlasText);
    for (let i = 0; i < item.pages.length; i++) {
      const bytes = await fs.readFile(localPath(item.pages[i]));
      assert.equal(bytes.subarray(1, 4).toString(), 'PNG');
      images.set(names[i], { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) });
    }
    const effect = createEffect(json, atlasText, images, item.version);
    if (item.format === 'skel') for (const skin of effect.data.skins) {
      for (const slot of skin.attachments) if (slot) for (const attachment of Object.values(slot)) {
        const type = attachment.constructor.name; attachmentTypes[type] = (attachmentTypes[type] || 0) + 1;
        if (type === 'ClippingAttachment') clippedFiles.push(item.id);
      }
    }
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
  assert.equal(new Set(catalog.items.map(item => item.id)).size, catalog.items.length, 'library IDs must not collide');
  for (const library of catalog.libraries) {
    assert.ok(!library.error, library.error);
    assert.equal(library.count, catalog.items.filter(item => item.libraryId === library.id).length);
    const item = catalog.items.find(item => item.libraryId === library.id);
    if (item) assert.equal((await fetch(base + '/asset/' + item.id.split('/').map(encodeURIComponent).join('/'))).status, 200);
  }
  assert.equal((await fetch(base + '/asset/%2e%2e%5cpath-of-immortals%5cREADME.md')).status, 403);
  assert.equal((await fetch(base + '/%2e%2e%5cconfig.json')).status, 403);
  assert.equal((await fetch(base + '/asset/classic/%2e%2e%5c%2e%2e%5cpath-of-immortals%5ctools%5cspine-preview%5cconfig.json')).status, 403);
  assert.equal((await fetch(base + '/asset/unconfigured/example.skel')).status, 404);
  assert.equal((await fetch(base + '/api/catalog', { method: 'POST' })).status, 405);
  const hostStatus = await new Promise((resolve, reject) => {
    http.get(base, { headers: { Host: 'untrusted.example' } }, response => { response.resume(); resolve(response.statusCode); }).on('error', reject);
  });
  assert.equal(hostStatus, 403);
} finally { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
console.log(JSON.stringify({ libraries: catalog.libraries.map(library => ({ id: library.id, count: library.count })), items: checkedItems.length, animations, binaryAttachments: attachmentTypes, clippedFiles, sampledTriangles: triangles, failures }, null, 2));
if (failures.length) process.exitCode = 1;
