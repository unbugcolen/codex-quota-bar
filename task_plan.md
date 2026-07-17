# Task Plan: Packaged App Visibility Fix

## Goal

Make `open .build/release/CodexQuotaBar.app` launch a menu-bar item that is visible on the 14-inch MacBook Pro and remains user-positionable.

## Phases

1. [complete] Reproduce packaged launch and distinguish launch failure from hidden UI.
2. [complete] Identify the root cause using process, Accessibility, screen-safe-area, and preferences evidence.
3. [complete] Add failing tests for a stable status-item autosave name and first-run visible position.
4. [complete] Implement stable app-bundle identity and a dynamic notch-safe status-item layout.
5. [complete] Run focused and full tests, rebuild the app, verify signing and launch identity, and leave unlock-time layout recalculation active.
6. [in_progress] Expand Hidden Bar in the unlocked session and move the quota item to the visible side of its separator.

## Decisions

- Use a stable autosave name so later Command-drag changes persist.
- Keep the compact 34-point display and existing Hidden Bar setup unchanged.
- When the system places the mini item under the camera housing, extend only its invisible hit area and right-align the short percentage in the safe area.
- Re-run notch layout when the user session becomes active after a locked launch.
- Treat Hidden Bar's spacer position as the remaining machine-local issue; do not add another AppKit layout workaround until the item has been moved across its separator.

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| JavaScript template parsed shell parameter syntax | 1 | Rebuilt the command from plain string lines. |
| Computer Use timed out targeting an LSUIElement app | 1 | Used Accessibility and Finder state instead. |
| Computer Use screenshot helper was not initialized after timeout | 1 | Imported the filesystem helpers in a fresh call. |
| First Accessibility query ran before the menu bar existed | 1 | Poll for the menu-bar item before reading its frame. |
| A nested shell command had unmatched quoting | 1 | Split launch and Accessibility polling into separate tool calls. |
| Synthetic Command-drag had no effect | 1 | Screen was locked; replaced it with app-managed notch-safe layout. |
| Python Quartz module was unavailable | 1 | Used `ioreg` to confirm the console lock state. |
