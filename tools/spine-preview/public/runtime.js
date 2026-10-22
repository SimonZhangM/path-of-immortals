import { spine as spine21 } from './vendor/spine-2.1.js';
import { spine as spine36 } from './vendor/spine-3.6.js';
import { spine as spine38 } from './vendor/spine-3.8.js';

const quad = new Uint16Array([0, 1, 2, 2, 3, 0]);
export function binaryVersion(binary) {
  let offset = 0;
  function readString() {
    let size = 0;
    for (let shift = 0; ; shift += 7) {
      if (offset >= binary.length || shift > 28) throw new Error('无效的 Spine 二进制头');
      const byte = binary[offset++]; size |= (byte & 127) << shift;
      if (!(byte & 128)) break;
    }
    const end = offset + Math.max(0, size - 1);
    if (size < 0 || end > binary.length) throw new Error('不完整的 Spine 二进制头');
    const value = new TextDecoder().decode(binary.subarray(offset, end)); offset = end;
    return value;
  }
  readString();
  return readString() || '未知';
}
export function parseSkeleton(source, atlasText, images, version = source.skeleton?.spine) {
  const old = version?.startsWith('2.1.');
  const runtime = old ? spine21 : version?.startsWith('3.6.') ? spine36 : version?.startsWith('3.8.') ? spine38 : null;
  if (!runtime) throw new Error(`暂不支持 Spine ${version}`);
  const atlas = old ? new runtime.Atlas(atlasText, {
    load(page, name) { const image = images.get(name); if (!image) throw new Error(`缺少图集：${name}`); page.width = image.width; page.height = image.height; page.rendererObject = image; },
    unload() {},
  }) : new runtime.TextureAtlas(atlasText, name => {
    const image = images.get(name);
    if (!image) throw new Error(`缺少图集：${name}`);
    return { getImage: () => image, setFilters() {}, setWraps() {}, dispose() {} };
  });
  const binary = source instanceof Uint8Array;
  if (binary && runtime !== spine38) throw new Error('二进制格式目前支持 Spine 3.8');
  const reader = new runtime[binary ? 'SkeletonBinary' : 'SkeletonJson'](new runtime.AtlasAttachmentLoader(atlas));
  // This opt-in is limited to the library's verified 3.8.75 exports; source files stay unchanged.
  reader.allowLegacy3875 = version === '3.8.75';
  const data = reader.readSkeletonData(binary ? new Uint8Array(source) : source);
  return { data, runtime, old };
}
export function createEffect(source, atlasText, images, version) {
  const { data, runtime, old } = parseSkeleton(source, atlasText, images, version);
  const skeleton = new runtime.Skeleton(data);
  const stateData = new runtime.AnimationStateData(data);
  const clipper = old ? null : new runtime.SkeletonClipping();
  let state, elapsed = 0;
  const effect = { skeleton, data, old, animation: '', duration: 0, bounds: null,
    reset(name = effect.animation) {
      effect.animation = name;
      skeleton.setToSetupPose();
      state = new runtime.AnimationState(stateData);
      if (name) state.setAnimationByName ? state.setAnimationByName(0, name, true) : state.setAnimation(0, name, true);
      effect.duration = data.animations.find(a => a.name === name)?.duration || 0;
      elapsed = 0;
      state.apply(skeleton); skeleton.updateWorldTransform();
    },
    advance(delta) { elapsed += delta; skeleton.update(delta); state.update(delta); state.apply(skeleton); skeleton.updateWorldTransform(); },
    get elapsed() { return elapsed; },
    geometry(visit) {
      clipper?.clipEnd();
      for (const slot of skeleton.drawOrder) {
        const attachment = slot.attachment;
        if (!attachment || slot.bone.active === false) { clipper?.clipEndWithSlot(slot); continue; }
        if (!old && attachment instanceof runtime.ClippingAttachment) { clipper.clipStart(slot, attachment); continue; }
        try {
        let image, vertices, indices;
        if (old) {
          if (!attachment.rendererObject) continue;
          image = attachment.rendererObject.page.rendererObject;
          if (attachment.type === runtime.AttachmentType.region) {
            vertices = new Float32Array(8); indices = quad;
            attachment.computeVertices(skeleton.x, skeleton.y, slot.bone, vertices);
          } else if (attachment.type === runtime.AttachmentType.mesh || attachment.type === runtime.AttachmentType.skinnedmesh) {
            vertices = new Float32Array(attachment.uvs.length); indices = attachment.triangles;
            attachment.computeWorldVertices(skeleton.x, skeleton.y, slot, vertices);
          } else continue;
        } else {
          if (!attachment.region) continue;
          image = attachment.region.page.texture.getImage();
          if (attachment instanceof runtime.RegionAttachment) {
            vertices = new Float32Array(8); indices = quad;
            attachment.computeWorldVertices(slot.bone, vertices, 0, 2);
          } else if (attachment instanceof runtime.MeshAttachment) {
            vertices = new Float32Array(attachment.worldVerticesLength); indices = attachment.triangles;
            attachment.computeWorldVertices(slot, 0, vertices.length, vertices, 0, 2);
          } else continue;
        }
        const sc = old ? slot : slot.color, ac = old ? attachment : attachment.color;
        const color = [sc.r * ac.r, sc.g * ac.g, sc.b * ac.b, sc.a * ac.a];
        if (color[3] <= 0.005) continue;
        let uvs = attachment.uvs;
        if (clipper?.isClipping()) {
          clipper.clipTriangles(vertices, vertices.length, indices, indices.length, uvs, sc, sc, false);
          const clipped = clipper.clippedVertices;
          vertices = new Float32Array(clipped.length / 4); uvs = new Float32Array(vertices.length);
          for (let i = 0, j = 0; i < clipped.length; i += 8, j += 2) {
            vertices[j] = clipped[i]; vertices[j + 1] = clipped[i + 1];
            uvs[j] = clipped[i + 6]; uvs[j + 1] = clipped[i + 7];
          }
          indices = clipper.clippedTriangles;
        }
        if (indices.length) visit({ vertices, indices, uvs, color, image, blend: old ? (slot.data.additiveBlending ? 1 : 0) : slot.data.blendMode });
        } finally { clipper?.clipEndWithSlot(slot); }
      }
      clipper?.clipEnd();
    },
    fit() {
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      effect.reset();
      const steps = Math.min(90, Math.max(24, Math.ceil(effect.duration * 30)));
      for (let step = 0; step <= steps; step++) {
        if (step) effect.advance(effect.duration / steps);
        effect.geometry(({ vertices }) => {
          for (let i = 0; i < vertices.length; i += 2) {
            minX = Math.min(minX, vertices[i]); maxX = Math.max(maxX, vertices[i]);
            minY = Math.min(minY, vertices[i + 1]); maxY = Math.max(maxY, vertices[i + 1]);
          }
        });
      }
      effect.bounds = Number.isFinite(minX) ? { x: (minX + maxX) / 2, y: (minY + maxY) / 2, width: Math.max(16, maxX - minX), height: Math.max(16, maxY - minY) } : { x: 0, y: 0, width: 200, height: 200 };
      effect.reset();
      return effect.bounds;
    },
  };
  effect.reset(data.animations[0]?.name || '');
  effect.fit();
  return effect;
}
