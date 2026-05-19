cask "guidgen" do
  version "1.0.1"
  sha256 "4330451fcfa2d6bc50fabd0f5f4188256beb5f175e4eb3bd7a6d08dc7e0cdd5c"

  url "https://github.com/AGrefslie/guidgen/releases/download/v#{version}/GuidGen-#{version}.dmg",
      verified: "github.com/AGrefslie/guidgen/"
  name "GuidGen"
  desc "Menu bar GUID/UUID generator with global hotkey and history"
  homepage "https://github.com/AGrefslie/guidgen"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "GuidGen.app"

  zap trash: [
    "~/Library/Preferences/axelgrefslie.GuidGen.plist",
    "~/Library/Saved Application State/axelgrefslie.GuidGen.savedState",
    "~/Library/Caches/axelgrefslie.GuidGen",
  ]
end
