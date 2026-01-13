#!/usr/bin/env zsh
set -euo pipefail

# Create all folders/files in the same directory as this script.
script_dir="${0:A:h}"
cd "$script_dir"

mkdir -p docs/product docs/design docs/tech docs/dev

cat > AGENTS.md <<'EOF'
# MTG Resolution Timeline (Flutter, iOS/Android)

## Quick commands
- Environment: `flutter doctor -v`
- Deps: `flutter pub get`
- Format: `dart format .`
- Analyze: `dart analyze`
- Tests: `flutter test`
- Run iOS sim: `flutter run -d ios`
- Run Android: `flutter run -d android`
- Build iOS: `flutter build ios`
- Build Android APK: `flutter build apk`
- Build Android AAB: `flutter build appbundle`

## Required Git workflow
After every meaningful change, update the local Git repo so changes are tracked:
- `git status`
- `git add -A`
- `git commit -m "Short, specific message"`

Optional:
- `git pull --rebase`
- `git checkout -b feature/<name>`

## Supported platforms
- iOS / iPadOS
- Android
Not supporting: web, Windows, Linux desktop.

## Non-negotiable constraints
- Session-only: nothing persists after user presses Reset.
- On-device OCR only (ML Kit). No cloud OCR. No network required.
- Do not keep/store original or full-resolution photos.
- Workflow must purge originals and intermediate crops immediately after generating OCR text + thumbnail.
- Thumbnails may be stored only as small files in temp/cache (or small bytes), and must be deleted on Reset.
- Prefer simple, incremental changes + tests for classifier, reorder, reset purge.

## High-level architecture (MVP)
- In-memory session store holds: items, ordering, bucket membership, notes, OCR text.
- Filesystem temp/cache holds: small thumbnails only.
- Reset wipes: in-memory state + deletes thumbnail files/folder.

## Documentation map (source of truth)
- Product overview: `docs/product/overview.md`
- MTG turn model + buckets: `docs/product/mtg_turn_model.md`
- UI layout + interactions + animations: `docs/design/ui_layout.md`
- Storage lifecycle + purge rules: `docs/tech/storage_and_lifecycle.md`
- OCR + cropping + auto-bucketing: `docs/tech/ocr_and_cropping.md`
- MVP checklist + tests: `docs/dev/checklists.md`

## Roadmap / next work
- Feature build order and current next tasks: `docs/dev/roadmap.md`

## Current milestone
MVP: capture → crop text → OCR → crop art → thumbnail → purge originals → timeline UI (collapsible steps) → reorder → swipe-to-trash + undo → detail view → reset wipes all.
EOF

cat > docs/product/overview.md <<'EOF'
# Product Overview

## Goal
During MTG Commander games, quickly capture card effects (rules text) and organize them into the step they matter in, so you can resolve triggers/effects in the right order without hunting through physical cards.

## Core concept
A “timeline item” is a reminder entry with:
- OCR-extracted rules text (string)
- Small thumbnail (art crop)
- A bucket (phase/step)
- An order within that bucket
- Optional note/label

Session-only: everything is temporary and wipes on Reset.

## MVP user stories
1) As a player, I can take a photo of a card and crop the rules text so the app can OCR it.
2) As a player, I can crop the artwork to generate a small thumbnail that helps identify the card.
3) As a player, I can place the item into the correct turn step bucket (Upkeep, Attackers, etc.).
4) As a player, I can reorder items within a bucket.
5) As a player, I can swipe an item away to Trash and undo/restore it during the session.
6) As a player, pressing Reset wipes everything (data + thumbnails).

## Out of scope (MVP)
- Any network sync / accounts / cloud storage
- Cloud OCR
- Long-term persistence across app restarts (unless explicitly added later)
- Card database integration (name lookup, oracle text validation, etc.)

## UX principles
- Fast in live play: few taps, minimal navigation.
- High signal: list shows thumbnail + short text snippet.
- Safe actions: swipe-to-trash with undo; Reset requires confirmation.
EOF

cat > docs/product/mtg_turn_model.md <<'EOF'
# MTG Turn Model and Buckets

## Phases/steps (for bucket ordering)
Beginning:
- Untap (rarely needs reminders)
- Upkeep
- Draw

Precombat Main

Combat:
- Begin Combat
- Declare Attackers
- Declare Blockers
- Combat Damage
- End Combat

Postcombat Main

Ending:
- End Step
- Cleanup (usually no priority; used as an “expires” reminder)

Meta buckets:
- Response Window (instant-speed / in response)
- Static (continuous “always-on” reminders)
- Trash (session-only)

## Bucket IDs (stable)
Do not rename IDs; labels can change.

- beginning.upkeep
- beginning.draw
- main.precombat
- combat.begin
- combat.attackers
- combat.blockers
- combat.damage
- combat.end
- main.postcombat
- ending.endStep
- ending.cleanup
- meta.responseWindow
- meta.static
- meta.trash

## Priority notes (for UI hints)
- Untap: generally no priority; treat as informational only.
- Cleanup: generally no priority; use it primarily as “until end of turn” expiry reminder.
- Most other steps: priority windows exist; “Response Window” bucket covers reminders that can be used any time you have priority.

## Future enhancements (not MVP)
- “Whose turn” toggles and multiplayer turn tracking
- Stack view / priority pass simulation
- Templates for common trigger types
EOF

cat > docs/design/ui_layout.md <<'EOF'
# UI Layout, Interactions, and Animations (iPhone 15 Pro Max target)

## Primary layout (recommended)
Single vertical “turn timeline” in turn order, with:
- Sticky step headers
- Collapsible sections
- Compact list rows

Rationale:
- Minimal navigation during live play
- Clear ordering aligned to actual turn structure
- Collapsing prevents long scrolls

## Screen structure
AppBar:
- Title: Current Turn
- Actions: Reset (confirm), optional Search

Body:
- CustomScrollView with sections in this order:
  - Upkeep, Draw
  - Precombat Main
  - Begin Combat, Attackers, Blockers, Damage, End Combat
  - Postcombat Main
  - End Step, Cleanup
  - Response Window, Static
  - Trash (either separate screen or last collapsible section)

Primary action:
- Floating Action Button (bottom-right): + Capture
- FAB opens modal bottom sheet: Camera / Import

## Step header (collapsible)
Header shows:
- Step name
- Count badge
- Chevron (rotates on expand/collapse)

Defaults:
- Expand steps that have items
- Collapse empty steps

## Item row (compact)
Left:
- Square thumbnail 44–56 px, rounded corners

Center:
- Label (user note or inferred)
- OCR snippet (1–2 lines, ellipsis)
- Optional chips: Until EOT, Response, etc.

Right:
- Drag handle (reorder)
- Optional overflow menu (Move, Note, Trash)

Tap:
- Detail view with larger thumbnail + full OCR text + notes + Move + Trash/Restore

## Gestures
Swipe:
- One direction only: move to Trash
- Snackbar with Undo

Reorder:
- Within-step reorder via drag handle
- Cross-step move via detail “Move to…” (MVP)
- Later: drag to another step header

## Animations (subtle, consistent)
Targets: 150–250ms
- Expand/collapse: AnimatedSize + chevron rotation
- Insert item: fade + slight slide
- Swipe-to-trash: dismiss animation + size collapse
- Detail transition: Hero on thumbnail
- Optional light haptics: capture success, reorder start, trash

## Visual style guidance
- Dark-mode friendly, high contrast
- Minimal color use; reserve for warnings/expiry chips
- Adequate padding: 16px horizontal, comfortable row heights (64–80px)
EOF

cat > docs/tech/storage_and_lifecycle.md <<'EOF'
# Storage and Lifecycle (Session-only)

## Goal
Never persist full-resolution photos. Keep only:
- OCR text (string)
- Small thumbnail (art crop)
- Session metadata (bucket + order + notes)

Everything must be wiped on Reset.

## Recommended approach
- Metadata: in-memory only (Riverpod/Bloc/etc.)
- Thumbnails: small files in temp/cache directory (preferred) OR small bytes in memory
- Purge originals + intermediate crops immediately after derivatives are produced

## Capture pipeline (must follow)
1) Capture/import -> save ORIGINAL image to a short-lived temp path
2) Crop #1: text region -> produce crop bytes/file (temporary)
3) OCR on text crop -> store OCR string
4) Crop #2: art region -> produce crop bytes/file (temporary)
5) Create thumbnail from art crop -> resize + compress -> store thumbnail file in temp/cache
6) Purge:
   - delete original temp photo
   - delete text crop
   - delete art crop

## Reset behavior (hard requirement)
Reset must:
- Clear session store (items, buckets, ordering, notes)
- Delete the app’s thumbnail folder/files in temp/cache
- Return to empty timeline state

Optional (recommended):
- On app startup, purge the thumbnail folder to guarantee blank sessions after relaunch.

## Thumbnail sizing
- Target: 256–320px square
- Compress: JPEG/WebP at moderate quality
- Keep thumbnails small to reduce disk and decode memory

## Rendering performance notes (Flutter)
- Use Image.file with cacheWidth/cacheHeight matching display size to prevent oversized decoded images.
- Avoid holding decoded full-size images in memory.
EOF

cat > docs/tech/ocr_and_cropping.md <<'EOF'
# OCR and Cropping

## OCR requirements
- On-device only (ML Kit)
- No network usage required
- Store only extracted text (string)

Suggested package:
- google_mlkit_text_recognition

## Cropping requirements
Two regions from one capture:
- Text region for OCR
- Artwork region for thumbnail

Do not persist:
- original capture
- intermediate crops (unless explicitly needed later)

## Crop UX patterns
Pattern A (later, best UX):
- Single “card frame” screen with two overlay boxes (art + text)
- One pan/zoom transform yields both crops

Pattern B (MVP, simplest):
- Two-step crop:
  1) crop text -> OCR
  2) crop art -> thumbnail

MVP should start with Pattern B.

## Auto-bucketing heuristics (first pass)
Regex-based suggestion on OCR text:
- `\bat the beginning of (your|each|the) upkeep\b` -> beginning.upkeep
- `\bat the beginning of (the )?combat\b` -> combat.begin
- `\bwhenever .* attacks\b` / `\bwhen(ever)? .* attacks\b` -> combat.attackers
- `\bwhenever .* blocks\b` / `\bbecomes blocked\b` -> combat.blockers
- `\bat end of combat\b` -> combat.end
- `\bat the beginning of the end step\b` / legacy “at end of turn” -> ending.endStep
- `\buntil end of turn\b` / `\bthis turn\b` -> ending.cleanup (expiry reminder)
- `\bflash\b` / `\bany time you could cast an instant\b` -> meta.responseWindow

Always allow manual override.

## Failure handling
- OCR fails: create item with thumbnail + “OCR failed” status; allow retry only if text crop is still present (MVP: require recapture).
- Art crop skipped: create item with OCR text and a placeholder thumbnail.
EOF

cat > docs/dev/checklists.md <<'EOF'
# MVP Checklist and Tests

## MVP definition of done
Capture pipeline:
- Capture/import photo
- Crop text -> OCR text stored
- Crop art -> thumbnail stored in temp/cache
- Originals and intermediate crops deleted immediately after success

Timeline UI:
- Single timeline screen with collapsible step sections in turn order
- Sticky headers (or equivalent)
- Reorder within step
- Swipe to Trash + Undo snackbar
- Trash restore
- Detail view: thumbnail + full OCR text + notes + move-to-step

Reset:
- Confirm dialog
- Wipes session store and deletes thumbnail folder/files
- App returns to empty timeline

Offline:
- No network required; on-device OCR only

## Unit tests (minimum)
- Classifier: OCR text -> suggested bucket
- Session store ordering: reorder updates order indices
- Trash/restore: deletedAt + previousBucketId behavior
- Reset: clears store and deletes thumbnail files

## Widget tests (minimum)
- Renders timeline sections with correct ordering
- Swipe action moves item to Trash and shows Undo
- Reorder interaction changes list order (basic)

## Release gate
- `dart format .` clean
- `dart analyze` clean (or known, tracked exceptions)
- `flutter test` passing

## Git rule
After each meaningful change:
- `git add -A`
- `git commit -m "message"`
EOF

cat > docs/dev/roadmap.md <<'EOF'
# Roadmap (Feature Build Order)

## Current focus (next tasks)
- Phase 0–1: project scaffolding + timeline UI skeleton
Acceptance criteria:
- App runs on iOS + Android
- Timeline screen shows all buckets in correct order
- Collapsible sections work
- Item row widget exists (placeholder thumbnail + placeholder text)

## Feature build order (MVP-first)

### Phase 0 — Project scaffolding
1) Flutter project (iOS/Android only), app theme, basic navigation shell
2) State management choice (Riverpod/Bloc) and a simple in-memory session store
3) Bucket definitions + ordering (from `docs/product/mtg_turn_model.md`)

### Phase 1 — Timeline UI (no camera yet)
4) Timeline screen: ordered step sections (collapsible)
5) Add dummy items (dev-only) to validate layout on iPhone 15 Pro Max
6) Item row widget (thumbnail placeholder + OCR snippet placeholder)

### Phase 2 — Core interactions
7) Reorder within a bucket (drag handle)
8) Swipe-to-trash (one direction) + Undo snackbar
9) Trash view (section or screen) + Restore
10) Reset button (confirm) clears in-memory state

### Phase 3 — Capture pipeline (images)
11) Camera/import entry point (FAB + bottom sheet)
12) Capture to short-lived temp file
13) Crop flow Pattern B:
   - Crop text region (output temp bytes/file)
   - Crop art region (output temp bytes/file)

### Phase 4 — Derivatives + purge (the “no originals” rule)
14) Thumbnail generation (resize + compress) saved to temp/cache folder
15) Immediate purge of:
   - original temp capture
   - text crop
   - art crop
16) Wire new entry creation: thumbPath + placeholder OCR text (until OCR step is done)

### Phase 5 — On-device OCR (ML Kit)
17) Integrate ML Kit Text Recognition
18) Run OCR on the text crop and store OCR string in the item
19) Basic error states:
   - OCR failed (create item with status/message)
   - crop cancelled (handle gracefully)

### Phase 6 — Detail + organization tools
20) Detail screen: thumbnail hero, full OCR text, notes
21) Move-to-step (bucket reassignment) from detail screen
22) Notes/label editing (optional but high value)

### Phase 7 — Auto-bucketing (quality-of-life)
23) Regex classifier suggests bucket from OCR text
24) Bucket chooser UI shows suggestion + allows override

### Phase 8 — Hardening + cleanup guarantees
25) Reset also deletes thumbnail folder/files (cache purge)
26) Optional startup purge of thumbnail folder (blank session on relaunch)
27) Memory/perf tuning:
   - display thumbs with cacheWidth/cacheHeight
   - cap ImageCache if needed

### Phase 9 — Polish
28) Animations:
   - expand/collapse (AnimatedSize)
   - insert item (fade/slide)
   - hero transitions
29) Haptics (light) for key actions
30) Accessibility pass (tap targets, contrast)

### Phase 10 — Tests and release readiness
31) Unit tests: classifier, reorder, trash/restore, reset purge
32) Widget tests: timeline render, swipe+undo, reorder basics
33) “No network required” verification

## Do not start yet (scope guard)
- Cloud sync/accounts
- Cloud OCR
- Persistent storage across sessions
- Card database integration
EOF

echo "Created:"
echo "  AGENTS.md"
echo "  docs/product/overview.md"
echo "  docs/product/mtg_turn_model.md"
echo "  docs/design/ui_layout.md"
echo "  docs/tech/storage_and_lifecycle.md"
echo "  docs/tech/ocr_and_cropping.md"
echo "  docs/dev/checklists.md"
echo "  docs/dev/roadmap.md"
echo ""
echo "Location: $script_dir"
