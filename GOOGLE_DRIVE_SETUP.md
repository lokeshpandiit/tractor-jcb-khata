# LxH ONE Google Drive Backup Setup

The v3 app supports Google account sign-in, account-isolated local data, visible JSON backups in a Drive folder named **LxH ONE Backup**, automatic restore, and a daily Android background backup attempt.

Google OAuth credentials must be configured before Google sign-in and Drive access can work.

## 1. Create Google Cloud credentials

1. Open Google Cloud Console and create or select a project.
2. Enable **Google Drive API**.
3. Configure the OAuth consent screen. While the app is in testing, add each Google account that will use the app as a test user.
4. Create an **Android OAuth client**:
   - Package name: com.example.tractor_jcb_khata
   - SHA-1: the SHA-1 fingerprint of the stable keystore used to sign the APK (see below).
5. Create a **Web application OAuth client**. Copy its Client ID; this becomes GOOGLE_SERVER_CLIENT_ID.

Google Sign-In on Android checks the package name and signing-certificate SHA-1. The Web client ID is passed to the app as serverClientId so it can request Drive access.

## 2. Create a stable signing keystore (Windows)

Run these commands in PowerShell from a safe folder. Keep this file private and keep a secure backup. The same keystore must be used for future app updates.

    keytool -genkeypair -v -keystore lxh-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lxh-upload
    keytool -list -v -keystore lxh-upload-key.jks -alias lxh-upload
    $bytes = [System.IO.File]::ReadAllBytes("$PWD\lxh-upload-key.jks")
    [Convert]::ToBase64String($bytes) | Set-Clipboard

Copy the SHA-1 fingerprint printed by the second command into the Android OAuth client.

## 3. Add GitHub Actions secrets

In the repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name | Value |
|---|---|
| GOOGLE_SERVER_CLIENT_ID | Web application OAuth Client ID from Google Cloud |
| ANDROID_KEYSTORE_BASE64 | Base64 copied to clipboard in step 2 |
| ANDROID_KEYSTORE_PASSWORD | Password chosen for the keystore |
| ANDROID_KEY_ALIAS | lxh-upload |
| ANDROID_KEY_PASSWORD | Key password chosen in step 2 |

The v3 build workflow uses the stable keystore when these signing secrets are present. Without them, it falls back to a debug signing key; that fallback is for build testing, not a stable Google OAuth identity.

## 4. Build and test

Push a commit to v3 or run the Build APK workflow. Download the LxH-ONE-APK artifact from the successful GitHub Actions run.

Install the APK, sign in with Google, and approve the Drive permission. The app creates **LxH ONE Backup** in that account's Drive. Each day it creates or refreshes that day's JSON file. The app also attempts a Drive backup after saved changes.

## Backup timing and safety

Android WorkManager schedules a 24-hour periodic task, but Android battery and network management may delay the exact run time. It is not an exact clock-time alarm. The app also performs an immediate Drive backup after saved changes while it is open.

Each Google account has a separate local data namespace and its own Google Drive. If Drive restore fails, the app stays at the sign-in screen instead of loading/editing partial data. The scheduled worker retries a pending restore before uploading anything.

SMS opens the phone's current default SMS app; the app does not send SMS automatically. WhatsApp itself determines whether a number is registered. The app can normalize the phone number, but cannot query WhatsApp's registration database.
