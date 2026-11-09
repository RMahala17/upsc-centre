# Stage 8: Backup UI, CSV export, PWA polish, deploy, test checklist

Plus: an appearance button (Light / System / Dark).

## Not run here
No Flutter SDK in the build sandbox. `flutter analyze` and `flutter test` were
**not** run. The Dart was checked by hand plus an import/bracket script. The web
files (`index.html`, `upsc_sw.js`, JS helpers) were tested in real headless Chromium:
download with Hindi text, file pick and cancel, theme-color meta, and offline reload
through the service worker. Run both commands first and send me any errors.

## Build command (important)
    flutter build web --release --no-web-resources-cdn --base-href "/"
See DEPLOY.md.

## What is new
**Appearance**: sun/moon button on Dashboard and More, and a selector on the Backup
& Settings screen. Choice saved in settings (`theme_mode`). A light theme was added.
The accent colours were chosen to pass contrast on both light and dark surfaces,
so the ~150 existing `AppColors.muted` uses keep working. Amber changed from
`FBBF24` to `D97706` in 8 files because the old one was unreadable on white.

**Backup & Settings** (`/backup`): download or copy a backup, restore from file or
pasted text with a preview, a safety snapshot taken *before* a restore plus
"Go back to that data", persistent-storage request, install button, CSV exports.
`BackupService.restore()` now saves the safety snapshot first.
After restore, all providers reload (`reload_all.dart`).

**CSV**: sessions, tasks, lectures, revision, tests, answers, PYQs, notes.
UTF-8 BOM (Hindi in Excel), CRLF, quoting, formula-injection guard.

**PWA**: icons (192/512 + maskable), manifest, splash, theme-color, iOS tags,
network-first offline service worker (`upsc_sw.js`), custom `flutter_bootstrap.js`.
`main.dart` asks the browser for persistent storage.

**Deploy**: GitHub Pages workflow, `firebase.json`, `netlify.toml`, `web/_headers`.

## Files
Everything in this zip is new or changed in Stage 8. Copy over your project.
Amber-colour edits to existing screens are small one-line changes.

## Known limits
* iPhone Safari cannot show an install button; use Share -> Add to Home Screen.
* Data is per browser and per site address. Backups are the only sync.
* Browser storage cannot be guaranteed; weekly backups are the safety net.
