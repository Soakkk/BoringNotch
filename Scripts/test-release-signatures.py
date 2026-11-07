#!/usr/bin/env python3
"""Exercise public-only verification and key matching using a disposable in-memory key."""
import base64
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='personal-signature-test-') as temporary:
    folder = Path(temporary)
    fixture = folder / 'fixture.swift'
    fixture.write_text('''import Foundation
import CryptoKit
let key = Curve25519.Signing.PrivateKey()
let data = Data("authentic update fixture".utf8)
let signature = try key.signature(for: data)
let result = ["seed":key.rawRepresentation.base64EncodedString(),
              "public":key.publicKey.rawRepresentation.base64EncodedString(),
              "signature":signature.base64EncodedString()]
print(String(data: try JSONSerialization.data(withJSONObject: result), encoding: .utf8)!)
''')
    result = subprocess.run(['swift', str(fixture)], check=True, capture_output=True)
    keys = json.loads(result.stdout)
    checker = root / 'Scripts/check-signing-key.swift'
    def key_check(value, expected):
        result = subprocess.run(['swift', str(checker), keys['public']], input=value,
                                capture_output=True)
        assert (result.returncode == 0) == expected
        assert keys['seed'].encode() not in result.stdout + result.stderr
    key_check(keys['seed'].encode(), True)
    key_check(b'invalid secret must never be printed!', False)
    key_check(base64.b64encode(bytes(32)), False)
    content = b'authentic update fixture'
    archive = folder / 'update.zip'
    archive.write_bytes(content)
    feed = folder / 'feed.xml'
    block = f"<!-- sparkle-signatures:\nedSignature: {keys['signature']}\nlength: {len(content)}\n-->\n".encode()
    feed.write_bytes(content + block)
    def verify(path, valid, signature=None):
        command = ['swift', str(root / 'Scripts/verify-update.swift'), keys['public'], str(path)]
        if signature:
            command.append(signature)
        result = subprocess.run(command, capture_output=True)
        assert (result.returncode == 0) == valid, result.stderr.decode()
    verify(archive, True, keys['signature'])
    verify(feed, True)
    archive.write_bytes(content + b'!')
    verify(archive, False, keys['signature'])
    feed.write_bytes(content.replace(b'authentic', b'malicious') + block)
    verify(feed, False)
    # Explicitly corrupt the signed length regardless of fixture size.
    feed.write_bytes(content + block.replace(f'length: {len(content)}'.encode(), b'length: 999'))
    verify(feed, False)
print('Release signatures: valid archive/feed accepted; tampering, length mismatch, malformed and wrong private keys rejected without secret logging.')
