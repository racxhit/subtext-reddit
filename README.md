# SubText

**A native macOS app that downloads Reddit threads and converts them into clean, readable text files without the official Reddit API.**

[![Platform](https://img.shields.io/badge/platform-macOS%2013.0+-blue)]()
[![Swift](https://img.shields.io/badge/swift-5.9-orange)]()
[![License: MIT](https://img.shields.io/badge/license-MIT-green)]()

SubText is a lightweight, open-source Reddit post downloader, thread fetcher, and text converter built for macOS. Paste a thread URL, hit download, and get back a fully structured `.txt` file containing the post and every nested comment, ready for offline reading, archiving, or further processing.

## Table of Contents

- [Why SubText](#why-subtext)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Output Format](#output-format)
- [Building from Source](#building-from-source)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Why SubText

Reddit locked its official API behind paid commercial pricing, and a lot of the older "Reddit downloader" and "Reddit scraper" repos on GitHub quietly stopped working as a result. SubText sidesteps that entirely, it pulls data from Reddit's public `.json` endpoints instead of the official API, so there's no API key, no OAuth app registration, and no developer account required.

It's also just a small, single-purpose native app rather than a browser extension or a Python script with a dozen dependencies to manage. Download it, run it, convert threads.

## Features

- **One-click conversion** — paste a thread URL, click Download, get a `.txt` file.
- **Full comment recursion** — every reply is captured, with depth and structure preserved.
- **No API key required** — works against Reddit's public JSON endpoints, not the restricted official API.
- **Built-in anti-blocking controls** — set a custom `User-Agent` and session `Cookie` from Settings if Reddit starts rate-limiting you.
- **Broad URL support** — handles `reddit.com`, `old.reddit.com`, and shared mobile (`sh.reddit.com`) links.
- **Fully native** — written in SwiftUI, no Electron, no background processes, minimal footprint.

## Installation

Download the latest build from the [Releases](../../releases) page, or build it yourself (see [Building from Source](#building-from-source)).

Since SubText isn't distributed through the Mac App Store, macOS Gatekeeper will block it the first time you open it. To allow it:

After moving `SubText.app` to `/Applications` and double-clicking to open it, click **OK** when the "cannot be opened" warning appears. Then:

**Option A — Terminal**
```bash
xattr -cr /Applications/SubText.app
```

**Option B — Settings**
1. Open your Mac's **System Settings** and navigate to **Privacy & Security**.
2. Scroll down to the **Security** section. You will see a message stating that "SubText" was blocked. Click **Open Anyway**.
3. Authenticate with your Mac password or Touch ID, then click **Open** on the final prompt to permanently authorize the app.

## Usage

1. Copy a link to any Reddit post or comment thread.
2. Open SubText and paste the URL into the input field.
3. Click **Download**.
4. The post and its full comment tree are saved as a `.txt` file to your configured output folder (defaults to Desktop).

## Configuration

Open Preferences with `⌘,` to adjust:

| Setting | Description |
|---|---|
| **Save Folder** | Where converted `.txt` files are written. Defaults to Desktop. |
| **User-Agent** | The request header sent to Reddit. Change this if downloads start failing. |
| **Cookie** | Paste a session cookie from your browser if requests start returning 403/429 errors. |

## Output Format

Threads are flattened into a depth-first, indentation-based layout:

```
POST TITLE: iOS 27 Beta 1 - Discussion

POST BODY:
Use this thread to share any changes & bugs you discover...

COMMENTS:

[Comment id=os511xh depth=0 score=42]
Author: hehaia
Text: Anyone noticed how much this new update makes the phone switch...

    [Comment id=os4pcn3 depth=1 score=15]
    Author: B_tj1
    Text: correct me if i'm wrong but did they not bring liquid glass...
```

## Building from Source

**Requirements:** macOS 13.0+, Xcode 15.0+

```bash
git clone https://github.com/racxhit/subtext-reddit.git
cd subtext-reddit
open SubText.xcodeproj
```

Select the `SubText` scheme and press `⌘R` to build and run.

## Troubleshooting

**Downloads fail or hang.** Reddit is likely throttling the default request signature. Open Preferences (`⌘,`) and paste in a `Cookie` value copied from your browser's developer tools (Network tab → any reddit.com request → request headers).

**"SubText is damaged and can't be opened."** This is Gatekeeper blocking an unsigned app, not actual corruption — see [Installation](#installation) above.

## Contributing

Issues and pull requests are welcome. If you're planning a larger feature, open an issue first to discuss the approach.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
