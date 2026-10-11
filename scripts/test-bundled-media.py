"""Disk/data contracts only. Native image rendering and Swift behaviour need Xcode."""
import hashlib
import json
import subprocess
import sys
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
def read(path): return json.loads((ROOT/path).read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

class BundledMediaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.assets=ROOT/'BAR/Assets.xcassets'
        cls.inventory=read('docs/release/image-inventory-current.json')
        cls.report=read('docs/release/PRODUCT-IMAGE-AUDIT.json')

    def test_all_declared_assets_decode_with_no_missing_or_empty_files(self):
        for folder in self.assets.iterdir():
            if folder.suffix not in ['.imageset','.appiconset']: continue
            with self.subTest(asset=folder.name):
                contents=json.loads((folder/'Contents.json').read_text())
                filenames={i['filename'] for i in contents['images'] if i.get('filename')}
                self.assertTrue(filenames)
                for name in filenames:
                    self.assertEqual(Path(name).name,name)
                    with Image.open(folder/name) as image: image.verify()

    def test_new_sources_hashes_and_canonical_ids_match_bundled_images(self):
        products={p['id']:p for p in self.inventory['canonical_products']}
        for record in read('docs/release/NEW-IMAGE-PROVENANCE.json'):
            with self.subTest(product=record['productID']):
                self.assertEqual(products[record['productID']]['imageName'],record['asset'])
                folder=self.assets/(record['asset']+'.imageset')
                contents=json.loads((folder/'Contents.json').read_text())
                image=folder/next(i['filename'] for i in contents['images'] if i.get('filename'))
                self.assertEqual(sha(image),record['imageSHA256'])
                self.assertTrue(record['rightsStatus']); self.assertTrue(record['owner'])
                self.assertTrue(record['sourceURL'].startswith('https://'))

    def test_optimisation_has_preserved_dimensions_and_recorded_bytes(self):
        report=read('docs/release/IMAGE-OPTIMISATION.json')
        for row in report['changes']:
            path=ROOT/row['afterFile']
            with self.subTest(asset=row['asset']):
                self.assertEqual(sha(path),row['afterSHA256'])
                self.assertEqual(path.stat().st_size,row['afterBytes'])
                with Image.open(path) as image:
                    self.assertEqual(image.size,(row['width'],row['height']))
                    self.assertEqual(image.format,'JPEG')
                self.assertLess(row['afterBytes'],row['beforeBytes']*.8)
                self.assertFalse((ROOT/row['beforeFile']).exists())
        self.assertEqual(report['savedBytes'],sum(r['beforeBytes']-r['afterBytes'] for r in report['changes']))

    def test_optimiser_refuses_repeat_lossy_pass(self):
        before=(ROOT/'docs/release/IMAGE-OPTIMISATION.json').read_bytes()
        result=subprocess.run([sys.executable,str(ROOT/'scripts/optimise-bundled-images.py')],capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('report already exists',result.stderr)
        self.assertEqual(before,(ROOT/'docs/release/IMAGE-OPTIMISATION.json').read_bytes())

    def test_icon_is_square_opaque_and_unmodified_by_optimiser(self):
        folder=self.assets/'AppIcon.appiconset'
        for path in folder.glob('*.png'):
            with Image.open(path) as image:
                self.assertEqual(image.size,(1024,1024))
                if image.mode=='RGBA':self.assertEqual(image.getextrema()[-1],(255,255))
        self.assertNotIn('AppIcon',{r['asset'] for r in read('docs/release/IMAGE-OPTIMISATION.json')['changes']})

    def test_report_covers_every_canonical_product_and_wine_once(self):
        products=self.report['products']; expected=self.inventory['canonical_products']
        self.assertEqual(len(products),len({p['id'] for p in products}))
        self.assertEqual({p['id'] for p in products},{p['id'] for p in expected})
        self.assertEqual({w['id'] for w in self.report['wines']},{w['id'] for w in read('BARCore/Data/hove-wines.json')})
        self.assertTrue(all(p['assessment'] and p['status'] and p['rights'] for p in products))

    def test_fallback_is_never_reported_as_exact_photography(self):
        for p in self.report['products']:
            if not p['defaultPhotoAvailable']:
                self.assertEqual(p['status'],'BAR category fallback');self.assertIsNone(p['asset'])
        self.assertEqual(sum(p['defaultPhotoAvailable'] for p in self.report['products']),self.report['summary']['productSpecificRenderable'])
        self.assertFalse(any(c['documentaryVenuePhoto'] for c in self.report['cocktailSourceRecords']))

    def test_brand_corrections_match_seed_without_new_stock_identities(self):
        products={p['id']:p for p in read('BARCore/Data/hove-products.json')}
        for row in read('docs/release/BRAND-CORRECTIONS.json')['changes']:
            self.assertEqual(products[row['id']]['brand'],row['after'])
            self.assertEqual(products[row['id']]['name'],row['name'])
        self.assertEqual(len(products),277)

if __name__=='__main__':unittest.main(verbosity=2)
