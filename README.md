# OSClip

A minimal clipboard history app for macOS. It lives in the menu bar and keeps the text, images and files that you copy.

**Website:** [osclip.shresthaoshan.com](https://osclip.shresthaoshan.com/)

- No dependencies. Swift and SwiftUI only.
- No permissions. OSClip does not need Accessibility access.
- History stays on your Mac and remains after a restart.

## Why OSClip

macOS keeps only one item on the clipboard. When you copy something new, the old item is gone.
Most clipboard managers fix this, but they add many features, need Accessibility permission, or cost money.

OSClip does one job: it keeps what you copy and gives it back fast. It has no dependencies, needs no permissions, and does not send your data anywhere.

## Features

- **Menu bar menu.** Shows the last 15 items. Select an item to put it on the clipboard.
- **Quick picker (⌃⌘V).** Opens a small list at the mouse pointer from any app. Type to search, then press Enter to copy.
- **History window.** Shows all items as a list or a grid, with search.
- **Text, images and files.** Images show as thumbnails.
- **Duplicates.** When you copy an item again, it moves to the top. OSClip does not save a second copy.
- **Password safety.** OSClip skips items that password managers mark as concealed or transient.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later, to build

## Install

OSClip has no prebuilt release yet. Build it from source:

```bash
git clone https://github.com/shresthaoshan/osclip.git
cd osclip
make app
mv OSClip.app /Applications/
open /Applications/OSClip.app
```

The clipboard icon appears in the menu bar. OSClip has no Dock icon.

## Build from source

```bash
make run
```

`make run` builds a release binary, puts it in `OSClip.app`, signs it ad hoc and opens it. Other targets:

| Command      | What it does                         |
|--------------|--------------------------------------|
| `make app`   | Builds `OSClip.app` and does not open it. |
| `make test`  | Runs the tests (`swift test`).       |
| `make clean` | Removes `.build` and `OSClip.app`.   |

### Signing

`make app` signs the app ad hoc (`codesign --sign -`). This is enough to run OSClip on your own Mac.

An ad hoc signature changes with each build. macOS uses the signature to identify the app, so after a rebuild you may need to turn **Launch at login** off and on again.
For a stable signature, sign with an Apple Development certificate. It is free with an Apple ID: in Xcode, open Settings › Accounts and add a certificate. Then change the `codesign` line in the `Makefile`:

```make
codesign --force --sign "Apple Development" $(APP)
```

### Permissions

OSClip needs no permissions:

- The ⌃⌘V hotkey uses `RegisterEventHotKey`, which does not need Accessibility access.
- Reading and writing the clipboard needs no permission on macOS 14 and 15.
- The quick picker gets keys in its own panel.

**Launch at login** can need your approval in System Settings › General › Login Items. Settings shows a button for it.

## Usage

### Menu bar

Click the clipboard icon. Select an item, then press ⌘V in any app. The menu also has **Open…** (⌘O), **Settings…** (⌘,) and **Quit** (⌘Q).

### Quick picker

Press **⌃⌘V** in any app. The list opens at the mouse pointer. The app that you use keeps focus, so you can paste immediately.

| Key          | Action                                 |
|--------------|----------------------------------------|
| Type         | Searches all history                   |
| ↑ / ↓        | Moves the selection                    |
| Enter        | Copies the item and closes the list    |
| Esc          | Closes the list                        |
| ⌃⌘V          | Closes the list                        |

A click outside the list also closes it. If another app already uses ⌃⌘V, the menu shows a message.

### History window

Open it from the menu with **Open…**. The search field has focus when the window opens.

| Key                  | Action                                            |
|----------------------|---------------------------------------------------|
| Type                 | Searches all history                              |
| ↑ / ↓                | Moves the selection                               |
| ← / →                | Moves the selection (grid only)                   |
| Enter                | Copies the item and hides the window              |
| ⌘⌫                   | Deletes the selected item (when the search is empty) |
| Esc                  | Clears the search. A second Esc closes the window. |
| ⌥, ⌘ or ⇧ with an arrow | Edits the search text                          |

Click an item to copy it. Right-click an item and select **Delete** to remove it. **Delete All…** in the toolbar removes all items after you confirm.

### Settings

- **History size.** Number of items to keep, from 10 to 5000. The default is 200. When you make the number smaller, OSClip deletes the oldest items immediately.
- **Launch at login.** macOS can ask you to approve this in System Settings › General › Login Items.
- **Delete All…** removes all items after you confirm.

## Storage and privacy

OSClip keeps its data in `~/Library/Application Support/osclip/`:

| File            | Contents                                          |
|-----------------|---------------------------------------------------|
| `index.json`    | Item list, with the first 2000 characters of each text item |
| `<id>.plist`    | The full content of one item                      |
| `<id>.png`      | Thumbnail of an image item (256 px)               |

- The data is not encrypted. Any app that can read your home folder can read it.
- OSClip does not send data anywhere.
- Images are saved as PNG. When the source supplies only TIFF, OSClip converts it.
- If `index.json` cannot be read, OSClip keeps it as `index-corrupt-<time>.json` and starts a new history.
- Search finds text in the first 2000 characters of an item. A paste always gives the full text.

To remove all data, quit OSClip and delete the folder.

## Known limitations

- OSClip does not paste for you. Select an item, then press ⌘V.
- The hotkey is fixed to ⌃⌘V.
- You cannot exclude apps. Items from apps that do not mark secrets are saved.
- OSClip checks the clipboard every 0.5 seconds, because macOS has no clipboard change event.
- Copies that have only a large TIFF image are converted on the main thread. This can take about 0.25 s.

## Roadmap

- Auto-paste after you select an item (needs Accessibility permission)
- Configurable hotkey

## Troubleshooting

**⌃⌘V does nothing.**
Open the menu. If it says "⌃⌘V is in use by another app", another app holds the shortcut. Quit that app or change its shortcut, then quit and open OSClip.

**An item is not in the history.**
- OSClip skips items that the source app marks as concealed or transient. Password managers do this.
- OSClip checks the clipboard every 0.5 seconds. If two copies happen within 0.5 seconds, it saves only the second one.
- OSClip saves only what it sees while it runs.

**Search does not find a text item.**
Search reads the first 2000 characters of each item. A match after that point is not found.

**Paste gives the wrong format.**
OSClip keeps plain text, RTF, PNG images and file references. It gives images back as PNG and TIFF. Other formats, such as HTML or app-specific data, are not kept.

**Launch at login does not work.**
Move `OSClip.app` to `/Applications`, then turn the setting off and on. If Settings shows **Open Login Items**, approve OSClip there. After a rebuild with ad hoc signing, turn the setting off and on again (see [Signing](#signing)).

## Uninstall

1. In Settings, turn off **Launch at login**.
2. Quit OSClip (menu bar icon › **Quit**).
3. Delete `OSClip.app`.
4. Delete the history and the settings:

```bash
rm -rf ~/Library/Application\ Support/osclip
```

```bash
defaults delete com.shresthaoshan.osclip
```

## Project structure

```
Sources/OSClip/
  OSClipApp.swift        App entry, menu bar menu, shared item views
  HistoryStore.swift     History model, persistence, thumbnails, search
  ClipboardWatcher.swift Clipboard polling, capture and restore
  HistoryView.swift      History window
  QuickPicker.swift      ⌃⌘V panel and arrow-key selection
  HotKey.swift           Global hotkey registration
  SettingsView.swift     Settings window
Tests/OSClipTests/       Swift Testing tests
Info.plist               App bundle settings (menu bar only, no Dock icon)
Makefile                 Build, run and test commands
```

## Contributing

Bug reports, ideas and pull requests are welcome. Read [CONTRIBUTING.md](https://github.com/shresthaoshan/osclip/blob/main/CONTRIBUTING.md) for the setup, how the code works, and how to send a change. [DESIGN.md](https://github.com/shresthaoshan/osclip/blob/main/DESIGN.md) has the UI and keyboard rules.

## License

OSClip is released under the [MIT License](https://github.com/shresthaoshan/osclip/blob/main/LICENSE).
