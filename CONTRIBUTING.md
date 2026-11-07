# Contributing to OSClip

Thank you for your help. This guide explains how to set up the project, how the code is organized, and how to send a change.

## Before you start

- For a bug fix or a small change, you can open a pull request directly.
- For a new feature or a larger change, open an issue first. Then we can agree on the design before you write code.
- Do not add a new dependency without discussion in an issue. OSClip has no dependencies, and we want to keep it that way.
- OSClip is minimal on purpose. A feature that most users do not need is likely to be declined.

## Set up

You need macOS 14 or later and Xcode 16 or later (Swift 6).

```bash
git clone https://github.com/shresthaoshan/osclip.git
cd osclip
swift build
swift test
make run
```

`make run` builds `OSClip.app`, signs it ad hoc and opens it. If OSClip is already running, quit it first (menu bar icon › Quit).

`swift run` also works for quick checks, but without the `.app` bundle the app shows a Dock icon, and launch at login does not work.

## How the code works

```
NSPasteboard ──poll every 0.5 s──▶ ClipboardWatcher ──add──▶ HistoryStore ──▶ index.json, <id>.plist, <id>.png
                                         ▲                       │
                                    copy(item)                 items
                                         │                       ▼
                     Menu bar menu, HistoryView, QuickPicker (⌃⌘V via HotKey)
```

1. `ClipboardWatcher` checks `NSPasteboard.changeCount` every 0.5 seconds, because macOS has no clipboard change event. On a change, it reads the string, RTF, PNG, TIFF and file URL types of each pasteboard item.
   - It skips items that have the `org.nspasteboard` concealed, transient or auto-generated markers.
   - It converts TIFF to PNG and keeps the largest image.
   - It classifies the item as file, text or image, in that order.
   - It drops the capture if the pasteboard changed during the reads.
2. `HistoryStore` keeps the items. `add` removes duplicates by a SHA-256 hash of the payload, trims the history to the limit, and saves.
   - `index.json` has the item list and the first 2000 characters of each text item.
   - `<id>.plist` (binary) has the full payload. `<id>.png` is a 256 px thumbnail of an image item.
   - `commit` saves the index **before** it deletes files, so a failed save never loses data.
3. `ClipboardWatcher.copy` writes an item back to the pasteboard and ignores the change that it makes itself. For images, it also supplies TIFF, because some apps read only TIFF.
4. The UI:
   - `MenuContent` (in `OSClipApp.swift`) shows the last 15 items.
   - `HistoryView` is the history window, with a list or a grid, search and keyboard navigation.
   - `QuickPicker` is a borderless, non-activating `NSPanel` at the mouse pointer. It does not activate OSClip, so the front app keeps focus for ⌘V.
   - `SettingsView` has the history size, launch at login and Delete All.
5. `HotKey` registers ⌃⌘V with Carbon `RegisterEventHotKey`, which needs no Accessibility permission.

### Rules

- OSClip must not need any permission. A change that needs Accessibility or another permission must be optional and off by default.
- `HistoryStore` and `ClipboardWatcher` take their folder and pasteboard as parameters. Tests use a temporary folder and `NSPasteboard.withUniqueName()`. Keep it that way, so tests never touch the real clipboard or the real history.
- Never lose user data. Save the index first, then delete files. Keep a file that cannot be read, and do not overwrite it.
- Key handlers (local `NSEvent` monitors) must handle only events for their own window, and must pass keys through while an input method composes text.
- Work on the main thread must stay short. The clipboard poll runs on the main thread.

## Tests

- `swift test` must pass before you send a pull request. CI runs it on each push and pull request.
- Add tests for each change in `HistoryStore`, `ClipboardWatcher`, `Selection` or `ClipItem`.
- For a bug fix, add a test that fails before the fix.
- Tests must not change real system state: no real clipboard, no real Application Support folder, no real login item.

### Test in the running app

Unit tests cannot check focus, windows or keys. Before you send a UI change:

1. Quit OSClip, then run `make run`.
2. Copy text, an image (for example a screenshot with ⌃⇧⌘4) and a file in Finder.
3. Check the menu, the ⌃⌘V picker in another app, and the history window in list and grid view.
4. Check that ⌘V pastes the selected item into the front app.

In the pull request, write which Mac and which macOS version you used.

## Code style

- For the menu, the picker, the window and the keys, follow [DESIGN.md](DESIGN.md).
- Match the code around your change: names, comment density, and idioms.
- Keep changes small. Prefer the standard library and system frameworks to new code.
- Write comments that explain **why**, not what.
- Swift 6 language mode, and no compiler warnings.

## AI-assisted contributions

You can use AI tools, such as coding assistants, to write code, tests, or documentation. OSClip itself was built with AI assistance.

- **Disclose it.** In the pull request, say which parts an AI tool wrote or changed.
- **You are responsible for the change.** Read, understand, and test every line before you send it. You must be able to explain the change in review.
- **Test in the running app.** An AI tool cannot see focus or feel a shortcut. UI and keyboard changes must be tested as described in [Test in the running app](#test-in-the-running-app).
- **No unreviewed output.** Pull requests and bug reports that look like unreviewed AI output are closed without review.

## Commits and pull requests

- One change for each pull request.
- Commit subject: [Conventional Commits](https://www.conventionalcommits.org/) in the imperative mood, for example `feat: add pinned items` or `fix: keep selection after delete`. Use the body for details.
- For a commit that changes only documentation, add `[skip ci]` to the subject.
- In the pull request, describe what changed, why, and how you tested it.

## Report a bug

Open an issue with:

- Your macOS version and Mac model.
- The OSClip version or commit.
- Where it happens: the menu, the picker, the window, Settings, or capture and paste. For capture and paste, the app that you copied from or pasted into.
- The steps to reproduce, what you expected, and what happened.

Do not paste secrets or private clipboard content into an issue.

## License

OSClip uses the [MIT License](LICENSE). When you send a pull request, you agree that your contribution is released under the same license.
