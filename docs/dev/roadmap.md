# Roadmap (Feature Build Order)

## Current focus (next tasks)
- Phase 8: hardening + cleanup guarantees
Acceptance criteria:
- Reset deletes cached thumbnails
- Optional startup purge is available
- Thumbnails render with cacheWidth/cacheHeight and ImageCache is capped if needed

## Feature build order (MVP-first)

### Phase 0 — Project scaffolding
1) Flutter project (iOS/Android only), app theme, basic navigation shell
2) State management choice (Riverpod/Bloc) and a simple in-memory session store
3) Bucket definitions + ordering (from `docs/product/mtg_turn_model.md`)

### Phase 0.5 — Navigation shell (optional)
3.1) App drawer (hamburger) navigation: Timeline / Decks

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

### Phase 11 — Deck library (post-MVP)
Goal: avoid rescanning the same cards across games by saving OCR text (and later, optional thumbnails) into named decks.
34) Deck list screen (create/rename/delete)
35) Deck detail editor (add/edit/delete saved cards)
36) Add saved card to session timeline (pick bucket, then reorder/move as needed)
37) Optional: export/import decks as JSON (share between devices without accounts)
38) Optional: store small thumbnails per saved card (must still follow “no originals” rule)

## Do not start yet (scope guard)
- Cloud sync/accounts
- Cloud OCR
- Persistent timeline sessions across restarts (unless explicitly added)
- Card database integration
