import Foundation

/// Decides whether the Sparkle updater may run, from the values in the app's
/// Info.plist. The updater stays hidden until the maintainer replaces the
/// placeholder public key with a real one, so a build without signing keys
/// never shows an update UI that could not verify anything.
public enum UpdaterConfiguration {
    /// The value `SUPublicEDKey` holds in `Resources/Info.plist` until a real key is set.
    public static let placeholderPublicKey = "SPARKLE_PUBLIC_ED_KEY_PLACEHOLDER"

    /// Length in bytes of an Ed25519 public key.
    static let ed25519KeyLength = 32

    /// True when `key` looks like a real Sparkle EdDSA public key: base64 of
    /// exactly 32 bytes, and not the placeholder.
    public static func isRealPublicKey(_ key: String?) -> Bool {
        guard let key = key?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty,
              key != placeholderPublicKey,
              let data = Data(base64Encoded: key)
        else { return false }
        return data.count == ed25519KeyLength
    }

    /// True when `url` is an https URL with a host, as Sparkle requires for the feed.
    public static func isValidFeedURL(_ url: String?) -> Bool {
        guard let url = url,
              let components = URLComponents(string: url),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty
        else { return false }
        return true
    }

    /// True when the updater should start: real public key, valid feed URL,
    /// and the app runs from a `.app` bundle (not `swift run`, which has
    /// nothing Sparkle could replace).
    public static func isEnabled(publicKey: String?, feedURL: String?, bundlePath: String) -> Bool {
        let path = bundlePath.hasSuffix("/") ? String(bundlePath.dropLast()) : bundlePath
        return isRealPublicKey(publicKey)
            && isValidFeedURL(feedURL)
            && path.lowercased().hasSuffix(".app")
    }
}
