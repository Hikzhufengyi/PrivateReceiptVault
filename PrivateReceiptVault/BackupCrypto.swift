import CryptoKit
import Foundation

enum BackupCrypto {
    private static let magic = Data("PRVBACKUP1".utf8)
    private static let saltLength = 16
    private static let rounds = 120_000

    static func encrypt(_ data: Data, password: String) throws -> Data {
        let salt = randomData(count: saltLength)
        let key = deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "BackupCrypto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create encrypted backup."])
        }
        var output = Data()
        output.append(magic)
        output.append(salt)
        output.append(combined)
        return output
    }

    static func decrypt(_ data: Data, password: String) throws -> Data {
        guard data.count > magic.count + saltLength,
              data.prefix(magic.count) == magic else {
            return data
        }

        let saltStart = magic.count
        let saltEnd = saltStart + saltLength
        let salt = data[saltStart..<saltEnd]
        let encrypted = data[saltEnd...]
        let key = deriveKey(password: password, salt: Data(salt))
        let box = try AES.GCM.SealedBox(combined: Data(encrypted))
        return try AES.GCM.open(box, using: key)
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        var material = Data(password.utf8) + salt
        for _ in 0..<rounds {
            material = Data(SHA256.hash(data: material + salt + Data(password.utf8)))
        }
        return SymmetricKey(data: material)
    }

    private static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}
