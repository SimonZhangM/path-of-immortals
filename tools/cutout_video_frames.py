"""Approved first-three-frame matte and shared helpers. For all 180 frames use batch_cutout_video_frames.py."""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def connected_regions(mask):
    remaining = mask.copy()
    height, width = mask.shape
    for y, x in zip(*np.nonzero(mask)):
        if not remaining[y, x]:
            continue
        remaining[y, x] = False
        queue = deque([(y, x)])
        region = []
        while queue:
            cy, cx = queue.popleft()
            region.append((cy, cx))
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < height and 0 <= nx < width and remaining[ny, nx]:
                    remaining[ny, nx] = False
                    queue.append((ny, nx))
        yield region


def make_alpha(rgb):
    # Approved first-three-frame matte; only the alpha channel is calculated.
    diff = rgb[:, :, 0].astype(np.float32) - rgb[:, :, 1].astype(np.float32)
    alpha = np.rint(np.clip((diff + 4) / 8, 0, 1) * 255).astype(np.uint8)
    alpha[660:, 590:] = 0
    alpha[:80, :160] = 0
    keep = np.zeros(alpha.shape, dtype=bool)
    for region in connected_regions(alpha > 0):
        if len(region) >= 10:
            ys, xs = zip(*region)
            keep[ys, xs] = True
    alpha[~keep] = 0
    for region in connected_regions(~keep):
        if len(region) <= 96 and all(0 < y < alpha.shape[0] - 1 and 0 < x < alpha.shape[1] - 1 for y, x in region):
            ys, xs = zip(*region)
            keep[ys, xs] = True
            alpha[ys, xs] = 255
    interior = np.array(Image.fromarray(keep.astype(np.uint8) * 255).filter(ImageFilter.MinFilter(3))) == 255
    alpha[interior] = 255
    feathered = np.array(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.45)))
    return np.where(keep, feathered, 0).astype(np.uint8)


def checker(size):
    yy, xx = np.indices((size[1], size[0]))
    values = np.where((xx // 24 + yy // 24) % 2, 205, 235).astype(np.uint8)
    return Image.fromarray(np.repeat(values[:, :, None], 3, axis=2)).convert('RGBA')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--reuse-first-three', type=Path)
    args = parser.parse_args()
    args.end = 3
    for number in range(1, args.end + 1):
        if not (args.source / f'frame_{number:06d}.png').is_file():
            parser.error(f'Missing source frame {number}')
    args.output.mkdir(parents=True, exist_ok=False)
    previews = args.output / 'previews'
    previews.mkdir()
    records = []
    sheet = Image.new('RGB', (1440, min(args.end, 3) * 760), '#ffffff')
    draw = ImageDraw.Draw(sheet)
    overview = None
    for number in range(1, args.end + 1):
        name = f'frame_{number:06d}.png'
        source = args.source / name
        original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
        image = Image.open(source).convert('RGB')
        assert image.size == (720, 720)
        rgb = np.array(image)
        destination = args.output / name
        reused = args.reuse_first_three is not None and number <= 3
        if reused:
            shutil.copy2(args.reuse_first_three / name, destination)
            cutout = Image.open(destination).convert('RGBA')
            alpha = np.array(cutout)[:, :, 3]
        else:
            alpha = make_alpha(rgb)
            cutout = Image.fromarray(np.dstack([rgb, alpha]))
            cutout.save(destination)
        saved = np.array(Image.open(destination))
        assert np.array_equal(saved[:, :, :3], rgb), 'Foreground RGB changed'
        assert saved.shape == (720, 720, 4)
        assert all(alpha[y, x] == 0 for x, y in ((0, 0), (719, 0), (0, 719), (719, 719)))
        assert hashlib.sha256(source.read_bytes()).hexdigest() == original_hash
        bbox = Image.fromarray(alpha).getbbox()
        records.append({'file': name, 'source_sha256': original_hash,
                        'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
                        'width': 720, 'height': 720, 'mode': 'RGBA', 'alpha_bbox': bbox,
                        'transparent_pixels': int(np.sum(alpha == 0)),
                        'edge_pixels': int(np.sum((alpha > 0) & (alpha < 255))),
                        'rgb_unchanged': True, 'source_unchanged': True,
                        'reused_approved_frame': reused})
        composite = Image.alpha_composite(checker(image.size), cutout).convert('RGB')
        if number <= 3:
            top = (number - 1) * 760
            draw.text((16, top + 12), name + ' | Original', fill='black')
            draw.text((736, top + 12), name + ' | Alpha cutout', fill='black')
            sheet.paste(image, (0, top + 40))
            sheet.paste(composite, (720, top + 40))
        slot = (number - 1) % 20
        if slot == 0:
            overview = Image.new('RGB', (1200, 1040), '#eeeeee')
        x, y = slot % 5 * 240, slot // 5 * 260
        ImageDraw.Draw(overview).text((x + 8, y + 4), name, fill='black')
        overview.paste(composite.resize((240, 240), Image.Resampling.LANCZOS), (x, y + 20))
        if slot == 19 or number == args.end:
            overview.save(previews / f'overview_{(number - 1) // 20 + 1:02d}.jpg', quality=95)
        if number % 10 == 0 or number == args.end:
            print(f'Completed {number}/{args.end}', flush=True)
    sheet.save(args.output / 'comparison.png')
    report = {'source_directory': str(args.source), 'method': 'Approved green chroma approach; alpha-only, no RGB edits, resizing or translation; background text masks at bottom right and top left', 'frames': records}
    (args.output / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'total': len(records), 'reused': sum(r['reused_approved_frame'] for r in records), 'new': sum(not r['reused_approved_frame'] for r in records), 'rgb_unchanged': all(r['rgb_unchanged'] for r in records), 'source_unchanged': all(r['source_unchanged'] for r in records)}, indent=2))


if __name__ == '__main__':
    main()
