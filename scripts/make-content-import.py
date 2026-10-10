#!/usr/bin/env python3
"""Prepare venue recipe/wine content for explicit owner review; never include operational state.

Products use Swift's canonical catalogue corrections and are intentionally not
exported from raw ingredient records here. Recommended is curated separately.
"""
import argparse
import json
from pathlib import Path

def build(output):
    seed = Path(__file__).resolve().parents[1] / 'BARCore/Data'
    def read(name):
        return json.loads((seed/(name+'.json')).read_text(encoding='utf-8'))
    content = {'schemaVersion': 1, 'venues': read('venues'),
               'cocktails': read('classics') + read('hove-cocktails') + read('house-classics'),
               'wines': read('hove-wines')}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(content, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f'Prepared venue content for owner review: {output}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output)
