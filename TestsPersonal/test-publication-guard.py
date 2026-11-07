"""Publication must preserve the pinned code identity, even with valid-looking assets."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PublicationGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='publication-guard-')
        self.root = Path(self.temporary.name)
        for folder in ('Scripts', 'Release', 'updater', 'assets'):
            (self.root / folder).mkdir()
        shutil.copy2(ROOT / 'Scripts/check-personal-publication.py', self.root / 'Scripts')
        shutil.copy2(ROOT / 'Release/codesign-certificate.pem', self.root / 'Release')
        self.meta = dict(json.loads((ROOT / 'Release/personal.json').read_text()), version='9.8.7', build='999999')
        (self.root / 'Release/personal.json').write_text(json.dumps(self.meta))
        (self.root / 'updater/personal-appcast.xml').write_text(
            '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
            '<sparkle:version>100</sparkle:version></item></channel></rss>')
        self.assets = self.root / 'assets'
        self.manifest = dict(self.meta, source_sha='1' * 40, signing='personal-certificate',
                             library_validation_exception=True, archive_signature='fixture-signature')
        basename = 'BoringNotch-Personal-9.8.7'
        (self.assets / (basename + '.zip')).write_bytes(b'fixture archive')
        (self.assets / (basename + '.dmg')).write_bytes(b'fixture disk image')
        (self.assets / 'personal-appcast.xml').write_text(
            '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
            '<sparkle:version>999999</sparkle:version><enclosure '
            f'url="https://github.com/Soakkk/BoringNotch/releases/download/personal-v9.8.7/{basename}.zip" '
            'length="15" sparkle:edSignature="fixture-signature"/></item></channel></rss>')

    def tearDown(self):
        self.temporary.cleanup()

    def check(self, valid, optimize=False):
        (self.assets / 'release-manifest.json').write_text(json.dumps(self.manifest))
        files = sorted(p for p in self.assets.iterdir() if p.name != 'SHA256SUMS')
        (self.assets / 'SHA256SUMS').write_text(''.join(
            hashlib.sha256(p.read_bytes()).hexdigest() + '  ' + p.name + '\n' for p in files))
        env = dict(os.environ, SOURCE_SHA='1' * 40, PYTHONOPTIMIZE='1' if optimize else '0')
        result = subprocess.run(['python3', str(self.root / 'Scripts/check-personal-publication.py'),
                                 str(self.assets)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, valid, result.stderr)

    def test_accepts_pinned_personal_certificate(self):
        self.check(True)

    def test_rejects_adhoc_even_with_library_exception(self):
        self.manifest['signing'] = 'ad-hoc'
        self.check(False)

    def test_rejects_missing_signing_identity(self):
        del self.manifest['signing']
        self.check(False)

    def test_rejects_unknown_signing_identity(self):
        self.manifest['signing'] = 'unverified'
        self.check(False)

    def test_rejects_wrong_certificate(self):
        self.manifest['codesign_certificate_sha256'] = '0' * 64
        self.check(False)

    def test_rejects_changed_public_certificate(self):
        (self.root / 'Release/codesign-certificate.pem').write_text('invalid certificate')
        self.check(False)

    def test_requires_existing_app_only_library_exception(self):
        self.manifest['library_validation_exception'] = False
        self.check(False)

    def test_optimization_cannot_disable_identity_enforcement(self):
        self.manifest['signing'] = 'ad-hoc'
        self.check(False, optimize=True)

    def test_rejects_source_mismatch(self):
        self.manifest['source_sha'] = '2' * 40
        self.check(False)

    def test_rejects_unexpected_release_asset(self):
        (self.assets / 'unexpected.txt').write_text('must not publish')
        self.check(False)


if __name__ == '__main__':
    unittest.main()
