# Findings

- `open` exits with status 0 and launches `CodexQuotaBar`; the bundle is not crashing.
- The main screen is 1512 points wide. Its camera housing occupies x=663 through x=848.
- The app's 36-point status item is placed at x=798 through x=834, entirely behind the camera housing.
- `swift run` and packaged launch both currently produce the same hidden coordinate; `swift run` merely stays attached to the terminal, while `open` returns immediately.
- `StatusItemConfiguration.autosaveName = nil` clears/ignores persisted status-item placement, so every launch returns to the default hidden position.
- Hidden Bar's expand/collapse item has preferred position 293 and separator has 419. A preferred position around 250 places the quota item in the always-visible right-side section.
- Existing packaged preferences already use the compact `miniProgress` display, so width is not the remaining cause.
- The assembled app bundle was not signed as a bundle: its code-signing identifier was `CodexQuotaBar`, `Info.plist` was not bound, and strict verification failed because the signature did not seal bundle resources.
- The incomplete bundle signature explains why Launch Services can start the executable while app identity and status-item persistence remain unreliable.
- Apple's documented `isVisible` behavior permits a status item to report visible while temporarily hidden for insufficient menu-bar space.
- The final package has a valid strict signature and code-signing identifier `com.colen.CodexQuotaBar.menubar`.
- The console remained locked during final verification, so an unlocked screenshot was not safe or possible; the app now observes session activation and recalculates layout immediately after unlock.
- On 2026-07-17, unlocked Accessibility data showed the quota item at `x=7, y=981`, which is an offscreen placeholder rather than the camera-housing range.
- Hidden Bar exposes three status items on accessibility menu bar 2: its visible toggle at `x=1189` and two separators at negative x positions, including a `5002pt` spacer. That spacer is what pushes the quota item offscreen.
- The dynamic notch bridge cannot fix an item whose status window has already been moved offscreen by Hidden Bar.
