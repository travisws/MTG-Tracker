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
- After capture + crop, choose the step to add the card into

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
- OCR text hidden until tap (full text in popup)
- Optional chips: Until EOT, Response, etc.

Right:
- Optional restore icon for Trash

Tap:
- Popup with full OCR text + notes

## Gestures
Swipe:
- One direction only: move to Trash
- Snackbar with Undo

Long-press:
- Action sheet: Move to..., Save to deck..., Trash

Reorder:
- Cross-step move via long-press actions (Move to...)

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
