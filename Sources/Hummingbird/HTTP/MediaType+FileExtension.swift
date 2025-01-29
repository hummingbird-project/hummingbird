import HummingbirdCore

extension MediaType {
    /// Type safe wrapper for file extensions. Additionally provides case insensitive comparison.
    public struct FileExtension: RawRepresentable, ExpressibleByStringLiteral, Sendable, Hashable {

        /// The raw file extension
        public let rawValue: String

        /// Initialize `FileExtension`
        /// - Parameter rawValue: The raw, textual file extension
        public init<S: StringProtocol>(_ rawValue: S) {
            self.init(rawValue: String(rawValue))
        }

        /// Initialize `FileExtension`
        /// - Parameter rawValue: The raw, textual file extension
        public init(rawValue: String) {
            self.rawValue = rawValue.lowercased()
        }

        /// Initialize `FileExtension` - `ExpressibleByStringLiteral` conformance
        /// - Parameter value: The raw, textual file extension
        public init(stringLiteral value: String) {
            self.init(rawValue: value)
        }
    }
}

extension MediaType.FileExtension {
    /// File extension for the aac format.
    public static let aac: Self = "aac"
    /// File extension for the abw format.
    public static let abw: Self = "abw"
    /// File extension for the arc format.
    public static let arc: Self = "arc"
    /// File extension for the azw format.
    public static let azw: Self = "azw"
    /// File extension for the bin format.
    public static let bin: Self = "bin"
    /// File extension for the bmp format.
    public static let bmp: Self = "bmp"
    /// File extension for the bz format.
    public static let bz: Self = "bz"
    /// File extension for the bz2 format.
    public static let bz2: Self = "bz2"
    /// File extension for the csh format.
    public static let csh: Self = "csh"
    /// File extension for the css format.
    public static let css: Self = "css"
    /// File extension for the csv format.
    public static let csv: Self = "csv"
    /// File extension for the doc format.
    public static let doc: Self = "doc"
    /// File extension for the docx format.
    public static let docx: Self = "docx"
    /// File extension for the eot format.
    public static let eot: Self = "eot"
    /// File extension for the epub format.
    public static let epub: Self = "epub"
    /// File extension for the gz format.
    public static let gz: Self = "gz"
    /// File extension for the gif format.
    public static let gif: Self = "gif"
    /// File extension for the htm format.
    public static let htm: Self = "htm"
    /// File extension for the html format.
    public static let html: Self = "html"
    /// File extension for the ico format.
    public static let ico: Self = "ico"
    /// File extension for the ics format.
    public static let ics: Self = "ics"
    /// File extension for the jar format.
    public static let jar: Self = "jar"
    /// File extension for the jpeg format.
    public static let jpeg: Self = "jpeg"
    /// File extension for the jpg format.
    public static let jpg: Self = "jpg"
    /// File extension for the js format.
    public static let js: Self = "js"
    /// File extension for the json format.
    public static let json: Self = "json"
    /// File extension for the jsonld format.
    public static let jsonld: Self = "jsonld"
    /// File extension for the mid format.
    public static let mid: Self = "mid"
    /// File extension for the midi format.
    public static let midi: Self = "midi"
    /// File extension for the mjs format.
    public static let mjs: Self = "mjs"
    /// File extension for the mp3 format.
    public static let mp3: Self = "mp3"
    /// File extension for the mp4 format.
    public static let mp4: Self = "mp4"
    /// File extension for the mpeg format.
    public static let mpeg: Self = "mpeg"
    /// File extension for the mpkg format.
    public static let mpkg: Self = "mpkg"
    /// File extension for the odp format.
    public static let odp: Self = "odp"
    /// File extension for the ods format.
    public static let ods: Self = "ods"
    /// File extension for the odt format.
    public static let odt: Self = "odt"
    /// File extension for the oga format.
    public static let oga: Self = "oga"
    /// File extension for the ogv format.
    public static let ogv: Self = "ogv"
    /// File extension for the ogx format.
    public static let ogx: Self = "ogx"
    /// File extension for the opus format.
    public static let opus: Self = "opus"
    /// File extension for the otf format.
    public static let otf: Self = "otf"
    /// File extension for the png format.
    public static let png: Self = "png"
    /// File extension for the pdf format.
    public static let pdf: Self = "pdf"
    /// File extension for the php format.
    public static let php: Self = "php"
    /// File extension for the ppt format.
    public static let ppt: Self = "ppt"
    /// File extension for the pptx format.
    public static let pptx: Self = "pptx"
    /// File extension for the rar format.
    public static let rar: Self = "rar"
    /// File extension for the rtf format.
    public static let rtf: Self = "rtf"
    /// File extension for the sh format.
    public static let sh: Self = "sh"
    /// File extension for the svg format.
    public static let svg: Self = "svg"
    /// File extension for the swf format.
    public static let swf: Self = "swf"
    /// File extension for the tar format.
    public static let tar: Self = "tar"
    /// File extension for the tif format.
    public static let tif: Self = "tif"
    /// File extension for the tiff format.
    public static let tiff: Self = "tiff"
    /// File extension for the ts format.
    public static let ts: Self = "ts"
    /// File extension for the ttf format.
    public static let ttf: Self = "ttf"
    /// File extension for the txt format.
    public static let txt: Self = "txt"
    /// File extension for the vsd format.
    public static let vsd: Self = "vsd"
    /// File extension for the wasm format.
    public static let wasm: Self = "wasm"
    /// File extension for the wav format.
    public static let wav: Self = "wav"
    /// File extension for the weba format.
    public static let weba: Self = "weba"
    /// File extension for the webm format.
    public static let webm: Self = "webm"
    /// File extension for the webp format.
    public static let webp: Self = "webp"
    /// File extension for the webmanifest format.
    public static let webmanifest: Self = "webmanifest"
    /// File extension for the woff format.
    public static let woff: Self = "woff"
    /// File extension for the woff2 format.
    public static let woff2: Self = "woff2"
    /// File extension for the xhtml format.
    public static let xhtml: Self = "xhtml"
    /// File extension for the xls format.
    public static let xls: Self = "xls"
    /// File extension for the xlsx format.
    public static let xlsx: Self = "xlsx"
    /// File extension for the xml format.
    public static let xml: Self = "xml"
    /// File extension for the zip format.
    public static let zip: Self = "zip"
    /// File extension for the 3gp format.
    public static let threeGP: Self = "3gp"
    /// File extension for the 3g2 format.
    public static let threeG2: Self = "3g2"
    /// File extension for the 7z format.
    public static let sevenZ: Self = "7z"
}
