"""One-time, declared-asset-only photographic PNG optimisation.

Opaque PNG photographs over 250 KB become JPEG (quality 94, 4:4:4). Transparent
PNGs retain lossless pixels/alpha. Existing JPEGs, icons and user photos are untouched.
Asset names stay stable; Contents.json points at the replacement. Git keeps originals.
The report makes repeat application explicit rather than recompressing JPEGs.
"""
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT/'BAR/Assets.xcassets'
REPORT = ROOT/'docs/release/IMAGE-OPTIMISATION.json'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def main():
    if REPORT.exists():
        raise SystemExit('An optimisation report already exists. Review it; do not recompress an existing pass.')
    changes = []
    for folder in sorted(ASSETS.glob('*.imageset')):
        contents_path = folder/'Contents.json'
        if not contents_path.exists():
            continue
        contents = json.loads(contents_path.read_text(encoding='utf-8'))
        changed = False
        seen = set()
        for entry in contents.get('images', []):
            filename = entry.get('filename', '')
            if filename in seen:
                continue
            seen.add(filename)
            source = folder/filename
            if source.suffix.lower() != '.png' or not source.is_file() or source.stat().st_size < 250_000:
                continue
            original = source.read_bytes()
            with Image.open(source) as image:
                image.load()
                # Never flatten genuine transparency or alter its edge colours.
                if image.mode not in ('RGB', 'RGBA') or (image.mode == 'RGBA' and image.getextrema()[-1][0] < 255):
                    continue
                encoded = io.BytesIO()
                image.convert('RGB').save(encoded, format='JPEG', quality=94, subsampling=0, optimize=True)
                result = encoded.getvalue()
                if len(result) >= len(original) * 0.8:
                    continue
                target = source.with_suffix('.jpg')
                if target.exists():
                    raise RuntimeError(f'Refusing to overwrite {target}')
                target.write_bytes(result)
                with Image.open(target) as check:
                    assert check.size == image.size
                    check.verify()
                for declaration in contents['images']:
                    if declaration.get('filename') == filename:
                        declaration['filename'] = target.name
                changes.append({'asset': folder.stem, 'beforeFile': source.relative_to(ROOT).as_posix(),
                    'afterFile': target.relative_to(ROOT).as_posix(), 'beforeBytes': len(original),
                    'afterBytes': len(result), 'width': image.width, 'height': image.height,
                    'beforeSHA256': digest(original), 'afterSHA256': digest(result)})
            source.unlink()  # Exact declared file, within this repository's asset catalogue.
            changed = True
        if changed:
            contents_path.write_text(json.dumps(contents, indent=2)+'\n', encoding='utf-8')
    REPORT.write_text(json.dumps({'method': __doc__, 'date': '2026-10-11', 'changes': changes,
        'savedBytes': sum(x['beforeBytes']-x['afterBytes'] for x in changes)}, indent=2)+'\n', encoding='utf-8')
    print(f'{len(changes)} opaque PNGs optimised once; {sum(x["beforeBytes"]-x["afterBytes"] for x in changes):,} bytes saved. Dimensions unchanged.')

if __name__ == '__main__':
    main()
