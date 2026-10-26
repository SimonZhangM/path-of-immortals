"""Import approved prose without changing its source; emit runtime JSON, not Markdown parsing in UI."""
import itertools
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "output/imagegen/灵根_四类灵根文案.md"
ELEMENTS = dict(zip("金木水火土风雷", ["metal", "wood", "water", "fire", "earth", "wind", "thunder"]))


def build():
    text = SOURCE.read_text(encoding="utf-8-sig")
    matches = re.findall(r"### (\d+)｜([^\n]+)\s+\*\*短句：\*\* ([^\n]+)\s+\*\*灵根描述：\*\* ([^\n]+)", text)
    assert len(matches) == 73
    records = []
    for number, title, phrase, description in matches:
        number = int(number)
        roots = [key for name, key in ELEMENTS.items() if name in title.split("·")[0]]
        count = len(roots) if number <= 63 else (4 if number <= 68 else 5)
        record = {
            "id": "base.root_copy.%02d" % number,
            "count": count,
            "name": title if count <= 3 else ("四灵根" if count == 4 else "五灵根"),
            "phrase": phrase,
            "description": description,
        }
        if count <= 3:
            record["elements"] = roots
        records.append(record)
    # Every one/two/three-root combination must have exactly one source description.
    for count in range(1, 4):
        expected = {tuple(c) for c in itertools.combinations(ELEMENTS.values(), count)}
        actual = [tuple(r["elements"]) for r in records if r["count"] == count]
        assert len(actual) == len(expected) and set(actual) == expected
    output = {"source": str(SOURCE.relative_to(ROOT)).replace("\\", "/"), "elements": list(ELEMENTS.values()), "records": records}
    target = ROOT / "data/character_root_descriptions.json"
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Imported 73 descriptions; specific configurations: 7 + 21 + 35 + 35 + 21 = 119.")


if __name__ == "__main__":
    build()
