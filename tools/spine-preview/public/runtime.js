import { spine as spine21 } from './vendor/spine-2.1.js';
import { spine as spine36 } from './vendor/spine-3.6.js';

const quad = new Uint16Array([0, 1, 2, 2, 3, 0]);
export function createEffect(json, atlasText, images) {
  const old = json.skeleton.spine.startsWith('2.1.');
  const runtime = old ? spine21 : spine36;
  const atlas = old ? new runtime.Atlas(atlasText, {
    load(page, name) { const image = images.get(name); if (!image) throw new Error(`缺少图集：${name}`); page.width = image.width; page.height = image.height; page.rendererObject = image; },
    unload() {},
  }) : new runtime.TextureAtlas(atlasText, name => {
    const image = images.get(name);
    if (!image) throw new Error(`缺少图集：${name}`);
    return { getImage: () => image, setFilters() {}, setWraps() {}, dispose() {} };
  });
  const data = new runtime.SkeletonJson(new runtime.AtlasAttachmentLoader(atlas)).readSkeletonData(json);
  const skeleton = new runtime.Skeleton(data);
  const stateData = new runtime.AnimationStateData(data);
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
      for (const slot of skeleton.drawOrder) {
        const attachment = slot.attachment;
        if (!attachment) continue;
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
        visit({ vertices, indices, uvs: attachment.uvs, color, image, blend: old ? (slot.data.additiveBlending ? 1 : 0) : slot.data.blendMode });
      }
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
