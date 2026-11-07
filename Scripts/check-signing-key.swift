import Foundation
import CryptoKit

// No key material is printed, even for malformed input. Sparkle 2.9 exports a 32-byte seed.
let input = FileHandle.standardInput.readDataToEndOfFile()
guard let text = String(data: input, encoding: .utf8),
      let seed = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
      seed.count == 32,
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed),
      CommandLine.arguments.count == 2,
      key.publicKey.rawRepresentation.base64EncodedString() == CommandLine.arguments[1] else {
    fputs("Private signing seed is invalid or does not match the application's public key.\n", stderr)
    exit(1)
}
