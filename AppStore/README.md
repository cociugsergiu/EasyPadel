# PadelPoint — App Store launch assets

## App icon
- `AppIcon-1024.png` — master, 1024×1024, no alpha, square (iOS applies the mask).
- `icons-ios/` — 20…1024 px for the iPhone asset catalog.
- `icons-watchos/` — 40…1024 px for the Watch asset catalog.

Xcode 15+ only needs the 1024 master in a single-size App Icon slot; the size sets are there for older catalogs and for any marketing use.

## iPhone screenshots — 1320×2868 (6.9", iPhone 16 Pro Max)
1. `iPhone-6.9-1-track-score-win.png` — Track. Score. Win.
2. `iPhone-6.9-2-court-side.png` — landscape scoreboard, golden point
3. `iPhone-6.9-3-milestones.png` — matches played + theme unlocks
4. `iPhone-6.9-4-apple-watch.png` — watch gestures

App Store Connect scales these down for the 6.5" and 6.1" slots automatically — no separate set needed.

## Apple Watch screenshots — 410×502
- `Watch-410x502-1-score.png`
- `Watch-410x502-2-progress.png`

Screen-only, no bezel, as required for the watchOS slot.

## Store copy
- Subtitle (30 char): `Keep score. Nothing else.`
- Alternates: `Padel scoring, made simple.` · `Tap to score. Beginner to pro.`

Regenerate any asset from `PadelPoint Store Export.dc.html` in the project root.
