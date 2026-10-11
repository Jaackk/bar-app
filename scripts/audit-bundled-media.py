import collections,hashlib,json,re,subprocess,unicodedata
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
out=root/'docs/release/image-inventory-current.json'
assetroot=root/'BAR/Assets.xcassets'
data={p.stem:json.loads(p.read_text(encoding='utf-8')) for p in (root/'BARCore/Data').glob('*.json')}
provenance=[]
for doc in ['docs/ASSETS.md','docs/PRODUCT-IMAGE-PROVENANCE.md','docs/COCKTAIL-IMAGE-PROVENANCE.md']:
 for n,line in enumerate((root/doc).read_text(encoding='utf-8').splitlines(),1):
  if not line.startswith('|') or line.startswith('| ---'):continue
  provenance.append({'document':doc,'line':n,'cells':[p.strip() for p in line.strip('|').split('|')],'text':line,'urls':re.findall(r'https?://[^\s|]+',line),'tokens':re.findall(r'`([^`]+)`',line)})
assets=[];assetmap={};hashes=collections.defaultdict(list)
for directory in sorted(assetroot.iterdir()):
 if not directory.is_dir() or directory.suffix not in ['.imageset','.appiconset']:continue
 name=directory.stem; cp=directory/'Contents.json'; contents=json.loads(cp.read_text()) if cp.exists() else None
 declared={i.get('filename') for i in contents.get('images',[]) if i.get('filename')} if contents else set()
 files=[]
 for f in sorted(directory.iterdir()):
  if not f.is_file() or f.name=='Contents.json':continue
  entry={'path':str(f.relative_to(root)).replace('\\','/'),'filename':f.name,'bytes':f.stat().st_size,'declared':f.name in declared,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
  try:
   with Image.open(f) as image:entry.update(width=image.width,height=image.height,mode=image.mode,format=image.format);image.verify()
   entry['valid_image']=True
  except Exception as e:entry.update(valid_image=False,error=str(e))
  files.append(entry);hashes[entry['sha256']].append(entry['path'])
 valid=bool(contents and any(f['declared'] and f['valid_image'] for f in files))
 asset={'name':name,'kind':directory.suffix[1:],'path':str(directory.relative_to(root)).replace('\\','/'),'has_contents_json':bool(contents),'declared_missing_files':[f for f in declared if not (directory/f).exists()],'valid_catalogue_image':valid,'files':files,'references':[]}
 if name in ['sea-glass','peach-bloom','coral-tide']:asset['image_kind']='AI-generated concept cocktail'
 elif name in ['fresh-fruit','fresh-herbs','bar-staples']:asset['image_kind']='AI-generated generic fallback'
 elif name in ['lime-photo','lemon-photo','orange-photo','strawberry-photo']:asset['image_kind']='Generated ingredient artwork; not supplier photography'
 elif name.startswith('cocktail-'):asset['image_kind']='Third-party representative cocktail photo; source notes determine match'
 elif directory.suffix=='.appiconset':asset['image_kind']='Native vector-drawn concept app icon rendered as PNG'
 else:asset['image_kind']='Bundled product/ingredient photo; verify linked provenance and visible packaging'
 asset['provenance']=[p for p in provenance if name in p['tokens'] or name+'.imageset' in p['tokens']]
 assets.append(asset);assetmap[name]=asset
raw=[]
for file,rows in data.items():
 for record in rows:
  name=record.get('imageName','');row={'file':'BARCore/Data/'+file+'.json','id':record.get('id'),'name':record.get('name'),'imageName':name,'has_image_reference':bool(name),'asset_directory_exists':name in assetmap,'renderable_catalogue_proxy':assetmap.get(name,{}).get('valid_catalogue_image',False)}
  raw.append(row)
  if name in assetmap:assetmap[name]['references'].append({'kind':'raw_json','file':row['file'],'id':row['id'],'name':row['name']})
s=(root/'BARCore/Services/ProductCatalogueCorrections.swift').read_text(encoding='utf-8')
def block(start,end):return s.split(start,1)[1].split(end,1)[0]
replacements={a:b or None for a,b,c in re.findall(r'"([^"]+)":\s*(?:"([^"]+)"|(nil))',block('public static let replacements:', '/// The source'))}
individual=dict(re.findall(r'"([^"]+)":\s*"([^"]+)"',block('private static let individualImageNames:','/// Earlier imports')))
invalid=set(re.findall(r'"([^"]+)"',block('private static let invalidBundledImageProductIDs:','public static func rejectsBundledImage')))
generic={'fresh-fruit','fresh-herbs','bar-staples'}
products=[dict(p) for p in data['hove-products'] if p['id'] not in replacements]
for p in products:
 p['rawImageName']=p.get('imageName','');p['imageName']='' if p['id'] in invalid else individual.get(p['id'],p['rawImageName'])
 # Apply the simple canonical name/category edits; alias expansion is immaterial to image availability.
 edit=re.search(r'"'+re.escape(p['id'])+r'":\s*\((nil|"[^"]+"),\s*(nil|"[^"]+")',block('private static let edits:', 'private static let individualImageNames:'))
 if edit:
  for key,value in zip(['name','category'],edit.groups()):
   if value!='nil':p[key]=value.strip('"')
for milk in ['skimmed','oat','almond','soy']:products.append({'id':'service-'+milk+'-milk','name':milk.title()+' Milk','category':'Other','brand':'','imageName':'','rawImageName':''})
for p in products:
 name=p['imageName'];p['declared_relevant_pre_fix']=bool(name and name not in generic);p['renderable_catalogue_proxy']=bool(p['declared_relevant_pre_fix'] and assetmap.get(name,{}).get('valid_catalogue_image',False));p['missing_after_renderability_check']=not p['renderable_catalogue_proxy']
 p['image_status']='available' if p['renderable_catalogue_proxy'] else 'configured_but_unavailable' if p['declared_relevant_pre_fix'] else 'intentionally_cleared_wrong_product' if p['id'] in invalid else 'generic_fallback' if name in generic else 'no_specific_image'
 p['provenance']=[row for row in provenance if p['id'] in row['tokens'] or name and name in row['tokens']]
 if name in assetmap:assetmap[name]['references'].append({'kind':'corrected_product','id':p['id'],'name':p['name']})
def norm(s):return ''.join(c for c in unicodedata.normalize('NFKD',s).lower() if c.isalnum())
wines=[]
for w in data['hove-wines']:
 matching=[p for p in products if norm(p['name'])==norm(w['name']) and p['category'] in ['Wine','Sparkling / Champagne']];p=matching[0] if len(matching)==1 else None
 wines.append({'id':w['id'],'name':w['name'],'canonical_product_id':p['id'] if p else None,'imageName':p['imageName'] if p else w.get('imageName',''),'renderable_catalogue_proxy':p['renderable_catalogue_proxy'] if p else False})
rawproducts=[r for r in raw if r['file']=='BARCore/Data/hove-products.json']
stats={'asset_directories':len(assets),'image_sets':sum(a['kind']=='imageset' for a in assets),'valid_image_sets':sum(a['kind']=='imageset' and a['valid_catalogue_image'] for a in assets),'invalid_image_sets':[a['name'] for a in assets if not a['valid_catalogue_image']],'data_file_records':{k:len(v) for k,v in data.items()},'raw_products':len(rawproducts),'raw_products_with_named_image':sum(r['has_image_reference'] for r in rawproducts),'raw_products_missing_or_generic_or_invalid':sum(not r['has_image_reference'] or r['imageName'] in generic or not r['renderable_catalogue_proxy'] for r in rawproducts),'corrected_products':len(products),'corrected_declared_relevant_before_fix':sum(p['declared_relevant_pre_fix'] for p in products),'corrected_relevant_available':sum(p['renderable_catalogue_proxy'] for p in products),'missing_filter_before_fix':sum(not p['declared_relevant_pre_fix'] for p in products),'missing_filter_after_fix':sum(p['missing_after_renderability_check'] for p in products),'false_complete_before_fix':[{k:p[k] for k in ['id','name','imageName']} for p in products if p['declared_relevant_pre_fix'] and not p['renderable_catalogue_proxy']],'status_counts':dict(collections.Counter(p['image_status'] for p in products)),'venue_wines':len(wines),'venue_wines_with_available_image':sum(w['renderable_catalogue_proxy'] for w in wines)}

# Keep evidence references without duplicating entire source tables/operational fields.
def compact_provenance(rows):
 return [{k:r[k] for k in ['document','line','urls']} for r in rows]
products=[{**{k:p[k] for k in ['id','name','category','imageName','rawImageName','renderable_catalogue_proxy','image_status']},'brand':p.get('brand',''),'unit':p.get('unit','carton' if p['id'].endswith('-milk') else ''),'provenance':compact_provenance(p['provenance'])} for p in products]
for asset in assets:
 asset.pop('references',None)
 asset['provenance']=compact_provenance(asset['provenance'])
# This inventory is a repeatable static proxy. Identity judgements are separate.
report={'method':'Pillow verifies bytes; Swift source-rule proxy enumerates defaults. This is not iOS asset compilation or licensing approval.', 'summary':stats, 'assets':assets, 'canonical_products':products, 'canonical_wines':wines}
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(stats,ensure_ascii=False,indent=2))
