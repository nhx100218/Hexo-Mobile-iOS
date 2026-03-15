# Hexo mobile

Hexo mobile is a fully native SwiftUI iOS app that turns any Hexo blog into a mobile-first reader experience.

Users only need to provide a base blog URL (for example, `https://example.com`). Hexo mobile automatically discovers a valid feed (`/atom.xml`, `/rss.xml`, or `/feed.xml`), fetches posts, and renders them in a clean reading UI.

## Features

- **SwiftUI-native app** targeting **iOS 26+**
- **MVVM architecture** for separation of concerns
- **Automatic feed detection** from a Hexo base URL
- **RSS/Atom parsing** powered by [FeedKit](https://github.com/nmdias/FeedKit)
- **Post list with metadata** (title, date, summary)
- **In-app native Markdown article reader** (no direct webpage rendering)
- **Modern visual style** with glass-like `.ultraThinMaterial` navigation bars
- **Dark mode + dynamic system colors**
- **Saved blog URL** using `UserDefaults`

## Project Layout

```
Hexo mobile
├── HexoReaderApp.swift
├── Models
│   └── Post.swift
├── Services
│   ├── BlogDetectService.swift
│   └── FeedService.swift
├── ViewModels
│   └── BlogViewModel.swift
├── Views
│   ├── ArticleView.swift
│   ├── BlogListView.swift
│   └── SettingsView.swift
└── Utils
```

## Build Locally (Xcode)

1. Open `HexoReader.xcodeproj` in Xcode 26+
2. Select the `HexoReader` scheme
3. Choose an iOS simulator or a device
4. Build and run (`⌘R`)

Command line build example:

```bash
xcodebuild -scheme HexoReader -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## CI: Unsigned IPA on GitHub Actions

The workflow at `.github/workflows/build-ios.yml` runs on every push to `main` and:

1. Checks out the repository
2. Archives the app without code signing
3. Packages an unsigned IPA directly from the archived `.app` (no signing/export options needed)
4. Uploads the IPA artifact (`Hexo-mobile-ipa`)

Manual equivalent:

```bash
xcodebuild \
  -scheme HexoReader \
  -sdk iphoneos \
  -configuration Release \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO \
  archive \
  -archivePath build/HexoReader.xcarchive

APP_PATH=$(find build/HexoReader.xcarchive/Products/Applications -maxdepth 1 -name "*.app" -print -quit)
mkdir -p build/Payload
cp -R "$APP_PATH" build/Payload/
(
  cd build
  /usr/bin/zip -qry Hexo-mobile.ipa Payload
)
rm -rf build/Payload
```

## Sideloading the IPA

After CI finishes, download the `Hexo-mobile-ipa` artifact and sideload using:

- **Sideloadly**
- **AltStore**

Typical flow:

1. Download the generated `.ipa`
2. Connect your iPhone to your Mac/PC
3. Open Sideloadly or AltStore
4. Select the IPA and your Apple ID/account
5. Install to your device

> Note: free Apple IDs require periodic re-signing.

## License

MIT (recommended for open-source; add `LICENSE` as needed).
