# CurseForge project page

Paste these into the project settings. The repository is the source of truth; edit here first.

The live page matches this text since 2026-11-15 (v1.1.2): the description and the third screenshot's description.
CurseForge's editor keeps the description as Markdown in its own style (`*   ` bullets, the brackets in the example
escaped), so change the sentences there rather than pasting the whole section over it.

## Summary

Makes Questie's plain-text quest links clickable for players who don't use Questie.

## Description

Players running Questie send quests in chat as plain text, like **[[34] Raptor Mastery (194)]**. Without Questie
you can't click them.

**Clickable Quest Links** turns that text into the game's own quest link:

- **Click it** to open the quest tooltip. With a quest database installed (**QuestieDB**, **Ding!**, **Polestar
  Guides** or **DonData**), it also shows the quest's level, the level it requires, and who starts and ends it, with
  their zone. That works for every quest link you open from chat.
- **Shift-click it** to put it in your chat message: as the game's own quest link when the quest is in your quest log,
  otherwise as Questie's text, which Questie users and players with this addon see as a link.
- **Its colour** shows how hard the quest is for you, as in your quest log. Prefer plain yellow? Turn off "Color links
  by difficulty" in Options, AddOns, Clickable Quest Links, or type **/cql**.

If you install Questie later, this addon steps aside and lets Questie handle the links.

**Optional:** any one of QuestieDB, Ding!, Polestar Guides or DonData, for the extra tooltip lines and for links sent
without a quest level. It reads the one you already run.

Bugs, ideas and translation fixes: https://github.com/Rambomst/clickable-quest-links/issues

---

### Buy me a coffee?

<a href="https://ko-fi.com/ram01"><img src="https://storage.ko-fi.com/cdn/brandasset/v2/support_me_on_kofi_beige.png" alt="Support me on Ko-fi" width="254" height="51"></a>

## Donation

General tab, Donation Method: Ko-fi, username `ram01` (set 2026-11-16): a Donate link on the project page. The
description also ends with the Ko-fi badge above, as the Nexus pages do (on the page since 2026-11-16).

The badge is HTML because only HTML keeps its size: the image is 980 by 198. The editor shows a saved description
back as Markdown and turns the badge into `[![Support me on Ko-fi](...)](https://ko-fi.com/ram01)` without the size,
so before saving any later edit, put the HTML line back in its place, or the badge goes up at full width.

## Screenshots

Under Media, in this order, with these titles and descriptions, all four marked Feature Media (uploaded 2026-11-15).
The two chat images are drawn by `tools/screenshots.py` from the addon's own output; the two tooltips are in-game
captures.

1. `docs/screenshots/before-after.png`
   - Title: Before and after
   - Description: Questie's plain-text quest links become links you can click. Drawn from the addon's own output in
     the game's chat font; the player names are made up.
2. `docs/screenshots/difficulty-colors.png`
   - Title: Colored by difficulty
   - Description: Each link takes the quest's difficulty color for your character, as in the quest log. Turn it off
     with /cql.
3. `docs/screenshots/tooltip-start-end.png`
   - Title: Who starts and ends it
   - Description: Click a link to open the quest. With a quest database, the tooltip adds the quest's level and who
     starts and ends it, with their zone.
4. `docs/screenshots/tooltip-objectives.png`
   - Title: Objectives and level
   - Description: The game's own objectives, with the quest's level and the level it requires.
