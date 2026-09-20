# ATLAS Music for iPhone

This is a native iOS wrapper for the ATLAS Music web app:

https://drakeroche4-star.github.io/atlas-music/

It uses `WKWebView` inside a real iOS app bundle and enables the iOS background-audio mode.

## Build without a Mac

The included GitHub Actions workflow builds an **unsigned IPA** using a GitHub-hosted macOS runner.

1. Create a new GitHub repository, for example `atlas-music-ios`.
2. Upload every file and folder from this project to that repository.
3. Open the repository's **Actions** tab.
4. Open **Build ATLAS Music IPA**.
5. Choose **Run workflow**.
6. When the run finishes, open it and download the artifact named:
   `ATLASMusic-unsigned-ipa`
7. Extract the downloaded ZIP. Inside is:
   `ATLASMusic-unsigned.ipa`

## Install from Windows

Use Sideloadly to sign and install the unsigned IPA with your Apple ID.

The final signing/install step happens on your PC; the GitHub workflow intentionally does not contain Apple credentials.

## Bundle ID

`com.drakeroche.atlasmusic`

## Important

ATLAS Music's actual library is still the web app's local storage/IndexedDB inside the app's `WKWebView`. This native wrapper has its own WebKit data container, so songs stored in the old Home Screen PWA will not automatically appear here. Import or restore the ATLAS Music library inside the native app after installation.
