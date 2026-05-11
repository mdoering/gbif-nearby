import Foundation

enum ImageCacheURL {
    enum Size {
        case width(Int)
        case square(Int)
        var path: String {
            switch self {
            case .width(let w): return "\(w)x"
            case .square(let n): return "\(n)x\(n)"
            }
        }
    }

    static func build(occurrenceKey: Int, identifier: String, size: Size) -> URL {
        let md5 = Data(identifier.utf8).md5HexLowercased()
        return URL(string: "https://api.gbif.org/v1/image/cache/\(size.path)/occurrence/\(occurrenceKey)/media/\(md5)")!
    }
}
