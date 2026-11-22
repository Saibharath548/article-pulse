# Article Pulse – AI-Powered Article Discovery App

> A distraction-free, personal article discovery and reading application built with Flutter & Dart for Android.

Article Pulse helps you discover, search, and explore high-quality informative articles across 11 diverse subjects instead of spending hours doom-scrolling social media feeds.

---

## Key Features

- **Daily Discovery Home Feed**: Curated three-part discovery combining **Fresh Pulses** (recent articles), **From the Vault** (timeless archive discoveries published 1–2 years ago), and **Random Spark** (interdisciplinary surprises).
- **Anti-Repetition Engine**: Local SQLite impression tracking records viewed articles and filters them out of recommendations for 48 hours.
- **11 Browseable Categories**: Game Development, Technology, Science, Psychology, Government and Politics, Society and Social Issues, History, Business and Economics, Artificial Intelligence, Environment, and General Knowledge.
- **Dedicated Live Articles Stream**: Real-time articles retrieved from open feeds, sorted newest first, clearly distinguishing between *Original Publication Date* and *Discovered Date*.
- **2+ Years Historical Search**: Deep archive discovery (2024 to 2026+) powered by dynamic multi-provider routing (Hacker News Algolia, Crossref Open Works, and optional The Guardian Open Platform).
- **Offline Storage & Bookmarks**: SQLite database for offline reading of article metadata, summaries, publisher attribution, and reading history.
- **Copyright & Attribution Integrity**: Full publisher attributions preserved. Original articles open directly in the device's external browser. No copyrighted article bodies are scraped.
- **Zero Paid Dependencies**: 100% free operation with no mandatory API keys or commercial AI subscriptions.

---

## Automated Cloud Build (GitHub Actions)

This repository includes a continuous integration and build workflow in [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml).

Every commit to `main` (and manual `workflow_dispatch` trigger) runs:
1. Flutter & Java 17 setup on `ubuntu-latest`.
2. `flutter pub get`
3. `flutter analyze` (Zero lint / syntax errors)
4. `flutter test` (10/10 automated tests passing)
5. `flutter build apk --release`
6. Uploads the release APK as a downloadable artifact `article-pulse-release-apk`.

---

## Installing on Android

1. Go to the **Actions** tab in this GitHub repository.
2. Select the latest completed workflow run.
3. Scroll down to **Artifacts** and download `article-pulse-release-apk.zip`.
4. Extract `app-release.apk` and transfer it to your Android device (or download directly on your phone).
5. Open the APK and allow installation from your browser/file manager when prompted.
