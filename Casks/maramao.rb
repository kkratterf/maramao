# Homebrew tap hosted in the Maramao repo itself:
#   brew tap kkratterf/maramao https://github.com/kkratterf/maramao
#   brew install --cask maramao
# version and sha256 are bumped by .github/workflows/release.yml after each
# stable release; sha256 stays :no_check until the first release with a DMG.
cask "maramao" do
  version "0.3.2"
  sha256 "fad34fa378b11c78aed9c556f6a4bec0ee9f7df59a75e530d89732f9dc30efac"

  url "https://github.com/kkratterf/maramao/releases/download/v#{version}/Maramao-#{version}.dmg"
  name "Maramao"
  desc "Pomodoro timer for the menu bar that stops you with cats"
  homepage "https://kkratterf.github.io/maramao/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :ventura

  app "Maramao.app"

  uninstall quit: "com.kkratterf.maramao"

  zap trash: [
    "~/Library/Caches/com.kkratterf.maramao",
    "~/Library/HTTPStorages/com.kkratterf.maramao",
    "~/Library/Preferences/com.kkratterf.maramao.plist",
    "~/Library/Saved Application State/com.kkratterf.maramao.savedState",
  ]

  caveats <<~EOS
    Maramao is not notarized by Apple yet, so macOS may block the first launch.
    Open it once, then click Open Anyway in System Settings > Privacy & Security,
    or run:
      xattr -dr com.apple.quarantine #{appdir}/Maramao.app
  EOS
end
