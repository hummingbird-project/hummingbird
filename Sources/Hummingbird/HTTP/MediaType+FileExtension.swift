import HummingbirdCore

extension MediaType {
    public struct FileExtension: RawRepresentable, ExpressibleByStringLiteral, Sendable, Hashable {
        public let rawValue: String

        public init<S: StringProtocol>(_ rawValue: S) {
            self.init(rawValue: String(rawValue))
        }

        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }

        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }
    }
}

extension MediaType.FileExtension {
    public static let aac: Self = "aac"
    public static let abw: Self = "abw"
    public static let arc: Self = "arc"
    public static let azw: Self = "azw"
    public static let bin: Self = "bin"
    public static let bmp: Self = "bmp"
    public static let bz: Self = "bz"
    public static let bz2: Self = "bz2"
    public static let csh: Self = "csh"
    public static let css: Self = "css"
    public static let csv: Self = "csv"
    public static let doc: Self = "doc"
    public static let docx: Self = "docx"
    public static let eot: Self = "eot"
    public static let epub: Self = "epub"
    public static let gz: Self = "gz"
    public static let gif: Self = "gif"
    public static let htm: Self = "htm"
    public static let html: Self = "html"
    public static let ico: Self = "ico"
    public static let ics: Self = "ics"
    public static let jar: Self = "jar"
    public static let jpeg: Self = "jpeg"
    public static let jpg: Self = "jpg"
    public static let js: Self = "js"
    public static let json: Self = "json"
    public static let jsonld: Self = "jsonld"
    public static let mid: Self = "mid"
    public static let midi: Self = "midi"
    public static let mjs: Self = "mjs"
    public static let mp3: Self = "mp3"
    public static let mp4: Self = "mp4"
    public static let mpeg: Self = "mpeg"
    public static let mpkg: Self = "mpkg"
    public static let odp: Self = "odp"
    public static let ods: Self = "ods"
    public static let odt: Self = "odt"
    public static let oga: Self = "oga"
    public static let ogv: Self = "ogv"
    public static let ogx: Self = "ogx"
    public static let opus: Self = "opus"
    public static let otf: Self = "otf"
    public static let png: Self = "png"
    public static let pdf: Self = "pdf"
    public static let php: Self = "php"
    public static let ppt: Self = "ppt"
    public static let pptx: Self = "pptx"
    public static let rar: Self = "rar"
    public static let rtf: Self = "rtf"
    public static let sh: Self = "sh"
    public static let svg: Self = "svg"
    public static let swf: Self = "swf"
    public static let tar: Self = "tar"
    public static let tif: Self = "tif"
    public static let tiff: Self = "tiff"
    public static let ts: Self = "ts"
    public static let ttf: Self = "ttf"
    public static let txt: Self = "txt"
    public static let vsd: Self = "vsd"
    public static let wasm: Self = "wasm"
    public static let wav: Self = "wav"
    public static let weba: Self = "weba"
    public static let webm: Self = "webm"
    public static let webp: Self = "webp"
    public static let webmanifest: Self = "webmanifest"
    public static let woff: Self = "woff"
    public static let woff2: Self = "woff2"
    public static let xhtml: Self = "xhtml"
    public static let xls: Self = "xls"
    public static let xlsx: Self = "xlsx"
    public static let xml: Self = "xml"
    public static let zip: Self = "zip"
    public static let threeGP: Self = "3gp"
    public static let threeG2: Self = "3g2"
    public static let sevenZ: Self = "7z"
}
