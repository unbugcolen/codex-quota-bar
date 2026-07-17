# Progress

## 2026-07-15

- Reproduced `open .build/release/CodexQuotaBar.app` from a clean process state.
- Confirmed Launch Services starts the packaged executable successfully.
- Measured the status item and screen safe areas with Accessibility/AppKit.
- Confirmed the item is fully obscured by the MacBook Pro camera housing.
- Tested an `Item-0` preference seed; it was ignored because the app resets the automatic autosave name to nil.
- Added regression tests for a stable autosave name, a first-run visible position, and preserving a user-selected position.
- Confirmed the focused test fails because the expected configuration API is absent.
- Implemented the stable v3 autosave name and first-run preferred position of 250 without overwriting saved values.
- Wired preference preparation before status-item creation.
- Confirmed focused configuration tests pass.
- Found a second packaged-only defect: strict code-sign verification fails and the bundle identifier is not bound into the signature.
- Added full-bundle ad-hoc signing and strict verification to the packaging script.
- Rebuilt successfully; strict verification passes and the signing identifier now matches the bundle identifier.
- Confirmed private preferred-position defaults still do not move the item immediately.
- Width experiments showed the hidden slot keeps x=798 while wider items extend into the right safe area; this supports a dynamic notch-bridge layout.
- Replaced the ineffective preference-position tests with notch-layout tests.
- Confirmed the notch-layout tests fail because the calculation is absent.
- Implemented the pure notch-bridge calculation and an asynchronous runtime adjustment for mini mode.
- Right-aligned the compact percentage so only the visual content occupies the safe area.
- Removed the ineffective private preferred-position bootstrap.
- Added a session-activation observer so an app launched while the Mac is locked recalculates its notch layout immediately after unlock.
- Removed the two experimental position defaults from the packaged app's preference domain.
- Full `swift test`: 14 tests passed, 0 failures.
- Final `Scripts/build-app.sh`: succeeded, including strict bundle verification.
- Final bundle identity: `com.colen.CodexQuotaBar.menubar`; `open` launched PID 63098 from the release app bundle.
- `git diff --check`: passed.
- The final app is running. Unlocked visual verification remains unavailable because `IOConsoleLocked` and `CGSSessionScreenIsLocked` are both `Yes`; unlock-time recalculation is installed for that transition.

## 2026-07-17

- Rechecked after the user reported the item was still unavailable.
- Captured an unlocked screenshot: the quota percentage is absent from the visible menu bar.
- Measured the running quota status item at offscreen coordinate `x=7, y=981`.
- Measured Hidden Bar's visible toggle at `x=1189` and its hidden spacer at width `5002`; this identifies Hidden Bar ordering as the actual remaining cause.
- Computer Use then reported the Mac had locked again, so it correctly refused to press the Hidden Bar toggle. Waiting for a manual unlock before moving the item.
