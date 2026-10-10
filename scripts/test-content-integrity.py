"""Executable content-contract checks. These do not execute Swift or prove native UI."""
import json
import math
import plistlib
import unittest
import importlib.util
import tempfile
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "BARCore/Data"
def read(name):
    return json.loads((DATA / (name + '.json')).read_text(encoding='utf-8'))

class ContentIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.refs = read('recommended-classics')
        cls.by_id = {r['id']: r for r in cls.refs}
        cls.raw = read('classics') + read('house-classics')

    def test_every_raw_classic_has_exactly_one_reference(self):
        aliases = [a for r in self.refs for a in r['aliases']]
        self.assertEqual(len(aliases), len(set(aliases)))
        self.assertEqual(set(aliases), {r['id'] for r in self.raw})

    def test_every_reference_has_professional_https_evidence(self):
        allowed = {'iba-world.com', 'www.diffordsguide.com', 'www.cointreau.com', 'www.diageobaracademy.com'}
        for ref in self.refs:
            with self.subTest(ref=ref['id']):
                self.assertTrue(ref['sources']); self.assertTrue(ref['decision'])
                self.assertRegex(ref['verifiedOn'], r'^\d{4}-\d{2}-\d{2}$')
                for source in ref['sources']:
                    url = urlparse(source['url'])
                    self.assertEqual(url.scheme, 'https'); self.assertIn(url.hostname, allowed)

    def test_sidecar_recommended_and_exact_legacy_correction(self):
        ref = self.by_id['reference-sidecar']
        self.assertIn('shake', ref['actions']); self.assertIn('strain', ref['actions'])
        self.assertEqual([i['amount'] for i in ref['recommended']['ingredients']], [50, 20, 20])
        old = next(r for r in self.raw if r['id'] == 'house-sidecar')
        self.assertEqual([i['amount'] for i in old['ingredients']], [50, 25, 10])
        self.assertEqual(old['method'], ref['correctedLegacyMethod'])
        self.assertIn('shake', ref['customMethod'].lower())

    def test_reference_never_contains_venue_stock_links(self):
        for ref in self.refs:
            if ref['recommended']:
                self.assertIsNone(ref['recommended'].get('venueID'))
                for ingredient in ref['recommended']['ingredients']:
                    self.assertIsNone(ingredient.get('stockProductID'))

    def test_recipe_service_fields_and_structured_actions_present(self):
        for ref in self.refs:
            recipe = ref['recommended']
            if recipe:
                with self.subTest(ref=ref['id']):
                    for key in ['method', 'glass', 'ice', 'garnish', 'prepInstructions', 'ingredients']:
                        self.assertTrue(recipe[key], key)
                    self.assertTrue(ref['actions'])

    def test_amounts_are_finite_and_variable_measures_not_invented(self):
        for ref in self.refs:
            for ingredient in (ref['recommended'] or {}).get('ingredients', []):
                self.assertTrue(math.isfinite(ingredient['amount']))
                self.assertGreaterEqual(ingredient['amount'], 0)
                if ingredient['amount'] == 0:
                    self.assertTrue(ingredient.get('quantityDisplay') or ingredient['unit'] == 'top', ingredient)

    def test_carbonation_and_fresh_foam_stay_outside_premix(self):
        for ref in self.refs:
            for ingredient in (ref['recommended'] or {}).get('ingredients', []):
                name = ingredient['name'].lower()
                if any(t in name for t in ['prosecco', 'champagne', 'soda', 'ginger beer', 'cola', 'lemonade', 'egg white', 'cream']):
                    if name == 'coconut cream':
                        continue
                    self.assertEqual(ingredient['batchBehaviour'], 'serviceOnly', (ref['id'], name))

    def test_ingredient_ids_are_unique_within_each_spec(self):
        for ref in self.refs:
            ingredients = (ref['recommended'] or {}).get('ingredients', [])
            self.assertEqual(len(ingredients), len({i['id'] for i in ingredients}))

    def test_house_only_variation_is_not_given_invented_measures(self):
        value = self.by_id['reference-chilli-pineapple-margarita']
        self.assertIsNone(value['recommended'])
        self.assertTrue(value['customReview'])

    def test_unresolved_house_sources_are_not_quiz_eligible(self):
        for id in ['bloody-mary', 'irish-coffee', 'limoncello-spritz', 'paloma', 'mojito', 'espresso-martini', 'spicy-margarita', 'pornstar-martini']:
            self.assertFalse(self.by_id['reference-' + id]['customTrainingEligible'])

    def test_wine_records_have_stable_unique_identity_and_plausible_scales(self):
        wines = read('hove-wines')
        self.assertEqual(len(wines), 59)
        self.assertEqual(len(wines), len({w['id'] for w in wines}))
        for wine in wines:
            self.assertTrue(wine['name'])
            for field in ['body', 'sweetness', 'acidity', 'tannin']:
                self.assertIn(wine[field], range(1, 6))

    def test_original_house_source_and_venue_recipes_remain_separate(self):
        self.assertEqual(len(read('house-classics')), 46)
        self.assertEqual(len(read('hove-cocktails')), 16)
        for value in read('house-classics') + read('hove-cocktails'):
            self.assertEqual(value['venueID'], 'rockwater-hove')
            self.assertNotIn('displaySpecification', value)

    def test_privacy_manifest_is_valid_and_declares_no_tracking(self):
        value = plistlib.loads((ROOT/'BAR/PrivacyInfo.xcprivacy').read_bytes())
        self.assertFalse(value['NSPrivacyTracking'])
        self.assertEqual(value['NSPrivacyCollectedDataTypes'], [])

    def test_app_icon_is_declared_and_nonempty(self):
        path = ROOT/'BAR/Assets.xcassets/AppIcon.appiconset'
        entries = json.loads((path/'Contents.json').read_text())['images']
        for entry in entries:
            if entry.get('filename'):
                self.assertGreater((path/entry['filename']).stat().st_size, 0)

    def test_export_tool_emits_only_source_content_and_resolvable_overrides(self):
        spec = importlib.util.spec_from_file_location('content_export', ROOT/'scripts/make-content-import.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'venue.json'
            module.build(output)
            content = json.loads(output.read_text(encoding='utf-8'))
        self.assertEqual(set(content), {'schemaVersion', 'venues', 'cocktails', 'wines'})
        globals = {c['id'] for c in content['cocktails'] if not c.get('venueID')}
        for drink in content['cocktails']:
            self.assertNotIn('displaySpecification', drink)
            if drink.get('overridesCocktailID'):
                self.assertIn(drink['overridesCocktailID'], globals)

if __name__ == '__main__':
    unittest.main()
