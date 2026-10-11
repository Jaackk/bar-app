"""Build the dated, conservative identity review from audit-bundled-media.py.

Judgements below record the final PC visual/source screening; regeneration does
not imply a fresh identity/licence review. Run the inventory first after edits.
"""
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/release'
inventory = json.loads((OUT/'image-inventory-current.json').read_text(encoding='utf-8'))
new = {r['productID']: r for r in json.loads((OUT/'NEW-IMAGE-PROVENANCE.json').read_text(encoding='utf-8'))}
generated = {'lime-photo', 'lemon-photo', 'orange-photo', 'strawberry-photo'}
named_ingredients = {'spec-absolut-vodka', 'spec-absolut-vanilla', 'spec-martini-extra-dry',
    'spec-martini-rosso', 'spec-teichene-peach', 'spec-taylors-velvet-falernum',
    'spec-benedictine', 'spec-angostura-bitters', 'spec-pimms', 'spec-coca-cola', 'spec-del-maguey-puebla'}
notes = {
 'menu-asahi-0-0': 'Generic Asahi logo did not establish alcohol-free expression. Suppressed.',
 'menu-orange-juice': 'Supplier badge was not an orange juice product photo. Suppressed.',
 'menu-kraken': 'Logo fragment removed; photograph the actual expression before selecting a bottle.',
 'spec-sweet-vermouth': 'Two different aperitif/vermouth bottles in one image did not identify a generic ingredient.',
 'menu-grey-goose-essences': 'Menu names a range, photograph/confirm the flavour. One pictured flavour is insufficient.',
 'menu-veuve-clicquot-brut-yellow-label-magnum': '750 ml reference is not the magnum pack. Correct-size photo required.',
 'menu-minuty-prestige-chateau-minuty-magnum': '750 ml reference is not the magnum pack. Correct-size photo required.',
 'menu-real-blush-sparkling': 'Current official Blush can is not the menu bottle. Do not substitute packaging.',
 'menu-touriga-nacional-santo-isidro-de-pegoes': 'Producer has Vinhas de Pegoes Touriga; exact Santo Isidro cuvee/label not established.',
 'menu-syrah-tumbleweed-big-sky-bruce-jack-wines': 'No verified primary image for exact Tumbleweed Big Sky found. Supplier/venue photo needed.',
 'menu-raboso-il-casone': 'Retail images are not permission. Obtain current supplier/venue label photograph.',
 'menu-montepulciano-blend-anima-osca-tenimenti-grieco': 'Producer Anima Osca Bianco sheet is not this red blend; old group shot remains suppressed.',
 'menu-saumur-champigny-vieilles-vignes-domaine-lavigne': 'Cuvee/label/vintage relationship needs confirmation; do not substitute Traditionnelle.',
 'menu-picpoul-de-pinet-tournee-du-sud': 'Unrelated Lafage Chardonnay removed previously. Exact approved primary asset not obtained.',
 'menu-grenache-chardonnay-cote-est-domaine-lafage': 'Producer brochure establishes range, not a licensed exact current bottle image.',
 'menu-cotes-de-provence-maia': 'Producer confirms wine/grapes; lifestyle photography does not establish current bottle pack.',
 'menu-cotes-de-provence-maia-magnum': 'Photograph actual magnum; standard bottle/lifestyle shot is insufficient.',
 'menu-lbv-quinta-do-vallado': 'LBV vintage required before exact label selection. Producer website is not a redistribution licence.',
 'menu-tawny-20yr-quinta-do-vallado': 'Producer confirms 20-year tawny blend, not a harvest vintage; approved bottle image still needed.',
 'menu-cornish-orchards-fruit-cider-4': 'Generic fruit cider menu wording does not establish Cherry/Blackberry vs Raspberry/Elderflower.',
 'menu-trip-lemon-basil': 'Exact current manufacturer product/asset not confirmed; never substitute Elderflower & Mint.',
 'spec-oggs': 'Manufacturer confirms aquafaba in multiple packs; group image rejected. Confirm actual pack, then photograph it.',
 'spec-blend-coffee': 'Venue bottle/brand unresolved; menu wording cannot identify exact liqueur.',
 'spec-blend-passionfruit': 'Venue bottle/brand unresolved; do not use puree or juice as liqueur image.',
 'spec-nll-fl': 'Unresolved venue abbreviation; existing unrelated image remains suppressed.',
 'spec-nll-ms': 'Unresolved venue abbreviation; existing unrelated image remains suppressed.',
 'spec-ms-betters-bitters': 'Brand alone does not establish which expression/formulation is used.',
 'menu-antica-rosso': 'Product identity remains ambiguous; confirm actual bottle rather than infer a vermouth.',
 'menu-glorious-greens': 'Existing picture is unrelated. Approved Daily Dose/venue pack needed.',
 'menu-ginger-zinger': 'Existing picture is unrelated. Approved Daily Dose/venue pack needed.',
 'menu-drip-sparkling-water-500ml': 'Still/unrelated water image suppressed. Capture DRIP sparkling 500 ml specifically.',
 'menu-sparkling-water-75cl': 'Do not substitute a flavoured/small-bottle water. Confirm brand and 75 cl pack.'
}
products = []
for p in inventory['canonical_products']:
    available = p['renderable_catalogue_proxy']
    pid = p['id']; asset = p['imageName']; category = p['category']
    if not available:
        status = 'BAR category fallback'
        reason = notes.get(pid, 'No confirmed product-specific image. Deliberate category artwork; exact packaging/brand is not invented.')
    elif pid in new and 'patron' in pid:
        status = 'Exact expression verified; older pack'
        reason = 'Individual manufacturer press bottle verified; not a group/Roca image. Current physical pack not inspected.'
    elif asset in generated:
        status = 'Representative generated ingredient illustration'
        reason = 'Recognisable ingredient artwork, not photography or evidence of venue produce.'
    elif category in ['Wine', 'Sparkling / Champagne']:
        status = 'Likely exact wine; vintage/pack unverified'
        reason = 'Label/producer/style visually screened against catalogue. Menu does not fix current vintage; not a stock or vintage certification.'
        if pid in new: reason = new[pid]['identity'] + '. Official producer source; redistribution permission still required.'
    elif (pid.startswith('spec-') and pid not in named_ingredients) or p.get('unit') == 'keg' or pid in ['menu-limoncello', 'menu-sambuca', 'menu-sugar-syrup', 'menu-orgeat', 'menu-still-water-75cl', 'menu-apple-juice', 'menu-pineapple-juice', 'menu-cranberry-juice', 'menu-tomato-juice', 'menu-glenmorangie', 'menu-diplomatico']:
        status = 'Representative; supplier/pack not established'
        reason = 'Appropriate product type, but generic catalogue wording or keg unit does not verify the pictured brand/expression/pack. Venue photo preferred.'
    else:
        status = 'Likely exact; visually screened'
        reason = 'Visible brand/expression screened at contact-sheet resolution against item name. No fresh supplier pack or licence certification.'
    sources = sorted({url.rstrip(')') for row in p['provenance'] for url in row['urls']})
    if pid in new: sources = [new[pid]['page'], new[pid]['sourceURL']]
    products.append({'id':pid, 'name':p['name'], 'category':category, 'brand':p.get('brand',''),
        'unit':p.get('unit','carton' if pid.startswith('service-') and pid.endswith('-milk') else ''),
        'asset':asset if available else None, 'status':status, 'assessment':reason,
        'defaultPhotoAvailable':available, 'userPhotoCapable':True,
        'rights':new[pid]['rightsStatus'] if pid in new else ('Existing source/rights require review' if available else 'Native BAR category drawing; no third-party bottle depicted'),
        'sources':sources})
by_id = {p['id']:p for p in products}
wines=[]
raw_wines=json.loads((ROOT/'BARCore/Data/hove-wines.json').read_text(encoding='utf-8'))
for w, raw in zip(inventory['canonical_wines'],raw_wines):
    p=by_id.get(w['canonical_product_id'])
    wines.append({**w, 'status':p['status'] if p else 'BAR category fallback',
        'assessment':p['assessment'] if p else 'No matching product image',
        'menuEvidence':'menu-status.json: unchanged Hove main menu; not physical stock',
        'wineRecord':raw})
blocked={'cocktail-daiquiri','cocktail-mai-tai','cocktail-guava-soda','cocktail-lychee-lagoon'}
assets={a['name']:a for a in inventory['assets']}
cocktails=[]
for filename in ['hove-cocktails','house-classics','classics']:
    for c in json.loads((ROOT/f'BARCore/Data/{filename}.json').read_text(encoding='utf-8')):
        name=c.get('imageName',''); visible=name not in blocked and assets.get(name,{}).get('valid_catalogue_image',False)
        kind='BAR category fallback' if not visible else 'Generated concept reference' if name in ['sea-glass','peach-bloom','coral-tide'] else 'Third-party reference; venue presentation unverified'
        cocktails.append({'source':filename,'id':c['id'],'name':c['name'],'asset':name if visible else None,'status':kind,
            'documentaryVenuePhoto':False,'rights':'Native artwork' if not visible else 'Review source rights before redistribution'})
asset_rights=[]
new_assets={v['asset']:v for v in new.values()}
for a in inventory['assets']:
    if a['name'] in new_assets: group='New official source; app usage permission scope unresolved'
    elif a['kind']=='appiconset': group='BAR icon; existing vector-generated artwork'
    elif a['name'] in generated|{'sea-glass','peach-bloom','coral-tide','fresh-fruit','fresh-herbs','bar-staples'}: group='Generated/reference illustration; not venue photography'
    else: group='Existing third-party/reference asset; redistribution grant not established'
    asset_rights.append({'asset':a['name'],'kind':a['kind'],'status':group,'provenance':a['provenance']})
counts=dict(collections.Counter(p['status'] for p in products))
totals={'products':len(products),'productSpecificRenderable':sum(p['defaultPhotoAvailable'] for p in products),
    'productFallbacks':sum(not p['defaultPhotoAvailable'] for p in products),'identityStatuses':counts,
    'wines':len(wines),'wineSpecificRenderable':sum(w['renderable_catalogue_proxy'] for w in wines),
    'houseCocktails':16,'verifiedHousePhotographs':0,'assets':inventory['summary']['image_sets'],
    'assetRightsStatuses':dict(collections.Counter(a['status'] for a in asset_rights)),
    'assetFileBytesIncludingIcon':sum(f['bytes'] for a in inventory['assets'] for f in a['files'])}
report={'reviewedOn':'2026-10-11','baseline':'28a95d7d94bee209a415e24f893d1c438d185326',
    'method':'All original 245 images visually screened on labelled contact sheets; new images inspected individually. Exact means expression, not current stock/pack/licence. Static mapping proxy, not native runtime validation.',
    'summary':totals,'products':products,'wines':wines,'cocktailSourceRecords':cocktails,'assetRights':asset_rights}
(OUT/'PRODUCT-IMAGE-AUDIT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['BAR PRODUCT IMAGE AUDIT — 11 OCTOBER 2026',report['method'],'',json.dumps(totals,ensure_ascii=False,indent=2),'','EVERY CANONICAL PRODUCT']
for p in products:lines += [f"{p['name']} [{p['id']}]",f"  {p['status']}. {p['assessment']}",f"  Asset: {p['asset'] or 'native category art'}; user photo supported. Rights: {p['rights']}"]
(OUT/'PRODUCT-IMAGE-AUDIT.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps(totals,ensure_ascii=False,indent=2))
