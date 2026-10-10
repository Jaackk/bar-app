"""Regenerate review evidence from the shipped immutable classic reference library."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'BARCore/Data'
OUT = ROOT / 'docs/release'
def load(name):
    return json.loads((DATA/(name+'.json')).read_text(encoding='utf-8'))
def measures(recipe):
    return '; '.join(f"{i.get('quantityDisplay') or str(i['amount']).removesuffix('.0') + ' ' + i['unit']} {i['name']}" for i in recipe['ingredients'])

def build():
    raw = {r['id']: r for r in load('classics') + load('house-classics')}
    records = []
    lines = ['BAR CLASSIC ACCURACY AUDIT — 10 October 2026',
             '77 original records (31 generic + 46 house), organised into 49 reference identities.',
             '48 researched Recommended specifications; 1 explicitly house-only variation.',
             'No stored Rockwater measures were rewritten. Reference choices are not claims of one universally correct ratio.',
             'Three exact imported house technique errors are corrected in resolved service views: Sidecar, Mai Tai, Pimm’s.',
             'The original methods remain in raw source and owner-editable Custom records for evidence.',
             'Verification means professional source review, not Rockwater management approval or allergen certification.', '']
    for ref in load('recommended-classics'):
        previous = [raw[id] for id in ref['aliases']]
        recommended = ref['recommended']
        record = dict(ref)
        record['previousRecords'] = [{'id': p['id'], 'name': p['name'], 'specification': measures(p), 'method': p['method'], 'steps': p.get('prepInstructions', []), 'source': p.get('sourceReference')} for p in previous]
        record['changesMade'] = ['Added separate curated reference and persistent specification selection; stored Custom remains intact.']
        if ref.get('correctedLegacyMethod'):
            record['changesMade'].append('Corrected exact imported technique in the service view: '+ref['correctedLegacyMethod']+' → '+ref['customMethod'])
        record['confidence'] = 'Source-backed selected professional variant; alternatives documented' if recommended else 'House variation only; no invented Recommended measurements'
        records.append(record)
        name = recommended['name'] if recommended else previous[0]['name']
        lines += [name.upper(), ref['id'], 'Recommended: '+(measures(recommended) if recommended else 'Not supplied: house-only variation'),
                  'Technique: '+(recommended['method'] if recommended else previous[0]['method'])]
        if recommended:
            lines += ['Glass: '+recommended['glass']+' | Ice: '+recommended['ice']+' | Garnish: '+recommended['garnish']]
            lines += ['  '+step for step in recommended['prepInstructions']]
        lines += ['Choice / variation: '+ref['decision'], 'House comparison: '+ref['customReview']]
        for p in previous:
            lines += [f"Previous {p['id']}: {measures(p)} | {p['method']}"]
        if ref.get('correctedLegacyMethod'):
            lines += ['Technique correction: '+ref['correctedLegacyMethod']+' → '+ref['customMethod']]
        lines += ['Sources: '+ '; '.join(s['name']+' '+s['url'] for s in ref['sources']),
                  'Verified: '+ref['verifiedOn']+' | Content version: '+str(ref['version']), '']
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/'classic-audit.json').write_text(json.dumps(records, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (OUT/'classic-audit.txt').write_text('\n'.join(line.rstrip() for line in lines), encoding='utf-8')
    print(f'Wrote {len(records)} complete classic audit entries')

if __name__ == '__main__':
    build()
