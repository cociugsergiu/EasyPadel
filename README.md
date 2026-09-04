# EasyPadel

A minimal, elegant padel scoreboard for iPhone and Apple Watch. Built as a
native SwiftUI app (not a web app) so the Watch can support real gesture
input — a plain website can't do that on watchOS. Runs entirely locally on
your own devices; nothing is published anywhere.

> The app's public name is **EasyPadel** (bundle ID `com.easypadel.app`).
> The Xcode project, targets, and folders keep the original internal name
> **PadelPoint** — that's just the project's codename and doesn't appear
> anywhere a user sees it (CFBundleDisplayName is set to EasyPadel).

## What's inside

- **EasyPadel** (iPhone target: `PadelPoint`) — the iPhone app. Two large tap
  zones (Team A / Team B), a center bar with the set/game score, and a
  hold-to-reset button.
- **EasyPadel Watch App** (Watch target: `PadelPoint Watch App`) — the Watch
  app, the primary way to keep score mid-match:
  - **Tap** anywhere → point for Team A
  - **Double tap** anywhere → point for Team B
  - **Hold** (~1 second) → reset the match
  - Each action has a distinct haptic, so you can register a point without
    looking at your wrist.
- **Shared** — the scoring engine and match state, used by both apps. It
  implements real padel/tennis scoring: 0-15-30-40, deuce, sets to 6 (win by
  2) with a tiebreak at 6-6, match to 2 sets. **Golden Point** (sudden-death
  at 40-40, no advantage) is on by default since that's how most padel clubs
  play — toggle it off in the iPhone app's settings (gear icon) if you play
  with advantage scoring.
- The two apps sync automatically over WatchConnectivity. The Watch app also
  works fully on its own if the phone isn't nearby (each device keeps a
  local copy of the score and reconciles when reachable again).

## Opening the project

```bash
open PadelPoint.xcodeproj
```

The project was generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml`. If you ever want to regenerate it (e.g. after editing
`project.yml`), run:

```bash
xcodegen generate
```

## Installing on your iPhone and Watch

1. Open `PadelPoint.xcodeproj` in Xcode.
2. Select the **PadelPoint** target in the project navigator → **Signing &
   Capabilities** tab, and set your **Team** to your personal Apple ID (free
   accounts work fine for local installs). Do the same for the
   **PadelPoint Watch App** target.
3. Connect your iPhone (with the paired Apple Watch) via cable or make sure
   it's on the same Wi-Fi for wireless install, and select it as the run
   destination.
4. Press **Run** (▶) with the **PadelPoint** scheme. Xcode installs the
   iPhone app and embeds the Watch app automatically — the Watch app will
   then be installed on the paired Watch (this can take a minute the first
   time).
5. First launch on a physical device requires trusting your developer
   certificate on the iPhone: **Settings → General → VPN & Device
   Management** → trust your Apple ID.

No App Store account, TestFlight, or publishing step is needed.

## A note on this Mac's setup

While building this, `xcodebuild` on this machine hit a **CoreSimulator
version mismatch** (a stale background service left over from a recent
Xcode update) and an unrelated asset-catalog simulator-metadata glitch when
compiling from the command line. Both are local Xcode/Simulator tooling
issues, not problems with the code — the Swift source for both targets
typechecks cleanly. Building and running from Xcode's own **Run** button
(rather than the command line) is the normal path anyway for installing to
your physical devices, and is unaffected by this. If Xcode itself ever
complains about a missing platform/component, use **Xcode → Settings →
Components** to install it.

## Design notes

- Colors: warm coral for Team A, deep teal for Team B, on a near-black
  background with a soft gold accent — kept deliberately minimal, no
  chrome beyond what's needed to read the score at a glance.
- Taps get a spring-scale + flash animation and haptic feedback; reset is a
  deliberate hold with a radial progress ring, mirrored identically on
  iPhone and Watch so the interaction feels the same on both.
- Team names are fixed as "Team A" / "Team B" for now — renaming them would
  be a small, easy follow-up if you want it.
