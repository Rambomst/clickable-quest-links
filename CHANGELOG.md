# Changelog

## v1.1.0

- Quest tooltips also read Ding!'s DingDB, Polestar's quest database and DonData, not only QuestieDB: whichever you
  run. With more than one, QuestieDB comes first, then Ding!, Polestar and DonData.
- `[[34] Raptor Mastery (194)]` now converts even for a quest your quest database doesn't have yet.
- `[Raptor Mastery (194)]` also converts when the game itself knows the quest by that name, or, with Ding!, by its
  English name.

## v1.0.0

First release.

- Turns Questie's plain-text quest links in chat, `[[34] Raptor Mastery (194)]` and `[Raptor Mastery (194)]`, into
  the game's own clickable quest links.
- With QuestieDB installed, quest tooltips opened from chat also show the quest's level, required level, and where it
  starts and ends.
- Converted links are coloured by the quest's difficulty for your character, with an option to keep them yellow
  (Options, AddOns, Clickable Quest Links, or `/cql`).
- Shift-clicking a quest link in chat inserts the game's own link when the quest is in your quest log, and Questie's
  text otherwise, so it survives being sent.
- Tooltip labels and the option in every client language.
- Does nothing when Questie is installed.
