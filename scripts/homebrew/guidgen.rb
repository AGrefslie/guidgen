cask "guidgen" do
  version "1.0"
  sha256 "bdf7dfae9a808b2e14a5f51b056f6a8507f61791f23a38cb80101586d3cdcfe0"

  url "https://github.com/AGrefslie/guidgen/releases/download/v#{version}/GuidGen-#{version}.dmg",
      verified: "github.com/AGrefslie/guidgen/"
  name "GuidGen"
  desc "Menu bar GUID/UUID generator with global hotkey and history"
  homepage "https://github.com/AGrefslie/guidgen"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :tahoe"

  app "GuidGen.app"

  zap trash: [
    "~/Library/Preferences/axelgrefslie.GuidGen.plist",
    "~/Library/Saved Application State/axelgrefslie.GuidGen.savedState",
    "~/Library/Caches/axelgrefslie.GuidGen",
  ]
end
