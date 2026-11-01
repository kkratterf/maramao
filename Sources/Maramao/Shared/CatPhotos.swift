import AppKit

/// The cat photos bundled in `Maramao.app/Contents/Resources/CatPhotos`: CC0 photos from
/// the WordPress Photo Directory, listed in `Resources/cat-photos.tsv` and fetched,
/// resized and copied into the app by `scripts/build-app.sh`.
///
/// A plain `swift build` has no app bundle and no photos: callers get `nil` and fall back
/// to a simple emoji scene.
@MainActor
final class CatPhotos {
    enum Kind: String {
        case sleeping
        case angry
    }

    static let shared = CatPhotos()

    private var urls: [Kind: [URL]] = [:]
    /// Photos not shown yet in the current round, per kind, so every photo comes up once
    /// before any repeats.
    private var bags: [Kind: [URL]] = [:]
    private var last: [Kind: URL] = [:]

    private init() {
        let root = Bundle.main.resourceURL?.appendingPathComponent("CatPhotos", isDirectory: true)
        for kind in [Kind.sleeping, .angry] {
            guard let folder = root?.appendingPathComponent(kind.rawValue, isDirectory: true),
                  let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            else { continue }
            urls[kind] = files.filter { ["jpg", "jpeg", "heic"].contains($0.pathExtension.lowercased()) }
        }
    }

    func hasPhotos(_ kind: Kind) -> Bool {
        !(urls[kind] ?? []).isEmpty
    }

    /// A photo of this kind, different from the previous one whenever there are two or more.
    func next(_ kind: Kind) -> NSImage? {
        let all = urls[kind] ?? []
        guard !all.isEmpty else { return nil }
        var bag = bags[kind] ?? []
        if bag.isEmpty {
            bag = all.shuffled()
            // A new round must not start with the photo that ended the last one.
            if bag.count > 1, bag.last == last[kind] {
                bag.swapAt(0, bag.count - 1)
            }
        }
        let url = bag.removeLast()
        bags[kind] = bag
        last[kind] = url
        return NSImage(contentsOf: url)
    }
}
