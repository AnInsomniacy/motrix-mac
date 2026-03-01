# Motrix for macOS

A native macOS download manager built with SwiftUI, reimagined from the ground up based on [Motrix](https://github.com/agalwood/Motrix).

<img width="936" height="636" alt="image" src="https://github.com/user-attachments/assets/2a01c1f0-66ea-4cb8-8154-5a44bb97e073" />

While the original Motrix is a cross-platform Electron app, this project is a complete rewrite targeting macOS exclusively — delivering a lighter footprint, tighter system integration, and a truly native experience powered by aria2.

## Features

- **Multi-protocol downloads** — HTTP, HTTPS, FTP, BitTorrent, Magnet, and Thunder links
- **BitTorrent selective download** — choose individual files from a torrent before downloading
- **Automatic tracker sync** — fetches and applies up-to-date tracker lists on launch
- **UPnP / NAT-PMP port mapping** — pure Swift implementation, no external dependencies
- **Engine watchdog** — monitors aria2 health and auto-restarts on failure
- **Adaptive polling** — speeds up refresh during active downloads, throttles when idle
- **Menu bar extra** — live speed display and quick controls from the system tray
- **Dock badge** — real-time download speed shown on the app icon
- **Drag & drop** — drop `.torrent` files or URLs directly onto the window
- **Dark mode** — native dark theme throughout
- **macOS notifications** — alerts on download completion or failure
- **Start at login** — managed via `SMAppService`
- **Auto update check** — queries GitHub Releases for newer versions

## Architecture

```
motrix-mac/
├── Engine/          Aria2Process (subprocess lifecycle) + Aria2Config (paths, args, RPC)
├── Models/          AppState (@Observable) + DownloadTask, GlobalStat
├── Services/        DownloadService (JSON-RPC client), ConfigService (@AppStorage),
│                    ProtocolService, TrackerService, UPnPService
├── Utilities/       ByteFormatter, TimeFormatter, MagnetLink, ThunderLink
└── Views/           MainWindow, Sidebar, TaskList, TaskRow, TaskDetail,
                     AddTask (with built-in bencode parser), Settings, About, MenuBar
```

The app embeds a bundled `aria2c` binary and communicates with it over HTTP JSON-RPC on `127.0.0.1:16800`. All user preferences are persisted via `@AppStorage` (UserDefaults).

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, AppKit interop |
| Download engine | [aria2](https://aria2.github.io/) (bundled binary) |
| RPC client | [Aria2Kit](https://github.com/nicklama/Aria2Kit) + [Alamofire](https://github.com/Alamofire/Alamofire) |
| Serialization | [AnyCodable](https://github.com/Flight-School/AnyCodable) |
| Torrent parsing | Built-in Bencode decoder |
| Networking | UPnP via raw Darwin sockets, URLSession |
| Persistence | @AppStorage (UserDefaults) |

## Requirements

- macOS 14.0+
- Xcode 15+
- Swift 5.9+

## Getting Started

```bash
git clone https://github.com/AnInsomniacy/motrix-mac.git
cd motrix-mac
open motrix-mac.xcodeproj
```

Build and run from Xcode. The bundled `aria2c` binary is included in `Engine/Resources/`.

## Acknowledgements

- [Motrix](https://github.com/agalwood/Motrix) by Dr_rOot — the original cross-platform download manager
- [aria2](https://aria2.github.io/) — the high-performance download engine
- [ngosang/trackerslist](https://github.com/ngosang/trackerslist) — public BitTorrent tracker lists
