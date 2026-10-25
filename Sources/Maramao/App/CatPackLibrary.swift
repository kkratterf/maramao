import SwiftUI
import AppKit
import os
import MaramaoCore

/// Everything the enabled packs add, merged. Read by break modes at any time, so it
/// lives in a lock-protected box instead of on the main actor.
struct CatPackContent {
    var palettes: [CatPalette] = []
    var catNames: [String] = []
    var captions: [MemeWallCaption] = []
    var imageURLs: [URL] = []
    var shortTips: [String] = []
    var longTips: [String] = []
    /// Bumped on every reload, so caches (e.g. the tip picker) know to rebuild.
    var generation = 0
}

/// Thread-safe holder of the current `CatPackContent`.
final class CatPackRuntime {
    static let shared = CatPackRuntime()

    private let lock = NSLock()
    private var stored = CatPackContent()

    var content: CatPackContent {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }
}

/// One folder found in the packs directory: a valid pack or the reason it was skipped.
struct CatPackEntry: Identifiable {
    let folder: URL
    let pack: CatPack?
    let error: String?

    var id: String { folder.lastPathComponent }
    var displayName: String { pack?.name ?? folder.lastPathComponent }
}

/// Finds, validates and merges the packs in ~/Library/Application Support/Maramao/Cats.
/// A bad pack is logged, skipped and listed with its error; it never stops a break.
@MainActor
final class CatPackLibrary: ObservableObject {
    static let shared = CatPackLibrary()

    @Published private(set) var entries: [CatPackEntry] = []
    @Published private(set) var disabledIDs: Set<String>

    private let defaults: UserDefaults
    private static let disabledKey = "catPacksDisabled"
    private static let maxPacks = 30
    private let log = Logger(subsystem: "com.kkratterf.maramao", category: "catpacks")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        disabledIDs = Set(defaults.stringArray(forKey: Self.disabledKey) ?? [])
    }

    /// ~/Library/Application Support/Maramao/Cats
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Maramao", isDirectory: true)
            .appendingPathComponent("Cats", isDirectory: true)
    }

    var validCount: Int { entries.filter { $0.pack != nil }.count }

    func isEnabled(_ entry: CatPackEntry) -> Bool {
        !disabledIDs.contains(entry.id)
    }

    func setEnabled(_ entry: CatPackEntry, _ enabled: Bool) {
        if enabled { disabledIDs.remove(entry.id) } else { disabledIDs.insert(entry.id) }
        defaults.set(Array(disabledIDs).sorted(), forKey: Self.disabledKey)
        publish()
    }

    /// Scans the folder again. Cheap: manifests are small and images are only
    /// checked for size here, decoded later when a break shows them.
    func reload() {
        let fm = FileManager.default
        let root = Self.folder
        var found: [CatPackEntry] = []
        let folders = (try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let directories = folders
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        for (index, folder) in directories.enumerated() {
            if index >= Self.maxPacks {
                found.append(CatPackEntry(folder: folder, pack: nil, error: "Troppi pacchetti: Maramao ne legge al massimo \(Self.maxPacks)."))
                continue
            }
            do {
                let pack = try CatPackLoader.load(folder: folder)
                found.append(CatPackEntry(folder: folder, pack: pack, error: nil))
            } catch let error as CatPackError {
                log.error("Skipping cat pack \(folder.lastPathComponent, privacy: .public): \(error.message, privacy: .public)")
                found.append(CatPackEntry(folder: folder, pack: nil, error: error.message))
            } catch {
                log.error("Skipping cat pack \(folder.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                found.append(CatPackEntry(folder: folder, pack: nil, error: error.localizedDescription))
            }
        }
        entries = found
        publish()
    }

    /// Opens the packs folder in Finder, creating it first.
    func openFolder() {
        let root = Self.folder
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        NSWorkspace.shared.open(root)
    }

    /// Merges the enabled packs into `CatPackRuntime`.
    private func publish() {
        var content = CatPackContent()
        var seenIDs = Set<String>()
        for entry in entries {
            guard let pack = entry.pack, isEnabled(entry), !seenIDs.contains(pack.id) else { continue }
            seenIDs.insert(pack.id)
            content.palettes += pack.palettes.map(CatPalette.init(pack:))
            content.catNames += pack.catNames
            content.captions += pack.captions.map { MemeWallCaption(top: $0.top, bottom: $0.bottom) }
            content.imageURLs += pack.images.map { CatPackLoader.imageURL(folder: entry.folder, path: $0) }
            content.shortTips += pack.shortTips
            content.longTips += pack.longTips
        }
        content.generation = CatPackRuntime.shared.content.generation + 1
        CatPackRuntime.shared.content = content
    }
}

extension CatPalette {
    /// A `CatView` palette from a pack palette. Missing stripes mean a plain coat.
    init(pack: CatPackPalette) {
        func color(_ c: CatPackColor) -> Color { Color(red: c.red, green: c.green, blue: c.blue) }
        self.init(
            fur: color(pack.fur),
            stripes: pack.stripes.map(color),
            belly: color(pack.belly),
            eyes: color(pack.eyes)
        )
        if let nose = pack.nose { self.nose = color(nose) }
    }
}

/// Settings section "Pacchetti di gatti".
struct CatPacksSettingsSection: View {
    @ObservedObject private var library = CatPackLibrary.shared

    var body: some View {
        Section("Pacchetti di gatti") {
            if library.entries.isEmpty {
                Text("Nessun pacchetto installato. Metti una cartella con un file pack.json in Maramao/Cats e premi Ricarica.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(library.entries) { entry in
                if let pack = entry.pack {
                    Toggle(isOn: binding(for: entry)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name)
                            Text(summary(pack))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("⚠️ \(entry.displayName)")
                        Text(entry.error ?? "Pacchetto non valido.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack {
                Button("Apri cartella") { library.openFolder() }
                Button("Ricarica") { library.reload() }
                Spacer()
            }
            Text("Un pacchetto aggiunge colori per i gatti, nomi, meme e consigli per le pause. Solo licenze CC0 o CC-BY, niente link dal web.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func binding(for entry: CatPackEntry) -> Binding<Bool> {
        Binding<Bool>(
            get: { library.isEnabled(entry) },
            set: { library.setEnabled(entry, $0) }
        )
    }

    private func summary(_ pack: CatPack) -> String {
        var parts: [String] = []
        if !pack.author.isEmpty { parts.append("di \(pack.author)") }
        parts.append(pack.license)
        if !pack.palettes.isEmpty { parts.append("\(pack.palettes.count) gatti") }
        if !pack.captions.isEmpty { parts.append("\(pack.captions.count) meme") }
        if !pack.images.isEmpty { parts.append("\(pack.images.count) immagini") }
        let tips = pack.shortTips.count + pack.longTips.count
        if tips > 0 { parts.append("\(tips) consigli") }
        if !pack.catNames.isEmpty { parts.append("nomi: \(pack.catNames.prefix(3).joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}
