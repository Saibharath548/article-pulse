# Article Pulse – Personal Article Discovery App

> A distraction-free, personal article discovery and reading application built with Flutter & Dart for Android.

Article Pulse helps you discover, search, and explore informative articles across 12 diverse subjects instead of spending hours doom-scrolling social media feeds.

---

## Key Features

- **Daily Discovery Home Feed**: Curated three-part discovery combining **Fresh Pulses** (recent articles), **From the Vault** (timeless archive discoveries published 1–2 years ago), and **Random Spark** (interdisciplinary surprises).
- **Anti-Repetition Engine**: Local SQLite impression tracking records viewed articles and filters them out of recommendations for 48 hours.
- **12 Browseable Categories**: Game Development, Geopolitics, Technology, Science, Psychology, Government and Politics, Society and Social Issues, History, Business and Economics, Artificial Intelligence, Environment, and General Knowledge.
- **Dedicated Geopolitics Feed**: Quick access to international relations, foreign policy, diplomacy, global security, conflicts, sanctions, and world affairs.
- **Dedicated Live Articles Stream**: Real-time articles retrieved from open feeds, sorted newest first, clearly distinguishing between *Original Publication Date* and *Discovered Date*.
- **2+ Years Historical Search**: Deep archive discovery powered by Hacker News Algolia, Crossref Open Works, and optional The Guardian Open Platform.
- **In-App Update Checks**: Article Pulse can check GitHub Releases on launch, notify you when a newer APK is available, download it, and open Android's installer. Android still requires you to confirm installation.
- **Direct APK Releases**: Signed builds are attached to GitHub Releases as APK files, so you no longer need to download and extract an Actions artifact ZIP.
- **Offline Storage & Bookmarks**: SQLite database for offline reading of article metadata, summaries, publisher attribution, and reading history.
- **Copyright & Attribution Integrity**: Full publisher attributions preserved. Original articles open directly in the device's external browser. No copyrighted article bodies are scraped.
- **Zero Paid Dependencies**: No paid search API or commercial AI subscription is required.

---

## Automated Builds and GitHub Releases

The workflow in .github/workflows/build-apk.yml runs Flutter dependency installation, static analysis, tests, and an Android APK build.

- Pushes to main publish a stable GitHub Release.
- Pushes to feature/** publish a prerelease for testing.
- Pull requests run validation and upload an APK artifact but do not publish a Release.
- Every published Release contains the APK directly as a downloadable asset.

The in-app updater checks the Releases API, including prereleases, so a test build from the feature branch can be offered inside the app.

---

## One-Time Android Signing Setup

Android only accepts an APK update when it is signed with the same signing certificate as the installed app. The GitHub Actions runners are temporary, so their default debug key is not stable between builds.

To enable direct Release APKs and reliable in-app updates, create one persistent upload keystore and keep it private:

1. On your own computer, run this in PowerShell:

       keytool -genkeypair -v -keystore article-pulse-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias article-pulse

2. Convert the keystore to one Base64 string in PowerShell:

       [Convert]::ToBase64String([IO.File]::ReadAllBytes(".\article-pulse-upload.jks"))

3. In the GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret** and add:
   - ANDROID_KEYSTORE_BASE64: the Base64 output from step 2
   - ANDROID_KEYSTORE_PASSWORD: the keystore password you chose
   - ANDROID_KEY_ALIAS: article-pulse
   - ANDROID_KEY_PASSWORD: the key password you chose

Never commit the keystore or passwords to the repository, and never share them in chat. The workflow skips publishing a Release until these secrets are configured; without them, it only uploads a temporary debug-signed APK artifact.

**Existing-install migration:** Earlier APKs were built with GitHub Actions' temporary debug signing. A new persistent signing key will have a different certificate. Android may therefore require a one-time uninstall of the old app before installing the first persistently signed APK. Uninstalling removes Article Pulse's local bookmarks and history, so export or otherwise preserve anything important before doing that. After the first install with the persistent key, future updates can install over the existing app without this signing mismatch.

---

## Installing on Android

1. Open the repository's Releases page.
2. Open the latest stable release (or the newest prerelease when testing the feature branch).
3. Download the APK asset directly.
4. Open it and allow Android to install apps from Article Pulse when prompted.

Once a persistently signed release is installed, the in-app update prompt can check, download, and hand the APK to Android's installer.
