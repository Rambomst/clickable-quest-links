# Clickable Quest Links

A World of Warcraft: Forever addon that makes Questie's quest links clickable for players who don't use Questie.

Questie sends quests in chat as plain text, like `[[34] Raptor Mastery (194)]`, because the chat server strips addon
links. Only another Questie user's game turns that text back into a link; everyone else sees text they can't click.

This addon turns that text into the game's own quest link:

- **Click it** to open Blizzard's quest tooltip. With [QuestieDB](https://www.curseforge.com/wow/addons/questiedb)
  installed, the tooltip also shows the quest's level, the level it requires, and who starts and ends it, with their
  zone. That works for every quest link you open from chat, including normal ones.
- **Shift-click it** to put it in your chat message. If the quest is in your quest log, it goes in as the game's own
  quest link, which anyone can click. If not, it goes in as Questie's text, which Questie users and players with this
  addon see as a link: a quest link made by an addon arrives as plain text. The same goes for any quest link you
  shift-click from chat.
- **Its colour** shows how hard the quest is for your character, as in the quest log: grey, green, yellow, orange or
  red. To keep links yellow, turn off "Color links by difficulty" in Options, AddOns, Clickable Quest Links (`/cql`
  opens it).

## What gets converted

- `[[34] Raptor Mastery (194)]`, which Questie sends when it shows quest levels. With QuestieDB installed, only quests
  it knows are converted.
- `[Raptor Mastery (194)]`, which Questie sends when quest levels are hidden. Only with QuestieDB installed, and only
  when the name matches the quest, because text like that turns up in normal chat too.
- Item links and other links in the same message are left alone.
- With Questie installed, this addon does nothing: Questie already handles these links.

Messages the game hides from addons, as it can in instances, stay as they are.

## Translations

The tooltip labels are translated for every client language at the top of `ClickableQuestLinks.lua`. Corrections
from native speakers are welcome as an issue or a pull request.

## Development

The tests run the addon on forever_sim, the headless Forever client in
[SkillUp Forever's repository](https://github.com/cjber/skillup-forever), against Blizzard's real chat and tooltip
code. They need LuaJIT, Python 3 and a SkillUp Forever clone next to this repository:

```bash
git clone https://github.com/cjber/skillup-forever ../skillup-forever
(cd ../skillup-forever && python3 tools/forever_sim/fetch.py)
tests/run.sh
```

`FOREVER_SIM_REPO` points the tests at a clone somewhere else. CI runs them on every push, pinned to the commit in
`.github/workflows/ci.yml`.

Pushing a `v*` tag runs the tests, then BigWigsMods/packager builds the zip and publishes it to GitHub Releases,
CurseForge and, when configured, Wago.

## License

MIT
