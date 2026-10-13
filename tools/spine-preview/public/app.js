import { createEffect } from './runtime.js';
import { Renderer } from './renderer.js';

const $ = id => document.getElementById(id);
const PAGE_SIZE = 9;
const assetUrl = relative => '/asset/' + relative.split('/').map(encodeURIComponent).join('/');
let catalog, filtered = [], page = 1, views = [], paused = false, speed = 1, zoom = 1;
let generation = 0, controller, renderer, detailView = null, previousFocus = null;
let toastTimer, searchTimer;
const savedKey = 'spine-preview-v1';
function toast(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').hidden = true, 3200); }
function save() { try { localStorage.setItem(savedKey, JSON.stringify({ query: $('search').value, version: $('version').value, page, background: $('background').value, speed, zoom })); } catch {} }
function restore() {
  try {
    const saved = JSON.parse(localStorage.getItem(savedKey) || '{}');
    $('search').value = saved.query || '';
    if (['', '2.1', '3.6'].includes(saved.version)) $('version').value = saved.version;
    if (['dark', 'light', 'black', 'checker'].includes(saved.background)) $('background').value = saved.background;
    if ([0.25, 0.5, 1, 2].includes(saved.speed)) speed = Number($('speed').value = saved.speed);
    if (saved.zoom >= 0.25 && saved.zoom <= 2.5) zoom = Number($('zoom').value = saved.zoom);
    page = Math.max(1, Math.floor(Number(saved.page) || 1));
  } catch {}
  document.body.dataset.background = $('background').value;
  $('zoom-value').value = `${Math.round(zoom * 100)}%`;
}
async function fetchOk(url, signal) { const response = await fetch(url, { signal }); if (!response.ok) throw new Error(`文件读取失败 (${response.status})：${decodeURIComponent(url)}`); return response; }
async function copyPath(item) { try { await navigator.clipboard.writeText(item.path); toast('已复制 JSON 完整路径'); } catch { toast(`路径：${item.path}`); } }
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
  element.innerHTML = '<div class="card-top"><span class="ordinal"></span><h2></h2><button class="expand" aria-label="放大查看" title="放大查看">⛶</button></div><div class="preview" role="button" tabindex="0" aria-label="放大查看特效"><div class="loading">加载中</div></div><div class="card-bottom"><span class="version-tag"></span><select aria-label="选择动画"></select><button class="copy" title="复制 JSON 文件完整路径">复制路径</button></div>';
  element.querySelector('.ordinal').textContent = String(index + 1).padStart(3, '0');
  element.querySelector('h2').textContent = item.name; element.querySelector('h2').title = item.folder + '\n' + item.name;
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
      fetchOk(assetUrl(view.item.id), signal).then(r => r.json()),
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
    view.effect = createEffect(json, atlasText, view.images);
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
  filtered = catalog.items.filter(item => (!version || item.version.startsWith(version)) && words.every(word => `${item.name} ${item.folder}`.toLocaleLowerCase().includes(word)));
  renderPage(reset ? 1 : page);
}
async function refresh(rescan = false) {
  $('refresh').disabled = true; $('refresh').textContent = '扫描中…';
  try {
    catalog = await (await fetchOk('/api/catalog' + (rescan ? '?refresh=1' : ''))).json();
    $('total').textContent = catalog.items.length; $('source').textContent = catalog.root; $('source').title = catalog.root;
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
$('clear-search').addEventListener('click', () => { $('search').value = ''; $('version').value = ''; filter(); });
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
