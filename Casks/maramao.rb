# Homebrew tap hosted in the Maramao repo itself:
#   brew tap kkratterf/maramao https://github.com/kkratterf/maramao
#   brew install --cask maramao
# version and sha256 are bumped by .github/workflows/release.yml after each
# stable release; sha256 stays :no_check until the first release with a DMG.
cask "maramao" do
  version "0.8.0"
  sha256 "b0a01ef9cfa266b95b075cfadbc0f00d7491a03e330357a3d9b46d4196f87251"

  url "https://github.com/kkratterf/maramao/releases/download/v#{version}/Maramao-#{version}.dmg"
  name "Maramao"
  desc "Pomodoro timer for the menu bar that stops you with cats"
  homepage "https://maramao.kkratter.com/"

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
end
