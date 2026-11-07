import Foundation
import CryptoKit

// Verifies downloaded updates without access to the private signing seed or Keychain.
// Usage: swift verify-update.swift TRUSTED_PUBLIC_KEY FILE [ARCHIVE_SIGNATURE]
func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(1)
}
let arguments = CommandLine.arguments
guard arguments.count == 3 || arguments.count == 4,
      let publicData = Data(base64Encoded: arguments[1]),
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicData),
      let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[2])) else {
    fail("Expected trusted public key, file, and optional archive signature.")
}
let content: Data
let signatureText: String
if arguments.count == 4 {
    content = data
    signatureText = arguments[3]
} else {
    let marker = Data("<!-- sparkle-signatures:\n".utf8)
    guard let range = data.range(of: marker, options: .backwards),
          let block = String(data: data[range.lowerBound...], encoding: .utf8) else {
        fail("Feed has no Sparkle signature block.")
    }
    content = data[..<range.lowerBound]
    let lines = block.split(separator: "\n").map(String.init)
    guard lines.count == 4, lines[0] == "<!-- sparkle-signatures:", lines[3] == "-->",
          lines[1].hasPrefix("edSignature: "), lines[2] == "length: \(content.count)" else {
        fail("Malformed Sparkle signature block or content length mismatch.")
    }
    signatureText = String(lines[1].dropFirst("edSignature: ".count))
}
guard let signature = Data(base64Encoded: signatureText),
      key.isValidSignature(signature, for: content) else {
    fail("Ed25519 signature verification failed.")
}
print("Ed25519 signature verified.")
