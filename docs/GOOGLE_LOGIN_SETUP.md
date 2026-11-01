# LxH ONE V3 Google Login and Drive Backup Setup

This branch uses the Flutter `google_sign_in` plugin and the Google Drive API.
It does not use Firebase Authentication.

## Fixed Android application identity

- Android package / applicationId: `com.example.tractor_jcb_khata`
- Release keystore alias: `lxh-one-release`
- Release certificate SHA-1: `56:E8:67:6F:37:48:38:4D:EC:09:3F:FF:1B:1A:B4:CD:C8:C4:26:0C`
- Requested Drive scope: `https://www.googleapis.com/auth/drive.file`
- Drive folder created by the app: `LxH ONE Backup`

## Google Cloud Console

1. Open https://console.cloud.google.com/ and select or create a Google Cloud project.
2. In APIs & Services > Library, enable **Google Drive API**.
3. Open Google Auth Platform > Branding. Set the app name to **LxH ONE**, choose a support email, and complete the contact details.
4. Open Google Auth Platform > Audience. While testing, choose External (if this is a personal app) and add the Google accounts that will test the app under Test users.
5. In Google Auth Platform > Data Access, ensure the app is allowed to request the Drive scope:
   `https://www.googleapis.com/auth/drive.file`.
6. In Google Auth Platform > Clients, create an OAuth client of type **Android**:
   - Package name: `com.example.tractor_jcb_khata`
   - SHA-1: `56:E8:67:6F:37:48:38:4D:EC:09:3F:FF:1B:1A:B4:CD:C8:C4:26:0C`
7. Create a second OAuth client of type **Web application**. Copy its Client ID (it ends with `.apps.googleusercontent.com`). This Web Client ID is the `serverClientId` used by the Android Google Sign-In plugin. No client secret is needed by this mobile app.

## GitHub Actions secrets

Open the repository:

Settings > Secrets and variables > Actions > New repository secret

Add these five secrets exactly:

| Secret name | Value |
|---|---|
| `GOOGLE_SERVER_CLIENT_ID` | The Web application Client ID from Google Cloud |
| `ANDROID_KEYSTORE_BASE64` | Entire one-line contents of the supplied `ANDROID_KEYSTORE_BASE64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | The private keystore password supplied separately |
| `ANDROID_KEY_ALIAS` | `lxh-one-release` |
| `ANDROID_KEY_PASSWORD` | The private key password supplied separately (same as the keystore password for this key) |

Never put the keystore, password, or Base64 value in a public repository, source file, issue, or workflow log. Keep an offline copy of the JKS in a safe place: losing this key prevents future APK updates under the same Android app identity.

## Build

After all five secrets are added, open Actions > Build APK > Run workflow and select branch `v3`, or push a new commit to `v3`.

The workflow now fails fast if any required secret is missing. It will not upload an APK with an empty Google Server Client ID or an unstable debug signing certificate.

## Important installation note

The already-generated V3 APKs were signed with a temporary Android Debug certificate. The new V3 release will be signed with the permanent LxH ONE key above. Android will not install it as an in-place update over a differently signed APK. Before replacing an installed debug-signed APK, export or otherwise safely preserve its local app data. Do not uninstall an app with data you need to keep until a verified backup/export is available.

## Encrypted Drive backup password

LxH ONE encrypts every new backup on the device before uploading it to Drive:

- AES-256-GCM authenticated encryption.
- PBKDF2-HMAC-SHA256 key derivation with a fresh random 16-byte salt for each backup.
- A new random AES-GCM nonce is generated for every encryption.
- The backup password is stored only in the device's secure storage. It is not uploaded to Drive or stored in SharedPreferences.
- The same backup password is required to restore that account's backup on another phone.
- Use at least 12 characters. A long, unique passphrase is recommended.
- If the password is forgotten, encrypted backups cannot be decrypted by LxH ONE or Google. Keep it in a trusted password manager or another safe place.

Existing unencrypted V3 backup files remain readable during the upgrade. Once the app has accepted or created the backup password, the next successful upload is encrypted. New uploads are encrypted by default.

On a new phone, sign in with the same Google account, then enter the Backup Password used on the first phone. If there is no previous backup for that account, create a new Backup Password and confirm it.

Do not share the Backup Password with anyone. Google account access and the backup password are two separate protections.

## Verification still required on a physical device

- Sign in using a Google account listed as a Test user.
- Confirm that the app creates the visible `LxH ONE Backup` folder and a dated JSON backup in Google Drive.
- Sign in with that same account on a second device and confirm that records restore.
- Confirm that a different Google account sees only its own data.
- Confirm that the daily WorkManager backup runs when the device is online and Android allows background work.
