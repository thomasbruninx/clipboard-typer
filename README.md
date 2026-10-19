# Clipboard Typer

A macOS 14+ menu bar utility that types clipboard text into the focused app with **⌘⇧V**. It sends keyboard events at approximately 100 characters per second rather than invoking Paste. No dependencies, network access, clipboard history, or content logging.

## Build and run

Requires Xcode or the Swift command line tools (Swift 5.10 or later).

```sh
./script/build_and_run.sh
```

The script builds a release executable for your Mac, packages and locally signs `dist/Clipboard Typer.app`, and launches it. The Codex **Run** button uses the same script. The app has a menu bar icon and no Dock icon or main window.

The app's keyboard artwork lives in `Assets/AppIcon.png`. Each build generates the full macOS `.icns` size set and embeds it in the app bundle. See [icon design notes](Assets/README.md) for the generation prompt. The menu bar continues to use a monochrome system symbol so it adapts to the menu bar appearance.

To build without launching, use `./script/build_and_run.sh --build`. Other modes: `--verify` (check process after launch), `--debug` (LLDB), `--logs`, and `--telemetry` (process logs). Run tests with `swift test`.

## Install

Quit any running copy, copy `dist/Clipboard Typer.app` to `/Applications`, and open it there. Grant permission to the copy you intend to use. This is a local, ad-hoc signed build; it is not notarized for public distribution. A build is native to the architecture of the Mac building it.

## Use

1. On first launch, choose **Open Settings** and enable **Clipboard Typer** under **System Settings → Privacy & Security → Accessibility**. If necessary, add the app with the **+** button. You can return there through **Accessibility Permission…** in the menu.
2. Copy text, then focus the destination field.
3. Press **⌘⇧V** and release the keys. Typing begins after the modifiers are released, with a two-second release timeout.
4. Press **Escape** to cancel. Switching foreground apps or opening the utility's menu also cancels. Pressing a modifier during typing stops the run.

Left-click or right-click the icon to open the menu. Choose **Pause** to release the shortcut for other apps, **Enable** to resume, or **Quit Clipboard Typer** to exit. Enabled/paused state is remembered; a new installation starts enabled. While enabled, this shortcut replaces the destination app's usual ⌘⇧V behavior. If registration fails, the menu shows **Shortcut unavailable**; pause and enable to retry after resolving the conflict.

Only one typing run is allowed at a time; repeated shortcuts during a run are ignored. The clipboard is read once at the start and is never modified. Empty or non-text clipboard contents do nothing. Clipboard text is held in memory only for the typing run.

## Text behavior and compatibility

- Unicode, accents, emoji, spaces, and punctuation are sent as Unicode keyboard events.
- CRLF and CR line endings are normalized to newlines. **Newlines send Return, and tabs send Tab**: the destination can submit a form/command or move focus as it would for those keys.
- Some games, remote sessions, custom editors, and secure input fields may reject or reinterpret simulated keyboard events. Compatibility depends on the destination app. This utility does not bypass secure input restrictions.
- The app checks Accessibility permission and the foreground app before each character. Permission loss, app switching, pause, and quit cancel the run. Already-posted keyboard events cannot be recalled; Escape is observed without suppressing it in the destination app. Focus changes within the same app are not tracked.
- Caps Lock and the destination's own formatting/indentation settings can affect results. Avoid other keyboard input while typing.
- No launch-at-login setting, configurable shortcut, or speed preferences are included.

## Verification

Automated tests cover Unicode tokenization, line endings/tabs, pacing, modifier release and timeout, repeated triggers, event failure, cancellation, permission/focus guards, and restarting after cancellation.

For end-to-end testing, use a new TextEdit plain-text document: copy a sample with ASCII, `café`, `é`, `🙂`, multiple lines, and tabs; focus the document and press ⌘⇧V. Check exact output, then test Escape, a switch to another app, changing the clipboard during a long run, pausing/re-enabling, relaunch persistence, and permission revocation. Check the menu opens on both mouse buttons and Quit removes the icon. These checks require user-granted Accessibility permission.
