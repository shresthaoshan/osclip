# OSClip design

The rules for what OSClip shows and how it behaves: the menu, the quick picker, the history window, Settings and the keys.
When the code and this file disagree, the code is correct. Update this file.

## Principles

- **Paste is the goal.** Every path ends with the item on the clipboard and the user back in the app where they work. OSClip never keeps focus after a selection.
- **Native first.** Use the system font, system controls, SF Symbols and the accent color. Add a custom look only where a native control cannot do the job.
- **Quiet.** No Dock icon, no window at launch, no notifications. OSClip shows something only when the user asks for it.
- **No permissions.** Each feature must work without Accessibility or any other permission.

## Item display

| Kind | Title | Icon |
|---|---|---|
| Text | The first line that is not empty, trimmed, at most 60 characters, then "…" | `text.alignleft` |
| Image | "Image" | The thumbnail |
| File | The file names, separated by ", " | `doc` |

- Thumbnails come from a 256 px PNG. The view scales them to fit the size it needs, and keeps the aspect ratio.
- The history window shows the time as relative ("2 minutes ago").

## Menu bar menu

- Icon: `doc.on.clipboard`.
- The last 15 items, newest first. Each item has its icon (images at 32 pt) and its title.
- "No history" when the history is empty.
- After a separator: **Open…** (⌘O), **Settings…** (⌘,), **Quit** (⌘Q).
- If ⌃⌘V cannot be registered, a line above **Open…** says "⌃⌘V is in use by another app".
- Selecting an item copies it. The menu closes, and focus stays in the front app.

## Quick picker (⌃⌘V)

| Item | Value |
|---|---|
| Panel | Borderless, non-activating `NSPanel`, 340 × 380 pt, `.popUpMenu` level, shadow |
| Position | Top-left corner at the mouse pointer, moved to stay inside the visible frame of the screen under the pointer |
| Background | `.regularMaterial`, corner radius 10 pt |
| Search field | Plain style, `.title3`, padding 10 pt, focused when the panel opens. Placeholder "Search history" |
| Rows | Icon 28 pt, title on one line |
| Selection | Accent 30% background, corner radius 6 pt. The first row is selected when the panel opens and after each search change |
| Empty | "No History" or "No Results", centered in the list area. The search field stays at the top |

- With an empty search, the picker shows the last 15 items. With a search, it shows all matches from the full history.
- The panel does not activate OSClip, so the front app keeps focus, and ⌘V goes to it after Enter.
- The panel closes on Enter, Esc, ⌃⌘V, or a click outside it.

## History window

| Item | Value |
|---|---|
| Size | Default 640 × 480 pt, minimum 420 × 360 pt. macOS keeps the size after the user changes it |
| Toolbar | List and grid toggle (segmented, `list.bullet` and `square.grid.2x2`), **Delete All…** (`trash`, red), search field |
| List row | Icon 40 pt, title on one line, relative time in `.caption` and `.secondary` |
| Grid cell | Height 140 pt, `.quaternary` background, corner radius 8 pt. Text in `.caption`, at most 7 lines. Images at 130 pt |
| Grid columns | `(width − 32) / 158`, at least 1. Keyboard movement uses the same number |
| Selection | List: accent 25% row background. Grid: 2 pt accent border |
| Empty | "No History" or "No Results" |

- The search field has focus each time the window becomes active.
- A click on an item copies it and hides OSClip, so focus goes back to the previous app.
- Right-click an item for **Delete**.
- **Delete All…** asks "Delete all history?" with "This cannot be undone." It is disabled when the history is empty.
- The list or grid choice is remembered.

## Settings

- A grouped `Form`, 360 pt wide.
- **History size:** a number field (70 pt) and a stepper, 10 to 5000, step 10. A smaller value deletes the oldest items immediately.
- **Launch at login:** a toggle. When macOS needs approval, a line says "Needs approval in System Settings" with an **Open Login Items** button. Errors show in red `.caption` text.
- **Delete All…:** the same dialog as in the history window.

## Keys

| Key | Quick picker | History window |
|---|---|---|
| Type | Search all history | Search all history |
| ↑ / ↓ | Move the selection | Move the selection (by one row in the grid) |
| ← / → | Move the text cursor | Grid: move the selection. List: move the text cursor |
| Enter | Copy and close | Copy and hide OSClip |
| Esc | Close | Clear the search. A second Esc closes the window |
| ⌘⌫ | Edit the search text | Empty search: delete the selected item. Otherwise: edit the search text |
| ⌥, ⌘ or ⇧ with an arrow | Edit the search text | Edit the search text |

- Keys for other windows pass through.
- While an input method composes text, all keys go to the input method.
- Plain ⌫ never deletes an item, because one extra press while the user clears the search would delete an item.

## Writing

- Use short, active sentences in the simple present tense.
- Use "Delete" for removing items, never "Clear" or "Remove".
- A button that opens a confirmation ends with "…". The button in the confirmation does not.
