# Third-party Spine runtimes

Vendor sources are pinned to Esoteric Software's official release tags. The original license notices are retained in the source files; Spine Runtimes have their own license terms. These sources are bundled for this local preview tool; redistribution/use remains subject to those terms.

- `public/vendor/spine-2.1.js`: <https://github.com/EsotericSoftware/spine-runtimes/blob/2.1.25/spine-js/spine.js>
- `public/vendor/spine-3.6.js`: <https://github.com/EsotericSoftware/spine-runtimes/blob/3.6.53/spine-ts/build/spine-core.js>
- `public/vendor/spine-3.8.js`: <https://github.com/EsotericSoftware/spine-runtimes/blob/3.8.95/spine-ts/build/spine-core.js>

All three files add `export { spine };` so each runtime has an isolated ES module scope. The 2.1 runtime contains these local compatibility fixes, verified against this library:

1. FlipX/FlipY timelines reference `this.boneIndex` (upstream referenced an undeclared `boneIndex`).
2. FFD keyframes use zero-initialized Float32Array storage for omitted deformation values and sparse offsets (upstream left array entries undefined).
3. FFD/IK duration calculation uses `timeline.frames.length` (upstream referenced an undefined `timeline.frameCount`).

The 3.8 binary reader rejects exports marked `3.8.75` upstream. Its version guard has a local opt-in, `allowLegacy3875`, which the adapter enables only when the binary header reports `3.8.75`. This does not rewrite the source assets or their version strings. It was validated on the 141 SKEL files / 294 animations in the local `141套Spine高级特效` library, including meshes, path constraints and the clipping sample `E54148`. Parsing and sampled geometry checks passed, with representative browser previews. This is a library-specific compatibility accommodation, not a claim that all 3.8.75 files are compatible or pixel-identical to the editor. The JSON reader's original version guard is unchanged.

Source URLs and original copyright/license headers are preserved. No asset files have been changed.
