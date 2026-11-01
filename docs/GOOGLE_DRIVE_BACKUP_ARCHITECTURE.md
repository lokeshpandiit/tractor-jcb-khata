# LxH ONE — Google Drive Backup Architecture

Status: planning groundwork only. No application behavior has been changed yet.

## Goals

- Google sign-in identifies the account that owns a backup.
- Each Google account has an independent backup namespace.
- Backups are ordinary, user-visible JSON files/folders in that account's Google Drive.
- A second device signed into the same Google account can discover and restore that account's backup.
- Preserve all existing app behavior and the existing SharedPreferences keys.

## Existing local data contract

The current app persists these JSON arrays in SharedPreferences:

| Key | Model |
| --- | --- |
| `vehicles_data` | Vehicle |
| `workers_data` | Person (Worker) |
| `clients_data` | Person (Client) |
| `logs_data` | WorkLog |
| `cash_data` | CashEntry |

A backup must contain all five arrays, including empty arrays. Restore must validate the complete payload before changing any local key. A failed/partial restore must leave current local data untouched.

## Drive layout

Use a user-visible folder in the signed-in user's Drive:

```
LxH ONE Backups/
  <stable-account-subject-or-account-hash>/
    backup-YYYY-MM-DDTHH-mm-ssZ.json
    latest.json
```

The account folder identifier is derived from the authenticated Google account subject on the trusted server, not from a user-editable display name. Do not store one account's backup under another account's folder. JSON includes schemaVersion, account subject, createdAt UTC, app version, and all five data arrays.

Use the least-privilege Google Drive `drive.file` scope for files created/opened by this app. Do not request full Drive access unless product requirements change.

## Required security model for dependable daily backup

The OAuth Web Client secret must never be embedded in Flutter/Dart code, the APK, Git history, or public GitHub Actions logs.

For dependable daily backups when the app is closed, use a small trusted backend:
1. Flutter signs the user in and obtains a one-time server authorization code.
2. Backend exchanges that code using the Web Client ID/secret.
3. Backend stores refresh credentials encrypted at rest, keyed by the immutable Google account subject.
4. Backend refreshes access tokens and uploads a timestamped JSON file to that same user's Drive.
5. A daily scheduled job processes only accounts that opted in and have valid authorization.
6. The app can also request an immediate backup and list/restore files for the currently authenticated account.

The app must provide clear consent, last-backup status, manual backup, restore selection, and sign-out. Sign-out must not delete Drive backups.

## Why app-only background scheduling is not the chosen design

A mobile periodic worker cannot reliably show an interactive Google consent screen while the app is closed. Access tokens expire, and a background worker must not assume a cached token remains valid indefinitely. A backend with securely stored refresh credentials is required for reliable daily upload while the phone/app is offline or closed.

## Current repository findings

- Android applicationId: `com.example.tractor_jcb_khata`.
- Current GitHub workflow deletes and recreates `android/` on every build. This can discard committed Android configuration and must be reconciled before OAuth integration.
- Current repository has no backend deployment, Firebase configuration, or server source.
- Current workflow builds an APK with the debug signing configuration. A stable release signing key is needed before registering a production Android OAuth client SHA-1.

## Remaining setup prerequisites

1. Choose/provision the backend host and project (for example, Firebase/Cloud Functions or Cloud Run).
2. Enable Google Drive API in the same Google Cloud project as OAuth.
3. Configure the OAuth consent screen and add test users while the app is in testing.
4. Register Android OAuth client using package name above and the SHA-1 of the stable signing certificate.
5. Keep the Web Client secret only in the backend secret manager. The GitHub Actions secrets currently created are not a backend and do not make the app deploy a server.
6. Decide the stable release signing approach and store signing material as protected GitHub secrets.

## Safety requirements for implementation

- Never replace local data automatically just because a backup exists.
- Show which Google account is active before backup/restore.
- Restore only after explicit user confirmation and successful validation.
- Keep a pre-restore local snapshot so restore can be rolled back.
- Treat account mismatch, malformed JSON, unsupported schema versions, expired credentials, quota errors, and network errors as recoverable errors.
- Keep local app usable when Google sign-in or Drive is unavailable.
- Do not change the existing five storage keys or current fleet/khata workflows.
