//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Define media type of file
public struct HBMediaType: CustomStringConvertible, HBSendable {
    /// general category
    public let type: Category
    /// exact kind of data specified
    public let subType: String
    /// optional parameter
    public let parameter: Parameter?

    /// Initialize `HBMediaType`
    /// - Parameters:
    ///   - type: category
    ///   - subType: specific kind of data
    ///   - parameter: additional parameter
    public init(type: Category, subType: String = "*", parameter: Parameter? = nil) {
        self.type = type
        self.subType = subType
        self.parameter = parameter
    }

    /// Construct `HBMediaType` from header value
    public init?(from header: String) {
        enum State: Equatable {
            case readingCategory
            case readingSubCategory
            case readingParameterKey
            case readingParameterValue(key: String)
            case finished
        }
        var parser = HBParser(header)
        var state = State.readingCategory

        var category: Category?
        var subCategory: String?
        var parameter: Parameter?

        while state != .finished {
            switch state {
            case .readingCategory:
                let categoryString = parser.read(while: { !Self.tSpecial.contains($0) }).string
                category = Category(rawValue: categoryString.lowercased())
                guard parser.current() == "/" else { return nil }
                parser.unsafeAdvance()
                state = .readingSubCategory

            case .readingSubCategory:
                subCategory = parser.read(while: { !Self.tSpecial.contains($0) }).string
                if parser.reachedEnd() {
                    state = .finished
                } else {
                    guard parser.current() == ";" else { return nil }
                    parser.unsafeAdvance()
                    parser.read(while: \.isWhitespace)
                    if parser.reachedEnd() {
                        state = .finished
                    } else {
                        state = .readingParameterKey
                    }
                }

            case .readingParameterKey:
                let key = parser.read(while: { !Self.tSpecial.contains($0) }).string
                guard parser.current() == "=" else { return nil }
                state = .readingParameterValue(key: key)
                parser.unsafeAdvance()

            case .readingParameterValue(let key):
                let value: String
                if parser.current() == "\"" {
                    parser.unsafeAdvance()
                    do {
                        value = try parser.read(until: "\"").string
                    } catch {
                        return nil
                    }
                } else {
                    value = parser.readUntilTheEnd().string
                }
                parameter = .init(name: key, value: value)
                state = .finished

            case .finished:
                break
            }
        }
        if let category = category,
           let subCategory = subCategory
        {
            self.type = category
            self.subType = subCategory.lowercased()
            self.parameter = parameter
        } else {
            return nil
        }
    }

    /// Return media type with new parameter
    public func withParameter(name: String, value: String) -> HBMediaType {
        return .init(type: self.type, subType: self.subType, parameter: .init(name: name, value: value))
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
    public static func getMediaType(forExtension: String) -> HBMediaType? {
        return extensionMediaTypeMap[forExtension]
    }

    /// Media type categories
    public enum Category: String, Equatable, HBSendable {
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

    /// Media type parameter
    public struct Parameter: HBSendable {
        public let name: String
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    static let tSpecial = Set<Unicode.Scalar>(["(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", "/", "[", "]", "?", ".", "="])
}

extension HBMediaType {
    // types
    public static var application: Self { .init(type: .application) }
    public static var audio: Self { .init(type: .audio) }
    public static var example: Self { .init(type: .example) }
    public static var font: Self { .init(type: .font) }
    public static var image: Self { .init(type: .image) }
    public static var message: Self { .init(type: .message) }
    public static var model: Self { .init(type: .model) }
    public static var multipart: Self { .init(type: .multipart) }
    public static var text: Self { .init(type: .text) }
    public static var video: Self { .init(type: .video) }

    // application files

    /// AbiWord document
    public static var applicationAbiWord: Self { .init(type: .application, subType: "x-abiword") }
    /// Archive document (multiple files embedded)
    public static var applicationArc: Self { .init(type: .application, subType: "x-freearc") }
    /// OGG
    public static var applicationOgg: Self { .init(type: .application, subType: "ogg") }
    /// Amazon Kindle eBook format
    public static var applicationAmzKindleEBook: Self { .init(type: .application, subType: "vnd.amazon.ebook") }
    /// Any kind of binary data
    public static var applicationBinary: Self { .init(type: .application, subType: "octet-stream") }
    /// BZip archive
    public static var applicationBzip: Self { .init(type: .application, subType: "x-bzip") }
    /// BZip2 archive
    public static var applicationBzip2: Self { .init(type: .application, subType: "x-bzip2") }
    /// C-Shell script
    public static var applicationCsh: Self { .init(type: .application, subType: "x-csh") }
    /// Microsoft Word
    public static var applicationMsword: Self { .init(type: .application, subType: "msword") }
    /// Microsoft Word (OpenXML)
    public static var applicationDocx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.wordprocessingml.document") }
    /// MS Embedded OpenType fonts
    public static var applicationEot: Self { .init(type: .application, subType: "vnd.ms-fontobject") }
    /// Electronic publication (EPUB)
    public static var applicationEpub: Self { .init(type: .application, subType: "application/epub+zip") }
    /// GZip Compressed Archive
    public static var applicationGzip: Self { .init(type: .application, subType: "gzip") }
    /// Java Archive (JAR)
    public static var applicationJar: Self { .init(type: .application, subType: "java-archive") }
    /// JSON format
    public static var applicationJson: Self { .init(type: .application, subType: "json") }
    /// JSON-LD format
    public static var applicationJsonLD: Self { .init(type: .application, subType: "ld+json") }
    /// Apple Installer Package
    public static var applicationMpkg: Self { .init(type: .application, subType: "application/vnd.apple.installer+xml") }
    /// URL encoded form data
    public static var applicationUrlEncoded: Self { .init(type: .application, subType: "x-www-form-urlencoded") }
    /// OpenDocument presentation document
    public static var applicationOdp: Self { .init(type: .application, subType: "vnd.oasis.opendocument.presentation") }
    /// OpenDocument spreadsheet document
    public static var applicationOds: Self { .init(type: .application, subType: "vnd.oasis.opendocument.spreadsheet") }
    /// OpenDocument text document
    public static var applicationOdt: Self { .init(type: .application, subType: "vnd.oasis.opendocument.text") }
    /// Adobe Portable Document Format
    public static var applicationPdf: Self { .init(type: .application, subType: "pdf") }
    /// Hypertext Preprocessor
    public static var applicationPhp: Self { .init(type: .application, subType: "x-httpd-php") }
    /// Microsoft PowerPoint
    public static var applicationPpt: Self { .init(type: .application, subType: "vnd.ms-powerpoint") }
    /// Microsoft PowerPoint (OpenXML)
    public static var applicationPptx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.presentationml.presentation") }
    /// RAR archive
    public static var applicationRar: Self { .init(type: .application, subType: "vnd.rar") }
    /// Rich Text Format (RTF)
    public static var applicationRtf: Self { .init(type: .application, subType: "rtf") }
    /// Bourne shell script
    public static var applicationSh: Self { .init(type: .application, subType: "x-sh") }
    /// Small web format (SWF) or Adobe Flash document
    public static var applicationSwf: Self { .init(type: .application, subType: "x-shockwave-flash") }
    /// Tape Archive (TAR)
    public static var applicationTar: Self { .init(type: .application, subType: "x-tar") }
    /// Microsoft Visio
    public static var applicationVsd: Self { .init(type: .application, subType: "vnd.visio") }
    /// XHTML
    public static var applicationXhtml: Self { .init(type: .application, subType: "xhtml+xml") }
    /// Microsoft Excel
    public static var applicationXls: Self { .init(type: .application, subType: "vnd.ms-excel") }
    /// Microsoft Excel (OpenXML)
    public static var applicationXlsx: Self { .init(type: .application, subType: "vnd.openxmlformats-officedocument.spreadsheetml.sheet") }
    /// XML
    public static var applicationXml: Self { .init(type: .application, subType: "xml") }
    /// ZIP archive
    public static var applicationZip: Self { .init(type: .application, subType: "zip") }
    /// 7-zip archive
    public static var application7z: Self { .init(type: .application, subType: "x-7z-compressed") }

    // text

    /// Text, (generally ASCII or ISO 8859-n)
    public static var textPlain: Self { .init(type: .text, subType: "plain") }
    /// iCalendar format
    public static var textICalendar: Self { .init(type: .text, subType: "calendar") }
    /// Cascading Style Sheets (CSS)
    public static var textCss: Self { .init(type: .text, subType: "css") }
    /// Comma-separated values (CSV)
    public static var textCsv: Self { .init(type: .text, subType: "csv") }
    /// HyperText Markup Language (HTML)
    public static var textHtml: Self { .init(type: .text, subType: "html") }
    /// JavaScript
    public static var textJavascript: Self { .init(type: .text, subType: "javascript") }

    // image formats

    /// Windows OS/2 Bitmap Graphics
    public static var imageBmp: Self { .init(type: .image, subType: "bmp") }
    /// Graphics Interchange Format (GIF)
    public static var imageGif: Self { .init(type: .image, subType: "gif") }
    /// Icon format
    public static var imageIco: Self { .init(type: .image, subType: "vnd.microsoft.icon") }
    /// JPEG images
    public static var imageJpeg: Self { .init(type: .image, subType: "jpeg") }
    /// Portable Network Graphics
    public static var imagePng: Self { .init(type: .image, subType: "png") }
    /// Scalable Vector Graphics (SVG)
    public static var imageSvg: Self { .init(type: .image, subType: "svg") }
    /// Tagged Image File Format (TIFF)
    public static var imageTiff: Self { .init(type: .image, subType: "tiff") }
    /// WEBP image
    public static var imageWebp: Self { .init(type: .image, subType: "webp") }

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
        "abw": .applicationAbiWord,
        "arc": .applicationArc,
        "azw": .applicationAmzKindleEBook,
        "bin": .applicationBinary,
        "bmp": .imageBmp,
        "bz": .applicationBzip,
        "bz2": .applicationBzip2,
        "csh": .applicationCsh,
        "css": .textCss,
        "csv": .textCsv,
        "doc": .applicationMsword,
        "docx": .applicationDocx,
        "eot": .applicationEot,
        "epub": .applicationEpub,
        "gz": .applicationGzip,
        "gif": .imageGif,
        "htm": .textHtml,
        "html": .textHtml,
        "ico": .imageIco,
        "ics": .textICalendar,
        "jar": .applicationJar,
        "jpeg": .imageJpeg,
        "jpg": .imageJpeg,
        "js": .textJavascript,
        "json": .applicationJson,
        "jsonld": .applicationJsonLD,
        "mid": .audioMidi,
        "midi": .audioMidi,
        "mjs": .textJavascript,
        "mp3": .audioMpeg,
        "mp4": .videoMp4,
        "mpeg": .videoMpeg,
        "mpkg": .applicationMpkg,
        "odp": .applicationOdp,
        "ods": .applicationOds,
        "odt": .applicationOdt,
        "oga": .audioOgg,
        "ogv": .videoOgg,
        "ogx": .applicationOgg,
        "opus": .audioOpus,
        "otf": .fontOtf,
        "png": .imagePng,
        "pdf": .applicationPdf,
        "php": .applicationPhp,
        "ppt": .applicationPpt,
        "pptx": .applicationPptx,
        "rar": .applicationRar,
        "rtf": .applicationRtf,
        "sh": .applicationSh,
        "svg": .imageSvg,
        "swf": .applicationSwf,
        "tar": .applicationTar,
        "tif": .imageTiff,
        "tiff": .imageTiff,
        "ts": .videoTs,
        "ttf": .fontTtf,
        "txt": .textPlain,
        "vsd": .applicationVsd,
        "wav": .audioWave,
        "weba": .audioWebm,
        "webm": .videoWebm,
        "webp": .imageWebp,
        "woff": .fontWoff,
        "woff2": .fontWoff2,
        "xhtml": .applicationXhtml,
        "xls": .applicationXls,
        "xlsx": .applicationXlsx,
        "xml": .applicationXml,
        "zip": .applicationZip,
        "3gp": .video3gp,
        "3g2": .video3g2,
        "7z": .application7z,
    ]
}
