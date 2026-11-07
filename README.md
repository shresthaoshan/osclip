# OSClip

A minimal clipboard history app for macOS. It lives in the menu bar and keeps the text, images and files that you copy.

- No dependencies. Swift and SwiftUI only.
- No permissions. OSClip does not need Accessibility access.
- History stays on your Mac and remains after a restart.

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

## Build and run

```bash
make run
```

`make run` builds a release binary, puts it in `OSClip.app`, signs it ad hoc and opens it. Other targets:

| Command      | What it does                         |
|--------------|--------------------------------------|
| `make app`   | Builds `OSClip.app` and does not open it. |
| `make test`  | Runs the tests (`swift test`).       |
| `make clean` | Removes `.build` and `OSClip.app`.   |

To install, move `OSClip.app` to `/Applications`. "Launch at login" works best from there.

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
