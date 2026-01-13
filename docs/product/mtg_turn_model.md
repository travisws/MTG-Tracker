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
