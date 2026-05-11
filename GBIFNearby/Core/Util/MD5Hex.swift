import Foundation
import CryptoKit

extension Data {
    func md5HexLowercased() -> String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
