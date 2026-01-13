# Storage and Lifecycle (Session timeline + Deck library)

## Goal
Never persist full-resolution photos. Keep only:
- OCR text (string)
- Small thumbnail (art crop)
- Session metadata (bucket + order + notes)

Everything in the session must be wiped on Reset.

## Deck library (reusable, local)
If using decks, the app may persist:
- Deck + saved-card metadata (labels/notes)
- OCR text (string)
- Small thumbnail bytes for saved cards (optional, user-deletable with the deck)

Do not persist original photos or intermediate crops for decks.

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

Reset does not delete the deck library; decks are deleted from the Decks screen.

Optional (recommended):
- On app startup, purge the thumbnail folder to guarantee blank sessions after relaunch.

## Thumbnail sizing
- Target: 256–320px square
- Compress: JPEG/WebP at moderate quality
- Keep thumbnails small to reduce disk and decode memory
- Deck thumbnail bytes are capped (256 KB) when saving to a deck

## Rendering performance notes (Flutter)
- Use Image.file with cacheWidth/cacheHeight matching display size to prevent oversized decoded images.
- Avoid holding decoded full-size images in memory.
