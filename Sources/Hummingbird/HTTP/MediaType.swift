/// Define media type of file
public struct HBMediaType: CustomStringConvertible {
    /// general category
    public let type: Category
    /// exact kind of data specified
    public let subType: String
    /// optional parameter
    public let parameter: (name: String, value: String)?

    /// Initialize `HBMediaType`
    /// - Parameters:
    ///   - type: category
    ///   - subType: specific kind of data
    ///   - parameter: additional parameter
    public init(type: Category, subType: String, parameter: (String, String)? = nil) {
        self.type = type
        self.subType = subType
        self.parameter = parameter
    }

    /// Construct `HBMediaType` from header value
    public init?(from header: String) {
        guard let slashIndex = header.firstIndex(of: "/") else { return nil }
        let categoryString = header[..<slashIndex]
        guard let category = Category(rawValue: String(categoryString).lowercased()) else { return nil }

        let subType: String
        let parameter: (String, String)?

        let afterSlash = header[header.index(after: slashIndex)...]
        // if there is a character after the alphanumeric data
        if let subTypeEnd = afterSlash.firstIndex(where: { !($0.isNumber || $0.isLetter) }) {
            // check character is ;
            guard afterSlash[subTypeEnd] == ";" else { return nil }
            subType = String(afterSlash[..<subTypeEnd])
            let afterSemicolon = afterSlash[afterSlash.index(after: subTypeEnd)...]
                .drop { $0.isWhitespace }
            let params = afterSemicolon.split(separator: "=", maxSplits: 1)
            guard params.count == 2 else { return nil }
            parameter = (String(params[0]).lowercased(), String(params[1]).lowercased())
        } else {
            subType = String(afterSlash)
            parameter = nil
        }
        self.type = category
        self.subType = subType.lowercased()
        self.parameter = parameter
    }

    /// Output
    public var description: String {
        if let parameter = self.parameter {
            return "\(self.type)/\(self.subType); \(parameter.name)=\(parameter.value)"
        } else {
            return "\(self.type)/\(self.subType)"
        }
    }

    /// Return if media type matches the input
    public func isType(_ type: HBMediaType) -> Bool {
        guard self.type == type.type,
              self.subType == type.subType || type.subType == "*",
              type.parameter == nil || (self.parameter?.name == type.parameter?.name && self.parameter?.value == type.parameter?.value)
        else {
            return false
        }
        return true
    }

    /// Get media type from a file extension
    /// - Parameter extension: file extension
    /// - Returns: media type
    public static func getMediaType(for extension: String) -> HBMediaType? {
        return extensionMediaTypeMap[`extension`]
    }

    /// Media type categories
    public enum Category: String, Equatable {
        case application
        case audio
        case example
        case font
        case image
        case message
        case model
        case multipart
        case text
        case video
        case any

        public static func == (_ lhs: Category, _ rhs: Category) -> Bool {
            switch (lhs, rhs) {
            case (.any, _), (_, .any):
                return true
            default:
                return lhs.rawValue == rhs.rawValue
            }
        }
    }
}

extension HBMediaType {
    // application files

    /// AbiWord document
    public static var abiWord: Self { .init(type: .application, subType: "x-abiword") }
    /// Archive document (multiple files embedded)
    public static var arc: Self { .init(type: .application, subType: "x-freearc") }
    /// OGG
    public static var applicationOgg: Self { .init(type: .application, subType: "ogg") }
    /// Amazon Kindle eBook format
    public static var amzKindleEBook: Self { .init(type: .application, subType: "vnd.amazon.ebook") }
    /// Any kind of binary data
    public static var binary: Self { .init(type: .application, subType: "octet-stream") }
    /// BZip archive
    public static var bzip: Self { .init(type: .application, subType: "x-bzip") }
    /// BZip2 archive
    public static var bzip2: Self { .init(type: .application, subType: "x-bzip2") }
    /// C-Shell script
    public static var csh: Self { .init(type: .application, subType: "x-csh") }
    /// Microsoft Word
    public static var msword: Self { .init(type: .application, subType: "msword") }
    /// Microsoft Word (OpenXML)
    public static var docx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.wordprocessingml.document") }
    /// MS Embedded OpenType fonts
    public static var eot: Self { .init(type: .application, subType: "vnd.ms-fontobject") }
    /// Electronic publication (EPUB)
    public static var epub: Self { .init(type: .application, subType: "application/epub+zip") }
    /// GZip Compressed Archive
    public static var gzip: Self { .init(type: .application, subType: "gzip") }
    /// Java Archive (JAR)
    public static var jar: Self { .init(type: .application, subType: "java-archive") }
    /// JSON format
    public static var json: Self { .init(type: .application, subType: "json") }
    /// JSON-LD format
    public static var jsonLD: Self { .init(type: .application, subType: "ld+json") }
    /// Apple Installer Package
    public static var mpkg: Self { .init(type: .application, subType: "application/vnd.apple.installer+xml") }
    /// URL encoded form data
    public static var urlEncoded: Self { .init(type: .application, subType: "x-www-form-urlencoded") }
    /// OpenDocument presentation document
    public static var odp: Self { .init(type: .application, subType: "vnd.oasis.opendocument.presentation") }
    /// OpenDocument spreadsheet document
    public static var ods: Self { .init(type: .application, subType: "vnd.oasis.opendocument.spreadsheet") }
    /// OpenDocument text document
    public static var odt: Self { .init(type: .application, subType: "vnd.oasis.opendocument.text") }
    /// Adobe Portable Document Format
    public static var pdf: Self { .init(type: .application, subType: "pdf") }
    /// Hypertext Preprocessor
    public static var php: Self { .init(type: .application, subType: "x-httpd-php") }
    /// Microsoft PowerPoint
    public static var ppt: Self { .init(type: .application, subType: "vnd.ms-powerpoint") }
    /// Microsoft PowerPoint (OpenXML)
    public static var pptx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.presentationml.presentation") }
    /// RAR archive
    public static var rar: Self { .init(type: .application, subType: "vnd.rar") }
    /// Rich Text Format (RTF)
    public static var rtf: Self { .init(type: .application, subType: "rtf") }
    /// Bourne shell script
    public static var sh: Self { .init(type: .application, subType: "x-sh") }
    /// Small web format (SWF) or Adobe Flash document
    public static var swf: Self { .init(type: .application, subType: "x-shockwave-flash") }
    /// Tape Archive (TAR)
    public static var tar: Self { .init(type: .application, subType: "x-tar") }
    /// Microsoft Visio
    public static var vsd: Self { .init(type: .application, subType: "vnd.visio") }
    /// XHTML
    public static var xhtml: Self { .init(type: .application, subType: "xhtml+xml") }
    /// Microsoft Excel
    public static var xls: Self { .init(type: .application, subType: "vnd.ms-excel") }
    /// Microsoft Excel (OpenXML)
    public static var xlsx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
    /// XML
    public static var xml: Self { .init(type: .application, subType: "xml") }
    /// ZIP archive
    public static var zip: Self { .init(type: .application, subType: "zip") }
    /// 7-zip archive
    public static var zip7z: Self { .init(type: .application, subType: "x-7z-compressed") }

    // text

    /// Text, (generally ASCII or ISO 8859-n)
    public static var plainText: Self { .init(type: .text, subType: "plain") }
    /// iCalendar format
    public static var iCalendar: Self { .init(type: .text, subType: "calendar") }
    /// Cascading Style Sheets (CSS)
    public static var css: Self { .init(type: .text, subType: "css") }
    /// Comma-separated values (CSV)
    public static var csv: Self { .init(type: .text, subType: "csv") }
    /// HyperText Markup Language (HTML)
    public static var html: Self { .init(type: .text, subType: "html") }
    /// JavaScript
    public static var javascript: Self { .init(type: .text, subType: "javascript") }

    // image formats

    /// Windows OS/2 Bitmap Graphics
    public static var bmp: Self { .init(type: .image, subType: "bmp") }
    /// Graphics Interchange Format (GIF)
    public static var gif: Self { .init(type: .image, subType: "gif") }
    /// Icon format
    public static var ico: Self { .init(type: .image, subType: "vnd.microsoft.icon") }
    /// JPEG images
    public static var jpeg: Self { .init(type: .image, subType: "jpeg") }
    /// Portable Network Graphics
    public static var png: Self { .init(type: .image, subType: "png") }
    /// Scalable Vector Graphics (SVG)
    public static var svg: Self { .init(type: .image, subType: "svg") }
    /// Tagged Image File Format (TIFF)
    public static var tiff: Self { .init(type: .image, subType: "tiff") }
    /// WEBP image
    public static var webp: Self { .init(type: .image, subType: "webp") }

    // audio

    /// AAC audio
    public static var audioAac: Self { .init(type: .audio, subType: "aac") }
    /// Musical Instrument Digital Interface (MIDI)
    public static var audioMidi: Self { .init(type: .audio, subType: "midi") }
    /// MP3 audio
    public static var audioMpeg: Self { .init(type: .audio, subType: "mpeg") }
    /// OGG audio
    public static var audioOgg: Self { .init(type: .audio, subType: "ogg") }
    /// Waveform Audio Format
    public static var audioWave: Self { .init(type: .audio, subType: "wave") }
    /// WEBM audio
    public static var audioWebm: Self { .init(type: .audio, subType: "webm") }
    /// Opus audio
    public static var audioOpus: Self { .init(type: .audio, subType: "opus") }
    /// 3GPP audio/video container
    public static var audio3gp: Self { .init(type: .audio, subType: "3gpp") }
    /// 3GPP2 audio/video container
    public static var audio3g2: Self { .init(type: .audio, subType: "3gpp2") }

    // video

    /// AVI: Audio Video Interleave
    public static var videoMp4: Self { .init(type: .video, subType: "mp4") }
    /// MPEG Video
    public static var videoMpeg: Self { .init(type: .video, subType: "mpeg") }
    /// OGG video
    public static var videoOgg: Self { .init(type: .video, subType: "ogg") }
    /// MPEG transport stream
    public static var videoTs: Self { .init(type: .video, subType: "mp2t") }
    /// WEBM video
    public static var videoWebm: Self { .init(type: .video, subType: "webm") }
    /// 3GPP audio/video container
    public static var video3gp: Self { .init(type: .video, subType: "3gpp") }
    /// 3GPP2 audio/video container
    public static var video3g2: Self { .init(type: .video, subType: "3gpp2") }

    // font

    /// OpenType font
    public static var fontOtf: Self { .init(type: .font, subType: "otf") }
    /// TrueType Font
    public static var fontTtf: Self { .init(type: .font, subType: "ttf") }
    /// Web Open Font Format (WOFF)
    public static var fontWoff: Self { .init(type: .font, subType: "woff") }
    /// Web Open Font Format (WOFF)
    public static var fontWoff2: Self { .init(type: .font, subType: "woff2") }

    // multipart

    /// Multipart formdata
    public static var multipartForm: Self { .init(type: .multipart, subType: "form-data") }

    /// map from extension string to media type
    static let extensionMediaTypeMap: [String: HBMediaType] = [
        "aac": .audioAac,
        "abw": .abiWord,
        "arc": .arc,
        "azw": .amzKindleEBook,
        "bin": .binary,
        "bmp": .bmp,
        "bz": .bzip,
        "bz2": .bzip2,
        "csh": .csh,
        "css": .css,
        "csv": .csv,
        "doc": .msword,
        "docx": .docx,
        "eot": .eot,
        "epub": .epub,
        "gz": .gzip,
        "gif": .gif,
        "htm": .html,
        "html": .html,
        "ico": .ico,
        "ics": .iCalendar,
        "jar": .jar,
        "jpeg": .jpeg,
        "jpg": .jpeg,
        "js": .javascript,
        "json": .json,
        "jsonld": .jsonLD,
        "mid": .audioMidi,
        "midi": .audioMidi,
        "mjs": .javascript,
        "mp3": .audioMpeg,
        "mpeg": .videoMpeg,
        "mpkg": .mpkg,
        "odp": .odp,
        "ods": .ods,
        "odt": .odt,
        "oga": .audioOgg,
        "ogv": .videoOgg,
        "ogx": .applicationOgg,
        "opus": .audioOpus,
        "otf": .fontOtf,
        "png": .png,
        "pdf": .pdf,
        "php": .php,
        "ppt": .ppt,
        "pptx": .pptx,
        "rar": .rar,
        "rtf": .rtf,
        "sh": .sh,
        "svg": .svg,
        "swf": .swf,
        "tar": .tar,
        "tif": .tiff,
        "tiff": .tiff,
        "ts": .videoTs,
        "ttf": .fontTtf,
        "txt": .plainText,
        "vsd": .vsd,
        "wav": .audioWave,
        "weba": .audioWebm,
        "webm": .videoWebm,
        "webp": .webp,
        "woff": .fontWoff,
        "woff2": .fontWoff2,
        "xhtml": .xhtml,
        "xls": .xls,
        "xlsx": .xlsx,
        "xml": .xml,
        "zip": .zip,
        "3gp": .video3gp,
        "3g2": .video3g2,
    ]
}
