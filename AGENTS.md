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

## Coding style (agent-friendly)
- Prefer small, focused files: if a file grows past ~200 lines (especially UI), split into feature-scoped widgets/sheets.
- Organize by feature: `lib/features/<feature>/` owns its screen + widgets; shared models in `lib/models/`, MTG domain constants in `lib/mtg/`, session state in `lib/session/`.
- Keep UI “dumb”: business rules and mutations live in the session store (or later, dedicated services), not inside widgets.
- Keep diffs incremental: avoid broad refactors unless they directly unblock the milestone; add/adjust tests alongside behavior changes.
- Maintain session-only timeline guarantees: Reset must clear in-memory session state and purge cached thumbnails; deck library persistence is allowed only for saved decks/cards and must be user-deletable.
- Deck library may persist small thumbnail files for saved cards; these persist until the deck is deleted.

## Non-negotiable constraints
- Session-only timeline: current timeline items/ordering/notes/OCR text must be wiped on Reset.
- Deck library is separate: saved decks/cards may persist locally across sessions and must have a clear “Delete all decks” control.
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
