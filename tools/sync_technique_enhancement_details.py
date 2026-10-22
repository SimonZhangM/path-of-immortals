"""Sync registered enhancement pages from copy, stable branch keys and existing art."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY = Path("output/imagegen/七系功法_357项强化文案.md")
SPELL_COPY = Path("output/imagegen/七系功法_56项法术文案.md")
source = (ROOT / COPY).read_text(encoding="utf-8")
spell_sections = re.split(r"(?m)^#### ", (ROOT / SPELL_COPY).read_text(encoding="utf-8"))[1:]
library = json.loads((ROOT / "data/cultivation_library.json").read_text(encoding="utf-8"))
art_books = json.loads((ROOT / "data/ui/technique_progress_books.json").read_text(encoding="utf-8"))
target = ROOT / "data/ui/technique_enhancement_details.json"
records = {}
source_numbers = set()

synced_choices = 0
synced_pages = 0
for book in library["books"]:
    book_id = book["id"]
    art = json.loads((ROOT / art_books[book_id]["content"].removeprefix("res://")).read_text(encoding="utf-8"))
    assert art["book_id"] == book_id
    body = next(s for s in re.split(r"(?m)^### ", source)[1:] if s.startswith("《" + book["name"] + "》"))
    body = re.split(r"(?m)^## ", body)[0]
    sections = re.split(r"(?m)^#### ", body)[1:]
    ranks = {}
    for stage in art["stages"]:
        combat = book["max_level"] == 8
        rank = stage["level"] + 1 if combat else stage["level"]
        spell = next(s for s in library["spells"] if s["book_id"] == book_id and s["learned_at_book_level"] == rank - 1) if combat else None
        choices = []
        for index, picture in enumerate(stage["choices"]):
            section = next(s for s in sections if f"｜{picture['name']}（第{rank}重" in s.splitlines()[0])
            heading, content = section.split("\n", 1)
            number = int(heading.split("｜", 1)[0])
            assert number not in source_numbers, heading
            source_numbers.add(number)
            fields = re.split(r"\*\*(?:分类|诗意配词|功能描述|核心要点)：\*\*", content)[1:]
            assert len(fields) == 4
            if book["role"] == "技艺":
                # Production branches are not registered for learning yet. Keep
                # preview identity separate from published gameplay branch IDs.
                key = f"ui.enhancement.{book_id.rsplit('.', 1)[1]}.{rank}.{index + 1}"
            else:
                key = next(k for k in book["branches"][str(rank)] if book.get("branch_display_names", {}).get(k, k) == picture["name"])
            assert (ROOT / picture["icon"].removeprefix("res://")).is_file()
            choices.append({
                "branch_key": key, "name": picture["name"], "icon": picture["icon"],
                "source_section": heading.strip(), "categories": fields[0].strip().split(" · "),
                "poem": fields[1].strip(), "description": fields[2].strip(),
                "core_points": re.findall(r"(?m)^\d+\. (.+)$", fields[3]),
            })
        assert len(choices) == (3 if book["role"].startswith("状态") else 2)
        assert all(c["description"] and c["core_points"] for c in choices)
        ranks[str(rank)] = {"spell_id": spell["id"] if spell else "", "choices": choices}
        if spell:
            section = next(s for s in spell_sections if s.splitlines()[0].endswith("｜" + spell["name"]))
            heading, content = section.split("\n", 1)
            fields = re.split(r"\*\*(?:分类|诗意配词|功能描述|核心要点|学习条件)：\*\*", content)[1:]
            picture = stage["spell"]
            assert len(fields) == 5 and picture["name"] == spell["name"]
            assert (ROOT / picture["icon"].removeprefix("res://")).is_file()
            # A summary does not register a full odd-rank spell detail page.
            ranks[str(rank)]["prerequisite"] = {
                "name": spell["name"], "icon": picture["icon"],
                "categories": fields[0].strip().split(" · "), "poem": fields[1].strip(),
                "source_document": SPELL_COPY.as_posix(), "source_section": heading.strip(),
            }
        synced_choices += len(choices)
        synced_pages += 1
    records[book_id] = {"source_document": COPY.as_posix(), "ranks": ranks}

assert len(records) == 35 and synced_choices == 357 and synced_pages == 161
assert source_numbers == set(range(1, 358))
output = json.dumps(records, ensure_ascii=False, indent=2) + "\n"
if "--check" in sys.argv:
    assert target.read_text(encoding="utf-8") == output, "Enhancement snapshot is stale; run this tool without --check."
else:
    target.write_text(output, encoding="utf-8")
print(f"Verified {synced_choices} enhancements across {synced_pages} pages / {len(records)} books, with 56 prerequisite summaries.")
