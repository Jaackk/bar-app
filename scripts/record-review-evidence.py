"""Summarise local observations without bundling downloaded menus or copied articles.

Usage: python scripts/record-review-evidence.py REVIEW_DIRECTORY
The media inventory is a source/Pillow audit, not proof of iOS asset compilation.
"""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
review = Path(sys.argv[1])
out = root / 'docs/release'
out.mkdir(parents=True, exist_ok=True)

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(name, value):
    (out / name).write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')

monitor = read(review / 'menu-monitor/latest-check.json')
menus = [{k: v for k, v in row.items() if k not in ('textLines', 'document')} for row in monitor['menus']]
write('menu-status.json', {k: monitor[k] for k in ('checkedAt', 'source', 'scope', 'status', 'errors', 'differences') if k in monitor} | {
    'menus': menus, 'baselineAccepted': monitor.get('baselineAccepted', False),
    'decision': 'No changed fingerprint: no public-menu content update manufactured. Linked older Shack material remains separate and is not current stock evidence.'})

audit = read(review / 'media-audit.json')
assets = []
for asset in audit['assets']:
    if asset['kind'] != 'imageset':
        continue
    assets.append({k: asset[k] for k in ('name', 'path', 'valid_catalogue_image', 'files', 'image_kind') if k in asset} | {
        'sourceURLs': sorted({url for p in asset.get('provenance', []) for url in p.get('urls', [])}),
        'provenanceDocuments': sorted({p['document'] for p in asset.get('provenance', [])}),
        'rights': 'Permission/licence not established by public availability; review before external distribution.',
        'visualScreening': 'Contact-sheet screening only; not a guarantee of exact expression, vintage or pack size.'})
products = [{k: p[k] for k in ('id', 'name', 'category', 'imageName', 'image_status', 'renderable_catalogue_proxy', 'sourceURL', 'sourcePage') if k in p} for p in audit['canonical_products']]
write('image-inventory.json', {'reviewedOn': '2026-10-10', 'method': audit['method'],
    'summary': audit['summary'], 'assets': assets, 'products': products,
    'duplicateFileGroups': audit['duplicate_file_groups'],
    'exceptions': ['Unreferenced zero-byte Johnnie Walker asset retained but rejected by rendering checks.',
        'Group shots and mismatched expressions are suppressed by ProductCatalogueCorrections.',
        'The strawberry image formerly used for plain Daiquiri is suppressed.',
        'House/reference illustrations are not proof of venue presentation. User photos have priority.']})
wines = read(root/'BARCore/Data/hove-wines.json')
mapping = {w['id']: w for w in audit['canonical_wines']}
write('wine-review.json', {'reviewedOn': '2026-10-10', 'count': len(wines),
    'basis': 'Current main-menu fingerprint matches reviewed source. Existing objective identities retained; no new public-menu revision. Pairing/taste prose is editorial, not guaranteed availability or allergens.',
    'limitation': 'All 59 source records and image mappings inspected. Exact bottle vintage/pack and redistribution rights require venue/supplier confirmation. No tasting or physical-stock verification claimed.',
    'wines': [w | {'imageAudit': mapping.get(w['id'])} for w in wines]})
print('Recorded menu fingerprints, full image inventory and 59-wine review.')
