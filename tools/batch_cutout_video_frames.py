"""Complete the authorized 180-frame cutout set without modifying source RGB.

Requires Pillow, numpy and opencv-python-headless. The first three approved
cutouts are copied byte-for-byte. Remaining frames use the same green-key seeds
with graph-cut boundary refinement for cool metal and soft alpha for dust.
"""
import argparse
from concurrent.futures import ProcessPoolExecutor
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw
from cutout_video_frames import make_alpha, checker


@lru_cache(maxsize=6)
def reference_mask(source, reference):
    import cv2
    rgb = np.array(Image.open(Path(source) / f'frame_{reference:06d}.png').convert('RGB'))
    protection = make_alpha(rgb) > 0
    protection[:500, :] = False
    protection[:, 450:] = False
    return cv2.dilate(protection.astype(np.uint8), np.ones((7, 7), np.uint8)) > 0


def motion_alpha(rgb, source, number):
    import cv2
    cv2.setNumThreads(1)
    diff = rgb[:, :, 0].astype(float) - rgb[:, :, 1].astype(float)
    base = make_alpha(rgb)
    mask = np.full(diff.shape, cv2.GC_PR_BGD, np.uint8)
    mask[diff > -14] = cv2.GC_PR_FGD
    mask[diff < -14] = cv2.GC_BGD
    core = cv2.erode((base >= 250).astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    mask[core & (diff > -4)] = cv2.GC_FGD
    mask[:80, :160] = cv2.GC_BGD
    mask[660:, 590:] = cv2.GC_BGD
    cv2.setRNGSeed(0)
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, None,
                np.zeros((1, 65)), np.zeros((1, 65)), 4, cv2.GC_INIT_WITH_MASK)
    foreground = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)
    alpha = cv2.GaussianBlur(foreground.astype(np.float32), (0, 0), .6)

    reference = min((1, 20, 50, 80, 120, 150), key=lambda value: abs(value - number))
    protection = reference_mask(source, reference)
    green_blue = rgb[:, :, 1].astype(float) - rgb[:, :, 2].astype(float)
    dust_zone = np.zeros(diff.shape, bool)
    dust_zone[470:660, :380] = True
    dust_zone &= ~protection & ~((green_blue < 9) & foreground)
    dust = np.clip((diff + 21) / 45, 0, 1).astype(np.float32)
    dust[~dust_zone] = 0
    dust = cv2.GaussianBlur(dust, (0, 0), 2)
    dust[dust < .06] = 0
    alpha[dust_zone] = dust[dust_zone]
    alpha[:80, :160] = 0
    alpha[660:, 590:] = 0
    return np.rint(np.clip(alpha, 0, 1) * 255).astype(np.uint8)


def process_frame(job):
    source_directory, output_directory, approved_directory, number = job
    name = f'frame_{number:06d}.png'
    source = Path(source_directory) / name
    destination = Path(output_directory) / name
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    image = Image.open(source).convert('RGB')
    assert image.size == (720, 720)
    rgb = np.array(image)
    if number <= 3:
        approved = Path(approved_directory) / name
        shutil.copy2(approved, destination)
        assert approved.read_bytes() == destination.read_bytes()
    else:
        alpha = motion_alpha(rgb, source_directory, number)
        Image.fromarray(np.dstack([rgb, alpha])).save(destination)
    saved = np.array(Image.open(destination))
    assert saved.shape == (720, 720, 4)
    assert np.array_equal(saved[:, :, :3], rgb), f'RGB changed: {name}'
    alpha = saved[:, :, 3]
    assert all(alpha[y, x] == 0 for x, y in ((0, 0), (719, 0), (0, 719), (719, 719)))
    assert alpha.max() == 255 and np.sum(alpha > 0) > 50000, name
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    return {'file': name, 'source_sha256': source_hash,
            'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'width': 720, 'height': 720, 'mode': 'RGBA',
            'alpha_bbox': Image.fromarray(alpha).getbbox(),
            'visible_pixels': int(np.sum(alpha > 0)),
            'transparent_pixels': int(np.sum(alpha == 0)),
            'partial_alpha_pixels': int(np.sum((alpha > 0) & (alpha < 255))),
            'rgb_unchanged': True, 'source_unchanged': True,
            'reused_approved_frame': number <= 3}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--approved', type=Path, required=True)
    parser.add_argument('--opencv-path', type=Path)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    if args.opencv_path:
        sys.path.insert(0, str(args.opencv_path.resolve()))
    import cv2
    for number in range(1, 181):
        assert (args.source / f'frame_{number:06d}.png').is_file()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'previews').mkdir()
    jobs = [(str(args.source.resolve()), str(args.output.resolve()), str(args.approved.resolve()), n) for n in range(1, 181)]
    records = []
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for record in pool.map(process_frame, jobs):
            records.append(record)
            if len(records) % 10 == 0:
                print(f'Validated {len(records)}/180', flush=True)
    assert len(list(args.output.glob('frame_*.png'))) == 180
    for page in range(9):
        sheet = Image.new('RGB', (1200, 1040), '#eeeeee')
        draw = ImageDraw.Draw(sheet)
        for slot in range(20):
            number = page * 20 + slot + 1
            name = f'frame_{number:06d}.png'
            rgba = Image.open(args.output / name).convert('RGBA')
            preview = Image.alpha_composite(checker(rgba.size), rgba).convert('RGB')
            x, y = slot % 5 * 240, slot // 5 * 260
            draw.text((x + 8, y + 4), name, fill='black')
            sheet.paste(preview.resize((240, 240), Image.Resampling.LANCZOS), (x, y + 20))
        sheet.save(args.output / 'previews' / f'overview_{page + 1:02d}.jpg', quality=95)
    report = {'source_directory': str(args.source), 'frames_total': 180, 'frames_new': 177,
              'frames_reused': 3, 'source_fps': 30, 'opencv_version': cv2.__version__,
              'method': 'Alpha-only green-key seeds with GrabCut boundary refinement and soft dust matte. Original RGB, frame size and positions remain unchanged. First 3 approved PNGs reused byte-for-byte.',
              'limitations': 'Alpha is estimated from compressed video; dust and motion blur may retain original green spill. No color decontamination, repainting, resizing or shifting.',
              'frames': records}
    (args.output / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({key: report[key] for key in ('frames_total', 'frames_new', 'frames_reused')}, indent=2))


if __name__ == '__main__':
    main()
