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

Session-only timeline: everything on the current timeline is temporary and wipes on Reset.
Deck library (optional): saved decks/cards are reusable across sessions and have their own delete controls; they store only text/metadata (no original photos).

## MVP user stories
1) As a player, I can take a photo of a card and crop the rules text so the app can OCR it.
2) As a player, I can crop the artwork to generate a small thumbnail that helps identify the card.
3) As a player, I can place the item into the correct turn step bucket (Upkeep, Attackers, etc.).
4) As a player, I can reorder items within a bucket.
5) As a player, I can swipe an item away to Trash and undo/restore it during the session.
6) As a player, pressing Reset wipes the current session (timeline data + thumbnails).
7) As a player, I can save reminders into decks and add them back into a session later (no rescanning).

## Out of scope (MVP)
- Any network sync / accounts / cloud storage
- Cloud OCR
- Long-term persistence across app restarts (unless explicitly added later)
- Card database integration (name lookup, oracle text validation, etc.)

## UX principles
- Fast in live play: few taps, minimal navigation.
- High signal: list shows thumbnail + short text snippet.
- Safe actions: swipe-to-trash with undo; Reset requires confirmation.
