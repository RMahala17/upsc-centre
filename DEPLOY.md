# Deploying UPSC Command Centre

The app is a static site. All data lives in the browser (IndexedDB), so there is
no server, no database and no account. Any static host works.

## 1. Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --base-href "/"
```

* `--no-web-resources-cdn` is important. Without it the Flutter engine is loaded
  from gstatic.com, which the offline service worker cannot cache, so the app
  would not open without internet.
* `--base-href` must match where the site lives: `"/"` for a root domain,
  `"/<repo-name>/"` for GitHub Pages project sites. It must start and end with `/`.
* The app uses `#/` URLs, so no rewrite rules are needed on any host.

Output is in `build/web`.

## 2. Pick a host (all free)

### GitHub Pages (workflow included)
1. Push the project to a GitHub repo, branch `main`.
2. Repo Settings -> Pages -> Source: **GitHub Actions**.
3. Push. `.github/workflows/deploy.yml` analyzes, tests, builds and publishes.
4. Site: `https://<user>.github.io/<repo>/`

### Netlify (easiest, no account setup beyond sign-up)
Build locally with `--base-href "/"`, then drag `build/web` onto
https://app.netlify.com/drop. `netlify.toml` and `web/_headers` set the cache rules.

### Cloudflare Pages
Create a project -> Direct Upload -> upload `build/web`. `_headers` is picked up.

### Firebase Hosting
```bash
npm i -g firebase-tools
firebase login
firebase init hosting   # public dir: build/web, single-page app: No
firebase deploy
```
`firebase.json` is already in the repo. If `init` offers to overwrite it, say no.

## 3. After the first deploy

1. Open the site once **with internet** and wait ~10 seconds so the offline cache fills.
2. Turn off Wi-Fi and reload. The app should still open.
3. On a phone: Chrome menu -> **Install app** / **Add to Home screen**.
   On iPhone: Safari -> Share -> **Add to Home Screen** (iOS cannot show an install button).
4. Open **More -> Backup & Settings** and tap **Request protection** so the browser
   is less likely to clear the data.

## 4. Updating the app

Deploy again. Users get the new version on the next open (the service worker is
network-first), usually after one reload. Their data is untouched. Updating never
touches IndexedDB.

## 5. Things that cause data loss (tell your friend)

The data is in the browser, not in the cloud. It is lost if the person:
* clears site data / "cookies and site data" for the site,
* uninstalls the browser, or uses a private window,
* switches phone or browser without restoring a backup.

So: **download a backup every week** (the dashboard reminds after 7 days) and
keep the file in Google Drive or WhatsApp-to-self. The site URL must stay the
same too; data is per-origin. Moving to a new domain means backup then restore.
