import XCTest
@testable import MaramaoCore

final class CatPackTests: XCTestCase {
    private func manifest(_ fields: [String: Any]) -> Data {
        var base: [String: Any] = [
            "schemaVersion": 1,
            "id": "micio",
            "name": "Micio",
            "license": "CC0-1.0",
        ]
        for (key, value) in fields { base[key] = value }
        return try! JSONSerialization.data(withJSONObject: base)
    }

    private func validate(_ fields: [String: Any], files: [String: Int] = [:]) throws -> CatPack {
        try CatPackValidator.validate(manifest: manifest(fields)) { files[$0] }
    }

    private func assertError(_ fields: [String: Any], files: [String: Int] = [:], _ expected: CatPackError, line: UInt = #line) {
        XCTAssertThrowsError(try validate(fields, files: files), line: line) { error in
            XCTAssertEqual(error as? CatPackError, expected, line: line)
        }
    }

    // MARK: - Valid packs

    func testMinimalPack() throws {
        let pack = try validate([:])
        XCTAssertEqual(pack.id, "micio")
        XCTAssertEqual(pack.name, "Micio")
        XCTAssertEqual(pack.license, "CC0-1.0")
        XCTAssertTrue(pack.palettes.isEmpty)
        XCTAssertTrue(pack.images.isEmpty)
    }

    func testFullPack() throws {
        let pack = try validate([
            "author": "Fé",
            "license": "CC-BY-4.0",
            "description": "Un gatto rosso.",
            "palettes": [["name": "Micio", "fur": "#FF8000", "stripes": "#804000", "belly": "#FFFFFF", "eyes": "#00ff00"]],
            "catNames": ["Micio", "Fufi"],
            "captions": [["top": "CIAO", "bottom": "MIAO"], ["bottom": "SOLO SOTTO"]],
            "images": ["./images/micio.png", "images/dance.gif"],
            "tips": ["short": ["Bevi."], "long": ["Esci."]],
        ], files: ["images/micio.png": 1000, "images/dance.gif": 2000])
        XCTAssertEqual(pack.author, "Fé")
        XCTAssertEqual(pack.palettes.count, 1)
        XCTAssertEqual(pack.palettes[0].name, "Micio")
        XCTAssertEqual(pack.palettes[0].fur, CatPackColor(red: 1, green: 128.0 / 255, blue: 0))
        XCTAssertNil(pack.palettes[0].nose)
        XCTAssertEqual(pack.catNames, ["Micio", "Fufi"])
        XCTAssertEqual(pack.captions, [CatPackCaption(top: "CIAO", bottom: "MIAO"), CatPackCaption(top: "", bottom: "SOLO SOTTO")])
        XCTAssertEqual(pack.images, ["images/micio.png", "images/dance.gif"])
        XCTAssertEqual(pack.shortTips, ["Bevi."])
        XCTAssertEqual(pack.longTips, ["Esci."])
    }

    func testUnknownKeysAreIgnored() throws {
        XCTAssertNoThrow(try validate(["futureField": true]))
    }

    // MARK: - Schema and metadata

    func testSchemaVersion() {
        assertError(["schemaVersion": 2], .unsupportedSchemaVersion(2))
        assertError(["schemaVersion": 0], .unsupportedSchemaVersion(0))
    }

    func testMissingRequiredField() {
        let data = try! JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "id": "a", "license": "CC0-1.0"])
        XCTAssertThrowsError(try CatPackValidator.validate(manifest: data) { _ in nil }) { error in
            XCTAssertEqual(error as? CatPackError, .invalidField("name", reason: "obbligatorio."))
        }
    }

    func testWrongType() {
        XCTAssertThrowsError(try validate(["catNames": "Micio"])) { error in
            guard case .invalidField(let field, _)? = error as? CatPackError else {
                return XCTFail("unexpected \(error)")
            }
            XCTAssertEqual(field, "catNames")
        }
    }

    func testBrokenJSON() {
        let data = Data("{ \"schemaVersion\": 1, ".utf8)
        XCTAssertThrowsError(try CatPackValidator.validate(manifest: data) { _ in nil }) { error in
            guard case .invalidJSON? = error as? CatPackError else { return XCTFail("unexpected \(error)") }
        }
    }

    func testManifestSizeLimit() {
        let big = String(repeating: "a", count: CatPackRules.maxManifestBytes)
        let data = manifest(["description": big])
        XCTAssertThrowsError(try CatPackValidator.validate(manifest: data) { _ in nil }) { error in
            guard case .manifestTooLarge? = error as? CatPackError else { return XCTFail("unexpected \(error)") }
        }
    }

    func testBadIds() {
        for id in ["", "Micio", "mi cio", "micio/../x", String(repeating: "a", count: 41)] {
            XCTAssertThrowsError(try validate(["id": id]), id)
        }
        XCTAssertNoThrow(try validate(["id": "gatti-di-fe-2"]))
    }

    func testLicenses() {
        assertError(["license": "MIT"], .unsupportedLicense("MIT"))
        assertError(["license": "All rights reserved"], .unsupportedLicense("All rights reserved"))
        assertError(["license": "CC-BY-4.0"], .invalidField("author", reason: "obbligatorio con una licenza CC-BY."))
        XCTAssertNoThrow(try validate(["license": "CC-BY-4.0", "author": "Fé"]))
    }

    func testTextLimits() {
        XCTAssertThrowsError(try validate(["name": "   "]))
        XCTAssertThrowsError(try validate(["name": String(repeating: "x", count: CatPackRules.maxNameLength + 1)]))
        XCTAssertThrowsError(try validate(["captions": [["top": String(repeating: "x", count: CatPackRules.maxCaptionLength + 1)]]]))
        XCTAssertThrowsError(try validate(["captions": [["top": " ", "bottom": ""]]]))
        XCTAssertThrowsError(try validate(["tips": ["short": [String(repeating: "x", count: CatPackRules.maxTipLength + 1)]]]))
        XCTAssertThrowsError(try validate(["catNames": [""]]))
    }

    func testCountLimits() {
        let names = Array(repeating: "Micio", count: CatPackRules.maxNames + 1)
        assertError(["catNames": names], .tooMany("catNames", count: names.count, limit: CatPackRules.maxNames))
        let palette = ["fur": "#000000", "belly": "#000000", "eyes": "#000000"]
        let palettes = Array(repeating: palette, count: CatPackRules.maxPalettes + 1)
        assertError(["palettes": palettes], .tooMany("palettes", count: palettes.count, limit: CatPackRules.maxPalettes))
    }

    // MARK: - Colours

    func testColors() {
        XCTAssertEqual(CatPackColor(hex: "#000000"), CatPackColor(red: 0, green: 0, blue: 0))
        XCTAssertEqual(CatPackColor(hex: "#FFffFF"), CatPackColor(red: 1, green: 1, blue: 1))
        XCTAssertNil(CatPackColor(hex: "FFFFFF"))
        XCTAssertNil(CatPackColor(hex: "#FFF"))
        XCTAssertNil(CatPackColor(hex: "#GG0000"))
        XCTAssertNil(CatPackColor(hex: "#+12345"))
        assertError(
            ["palettes": [["fur": "red", "belly": "#000000", "eyes": "#000000"]]],
            .invalidField("palettes[0].fur", reason: "colore nel formato \"#RRGGBB\".")
        )
    }

    // MARK: - Images

    func testRemoteURLsAreRejected() {
        for url in ["https://example.com/cat.png", "http://x/y.gif", "file:///etc/cat.png", "data:image/png;base64,AAAA", "HTTPS://X/Y.PNG"] {
            assertError(["images": [url]], .remoteURL(url))
        }
    }

    func testUnsafePathsAreRejected() {
        for path in ["/etc/cat.png", "../cat.png", "images/../../cat.png", "~/cat.png", ".hidden/cat.png", "images\\cat.png"] {
            assertError(["images": [path]], files: [path: 10], .unsafePath(path))
        }
    }

    func testImageTypesAndSizes() {
        assertError(["images": ["cat.svg"]], files: ["cat.svg": 10], .unsupportedImageType("cat.svg"))
        assertError(["images": ["cat.png"]], .missingImage("cat.png"))
        let big = CatPackRules.maxImageBytes + 1
        assertError(["images": ["cat.png"]], files: ["cat.png": big], .imageTooLarge("cat.png", bytes: big))
        XCTAssertNoThrow(try validate(["images": ["CAT.JPEG"]], files: ["CAT.JPEG": 10]))
    }

    func testTotalPackSize() {
        let names = (0..<7).map { "c\($0).png" }
        var files: [String: Int] = [:]
        for name in names { files[name] = CatPackRules.maxImageBytes }
        XCTAssertThrowsError(try validate(["images": names], files: files)) { error in
            guard case .packTooLarge? = error as? CatPackError else { return XCTFail("unexpected \(error)") }
        }
    }

    func testEveryErrorHasAMessage() {
        let errors: [CatPackError] = [
            .missingManifest, .manifestTooLarge(bytes: 1), .invalidJSON("x"), .unsupportedSchemaVersion(9),
            .invalidField("a", reason: "b"), .unsupportedLicense("MIT"), .tooMany("a", count: 2, limit: 1),
            .remoteURL("u"), .unsafePath("p"), .unsupportedImageType("i"), .missingImage("m"),
            .imageTooLarge("i", bytes: 1), .packTooLarge(bytes: 1),
        ]
        for error in errors { XCTAssertFalse(error.message.isEmpty) }
    }

    // MARK: - Loader (real files)

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("catpack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testLoaderReadsFolder() throws {
        let folder = try makeFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: folder.appendingPathComponent("images/a.png"))
        try manifest(["images": ["images/a.png"]]).write(to: folder.appendingPathComponent("pack.json"))
        let pack = try CatPackLoader.load(folder: folder)
        XCTAssertEqual(pack.images, ["images/a.png"])
    }

    func testLoaderWithoutManifest() throws {
        let folder = try makeFolder()
        XCTAssertThrowsError(try CatPackLoader.load(folder: folder)) { error in
            XCTAssertEqual(error as? CatPackError, .missingManifest)
        }
    }

    func testLoaderRejectsSymlinkOutsideThePack() throws {
        let folder = try makeFolder()
        let outside = try makeFolder()
        try Data([1, 2, 3]).write(to: outside.appendingPathComponent("secret.png"))
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("link.png"),
            withDestinationURL: outside.appendingPathComponent("secret.png")
        )
        try manifest(["images": ["link.png"]]).write(to: folder.appendingPathComponent("pack.json"))
        XCTAssertThrowsError(try CatPackLoader.load(folder: folder)) { error in
            XCTAssertEqual(error as? CatPackError, .missingImage("link.png"))
        }
    }

    /// Every pack shipped in the repo (packs/<name>/) must validate: this is the CI
    /// check for community packs submitted by pull request.
    func testRepositoryPacksAreValid() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packs = root.appendingPathComponent("packs")
        let folders = try FileManager.default.contentsOfDirectory(
            at: packs,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        XCTAssertFalse(folders.isEmpty, "packs/ should contain at least the example pack")
        for folder in folders {
            do {
                let pack = try CatPackLoader.load(folder: folder)
                XCTAssertEqual(pack.id, folder.lastPathComponent, "the folder name must match the pack id")
            } catch let error as CatPackError {
                XCTFail("\(folder.lastPathComponent): \(error.message)")
            }
        }
    }
}
