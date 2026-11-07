#!/usr/bin/env python3
"""Package a personal release; publication is a separate, explicit workflow step."""
import argparse
import base64
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
META = json.loads((ROOT / 'Release/personal.json').read_text())
SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def plist(path):
    return plistlib.loads(Path(path).read_bytes())


def validate_app(app):
    info = plist(app / 'Contents/Info.plist')
    expected = {'CFBundleIdentifier': META['bundle_id'], 'CFBundleShortVersionString': META['version'],
                'CFBundleVersion': META['build'], 'SUFeedURL': META['feed'],
                'SURequireSignedFeed': True, 'SUVerifyUpdateBeforeExtraction': True}
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f'Unexpected {key}: {info.get(key)!r}')
    public = base64.b64decode(info['SUPublicEDKey'], validate=True)
    if len(public) != 32 or info['SUPublicEDKey'] == 'B1Y47t8C/v8ImurYA+9arEsuCrpxwJSviekiflMElbI=':
        raise ValueError('A new personal Sparkle public key is required')
    helper = app / 'Contents/XPCServices/BoringNotchXPCHelper.xpc'
    if plist(helper / 'Contents/Info.plist')['CFBundleIdentifier'] != META['helper_id']:
        raise ValueError('Unexpected XPC helper identity')
    for bundle, executable in ((app, META['name']), (helper, 'BoringNotchXPCHelper')):
        for architecture in ('arm64', 'x86_64'):
            run('lipo', bundle / 'Contents/MacOS' / executable, '-verify_arch', architecture)
    return info


def sign_app(app, library_exception):
    """Sign from the inside out, preserving Sparkle's per-service entitlements."""
    bundles = [p for p in app.rglob('*') if p.is_dir() and not p.is_symlink()
               and p.suffix in ('.xpc', '.app', '.framework')]
    bundles.sort(key=lambda p: len(p.parts), reverse=True)
    entitlements = {}
    for bundle in bundles:
        existing = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(bundle)],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False).stdout
        entitlements[bundle] = plistlib.loads(existing) if existing.strip() else {}
        entitlements[bundle].pop('com.apple.security.get-task-allow', None)
    helper = app / 'Contents/XPCServices/BoringNotchXPCHelper.xpc'
    entitlements[helper] = plist(ROOT / 'BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements')
    app_entitlements = plist(ROOT / 'boringNotch/boringNotch.entitlements')
    app_entitlements['com.apple.security.temporary-exception.mach-lookup.global-name'] = [
        META['bundle_id'] + '-spks', META['bundle_id'] + '-spki']
    if library_exception:
        app_entitlements['com.apple.security.cs.disable-library-validation'] = True
    entitlements[app] = app_entitlements
    with tempfile.TemporaryDirectory(prefix='personal-codesign-') as temporary:
        # Sign all Mach-O files first, including loose Autoupdate and media tools.
        for path in sorted(app.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            if not path.is_file() or path.is_symlink():
                continue
            with path.open('rb') as stream:
                magic = stream.read(4)
            if magic in (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
                run('codesign', '--force', '--sign', '-', '--timestamp=none', '--options', 'runtime', path)
        for index, bundle in enumerate(bundles + [app]):
            path = Path(temporary) / f'{index}.plist'
            path.write_bytes(plistlib.dumps(entitlements[bundle]))
            run('codesign', '--force', '--sign', '-', '--timestamp=none', '--options', 'runtime',
                '--entitlements', path, bundle)
    run('codesign', '--verify', '--deep', '--strict', '--verbose=2', app)
    signed = run('codesign', '-d', '--entitlements', ':-', app,
                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL).stdout
    assert plistlib.loads(signed)['com.apple.security.app-sandbox'] is True
    flags = run('codesign', '-dv', '--verbose=4', app, capture_output=True, text=True).stderr
    assert 'runtime' in flags and 'Signature=adhoc' in flags


def sign_update(tool, path, secret, *args):
    # Pipe a validated key. Neither argv nor files, logs, artifacts or subprocess errors contain it.
    return run(tool, '--ed-key-file', '-', *args, path,
               input=secret, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.decode().strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True, type=Path)
    parser.add_argument('--sign-update', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--allow-adhoc-library-validation-exception', action='store_true',
                        help='Explicit personal-signing exception; see Release/README.md before use')
    args = parser.parse_args()
    if len(args.source_sha) != 40 or any(c not in '0123456789abcdef' for c in args.source_sha):
        parser.error('source-sha must be a full lowercase commit SHA')
    info = validate_app(args.app)
    secret = os.environ.get('BORINGNOTCH_SPARKLE_PRIVATE_KEY', '').strip().encode()
    run('swift', ROOT / 'Scripts/check-signing-key.swift', info['SUPublicEDKey'], input=secret)
    if args.output.exists() and any(args.output.iterdir()):
        parser.error('output must be empty to enforce the artifact allowlist')
    args.output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='personal-release-') as temporary:
        stage = Path(temporary)
        app = stage / (META['name'] + '.app')
        run('ditto', args.app, app)
        resources = app / 'Contents/Resources'
        shutil.copy2(ROOT / 'LICENSE', resources / 'COPYING')
        licenses = ROOT / 'THIRD_PARTY_LICENSES'
        if licenses.is_dir():
            shutil.copytree(licenses, resources / 'THIRD_PARTY_LICENSES', dirs_exist_ok=True)
        else:
            shutil.copy2(licenses, resources / 'THIRD_PARTY_LICENSES')
        (resources / 'PERSONAL_SOURCE.txt').write_text(
            f"BoringNotch Personal is a GPL fork of TheBoredTeam/boring.notch.\n"
            f"Corresponding source: https://github.com/{META['repository']}/tree/{args.source_sha}\n")
        sign_app(app, args.allow_adhoc_library_validation_exception)
        basename = f"BoringNotch-Personal-{META['version']}"
        archive = args.output / (basename + '.zip')
        run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', app, archive)
        (stage / 'Applications').symlink_to('/Applications')
        shutil.copy2(ROOT / 'LICENSE', stage / 'COPYING')
        dmg = args.output / (basename + '.dmg')
        run('hdiutil', 'create', '-volname', META['name'], '-srcfolder', stage,
            '-ov', '-format', 'UDZO', dmg)
        signature = sign_update(args.sign_update, archive, secret, '-p')
        run(args.sign_update, '--ed-key-file', '-', '--verify', archive, signature,
            input=secret, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        channel = ET.Element('rss', {'version': '2.0'})
        channel = ET.SubElement(channel, 'channel')
        ET.SubElement(channel, 'title').text = META['name']
        ET.SubElement(channel, 'link').text = 'https://github.com/' + META['repository']
        item = ET.SubElement(channel, 'item')
        ET.SubElement(item, 'title').text = META['name'] + ' ' + META['version']
        ET.SubElement(item, f'{{{SPARKLE}}}version').text = META['build']
        ET.SubElement(item, f'{{{SPARKLE}}}shortVersionString').text = META['version']
        ET.SubElement(item, f'{{{SPARKLE}}}minimumSystemVersion').text = '15.0.0'
        ET.SubElement(item, 'pubDate').text = datetime.datetime.now(datetime.timezone.utc).strftime('%a, %d %b %Y %H:%M:%S +0000')
        ET.SubElement(item, 'description').text = 'Compact agenda and music, with quieter rendering. Personal ad-hoc build; source and GPL license included.'
        ET.SubElement(item, 'enclosure', {
            'url': f"https://github.com/{META['repository']}/releases/download/personal-v{META['version']}/{archive.name}",
            f'{{{SPARKLE}}}edSignature': signature, 'length': str(archive.stat().st_size),
            'type': 'application/octet-stream'})
        feed = args.output / 'personal-appcast.xml'
        rss = ET.Element('rss', {'version': '2.0'})
        rss.append(channel)
        ET.ElementTree(rss).write(feed, encoding='utf-8', xml_declaration=True)
        sign_update(args.sign_update, feed, secret)
        run(args.sign_update, '--ed-key-file', '-', '--verify', feed,
            input=secret, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        manifest = dict(META, source_sha=args.source_sha, signing='ad-hoc', notarized=False,
                        public_key=info['SUPublicEDKey'],
                        library_validation_exception=args.allow_adhoc_library_validation_exception,
                        archive_signature=signature)
        (args.output / 'release-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        files = sorted(args.output.iterdir())
        assert {path.name for path in files} == {archive.name, dmg.name, 'personal-appcast.xml', 'release-manifest.json'}
        (args.output / 'SHA256SUMS').write_text(''.join(
            hashlib.sha256(path.read_bytes()).hexdigest() + '  ' + path.name + '\n' for path in files))
    print(f'Verified personal artifacts in {args.output}')


if __name__ == '__main__':
    main()
