"""Export approved book copy; --check verifies the committed runtime snapshot."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen/七系功法_35本四栏文案.md"
TARGET = ROOT / "data/ui/technique_item_presentations.json"


def records():
    source = SOURCE.read_text(encoding="utf-8")
    source = source.split("<!-- UI_COPY_BEGIN", 1)[1].split("<!-- UI_COPY_END", 1)[0]
    books = json.loads((ROOT / "data/cultivation_library.json").read_text(encoding="utf-8"))["books"]
    by_name = {book["name"]: book for book in books}
    art = json.loads((ROOT / "data/ui/technique_book_art.json").read_text(encoding="utf-8"))
    overview = json.loads((ROOT / "data/ui/technique_overviews.json").read_text(encoding="utf-8"))
    result = {}
    for name, block in re.findall(r"### \d+｜《([^》]+)》\s*(.*?)(?=### |\Z)", source, re.S):
        book = by_name[name]
        tags = re.search(r"\*\*评估要点：\*\*\s*([^\n]+)", block)[1].split("｜")[0].split("·")
        intro = re.search(r"\*\*简介：\*\*\s*([^\n]+)", block)[1].strip()
        poem_block = block.split("**诗意配词：**", 1)[1].split("**来历与核心：**", 1)[0]
        poem = "\n".join(line[1:].strip() for line in poem_block.splitlines() if line.startswith(">"))
        assert len(tags) == 2 and all(tags) and intro and poem, name
        assert poem.replace("\n", "") == overview[book["id"]]["poem"].replace("\n", ""), name
        assert (ROOT / art[book["id"]].removeprefix("res://")).is_file(), name
        assert book["id"] not in result, name
        result[book["id"]] = {"name": name, "tags": tags, "flavor_description": poem, "description": intro}
    assert len(result) == 35 and set(result) == {book["id"] for book in books}
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = records()
    if args.check:
        assert json.loads(TARGET.read_text(encoding="utf-8")) == data, "Runtime copy differs from approved source"
    else:
        TARGET.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PASS: 35 book names, two tags, poems, introductions and cover paths match approved content")
