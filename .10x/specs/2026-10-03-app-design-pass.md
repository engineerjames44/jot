# Jot design pass: analysis and proposed direction

Branch `app-design-pass`. Screens reviewed in the iPhone 17 simulator with sample data:
onboarding, Today, Inbox, item detail, Settings, capture (listening, confirmation).

Done already on this branch: greeting by name (onboarding step with live preview,
Settings field, Today header, morning brief title), 3 new tests.

## What's wrong now

### Visual
1. **Every item is the same card.** White rounded card, coloured leading bar, caps kind
   label with a coloured dot. The kind is shown three times (rail node, bar, label), so
   the list is loud and nothing stands out.
2. **Caps labels everywhere.** The date, TIMELINE, ANYTIME, REMINDER, EVENT, EVERYTHING
   YOU'VE CAPTURED, CLAUDE, SMART SORTING. They flatten the hierarchy and read as a template.
3. **Orange means three things.** It's the brand and record orb, the "now" line, and the
   "Overdue" warning. Three of four morning items are orange-flagged, so the orb's colour
   stops meaning "live".
4. **The orb covers content.** The orb floats over the bottom card, and the floating tab
   bar sits under it, so roughly the bottom fifth of Today and Inbox is hidden.
5. **Header counts add little.** "2 events, 2 reminders, 3 tasks" repeats what the
   timeline shows and doesn't say what matters (what's next, what's left).
6. **Inbox repeats itself.** The count 11 appears three times, and the filter chips
   are cut off ("Notes" is clipped).
7. **Settings starts with branding.** A large wordmark and tagline take the top of the
   screen; the Morning brief, one of the best features, is buried in Settings.
8. **Detail screen title** collides with the status bar area when it scrolls.

### UX
9. **Overdue items pile up in the morning slots** with no "move to tomorrow" action.
10. **No voice correction.** After a capture you can Undo or Edit by hand, but not say
    "no, Friday".
11. **Capture is small.** The defining moment (talking to Jot) happens in a small
    card over the list. It should feel like the app's signature moment.

### Integrations
Already have: Siri and Shortcuts, Control Center control, Action Button, Home and
Lock Screen widgets, Live Activity, notification Done and Snooze, calendar read.

Missing, in priority order:
- **P1: On-device sorting with Apple's Foundation Models (iOS 26).** Sorting works
  offline and without sending anything, with Claude as an opt-in fallback. This is
  the strongest privacy story and removes the consent step for most users.
- **P1: Add to Calendar and Apple Reminders.** Write events to the calendar and
  reminders to Reminders, so Jot fits how people already work.
- **P1: Interactive widgets.** Check items off from the Home and Lock Screen.
- **P1: Spotlight and Siri queries.** Index items and expose App Intent entities, so
  "What's on Jot today?" works.
- **P2: Apple Watch capture.** Hold to talk on the wrist. This is the closest thing to
  the hardware device and a strong demo.
- **P2: Contacts.** "Send Sam the trip photos" links to Sam, with Message or Call.
- **P2: Location reminders.** "When I get home…".
- **P2: Share extension.** Send text or links into Jot to be sorted.
- **P3: Focus filters, StandBy.**

## Proposed direction: "Instrument"

Jot is a voice recorder that becomes a device. Design the app like that instrument:
calm, precise, with one live light, which is the orb.

**Colour.** Orange means live (recording, now) and nothing else.
- Ink `#1D1D1F`
- Surface `#FFFFFF` and Ground `#F2F2F4` (cool, not cream)
- Graphite `#6E6E73` for secondary text
- Rule `#DCDCE0`
- Signal `jotAccent` (existing orange), only for live states
- Kind colours stay, but only as the small rail node.
- Dark mode uses true black, plus `#1C1C1E` surfaces.

**Type.**
- SF Pro Rounded Heavy only for the wordmark and the greeting.
- SF Pro for content, at Dynamic Type sizes.
- SF Mono for times, like a device readout, so the time column lines up.
- Sentence case labels; no tracked caps.

**Layout (Today).** Items are lines on one rail, not cards. Overdue items fold into
one "Still open from earlier" row with "Move to tomorrow". The orb sits in the tab
bar, between Today and Inbox. Settings moves to a round initial badge (your name's
first letter) at the top right.

```
Saturday 3 October                      (J)
Good afternoon,
James
Next: Dinner with Sam at 7:30

 9:30 ●  Standup with design
         Bring the new timeline mocks
12:00 ■  Send invoice to Northwind      ○
── 15:53 ────────────────────────────────
19:30 ●  Dinner with Sam · Dishoom

Still open from earlier (2)   Move to tomorrow
Anytime
Notes

   [ Today ]   ( ◉ orb )   [ Inbox ]
```

**The one bold moment: capture.** Holding the orb dims the screen to ink. Your words
appear large in the centre as you speak. On release, the sentence shrinks and slides
into its slot on the timeline. Everything else stays quiet.

**Review against the brief.** The first draft kept rounded cards with coloured bars,
which is the default for any to-do app. It was changed to a single rail with lines,
because the timeline and the voice are what make Jot specific. Cream backgrounds and
tracked caps were rejected as defaults.
