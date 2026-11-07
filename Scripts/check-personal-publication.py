#!/usr/bin/env python3
"""Fail closed before publication if release identity, checksums or build ordering differ."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
folder = Path(sys.argv[1])
meta = json.loads((root / 'Release/personal.json').read_text())
manifest = json.loads((folder / 'release-manifest.json').read_text())
for key, value in meta.items():
    assert manifest[key] == value, f'Release metadata mismatch: {key}'
assert manifest['source_sha'] == os.environ['SOURCE_SHA'], 'Release source mismatch'
basename = f"BoringNotch-Personal-{meta['version']}"
allowed = {basename + '.zip', basename + '.dmg', 'SHA256SUMS', 'personal-appcast.xml', 'release-manifest.json'}
assert {p.name for p in folder.iterdir()} == allowed, 'Unexpected release asset'
checksums = {}
for line in (folder / 'SHA256SUMS').read_text().splitlines():
    digest, name = line.split('  ', 1)
    assert name in allowed - {'SHA256SUMS'} and name not in checksums
    assert re.fullmatch('[0-9a-f]{64}', digest)
    assert hashlib.sha256((folder / name).read_bytes()).hexdigest() == digest, 'Asset checksum mismatch'
    checksums[name] = digest
assert set(checksums) == allowed - {'SHA256SUMS'}, 'Missing checksum'
namespace = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
feed = ET.parse(folder / 'personal-appcast.xml')
items = feed.findall('./channel/item')
assert len(items) == 1
assert items[0].findtext('sparkle:version', namespaces=namespace) == meta['build']
enclosure = items[0].find('enclosure')
assert enclosure.get('url') == f"https://github.com/{meta['repository']}/releases/download/personal-v{meta['version']}/{basename}.zip"
assert enclosure.get('length') == str((folder / (basename + '.zip')).stat().st_size)
assert enclosure.get('{'+namespace['sparkle']+'}edSignature') == manifest['archive_signature']
previous = root / 'updater/personal-appcast.xml'
if previous.exists():
    builds = ET.parse(previous).findall('./channel/item/sparkle:version', namespace)
    assert all(int(meta['build']) > int(item.text) for item in builds), 'Build must increase'
print('Publication identity, source, artifact allowlist, checksums and build ordering verified.')
