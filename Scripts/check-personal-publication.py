#!/usr/bin/env python3
"""Fail closed before publication if release identity, checksums or build ordering differ."""
import hashlib
import json
import os
from pathlib import Path
import re
import ssl
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
folder = Path(sys.argv[1])
meta = json.loads((root / 'Release/personal.json').read_text())
manifest = json.loads((folder / 'release-manifest.json').read_text())

def require(condition, message):
    if not condition:
        raise ValueError(message)


for key, value in meta.items():
    require(manifest.get(key) == value, f'Release metadata mismatch: {key}')
require(manifest['source_sha'] == os.environ['SOURCE_SHA'], 'Release source mismatch')
require(manifest.get('signing') == 'personal-certificate', 'Publication requires pinned personal certificate signing')
certificate = ssl.PEM_cert_to_DER_cert((root / 'Release/codesign-certificate.pem').read_text())
require(hashlib.sha256(certificate).hexdigest() == meta.get('codesign_certificate_sha256'),
        'Public certificate differs from the pinned identity')
require(manifest.get('library_validation_exception') is True,
        'Personal signing requires the reviewed app-only library-validation exception')
basename = f"BoringNotch-Personal-{meta['version']}"
allowed = {basename + '.zip', basename + '.dmg', 'SHA256SUMS', 'personal-appcast.xml', 'release-manifest.json'}
require({p.name for p in folder.iterdir()} == allowed, 'Unexpected release asset')
require(all(p.is_file() and not p.is_symlink() for p in folder.iterdir()), 'Release assets must be regular files')
checksums = {}
for line in (folder / 'SHA256SUMS').read_text().splitlines():
    digest, name = line.split('  ', 1)
    require(name in allowed - {'SHA256SUMS'} and name not in checksums, 'Unexpected or repeated checksum')
    require(re.fullmatch('[0-9a-f]{64}', digest), 'Invalid checksum format')
    require(hashlib.sha256((folder / name).read_bytes()).hexdigest() == digest, 'Asset checksum mismatch')
    checksums[name] = digest
require(set(checksums) == allowed - {'SHA256SUMS'}, 'Missing checksum')
namespace = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
feed = ET.parse(folder / 'personal-appcast.xml')
items = feed.findall('./channel/item')
require(len(items) == 1, 'Expected one appcast item')
require(items[0].findtext('sparkle:version', namespaces=namespace) == meta['build'], 'Appcast build mismatch')
enclosure = items[0].find('enclosure')
require(enclosure is not None, 'Missing appcast enclosure')
require(enclosure.get('url') == f"https://github.com/{meta['repository']}/releases/download/personal-v{meta['version']}/{basename}.zip", 'Unexpected update URL')
require(enclosure.get('length') == str((folder / (basename + '.zip')).stat().st_size), 'Archive length mismatch')
require(enclosure.get('{'+namespace['sparkle']+'}edSignature') == manifest['archive_signature'], 'Archive signature mismatch')
previous = root / 'updater/personal-appcast.xml'
if previous.exists():
    builds = ET.parse(previous).findall('./channel/item/sparkle:version', namespace)
    require(all(int(meta['build']) > int(item.text) for item in builds), 'Build must increase')
print('Publication identity, source, artifact allowlist, checksums and build ordering verified.')
