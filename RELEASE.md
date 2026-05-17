# Claud-y v4.0 Release Instructions (DMG)

This file is your **dumb-proof checklist** for cutting a v4.0 DMG release for the GitHub release page. You have a paid Apple Developer account, so we use proper Developer-ID signing + notarisation. The result is a DMG that opens cleanly on any Mac with no Gatekeeper warnings.

**Total time:** about 25–35 minutes (most of it waiting for the notarisation server).

---

## Prerequisites — verify these BEFORE you start

Run these commands. Each should print something useful:

```bash
xcodebuild -version              # Xcode 15+ installed
xcrun notarytool --help          # notarytool available
security find-identity -v -p codesigning | grep "Developer ID Application"
                                 # → should show your "Developer ID Application: Your Name (TEAMID)" cert
hdiutil --help                   # built-in macOS, should be there
```

If `find-identity` shows nothing, your Developer ID certificate is missing. Open Xcode → Settings → Accounts → your Apple ID → "Manage Certificates" → "+" → "Developer ID Application". Then re-run.

You'll also need an **app-specific password** for `notarytool`:
1. Go to https://appleid.apple.com → Sign In → "App-Specific Passwords"
2. Create one named e.g. `notarytool-claudy`
3. Save it — you'll paste it once below.

---

## Step 1 — Bump the version (~30 s)

Open `Claudy/Claudy.xcodeproj` in Xcode. In the project settings:
- **Marketing Version**: `4.0` (or whatever the public version is)
- **Current Project Version**: bump by 1 from the previous build (e.g. 4 → 5)

Save. Close Xcode (or leave it; doesn't matter).

---

## Step 2 — Archive the app (~3–5 min)

From the project root:

```bash
cd "/Users/eali/Documents/App Dev/Apps/Claud-y"

# Clean the derived-data + build folders for a fresh archive
rm -rf build
mkdir -p build

# Archive — produces Claudy.xcarchive
xcodebuild \
  -project Claudy/Claudy.xcodeproj \
  -scheme Claudy \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath build/Claudy.xcarchive \
  archive
```

**If this fails:** open Xcode, build with ⌘B in Release config, fix any errors, then re-run the archive command.

---

## Step 3 — Export the signed `.app` (~1 min)

Create `build/ExportOptions.plist`:

```bash
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
EOF
```

Then export:

```bash
xcodebuild -exportArchive \
  -archivePath build/Claudy.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath build/export
```

Your signed app lives at `build/export/Claudy.app`. Quick sanity check:

```bash
codesign -dvvv build/export/Claudy.app 2>&1 | grep "Authority"
# Should show: Authority=Developer ID Application: Your Name (TEAMID)
```

---

## Step 4 — Notarise (~5–15 min, mostly waiting)

Submit to Apple's notarisation service. You only need to enter the password the first time — `--keychain-profile` saves it for future runs.

**First time only — store credentials in Keychain:**
```bash
xcrun notarytool store-credentials "claudy-notary" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "your-app-specific-password"
```
(Find your Team ID at https://developer.apple.com/account/#MembershipDetailsCard.)

**Every time — zip the app, submit, wait:**
```bash
# Zip the .app for upload
ditto -c -k --keepParent build/export/Claudy.app build/Claudy.zip

# Submit and wait synchronously
xcrun notarytool submit build/Claudy.zip \
  --keychain-profile "claudy-notary" \
  --wait
```

Output ends with `status: Accepted`. If it says `Invalid`, run:
```bash
xcrun notarytool log <submission-uuid-from-output> --keychain-profile "claudy-notary"
```
to see the issues.

**Staple the notarisation ticket onto the .app:**
```bash
xcrun stapler staple build/export/Claudy.app
```

Should print `The staple and validate action worked!`.

---

## Step 5 — Build the DMG (~30 s)

```bash
# Make a temp staging folder
rm -rf build/dmg-staging
mkdir build/dmg-staging
cp -R build/export/Claudy.app build/dmg-staging/

# Add a symlink to /Applications so users can drag-drop to install
ln -s /Applications build/dmg-staging/Applications

# Create the DMG
hdiutil create \
  -volname "Claud-y v4.0" \
  -srcfolder build/dmg-staging \
  -ov \
  -format UDZO \
  build/Claud-y-v4.0.dmg
```

The DMG appears at `build/Claud-y-v4.0.dmg`. About 90–110 MB.

---

## Step 6 — Notarise + staple the DMG itself (~5 min)

The DMG also gets notarised so Gatekeeper trusts the **download**, not just the unzipped app.

```bash
xcrun notarytool submit build/Claud-y-v4.0.dmg \
  --keychain-profile "claudy-notary" \
  --wait

xcrun stapler staple build/Claud-y-v4.0.dmg
```

Both should succeed.

---

## Step 7 — Verify Gatekeeper acceptance (~10 s)

```bash
spctl -a -t open --context context:primary-signature -vv build/Claud-y-v4.0.dmg
# Expected: source=Notarized Developer ID
```

If you see `source=Notarized Developer ID`, you're done. The DMG will open without warnings on any Mac.

---

## Step 8 — Upload to GitHub Releases

1. Go to https://github.com/<your-org>/Claud-y/releases/new
2. Tag: `v4.0.0` (matches the marketing version)
3. Title: `Claud-y v4.0 — 3D, voice mode, accessories`
4. Description: paste the V4 section of `CHANGELOG.md`
5. Drag `build/Claud-y-v4.0.dmg` into the assets uploader
6. Tick "Set as the latest release"
7. Publish

Done.

---

## Common problems

| Problem | Fix |
|---|---|
| `archive failed: signing required` | In Xcode → target → Signing & Capabilities → tick "Automatically manage signing", select your team. |
| `notarytool: Invalid status` | Run `xcrun notarytool log <uuid>` to see what failed. Usually a missing entitlement or unsigned binary inside the app bundle. |
| `staple failed: 65` | Notarisation hasn't finished yet. Wait a minute and re-run staple. |
| `spctl: rejected` | App or DMG isn't notarised. Repeat steps 4 or 6. |
| DMG opens but app shows "damaged" | The DMG wasn't notarised. Repeat step 6. |
| App launches but immediately quits | Check Console.app for crash report. Usually a missing framework signature in a dependency. |

---

## What gets included in the DMG (for the GitHub release upload)

Only the official files. The user has explicitly said NOT to include:
- `.planning/` development memory
- `Memory/`, `archives/` agent traces
- Local DMGs from previous releases (`Claudy-v*.zip`, `Claudy-v*.dmg`)
- Anything else not part of the public source

If unsure what to commit, run `git status` and add files individually rather than `git add .`.
