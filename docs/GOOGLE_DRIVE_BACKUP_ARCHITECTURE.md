# LxH ONE — Google Drive Backup

## User-visible Drive layout

The app stores JSON backups in the signed-in Google account's ordinary Drive folder:

```
My Drive/
  LxH ONE Backups/
    LxH_ONE_Backup_YYYY-MM-DD.json
```

Each Google account has its own Drive, so different accounts naturally keep separate backups. A second device signed into the same Google account can list and restore backups from this folder. A same-day backup updates that day's file instead of creating duplicate files.

## App behavior

- Uses Google Sign-In and the least-privilege `drive.file` scope.
- Manual Backup to Google Drive uploads the current complete JSON snapshot.
- Restore from Google Drive lists dated JSON files from the same folder and requires explicit user confirmation before replacing local data.
- Daily backup runs the next time the app is opened when a Google account is already connected. If not connected, the app asks the user to connect and back up.
- Daily filename is `LxH_ONE_Backup_YYYY-MM-DD.json`.
- The app remains usable offline; Drive actions require internet.

## Important limitation

A Flutter app cannot guarantee a daily upload while the app is closed or the phone is offline. The current app-side daily backup runs on app launch. True scheduled uploads while the app is closed require a deployed trusted backend with encrypted refresh-token storage and a scheduled job. No OAuth client secret is embedded in the APK.

## Google Cloud configuration

- Project: `LxH ONE`.
- Drive API must be enabled.
- OAuth consent screen: External, app name `LxH ONE`.
- Android package: `com.example.tractor_jcb_khata`.
- Web OAuth client ID is used as `serverClientId` in Flutter. Its secret must never be embedded in the app.
- The Android OAuth client SHA-1 must match the certificate that signs the installed APK. If the build signing certificate changes, update the Android OAuth client fingerprint or use a stable signing key.
