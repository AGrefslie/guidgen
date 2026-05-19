# Homebrew Cask submission

`guidgen.rb` is ready to submit to [homebrew-cask](https://github.com/Homebrew/homebrew-cask).

## Test locally first

```bash
# Audit
brew audit --new --cask scripts/homebrew/guidgen.rb

# Style-check
brew style --fix scripts/homebrew/guidgen.rb

# Install from the local file (verifies download + signature)
brew install --cask --no-quarantine scripts/homebrew/guidgen.rb

# Uninstall to clean up
brew uninstall --cask guidgen
brew uninstall --zap --cask guidgen   # also wipes prefs
```

## Submit the PR

```bash
# Fork + clone homebrew-cask
gh repo fork Homebrew/homebrew-cask --clone
cd homebrew-cask

# Copy the cask into the correct alphabetical bucket
cp /path/to/guidgen/scripts/homebrew/guidgen.rb Casks/g/

git checkout -b add-guidgen
git add Casks/g/guidgen.rb
git commit -m "Add guidgen 1.0"
git push origin add-guidgen

gh pr create --base master --title "Add guidgen 1.0" --body "Menu bar GUID/UUID generator with global hotkey and history. Notarized Developer ID build. Upstream: https://github.com/AGrefslie/guidgen"
```

The Homebrew bot will run `brew test-bot` against the PR. Fix any audit failures, push fixes. Expect 1–3 days for human review + merge.

## After merge

Users install with:
```bash
brew install --cask guidgen
```

Future releases auto-pick-up via the `livecheck` block — Homebrew bots watch the GitHub Releases page and open a PR to bump the version + sha256 each time you ship a new tag.

## Important: deployment target

The current cask declares `depends_on macos: ">= :tahoe"` (macOS 26) because the project's `MACOSX_DEPLOYMENT_TARGET` is set to 26.0. That kills nearly all real-world reach — most macs are on Ventura/Sonoma/Sequoia.

**Before submitting the PR, lower the deployment target in `GuidGen.xcodeproj` to macOS 13 (Ventura) or 14 (Sonoma), rebuild, re-notarize, replace the release DMG, recompute the sha256 in `guidgen.rb`, and update `depends_on macos:` to `">= :ventura"` (or `">= :sonoma"`).**

`MenuBarExtra` requires macOS 13+. `.icon` Icon Composer bundles can target older OSes via fallback `.icns` if needed.
