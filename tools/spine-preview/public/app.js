import { createEffect } from './runtime.js';
import { Renderer } from './renderer.js';

const $ = id => document.getElementById(id);
const PAGE_SIZE = 9;
const assetUrl = relative => '/asset/' + relative.split('/').map(encodeURIComponent).join('/');
let catalog, filtered = [], page = 1, views = [], paused = false, speed = 1, zoom = 1;
let generation = 0, controller, renderer, detailView = null, previousFocus = null;
let toastTimer, searchTimer;
let libraryId = null, folder = '';
const folderCollator = new Intl.Collator('zh-CN', { numeric: true });
const savedKey = 'spine-preview-v1';
function toast(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').hidden = true, 3200); }
function save() { try { localStorage.setItem(savedKey, JSON.stringify({ query: $('search').value, version: $('version').value, page, background: $('background').value, speed, zoom, libraryId, folder })); } catch {} }
function restore() {
  try {
    const saved = JSON.parse(localStorage.getItem(savedKey) || '{}');
    $('search').value = saved.query || '';
    if (['', '2.1', '3.6', '3.8'].includes(saved.version)) $('version').value = saved.version;
    if (typeof saved.libraryId === 'string') libraryId = saved.libraryId;
    if (typeof saved.folder === 'string') folder = saved.folder;
    if (['dark', 'light', 'black', 'checker'].includes(saved.background)) $('background').value = saved.background;
    if ([0.25, 0.5, 1, 2].includes(saved.speed)) speed = Number($('speed').value = saved.speed);
    if (saved.zoom >= 0.25 && saved.zoom <= 2.5) zoom = Number($('zoom').value = saved.zoom);
    page = Math.max(1, Math.floor(Number(saved.page) || 1));
  } catch {}
  document.body.dataset.background = $('background').value;
  $('zoom-value').value = `${Math.round(zoom * 100)}%`;
}
async function fetchOk(url, signal) { const response = await fetch(url, { signal }); if (!response.ok) throw new Error(`文件读取失败 (${response.status})：${decodeURIComponent(url)}`); return response; }
async function copyPath(item) { try { await navigator.clipboard.writeText(item.path); toast('已复制素材完整路径'); } catch { toast(`路径：${item.path}`); } }
function release(view) { renderer.release(view.images); for (const image of view.images.values()) image.close?.(); view.images.clear(); view.effect = null; }
function fillAnimations(select, item, value) {
  select.replaceChildren();
  for (const name of item.animations.length ? item.animations : ['静态姿势']) { const option = new Option(name, item.animations.length ? name : ''); select.add(option); }
  if (value !== undefined) select.value = value;
  select.disabled = !item.animations.length;
}
function changeAnimation(view, value) {
  if (!view.effect) return;
  try { view.effect.reset(value); view.effect.fit(); view.select.value = value; } catch (error) { failView(view, error); }
}
function failView(view, error) {
  view.message.className = 'card-error'; view.message.textContent = `无法预览：${error.message || error}`; view.message.hidden = false;
  view.card.dataset.state = 'error'; view.select.disabled = true; view.expand.disabled = true; view.effect = null;
  console.error(view.item.id, error);
}
function card(item, index) {
  const element = document.createElement('article'); element.className = 'card'; element.dataset.state = 'loading'; element.dataset.id = item.id;
  element.innerHTML = '<div class="card-top"><span class="ordinal"></span><h2></h2><button class="expand" aria-label="放大查看" title="放大查看">⛶</button></div><p class="card-location"></p><div class="preview" role="button" tabindex="0" aria-label="放大查看特效"><div class="loading">加载中</div></div><div class="card-bottom"><span class="version-tag"></span><select aria-label="选择动画"></select><button class="copy" title="复制素材文件完整路径">复制路径</button></div>';
  element.querySelector('.ordinal').textContent = String(index + 1).padStart(3, '0');
  element.querySelector('h2').textContent = item.name; element.querySelector('h2').title = item.folder + '\n' + item.name;
  element.querySelector('.card-location').textContent = `${item.libraryName} / ${item.folder || '根目录'}`;
  element.querySelector('.card-location').title = item.path;
  element.querySelector('.version-tag').textContent = item.version;
  const view = { item, card: element, preview: element.querySelector('.preview'), message: element.querySelector('.loading'), select: element.querySelector('select'), expand: element.querySelector('.expand'), images: new Map(), effect: null };
  fillAnimations(view.select, item);
  view.select.addEventListener('change', () => changeAnimation(view, view.select.value));
  element.querySelector('.copy').addEventListener('click', () => copyPath(item));
  view.expand.addEventListener('click', () => openDetail(view));
  view.preview.addEventListener('click', () => openDetail(view));
  view.preview.addEventListener('keydown', event => { if (['Enter', ' '].includes(event.key)) { event.preventDefault(); openDetail(view); } });
  return view;
}
async function loadView(view, signal, token) {
  try {
    if (view.item.error) throw new Error(view.item.error);
    const [json, atlasText] = await Promise.all([
      fetchOk(assetUrl(view.item.id), signal).then(async r => view.item.format === 'skel' ? new Uint8Array(await r.arrayBuffer()) : r.json()),
      fetchOk(assetUrl(view.item.atlas), signal).then(r => r.text()),
    ]);
    // Each atlas block starts with its image page; images remain in memory for this page only.
    const pageNames = atlasText.trim().split(/\r?\n\s*\r?\n/).map(block => block.trim().split(/\r?\n/)[0].trim());
    for (let i = 0; i < pageNames.length; i++) {
      const blob = await (await fetchOk(assetUrl(view.item.pages[i]), signal)).blob();
      const image = await createImageBitmap(blob, { premultiplyAlpha: 'none' });
      if (token !== generation || signal.aborted) { image.close(); return; }
      view.images.set(pageNames[i], image);
    }
    if (token !== generation) return;
    view.effect = createEffect(json, atlasText, view.images, view.item.version);
    for (const image of view.images.values()) renderer.texture(image);
    view.message.hidden = true; view.card.dataset.state = 'ready';
    view.preview.setAttribute('aria-label', `放大查看 ${view.item.name}`);
    view.select.value = view.effect.animation;
  } catch (error) { if (!signal.aborted && token === generation) { release(view); failView(view, error); } }
}
function updatePager() {
  const count = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  $('first').disabled = $('prev').disabled = page <= 1;
  $('next').disabled = $('last').disabled = page >= count;
  $('page-number').max = count; $('page-number').value = page;
  $('pages').replaceChildren();
  const start = Math.max(1, Math.min(page - 2, count - 4));
  for (let n = start; n <= Math.min(count, start + 4); n++) {
    const button = document.createElement('button'); button.textContent = n; button.ariaLabel = `第 ${n} 页`;
    if (page === n) { button.className = 'current'; button.setAttribute('aria-current', 'page'); }
    button.addEventListener('click', () => renderPage(n)); $('pages').append(button);
  }
  $('results').textContent = filtered.length ? `共 ${filtered.length} 个特效 · 第 ${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, filtered.length)} 个 · ${page} / ${count} 页` : '共 0 个特效';
}
function renderPage(next = page) {
  closeDetail();
  page = Math.max(1, Math.min(next, Math.ceil(filtered.length / PAGE_SIZE) || 1));
  controller?.abort(); controller = new AbortController(); generation++;
  for (const view of views) release(view);
  views = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE).map((item, index) => card(item, (page - 1) * PAGE_SIZE + index));
  $('grid').replaceChildren(...views.map(view => view.card));
  $('grid').hidden = !filtered.length; $('empty').hidden = !!filtered.length;
  updatePager(); save();
  for (const view of views) void loadView(view, controller.signal, generation);
}
function filter(reset = true) {
  const words = $('search').value.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean), version = $('version').value;
  filtered = catalog.items.filter(item => (!libraryId || item.libraryId === libraryId) && (!folder || item.folder === folder || item.folder.startsWith(folder + '/')) && (!version || item.version.startsWith(version)) && words.every(word => `${item.name} ${item.folder} ${item.libraryName}`.toLocaleLowerCase().includes(word)));
  const library = catalog.libraries.find(library => library.id === libraryId);
  $('scope').textContent = `${library?.name || '全部素材库'} / ${folder || '全部文件夹'}`;
  $('reset-scope').hidden = !folder;
  $('source').textContent = library ? (library.error ? `${library.root} · 无法读取，请检查目录` : library.root) : `已连接 ${catalog.libraries.length} 个素材库`;
  $('source').title = library?.error || library?.root || catalog.libraries.map(library => library.root).join('\n');
  for (const button of $('folders').querySelectorAll('[data-folder]')) button.setAttribute('aria-pressed', button.dataset.folder === folder);
  renderPage(reset ? 1 : page);
}
function chooseFolder(path) { folder = path; filter(); }
function renderFolders() {
  $('folders').replaceChildren();
  $('folder-search').disabled = !libraryId;
  if (!libraryId) {
    const hint = document.createElement('p'); hint.className = 'folder-hint'; hint.textContent = '选择一个素材库，浏览其中的文件夹。'; $('folders').append(hint); return;
  }
  const root = { children: new Map(), count: 0, path: '', name: '全部文件夹' };
  for (const item of catalog.items.filter(item => item.libraryId === libraryId)) {
    root.count++;
    let node = root;
    for (const name of item.folder.split('/').filter(Boolean)) {
      if (!node.children.has(name)) node.children.set(name, { name, path: node.path ? `${node.path}/${name}` : name, children: new Map(), count: 0 });
      node = node.children.get(name); node.count++;
    }
  }
  const query = $('folder-search').value.trim().toLocaleLowerCase();
  const matches = node => !query || node.path.toLocaleLowerCase().includes(query) || [...node.children.values()].some(matches);
  function renderNode(node, parent, isRoot = false) {
    if (!isRoot && !matches(node)) return;
    const branch = document.createElement('div'); branch.className = 'folder-branch';
    const row = document.createElement('div'); row.className = 'folder-row';
    const children = document.createElement('div'); children.className = 'folder-children';
    children.hidden = !isRoot && !query && !(folder === node.path || folder.startsWith(node.path + '/'));
    if (node.children.size && !isRoot) {
      const toggle = document.createElement('button'); toggle.className = 'folder-toggle'; toggle.textContent = children.hidden ? '›' : '⌄'; toggle.setAttribute('aria-label', `展开或收起 ${node.path}`); toggle.setAttribute('aria-expanded', !children.hidden);
      toggle.addEventListener('click', () => { children.hidden = !children.hidden; toggle.textContent = children.hidden ? '›' : '⌄'; toggle.setAttribute('aria-expanded', !children.hidden); }); row.append(toggle);
    }
    const button = document.createElement('button'); button.className = 'folder-choice'; button.dataset.folder = node.path; button.title = node.path || '全部文件夹'; button.setAttribute('aria-pressed', node.path === folder);
    const label = document.createElement('span'); label.textContent = node.name;
    const count = document.createElement('small'); count.textContent = node.count;
    button.append(label, count); button.addEventListener('click', () => chooseFolder(node.path)); row.append(button); branch.append(row);
    for (const child of [...node.children.values()].sort((a, b) => folderCollator.compare(a.name, b.name))) renderNode(child, children);
    if (node.children.size) branch.append(children);
    parent.append(branch);
  }
  renderNode(root, $('folders'), true);
}
function renderLibraries() {
  $('libraries').replaceChildren();
  for (const library of [{ id: '', name: '全部素材', count: catalog.items.length }, ...catalog.libraries]) {
    const button = document.createElement('button'); button.dataset.library = library.id; button.setAttribute('aria-pressed', library.id === libraryId);
    const label = document.createElement('span'); label.textContent = library.name;
    const count = document.createElement('small'); count.textContent = library.error ? '不可用' : library.count;
    button.append(label, count); button.title = library.error || library.root || '显示所有已配置素材库';
    button.addEventListener('click', () => { libraryId = library.id; folder = ''; $('folder-search').value = ''; renderLibraries(); renderFolders(); filter(); });
    $('libraries').append(button);
  }
}
async function refresh(rescan = false) {
  $('refresh').disabled = true; $('refresh').textContent = '扫描中…';
  try {
    catalog = await (await fetchOk('/api/catalog' + (rescan ? '?refresh=1' : ''))).json();
    if (libraryId === null) { libraryId = catalog.libraries.at(-1)?.id || ''; page = 1; $('search').value = ''; $('version').value = ''; }
    if (libraryId && !catalog.libraries.some(library => library.id === libraryId)) { libraryId = ''; folder = ''; }
    if (folder && !catalog.items.some(item => item.libraryId === libraryId && (item.folder === folder || item.folder.startsWith(folder + '/')))) folder = '';
    $('total').textContent = catalog.items.length;
    renderLibraries(); renderFolders();
    filter(!rescan ? false : true);
    if (rescan) toast(`扫描完成，共 ${catalog.items.length} 个特效`);
  } catch (error) { $('source').textContent = '素材读取失败'; $('results').textContent = error.message; toast(error.message); }
  finally { $('refresh').disabled = false; $('refresh').textContent = '↻ 重新扫描'; }
}
function openDetail(view) {
  if (!view.effect) return;
  previousFocus = document.activeElement; detailView = view;
  $('detail-title').textContent = view.item.name; $('detail-path').textContent = view.item.path;
  fillAnimations($('detail-animation'), view.item, view.effect.animation);
  $('detail-play').textContent = $('play').textContent;
  $('detail-speed').value = speed; $('detail-zoom').value = zoom;
  $('detail').hidden = false; document.body.classList.add('detail-open'); $('close-detail').focus();
}
function closeDetail() {
  if (!detailView) return;
  detailView = null; $('detail').hidden = true; document.body.classList.remove('detail-open'); previousFocus?.focus();
}
function togglePlay() { paused = !paused; $('play').textContent = $('detail-play').textContent = paused ? '▶ 播放' : 'Ⅱ 暂停'; $('play').setAttribute('aria-pressed', paused); $('detail-play').setAttribute('aria-pressed', paused); }
function replay() { for (const view of detailView ? [detailView] : views) view.effect?.reset(); }
$('search').addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(() => { if (catalog) filter(); }, 180); });
$('version').addEventListener('change', () => catalog && filter());
$('clear-search').addEventListener('click', () => { $('search').value = ''; $('version').value = ''; folder = ''; renderFolders(); filter(); });
$('folder-search').addEventListener('input', renderFolders);
$('reset-scope').addEventListener('click', () => chooseFolder(''));
$('refresh').addEventListener('click', () => refresh(true));
$('play').addEventListener('click', togglePlay); $('replay').addEventListener('click', replay);
$('speed').addEventListener('change', () => { speed = Number($('speed').value); save(); });
$('background').addEventListener('change', () => { document.body.dataset.background = $('background').value; save(); });
$('zoom').addEventListener('input', () => { zoom = Number($('zoom').value); $('zoom-value').value = `${Math.round(zoom * 100)}%`; save(); });
$('first').addEventListener('click', () => renderPage(1)); $('last').addEventListener('click', () => renderPage(Math.ceil(filtered.length / PAGE_SIZE)));
$('prev').addEventListener('click', () => renderPage(page - 1)); $('next').addEventListener('click', () => renderPage(page + 1));
$('jump').addEventListener('submit', event => { event.preventDefault(); renderPage(Math.floor(Number($('page-number').value)) || 1); });
$('close-detail').addEventListener('click', closeDetail);
$('detail').addEventListener('click', event => { if (event.target === $('detail')) closeDetail(); });
$('detail-animation').addEventListener('change', () => changeAnimation(detailView, $('detail-animation').value));
$('detail-replay').addEventListener('click', replay); $('detail-copy').addEventListener('click', () => copyPath(detailView.item));
$('detail-play').addEventListener('click', togglePlay);
$('detail-speed').addEventListener('change', () => { speed = Number($('detail-speed').value); $('speed').value = speed; save(); });
$('detail-zoom').addEventListener('input', () => { zoom = Number($('detail-zoom').value); $('zoom').value = zoom; $('zoom-value').value = `${Math.round(zoom * 100)}%`; save(); });
document.addEventListener('keydown', event => {
  if (event.key === 'Escape') closeDetail();
  if (detailView && event.key === 'Tab') {
    const focusable = [...$('detail').querySelectorAll('button,select,input')].filter(element => !element.disabled);
    const first = focusable[0], last = focusable.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }
  if (event.target.matches('input,select,textarea,button') || event.target.isContentEditable || event.altKey || event.ctrlKey || event.metaKey) return;
  if (event.key === ' ') { event.preventDefault(); togglePlay(); }
  if (event.key === '/' && !detailView) { event.preventDefault(); $('search').focus(); }
  if (catalog && !detailView && event.key === 'ArrowLeft') { event.preventDefault(); renderPage(page - 1); }
  if (catalog && !detailView && event.key === 'ArrowRight') { event.preventDefault(); renderPage(page + 1); }
});
window.addEventListener('rendererror', event => { paused = true; toast(event.detail); $('results').textContent = event.detail; });
let last = performance.now();
function frame(now) {
  const delta = Math.min((now - last) / 1000, 0.1); last = now;
  if (renderer && !document.hidden) {
    renderer.clear();
    for (const view of detailView ? [detailView] : views) if (view.effect) {
      try {
        if (!paused) view.effect.advance(delta * speed);
        renderer.draw(view.effect, (detailView ? $('detail-view') : view.preview).getBoundingClientRect(), zoom);
      } catch (error) { failView(view, error); }
    }
  }
  requestAnimationFrame(frame);
}
restore();
try { renderer = new Renderer($('stage')); requestAnimationFrame(frame); await refresh(); }
catch (error) { $('results').textContent = error.message; toast(error.message); }
