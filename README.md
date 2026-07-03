# Anygram iOS Messenger

Telegram-like iOS messenger built with Swift 5.10, SwiftUI, MVVM + Clean Architecture.

## Requirements

- macOS with Xcode 15+
- iOS 17+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (recommended)

## Setup on Mac

```bash
cd "anygram ios"
brew install xcodegen
xcodegen generate
open Anygram.xcodeproj
```

Build and run on iOS Simulator or device (Cmd+R).

## Architecture

```
View → ViewModel → Repository → ServiceProtocol → MockService
```

- **DI Container**: `Core/DIContainer.swift`
- **MTProto Ready**: Proxy layer in `Networking/`
- **Default Proxy**: Enabled on first launch

## Limitations

- Mock data only (no real MTProto/Telegram API yet)
- Media are color placeholders
- Requires Mac/Xcode to compile
