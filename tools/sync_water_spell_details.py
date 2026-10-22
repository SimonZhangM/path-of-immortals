"""Sync all 56 spell sidebars; retain the established command for compatibility."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY = Path("output/imagegen/七系功法_56项法术文案.md")
source = (ROOT / COPY).read_text(encoding="utf-8")
library = json.loads((ROOT / "data/cultivation_library.json").read_text(encoding="utf-8"))
target = ROOT / "data/ui/technique_spell_details.json"
records = {}
art = {}
art_books = json.loads((ROOT / "data/ui/technique_progress_books.json").read_text(encoding="utf-8"))
for mapping in art_books.values():
    book = json.loads((ROOT / mapping["content"].removeprefix("res://")).read_text(encoding="utf-8"))
    for stage in book["stages"]:
        if "spell" in stage:
            art[(book["book_id"], stage["level"])] = stage["spell"]

sections = re.split(r"(?m)^#### ", source)[1:]
for spell in library["spells"]:
    section = next(s for s in sections if s.splitlines()[0].endswith("｜" + spell["name"]))
    heading, body = section.split("\n", 1)
    fields = re.split(r"\*\*(?:分类|诗意配词|功能描述|核心要点|学习条件)：\*\*", body)[1:]
    assert len(fields) == 5
    numbered = lambda text: re.findall(r"(?m)^\d+\. (.+)$", text)
    rank = spell["learned_at_book_level"]
    picture = art[(spell["book_id"], rank)]
    assert picture["name"] == spell["name"]
    assert (ROOT / picture["icon"].removeprefix("res://")).is_file()
    conditions = numbered(fields[4])
    records[spell["id"]] = {
        "book_id": spell["book_id"], "rank": rank, "name": spell["name"],
        "icon": picture["icon"], "source_document": COPY.as_posix(),
        "source_section": heading.strip(), "categories": fields[0].strip().split(" · "),
        "poem": fields[1].strip(), "description": fields[2].strip(),
        "core_points": numbered(fields[3]), "learning_conditions": conditions,
        "required_realm": (rank + 1) // 2,
        "learning_cost": int(re.search(r"）(\d+)", conditions[1]).group(1)),
    }
assert len(records) == 56
assert {int(r["source_section"].split("｜", 1)[0]) for r in records.values()} == set(range(1, 57))
output = json.dumps(dict(sorted(records.items())), ensure_ascii=False, indent=2) + "\n"
if "--check" in sys.argv:
    assert target.read_text(encoding="utf-8") == output, "Spell snapshot needs synchronization."
else:
    target.write_text(output, encoding="utf-8")
print("Verified 56 spells across 14 combat books / seven elements.")
