import Foundation

// Community cat packs: a folder with a `pack.json` manifest and optional images,
// in ~/Library/Application Support/Maramao/Cats/<pack>/. The format is declarative
// (no code), validated here before anything reaches the screen. See README → Cat packs.

/// An sRGB colour from a "#RRGGBB" string, 0...1 per channel.
public struct CatPackColor: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Parses "#RRGGBB" (the "#" is required). Returns nil for anything else.
    public init?(hex: String) {
        let text = hex.trimmingCharacters(in: .whitespaces)
        guard text.count == 7, text.first == "#" else { return nil }
        let digits = text.dropFirst()
        guard digits.allSatisfy({ $0.isHexDigit }), let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }
}

/// Fur colours for the code-drawn cat (`CatView`).
public struct CatPackPalette: Equatable, Sendable {
    public var name: String?
    public var fur: CatPackColor
    public var stripes: CatPackColor?
    public var belly: CatPackColor
    public var eyes: CatPackColor
    public var nose: CatPackColor?
}

/// A top/bottom caption for the meme wall.
public struct CatPackCaption: Equatable, Sendable {
    public var top: String
    public var bottom: String
}

/// A validated pack, ready to use.
public struct CatPack: Equatable, Sendable {
    public var id: String
    public var name: String
    public var author: String
    public var license: String
    public var description: String
    public var palettes: [CatPackPalette]
    public var catNames: [String]
    public var captions: [CatPackCaption]
    /// Image paths relative to the pack folder, checked to exist and stay inside it.
    public var images: [String]
    public var shortTips: [String]
    public var longTips: [String]
}

/// Why a pack was rejected. `message` is shown in Settings, so it is Italian.
public enum CatPackError: Error, Equatable, Sendable {
    case missingManifest
    case manifestTooLarge(bytes: Int)
    case invalidJSON(String)
    case unsupportedSchemaVersion(Int)
    case invalidField(String, reason: String)
    case unsupportedLicense(String)
    case tooMany(String, count: Int, limit: Int)
    case remoteURL(String)
    case unsafePath(String)
    case unsupportedImageType(String)
    case missingImage(String)
    case imageTooLarge(String, bytes: Int)
    case packTooLarge(bytes: Int)

    public var message: String {
        switch self {
        case .missingManifest:
            return "Manca il file \(CatPackRules.manifestFileName)."
        case .manifestTooLarge(let bytes):
            return "\(CatPackRules.manifestFileName) è troppo grande (\(bytes / 1024) KB, massimo \(CatPackRules.maxManifestBytes / 1024) KB)."
        case .invalidJSON(let detail):
            return "\(CatPackRules.manifestFileName) non è un JSON valido: \(detail)"
        case .unsupportedSchemaVersion(let version):
            return "Versione dello schema \(version) non supportata (Maramao legge la \(CatPackRules.schemaVersion))."
        case .invalidField(let field, let reason):
            return "Campo \"\(field)\": \(reason)"
        case .unsupportedLicense(let license):
            return "Licenza \"\(license)\" non ammessa: usa \(CatPackRules.licenses.sorted().joined(separator: ", "))."
        case .tooMany(let field, let count, let limit):
            return "Troppi elementi in \"\(field)\": \(count), massimo \(limit)."
        case .remoteURL(let value):
            return "Niente indirizzi web: \"\(value)\" deve essere un file dentro il pacchetto."
        case .unsafePath(let value):
            return "Percorso non valido: \"\(value)\" deve restare dentro la cartella del pacchetto."
        case .unsupportedImageType(let value):
            return "\"\(value)\": sono ammesse solo immagini PNG, GIF o JPEG."
        case .missingImage(let value):
            return "Immagine non trovata: \"\(value)\"."
        case .imageTooLarge(let value, let bytes):
            return "\"\(value)\" è troppo grande (\(bytes / 1_000_000) MB, massimo \(CatPackRules.maxImageBytes / 1_000_000) MB)."
        case .packTooLarge(let bytes):
            return "Il pacchetto è troppo grande (\(bytes / 1_000_000) MB, massimo \(CatPackRules.maxPackBytes / 1_000_000) MB)."
        }
    }
}

/// Limits of the format. Generous for real packs, small enough that a broken or
/// hostile pack cannot slow a break down.
public enum CatPackRules {
    public static let manifestFileName = "pack.json"
    public static let schemaVersion = 1
    /// SPDX ids. CC-BY packs must name an author.
    public static let licenses: Set<String> = ["CC0-1.0", "CC-BY-4.0"]
    public static let maxManifestBytes = 256 * 1024
    public static let maxImageBytes = 5_000_000
    public static let maxPackBytes = 30_000_000
    public static let maxPalettes = 16
    public static let maxNames = 50
    public static let maxCaptions = 200
    public static let maxImages = 50
    public static let maxTips = 100
    public static let maxNameLength = 60
    public static let maxCatNameLength = 30
    public static let maxCaptionLength = 80
    public static let maxTipLength = 160
    public static let maxDescriptionLength = 300
    public static let imageExtensions: Set<String> = ["png", "gif", "jpg", "jpeg"]
}

/// Validates a manifest. Pure: the file system is reached only through `fileSize`,
/// which returns the size of a pack-relative path, or nil when it does not exist.
public enum CatPackValidator {
    public static func validate(manifest data: Data, fileSize: (String) -> Int?) throws -> CatPack {
        guard data.count <= CatPackRules.maxManifestBytes else {
            throw CatPackError.manifestTooLarge(bytes: data.count)
        }
        let raw: RawManifest
        do {
            raw = try JSONDecoder().decode(RawManifest.self, from: data)
        } catch let DecodingError.keyNotFound(key, _) {
            throw CatPackError.invalidField(key.stringValue, reason: "obbligatorio.")
        } catch let DecodingError.typeMismatch(_, context) {
            throw CatPackError.invalidField(fieldName(context.codingPath), reason: "tipo sbagliato.")
        } catch let DecodingError.valueNotFound(_, context) {
            throw CatPackError.invalidField(fieldName(context.codingPath), reason: "valore mancante.")
        } catch {
            throw CatPackError.invalidJSON("controlla virgole e parentesi.")
        }

        guard raw.schemaVersion == CatPackRules.schemaVersion else {
            throw CatPackError.unsupportedSchemaVersion(raw.schemaVersion)
        }

        let id = raw.id.trimmingCharacters(in: .whitespaces)
        let idCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard !id.isEmpty, id.count <= 40, id.unicodeScalars.allSatisfy({ idCharacters.contains($0) }) else {
            throw CatPackError.invalidField("id", reason: "solo lettere minuscole, cifre e trattini, massimo 40.")
        }
        let name = try text(raw.name, field: "name", maxLength: CatPackRules.maxNameLength, required: true)
        let author = try text(raw.author ?? "", field: "author", maxLength: CatPackRules.maxNameLength, required: false)
        let description = try text(raw.description ?? "", field: "description", maxLength: CatPackRules.maxDescriptionLength, required: false)

        let license = raw.license.trimmingCharacters(in: .whitespaces)
        guard CatPackRules.licenses.contains(license) else {
            throw CatPackError.unsupportedLicense(license)
        }
        if license.hasPrefix("CC-BY"), author.isEmpty {
            throw CatPackError.invalidField("author", reason: "obbligatorio con una licenza CC-BY.")
        }

        let rawPalettes = raw.palettes ?? []
        try limit(rawPalettes.count, CatPackRules.maxPalettes, field: "palettes")
        var palettes: [CatPackPalette] = []
        for (index, palette) in rawPalettes.enumerated() {
            let field = "palettes[\(index)]"
            let paletteName = try text(palette.name ?? "", field: "\(field).name", maxLength: CatPackRules.maxCatNameLength, required: false)
            palettes.append(CatPackPalette(
                name: paletteName.isEmpty ? nil : paletteName,
                fur: try color(palette.fur, field: "\(field).fur"),
                stripes: try palette.stripes.map { try color($0, field: "\(field).stripes") },
                belly: try color(palette.belly, field: "\(field).belly"),
                eyes: try color(palette.eyes, field: "\(field).eyes"),
                nose: try palette.nose.map { try color($0, field: "\(field).nose") }
            ))
        }

        let rawNames = raw.catNames ?? []
        try limit(rawNames.count, CatPackRules.maxNames, field: "catNames")
        let catNames = try rawNames.enumerated().map { index, value in
            try text(value, field: "catNames[\(index)]", maxLength: CatPackRules.maxCatNameLength, required: true)
        }

        let rawCaptions = raw.captions ?? []
        try limit(rawCaptions.count, CatPackRules.maxCaptions, field: "captions")
        var captions: [CatPackCaption] = []
        for (index, caption) in rawCaptions.enumerated() {
            let field = "captions[\(index)]"
            let top = try text(caption.top ?? "", field: "\(field).top", maxLength: CatPackRules.maxCaptionLength, required: false)
            let bottom = try text(caption.bottom ?? "", field: "\(field).bottom", maxLength: CatPackRules.maxCaptionLength, required: false)
            guard !(top.isEmpty && bottom.isEmpty) else {
                throw CatPackError.invalidField(field, reason: "serve almeno \"top\" o \"bottom\".")
            }
            captions.append(CatPackCaption(top: top, bottom: bottom))
        }

        let shortTips = try tips(raw.tips?.short ?? [], field: "tips.short")
        let longTips = try tips(raw.tips?.long ?? [], field: "tips.long")

        let rawImages = raw.images ?? []
        try limit(rawImages.count, CatPackRules.maxImages, field: "images")
        var images: [String] = []
        var total = data.count
        for value in rawImages {
            let path = try safeRelativePath(value)
            guard let size = fileSize(path) else { throw CatPackError.missingImage(value) }
            guard size <= CatPackRules.maxImageBytes else { throw CatPackError.imageTooLarge(value, bytes: size) }
            total += size
            guard total <= CatPackRules.maxPackBytes else { throw CatPackError.packTooLarge(bytes: total) }
            images.append(path)
        }

        return CatPack(
            id: id,
            name: name,
            author: author,
            license: license,
            description: description,
            palettes: palettes,
            catNames: catNames,
            captions: captions,
            images: images,
            shortTips: shortTips,
            longTips: longTips
        )
    }

    /// Checks an image path: relative, inside the pack, no URL, an image extension.
    /// Returns it normalised ("./a/b.png" → "a/b.png").
    public static func safeRelativePath(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if lower.contains("://") || lower.hasPrefix("http:") || lower.hasPrefix("https:")
            || lower.hasPrefix("file:") || lower.hasPrefix("data:") || lower.hasPrefix("ftp:") {
            throw CatPackError.remoteURL(value)
        }
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.hasPrefix("~"), !trimmed.contains("\\") else {
            throw CatPackError.unsafePath(value)
        }
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true).filter { $0 != "." }
        guard !parts.isEmpty, !parts.contains(where: { $0 == ".." || $0.hasPrefix(".") }) else {
            throw CatPackError.unsafePath(value)
        }
        let normalised = parts.joined(separator: "/")
        let ext = (normalised as NSString).pathExtension.lowercased()
        guard CatPackRules.imageExtensions.contains(ext) else {
            throw CatPackError.unsupportedImageType(value)
        }
        return normalised
    }

    // MARK: - Helpers

    private static func text(_ value: String, field: String, maxLength: Int, required: Bool) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if required && trimmed.isEmpty {
            throw CatPackError.invalidField(field, reason: "non può essere vuoto.")
        }
        guard trimmed.count <= maxLength else {
            throw CatPackError.invalidField(field, reason: "troppo lungo (massimo \(maxLength) caratteri).")
        }
        return trimmed
    }

    private static func tips(_ values: [String], field: String) throws -> [String] {
        try limit(values.count, CatPackRules.maxTips, field: field)
        return try values.enumerated().map { index, value in
            try text(value, field: "\(field)[\(index)]", maxLength: CatPackRules.maxTipLength, required: true)
        }
    }

    private static func color(_ value: String, field: String) throws -> CatPackColor {
        guard let color = CatPackColor(hex: value) else {
            throw CatPackError.invalidField(field, reason: "colore nel formato \"#RRGGBB\".")
        }
        return color
    }

    private static func limit(_ count: Int, _ maximum: Int, field: String) throws {
        if count > maximum { throw CatPackError.tooMany(field, count: count, limit: maximum) }
    }

    private static func fieldName(_ path: [CodingKey]) -> String {
        path.map { key in key.intValue.map { "[\($0)]" } ?? key.stringValue }
            .joined(separator: ".")
            .replacingOccurrences(of: ".[", with: "[")
    }

    // MARK: - JSON shape

    private struct RawManifest: Decodable {
        var schemaVersion: Int
        var id: String
        var name: String
        var author: String?
        var license: String
        var description: String?
        var palettes: [RawPalette]?
        var catNames: [String]?
        var captions: [RawCaption]?
        var images: [String]?
        var tips: RawTips?
    }

    private struct RawPalette: Decodable {
        var name: String?
        var fur: String
        var stripes: String?
        var belly: String
        var eyes: String
        var nose: String?
    }

    private struct RawCaption: Decodable {
        var top: String?
        var bottom: String?
    }

    private struct RawTips: Decodable {
        var short: [String]?
        var long: [String]?
    }
}

/// Reads a pack folder from disk and validates it.
public enum CatPackLoader {
    /// Loads `<folder>/pack.json` and checks every referenced image exists inside the
    /// folder (symlinks pointing outside count as missing).
    public static func load(folder: URL) throws -> CatPack {
        let fm = FileManager.default
        let manifestURL = folder.appendingPathComponent(CatPackRules.manifestFileName)
        guard fm.fileExists(atPath: manifestURL.path) else { throw CatPackError.missingManifest }
        let manifestSize = fileSize(at: manifestURL) ?? 0
        guard manifestSize <= CatPackRules.maxManifestBytes else {
            throw CatPackError.manifestTooLarge(bytes: manifestSize)
        }
        let data: Data
        do {
            data = try Data(contentsOf: manifestURL)
        } catch {
            throw CatPackError.invalidJSON("non riesco a leggere il file.")
        }
        let root = folder.resolvingSymlinksInPath().standardizedFileURL.path
        return try CatPackValidator.validate(manifest: data) { relative in
            let url = folder.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
            guard url.path.hasPrefix(root + "/") else { return nil }
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
            return fileSize(at: url)
        }
    }

    /// Absolute URL of a validated pack-relative image path.
    public static func imageURL(folder: URL, path: String) -> URL {
        folder.appendingPathComponent(path)
    }

    private static func fileSize(at url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }
}
