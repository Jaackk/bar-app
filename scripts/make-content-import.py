#!/usr/bin/env python3
"""Combine editable seed arrays into a content-only import file. No personal data."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, help="Destination JSON file")
args = parser.parse_args()
seed = Path(__file__).resolve().parents[1] / "BARCore" / "Data"
content = {"schemaVersion": 1}
for key in ("venues", "cocktails", "wines", "prep", "stock"):
    content[key] = json.loads((seed / f"{key}.json").read_text())
content["cocktails"] += json.loads((seed / "classics.json").read_text())
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(content, indent=2, ensure_ascii=False) + "\n")
print(f"Created content-only import: {args.output}")
