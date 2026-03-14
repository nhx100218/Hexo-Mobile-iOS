# HexoReader

HexoReader is a fully native SwiftUI iOS app that turns any Hexo blog into a mobile-first reader experience.

Users only need to provide a base blog URL (for example, `https://example.com`). HexoReader automatically discovers a valid feed (`/atom.xml`, `/rss.xml`, or `/feed.xml`), fetches posts, and renders them in a clean reading UI.

## Features

- **SwiftUI-native app** targeting **iOS 17+**
- **MVVM architecture** for separation of concerns
- **Automatic feed detection** from a Hexo base URL
- **RSS/Atom parsing** powered by [FeedKit](https://github.com/nmdias/FeedKit)
- **Post list with metadata** (title, date, summary)
- **In-app article reader** using `WKWebView`
- **Modern visual style** with glass-like `.ultraThinMaterial` navigation bars
- **Dark mode + dynamic system colors**
- **Saved blog URL** using `UserDefaults`

## Project Layout

```
HexoReader
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

1. Open `HexoReader.xcodeproj` in Xcode 15+
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
3. Exports an unsigned IPA using `ExportOptions.plist`
4. Uploads the IPA artifact (`HexoReader-ipa`)

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

xcodebuild -exportArchive \
  -archivePath build/HexoReader.xcarchive \
  -exportPath build \
  -exportOptionsPlist ExportOptions.plist \
  CODE_SIGNING_ALLOWED=NO
```

## Sideloading the IPA

After CI finishes, download the `HexoReader-ipa` artifact and sideload using:

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
