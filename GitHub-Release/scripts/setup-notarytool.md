# Setting up notarytool (one-time)

You only need to do this once. It stores your Apple credentials securely in your Mac's Keychain so the build script can submit for notarization without you entering a password each time.

## What you'll need

- Your Apple Developer account email
- An **App Store Connect API key** (recommended over password — more secure, doesn't expire with 2FA prompts)

## Step 1 — Create an App Store Connect API Key

1. Go to [App Store Connect → Users & Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/api)
2. Click **+** to generate a new key
3. Give it a name like "Notarytool" and set role to **Developer**
4. Download the `.p8` file — **you can only download it once**
5. Note down:
   - **Key ID** (shown in the table, e.g. `ABCDEF1234`)
   - **Issuer ID** (shown at the top of the page, e.g. `12345678-1234-…`)

## Step 2 — Store credentials in Keychain

```bash
xcrun notarytool store-credentials "notarytool-profile" \
    --key ~/Downloads/AuthKey_ABCDEF1234.p8 \
    --key-id ABCDEF1234 \
    --issuer 12345678-1234-1234-1234-123456789012
```

Replace the values with yours. The profile name `notarytool-profile` matches what `build-dmg.sh` expects — change both if you prefer a different name.

## Step 3 — Build and notarize

```bash
cd GitHub-Release/scripts
chmod +x build-dmg.sh
./build-dmg.sh --team-id YOUR_TEAM_ID
```

Your Team ID is the 10-character string in your [Apple Developer account → Membership](https://developer.apple.com/account/#!/membership).

## What happens

1. Xcode archives a Release build
2. Exports a Developer ID–signed `.app`
3. Wraps it in a `.dmg` with an Applications symlink (standard drag-to-install)
4. Signs the DMG with your Developer ID certificate
5. Submits to Apple's notarization service (~2–5 minutes)
6. Staples the notarization ticket to the DMG

The result: `Claud-y.dmg` — double-clicking it on any Mac will work without Gatekeeper warnings.

## Upload to GitHub

1. Create a new Release on GitHub (tag it `v1.0.0`)
2. Drag `Claud-y.dmg` into the release assets
3. Write release notes (you can paste from `SPEC.md`)
4. Publish
