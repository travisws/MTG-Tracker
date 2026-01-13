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
