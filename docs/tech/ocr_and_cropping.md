# OCR and Cropping

## OCR requirements
- On-device only (ML Kit)
- No network usage required
- Store only extracted text (string)

Suggested package:
- google_mlkit_text_recognition

## Current implementation
- OCR runs immediately after the text crop, before the art crop.
- Text crop is deleted right after OCR completes.
- OCR input is lightly preprocessed (grayscale + normalize) before recognition.
- User reviews/edits the OCR text before choosing a step.

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
