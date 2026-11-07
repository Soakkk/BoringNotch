"""Pinned personal code signing in a disposable keychain, with no ad-hoc fallback."""
import base64
import hashlib
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import tempfile


def private_command(*args, input=None):
    """Never propagate command arguments or command output containing credential material."""
    result = subprocess.run([str(arg) for arg in args], input=input, capture_output=True)
    if result.returncode:
        hints = {b'MAC verification failed': 'PKCS#12 import verification failed',
                 b'User interaction is not allowed': 'keychain authorization unavailable',
                 b'CSSMERR_TP_NOT_TRUSTED': 'certificate trust rejected',
                 b'no identity found': 'signing identity unavailable',
                 b'errSecInternalComponent': 'code-signing security service rejected the operation'}
        hint = next((value for marker, value in hints.items() if marker in result.stderr), 'operation failed')
        raise RuntimeError(f'Personal signing: {Path(args[0]).name} {hint} ({result.returncode})')
    return result.stdout


class PersonalCodeSigner:
    def __init__(self, public_certificate, expected_sha256):
        encoded = os.environ.get('BORINGNOTCH_CODESIGN_P12_BASE64', '')
        self.password = os.environ.get('BORINGNOTCH_CODESIGN_PASSWORD', '')
        if not encoded or not self.password:
            raise ValueError('Missing personal signing credentials; ad-hoc fallback is forbidden')
        if len(encoded) > 1024 * 1024:
            raise ValueError('Invalid personal signing credentials')
        try:
            self.pkcs12 = base64.b64decode(encoded, validate=True)
        except ValueError:
            raise ValueError('Invalid personal signing credentials') from None
        if not isinstance(expected_sha256, str) or not re.fullmatch('[0-9a-f]{64}', expected_sha256):
            raise ValueError('Missing pinned certificate fingerprint')
        der = private_command('/usr/bin/openssl', 'x509', '-in', public_certificate, '-outform', 'DER')
        self.sha256 = hashlib.sha256(der).hexdigest()
        self.sha1 = hashlib.sha1(der).hexdigest().upper()
        if self.sha256 != expected_sha256:
            raise ValueError('Public signing identity does not match the pinned certificate')
        self.temporary = None
        self.keychain = None
        self.original_search_list = None

    def __enter__(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='boring-codesign-')
        try:
            folder = Path(self.temporary.name)
            folder.chmod(0o700)
            archive = folder / 'identity.p12'
            archive.write_bytes(self.pkcs12)
            archive.chmod(0o600)
            certificate = private_command('/usr/bin/openssl', 'pkcs12', '-in', archive, '-clcerts', '-nokeys',
                                          '-passin', 'stdin', input=(self.password + '\n').encode())
            if certificate.count(b'-----BEGIN CERTIFICATE-----') != 1:
                raise ValueError('PKCS#12 must contain exactly the pinned certificate')
            der = private_command('/usr/bin/openssl', 'x509', '-outform', 'DER', input=certificate)
            if hashlib.sha256(der).hexdigest() != self.sha256:
                raise ValueError('Private signing identity does not match the pinned certificate')
            self.keychain = folder / 'signing.keychain-db'
            keychain_password = secrets.token_urlsafe(32)
            private_command('security', 'create-keychain', '-p', keychain_password, self.keychain)
            private_command('security', 'set-keychain-settings', '-lut', '3600', self.keychain)
            private_command('security', 'unlock-keychain', '-p', keychain_password, self.keychain)
            private_command('security', 'import', archive, '-k', self.keychain, '-P', self.password,
                            '-T', '/usr/bin/codesign')
            private_command('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:',
                            '-s', '-k', keychain_password, self.keychain)
            # --keychain selects the identity but still requires its keychain in
            # the search list on headless runners. Restore the exact list on exit.
            self.original_search_list = shlex.split(
                private_command('security', 'list-keychains', '-d', 'user').decode())
            private_command('security', 'list-keychains', '-d', 'user', '-s',
                            self.keychain, *self.original_search_list)
            archive.unlink()
            self.pkcs12 = b''
            self.password = ''
            return self
        except BaseException:
            self.__exit__(None, None, None)
            raise

    def sign(self, path, entitlements=None):
        args = ['codesign', '--force', '--sign', self.sha1, '--keychain', self.keychain,
                '--timestamp=none', '--options', 'runtime']
        if entitlements is not None:
            args.extend(['--entitlements', entitlements])
        private_command(*args, path)

    def verify(self, path, identifier):
        # Certificate pin, not a broad identifier-only requirement: another signer cannot inherit grants.
        requirement = f'=identifier "{identifier}" and certificate leaf = H"{self.sha1}"'
        private_command('codesign', '--verify', '--deep', '--strict', '-R', requirement, path)

    @property
    def manifest(self):
        return {'signing': 'personal-certificate', 'codesign_certificate_sha256': self.sha256}

    def __exit__(self, *_):
        try:
            if self.original_search_list is not None:
                private_command('security', 'list-keychains', '-d', 'user', '-s',
                                *self.original_search_list)
        finally:
            if self.keychain is not None and self.keychain.exists():
                subprocess.run(['security', 'delete-keychain', str(self.keychain)], capture_output=True)
            if self.temporary is not None:
                self.temporary.cleanup()
            self.pkcs12 = b''
            self.password = ''
