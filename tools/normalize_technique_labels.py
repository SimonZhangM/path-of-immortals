"""Normalize the 35 user-approved label PNGs; prepare before applying backups.

Uses alpha > 3 to discard generation dust (at most 1.18% opacity), then
resamples the complete label to a shared visible extent with premultiplied
alpha. Original files are hash-checked and backed up byte-for-byte before
any replacement. No game assets are modified.
"""
import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

CANVAS = (1086, 362)
LABEL = (1068, 120)
BOX = (9, 121, 1077, 241)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(path):
    with Image.open(path) as image:
        assert image.mode == "RGBA", path
        assert image.size == CANVAS, path
        assert image.getchannel("A").getbbox() == BOX, path
        assert image.getpixel((0, 0))[3] == 0, path


def prepare(source, output):
    files = sorted(source.glob("UI-*-*-label.png"))
    assert len(files) == 35, f"Expected 35 PNG labels, got {len(files)}"
    normalized = output / "normalized"
    normalized.mkdir(parents=True, exist_ok=True)
    records = []
    for path in files:
        with Image.open(path) as image:
            pixels = np.array(image.convert("RGBA"))
            original_size = image.size
        pixels[pixels[:, :, 3] <= 3] = 0
        clean = Image.fromarray(pixels)
        source_box = clean.getchannel("A").getbbox()
        # RGBa prevents dark fringes from transparent RGB during resampling.
        label = clean.crop(source_box).convert("RGBa").resize(
            LABEL, Image.Resampling.LANCZOS
        ).convert("RGBA")
        assert label.getchannel("A").getbbox() == (0, 0, *LABEL), path
        result = Image.new("RGBA", CANVAS)
        result.paste(label, BOX[:2])  # Do not apply alpha twice via a paste mask.
        target = normalized / path.name
        result.save(target)
        validate(target)
        records.append({"name": path.name, "source_sha256": digest(path),
                        "source_canvas": original_size, "source_clean_bounds": source_box,
                        "output_sha256": digest(target)})
    manifest = {"source": str(source.resolve()), "canvas": CANVAS,
                "label_extent": LABEL, "bounds": BOX, "center": [543, 181],
                "alpha_cleanup_max": 3, "files": records}
    (output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    # Inspection sheet: all 35 labels at the same scale, no changes to deliverables.
    sheet = Image.new("RGB", (1120, 18 * 92), "#202830")
    draw = ImageDraw.Draw(sheet)
    for i, row in enumerate(records):
        x, y = (i % 2) * 560, (i // 2) * 92
        draw.text((x + 12, y + 4), row["name"], fill="#e9ddbb")
        with Image.open(normalized / row["name"]) as image:
            sample = image.crop(BOX).resize((534, 60), Image.Resampling.LANCZOS)
            sheet.paste(sample, (x + 13, y + 24), sample)
        draw.line((x + 280, y + 21, x + 280, y + 88), fill="#82949b", width=1)
    sheet.save(output / "inspection.png")
    print(json.dumps({"prepared": len(records), "output": str(normalized),
                      "canvas": CANVAS, "visible_bounds": BOX, "center": [543, 181]}))


def apply(source, output):
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    assert source.resolve() == Path(manifest["source"]).resolve()
    records = manifest["files"]
    assert len(records) == 35
    for row in records:
        assert Path(row["name"]).name == row["name"]
        assert digest(source / row["name"]) == row["source_sha256"], "Original changed; abort"
        target = output / "normalized" / row["name"]
        assert digest(target) == row["output_sha256"], "Prepared output changed; abort"
        validate(target)
    backup = source.parent / (source.name + "-label-backup-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    backup.mkdir(exist_ok=False)
    for row in records:
        shutil.copy2(source / row["name"], backup / row["name"])
        assert digest(backup / row["name"]) == row["source_sha256"]
    shutil.copy2(output / "manifest.json", backup / "manifest.json")
    for row in records:
        destination = source / row["name"]
        assert digest(destination) == row["source_sha256"], "Original changed during apply"
        temporary = source / (row["name"] + ".normalizing")
        assert not temporary.exists()
        shutil.copyfile(output / "normalized" / row["name"], temporary)
        temporary.replace(destination)
        assert digest(destination) == row["output_sha256"]
        validate(destination)
    receipt = {"replaced": len(records), "source": str(source), "backup": str(backup),
               "verified_original_backups": 35, "verified_outputs": 35}
    (output / "applied.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    (apply if args.apply else prepare)(args.source, args.output)
