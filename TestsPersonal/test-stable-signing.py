#!/usr/bin/env python3
"""Exercise the release signer on different native app/helper builds, not mocks."""
import base64
import hashlib
import importlib.util
import os
from pathlib import Path
import plistlib
import secrets
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Scripts'))
spec = importlib.util.spec_from_file_location('personal_release', ROOT / 'Scripts/personal-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def run(*args, input=None):
    result = subprocess.run([str(x) for x in args], input=input, capture_output=True)
    if result.returncode:
        raise RuntimeError(f'{Path(args[0]).name} failed ({result.returncode}): {result.stderr.decode(errors="replace")}')
    return result.stdout


def make_identity(folder):
    folder.mkdir()
    key, cert, p12 = [folder / name for name in ('key.pem', 'cert.pem', 'identity.p12')]
    config = folder / 'certificate.cnf'
    config.write_text('''[req]
distinguished_name=subject
x509_extensions=signing
prompt=no
[subject]
CN=BoringNotch disposable signing regression
[signing]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
''')
    run('/usr/bin/openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
        '-config', config, '-keyout', key, '-out', cert)
    key.chmod(0o600)
    password = secrets.token_urlsafe(32)
    run('/usr/bin/openssl', 'pkcs12', '-export', '-descert', '-inkey', key, '-in', cert, '-out', p12,
        '-passout', 'stdin', input=(password + '\n').encode())
    p12.chmod(0o600)
    der = run('/usr/bin/openssl', 'x509', '-in', cert, '-outform', 'DER')
    return cert, {'BORINGNOTCH_CODESIGN_P12_BASE64': base64.b64encode(p12.read_bytes()).decode(),
                  'BORINGNOTCH_CODESIGN_PASSWORD': password}, hashlib.sha256(der).hexdigest()


class StableSigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='boring-signing-regression-')
        cls.folder = Path(cls.temporary.name)
        cls.cert, cls.credentials, cls.pin = make_identity(cls.folder / 'identity')
        cls.other_cert, cls.other_credentials, cls.other_pin = make_identity(cls.folder / 'other')
        cls.policy = cls.folder / 'policy'
        (cls.policy / 'Release').mkdir(parents=True)
        shutil.copy2(cls.cert, cls.policy / 'Release/codesign-certificate.pem')
        for relative in ('boringNotch/boringNotch.entitlements',
                         'BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements'):
            destination = cls.policy / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / relative, destination)
        cls.original_root, cls.original_meta = release.ROOT, release.META
        release.ROOT = cls.policy
        release.META = dict(release.META, codesign_certificate_sha256=cls.pin)

    @classmethod
    def tearDownClass(cls):
        release.ROOT, release.META = cls.original_root, cls.original_meta
        cls.temporary.cleanup()

    def fixture(self, label, version):
        app = self.folder / label / (release.META['name'] + '.app')
        helper = app / 'Contents/XPCServices/BoringNotchXPCHelper.xpc'
        for bundle, executable, identifier, kind in (
            (app, release.META['name'], release.META['bundle_id'], 'APPL'),
            (helper, 'BoringNotchXPCHelper', release.META['helper_id'], 'XPC!')):
            (bundle / 'Contents/MacOS').mkdir(parents=True, exist_ok=True)
            (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps({
                'CFBundleIdentifier': identifier, 'CFBundleExecutable': executable,
                'CFBundleVersion': str(version), 'CFBundlePackageType': kind}))
            run('xcrun', 'clang', '-x', 'c', '-', '-o', bundle / 'Contents/MacOS' / executable,
                input=f'int main(void) {{ return {version}; }}'.encode())
        return app, helper

    def test_updates_share_identity_and_reject_adhoc_replacements(self):
        search_list = run('security', 'list-keychains', '-d', 'user')
        first = self.fixture('first', 1)
        second = self.fixture('second', 2)
        impostor = self.fixture('adhoc', 3)
        with patch.dict(os.environ, self.credentials):
            release.sign_app(first[0], True)
            release.sign_app(second[0], True)
        self.assertEqual(run('security', 'list-keychains', '-d', 'user'), search_list,
                         'Packaging must restore the normal keychain search list')
        other = self.fixture('other-signer', 6)
        other_policy = self.folder / 'other-policy'
        shutil.copytree(self.policy, other_policy)
        shutil.copy2(self.other_cert, other_policy / 'Release/codesign-certificate.pem')
        with patch.dict(os.environ, self.other_credentials), patch.object(release, 'ROOT', other_policy), \
             patch.dict(release.META, {'codesign_certificate_sha256': self.other_pin}):
            release.sign_app(other[0], True)
        run('codesign', '--force', '--deep', '--sign', '-', impostor[0])
        for index, (old, new, wrong) in enumerate(zip(first, second, impostor)):
            for source, target in ((old, new), (new, old)):
                requirement = self.folder / f'requirement-{index}-{source.parent.name}'
                run('codesign', '-d', '-r', requirement, source)
                expression = requirement.read_text().strip().removeprefix('# ').removeprefix('designated => ').strip()
                run('codesign', '--verify', '--strict', '-R', '=' + expression, source)
                result = subprocess.run(['codesign', '--verify', '--strict', '-R', '=' + expression,
                                         str(target)], capture_output=True)
                self.assertEqual(result.returncode, 0,
                                 'A new release must satisfy the previous app/helper identity: ' +
                                 result.stderr.decode())
                rejected = subprocess.run(['codesign', '--verify', '--strict', '-R', '=' + expression,
                                           str(wrong)], capture_output=True)
                self.assertNotEqual(rejected.returncode, 0, 'Ad-hoc replacement must not inherit identity')
                different_signer = subprocess.run(['codesign', '--verify', '--strict', '-R', '=' + expression,
                                                   str(other[index])], capture_output=True)
                self.assertNotEqual(different_signer.returncode, 0,
                                    'A different certificate with the same app identifier must be rejected')
            flags = subprocess.run(['codesign', '-dv', '--verbose=4', str(new)], capture_output=True).stderr
            self.assertNotIn(b'Signature=adhoc', flags)
            self.assertIn(b'runtime', flags)
        entitlements = plistlib.loads(run('codesign', '-d', '--entitlements', ':-', second[0]))
        self.assertIs(entitlements['com.apple.security.app-sandbox'], True)
        self.assertIs(entitlements['com.apple.security.cs.disable-library-validation'], True)

    def test_missing_identity_does_not_fall_back_to_adhoc(self):
        app, _ = self.fixture('missing', 4)
        with patch.dict(os.environ, {key: '' for key in self.credentials}):
            with self.assertRaisesRegex(ValueError, 'signing credentials'):
                release.sign_app(app, True)

    def test_wrong_private_identity_is_rejected_before_signing(self):
        app, _ = self.fixture('wrong', 5)
        with patch.dict(os.environ, self.other_credentials):
            with self.assertRaisesRegex(ValueError, 'pinned certificate'):
                release.sign_app(app, True)

    def test_failed_import_cleans_up_without_exposing_credentials(self):
        search_list = run('security', 'list-keychains', '-d', 'user')
        wrong_password = 'must-not-appear-in-signing-errors'
        with patch.dict(os.environ, dict(self.credentials, BORINGNOTCH_CODESIGN_PASSWORD=wrong_password)):
            with self.assertRaises(RuntimeError) as error:
                release.sign_app(self.folder / 'unused.app', True)
        self.assertNotIn(wrong_password, str(error.exception))
        self.assertNotIn(self.credentials['BORINGNOTCH_CODESIGN_P12_BASE64'], str(error.exception))
        self.assertEqual(run('security', 'list-keychains', '-d', 'user'), search_list)

    def test_modified_public_pin_is_rejected(self):
        with patch.dict(os.environ, self.credentials), \
             patch.dict(release.META, {'codesign_certificate_sha256': '0' * 64}):
            with self.assertRaisesRegex(ValueError, 'pinned certificate'):
                release.sign_app(self.folder / 'unused.app', True)


if __name__ == '__main__':
    unittest.main()
