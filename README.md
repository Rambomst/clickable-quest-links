# Clickable Quest Links

A World of Warcraft: Forever addon that makes Questie's quest links clickable for players who don't use Questie.

Questie sends quests in chat as plain text, like `[[34] Raptor Mastery (194)]`, because the chat server strips addon
links. Only another Questie user's game turns that text back into a link; everyone else sees text they can't click.

This addon turns that text into the game's own quest link:

![Questie's text in chat, and the same messages with the addon](docs/screenshots/before-after.png)

- **Click it** to open Blizzard's quest tooltip. With a [quest database](#quest-databases) installed, the tooltip
  also shows the quest's level, the level it requires, and who starts and ends it, with their zone. That works for
  every quest link you open from chat, including normal ones.
- **Shift-click it** to put it in your chat message. If the quest is in your quest log, it goes in as the game's own
  quest link, which anyone can click. If not, it goes in as Questie's text, which Questie users and players with this
  addon see as a link: a quest link made by an addon arrives as plain text. The same goes for any quest link you
  shift-click from chat.
- **Its colour** shows how hard the quest is for your character, as in the quest log: grey, green, yellow, orange or
  red. To keep links yellow, turn off "Color links by difficulty" in Options, AddOns, Clickable Quest Links (`/cql`
  opens it).

## Install

Install it from [CurseForge](https://www.curseforge.com/wow/addons/clickable-quest-links), by hand or with an addon
manager, or extract the zip from the newest [release](https://github.com/Rambomst/clickable-quest-links/releases)
into `World of Warcraft/_forever_/Interface/AddOns`.

## What gets converted

- `[[34] Raptor Mastery (194)]`, which Questie sends when it shows quest levels. Always converted, even for a quest
  your quest database doesn't have yet.
- `[Raptor Mastery (194)]`, which Questie sends when quest levels are hidden. Only when a quest database or the game
  itself knows that quest by that name, because text like that turns up in normal chat too.
- Item links and other links in the same message are left alone.
- With Questie installed, this addon does nothing: Questie already handles these links.

Messages the game hides from addons, as it can in instances, stay as they are.

## Quest databases

The extra tooltip lines come from whichever of these you already run. When you have more than one, the first in this
list that knows the quest is used:

| Addon | Gives |
| --- | --- |
| [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) | level, required level, who starts and ends the quest, with their zone |
| [Ding!](https://www.curseforge.com/wow/addons/ding-xp-and-leveling-guide) (its DingDB) | the same, and English quest names, so `[Name (id)]` from an English client converts on any client |
| [Polestar Guides](https://www.curseforge.com/wow/addons/polestar) | the same, while one of Polestar's quest features is on (its quest data loads only then) |
| [DonData](https://www.curseforge.com/wow/addons/dondata) (with Questdon or Leveldon) | the required level, and a starter and a finisher once the game or DonData's records know their names; the level comes from the link or the game |

With none of them, links still convert and open Blizzard's own quest tooltip.

RestedXP has no quest data to read: its Forever files map quests to items, and quest and NPC names appear only in
guide text.

## Bugs, ideas and translations

Report bugs and ideas as an [issue](https://github.com/Rambomst/clickable-quest-links/issues). The tooltip labels are
translated for every client language at the top of `ClickableQuestLinks.lua`; corrections from native speakers are
welcome as an issue or a pull request.

## Support

If Clickable Quest Links is useful to you and you'd like to say thanks, you can
[buy me a coffee on Ko-fi](https://ko-fi.com/ram01). It's free either way.

## Development

Everything the addon runs is in `ClickableQuestLinks.lua`:

- `Rewrite` and `Filter`: the chat filter that turns Questie's text into links.
- `OnInsertLink`: what goes in the chat box when a quest link is shift-clicked.
- `AddQuestInfo`: the tooltip lines a quest database adds.
- `LinkColor`: a converted link's colour.
- `SOURCES`: the quest databases, best first; the comment above it says what each entry provides. A new database
  needs an entry there, a stand-in with its API's shape in `tests/fixtures`, and scenarios in
  `tests/questlinks_test.lua`, as the other four have.
- `TRANSLATIONS`: the tooltip labels and the option's text in each client language.

Lua is formatted with [StyLua](https://github.com/JohnnyMorganz/StyLua): run `stylua .`, which reads `.stylua.toml`.

### Tests

The tests run the addon on forever_sim, the headless Forever client from
[forever-core](https://github.com/cjber/forever-core), against Blizzard's real chat and tooltip code. They need
LuaJIT, Python 3, git and curl:

```bash
tests/run.sh
```

The first run downloads forever_sim at the commit pinned in `tests/forever_sim.txt`, the Blizzard UI source and
client data it runs against, and the quest databases the "real" scenarios read, into `~/.cache/questlinks-sim`.

- `tests/run.sh "shift-click"` runs only the scenarios whose names contain that text.
- `FOREVER_SIM` points the tests at another forever_sim folder, such as the one in a forever-core checkout
  (`.agents/skills/wow-forever-addon/tooling/forever_sim`).
- Most scenarios use small stand-ins for the quest databases. The "real" ones read released QuestieDB, Ding!,
  Polestar and DonData builds, pinned in `tests/run.sh`. `QUESTLINKS_DATABASES=latest` takes each one's newest
  release instead (needs the GitHub CLI), and `REAL_QUESTIEDB`, `REAL_DING`, `REAL_POLESTAR` and `REAL_DONDATA`
  point at copies of your own.

CI runs the tests on every push and pull request.

### In game

Some things only the real client has: its zone names, its quest data and the colour its quest log gives a quest.
`tests/ingame/ClickableQuestLinks_SelfTest` is a development-only addon that checks those:

1. Copy or link this repository into `Interface/AddOns` as `ClickableQuestLinks` (the folder name has to match the
   TOC's), and `tests/ingame/ClickableQuestLinks_SelfTest` next to it. Disable Questie: with it loaded, this addon
   stays out of the way. Restart the game, which only looks for new addon folders at startup.
2. Type `/cqltest`. It sends the test quests through the client's chat filters, opens their tooltips, and prints how
   many checks passed and which failed. The expected tooltip lines are an English client's; on other languages it
   says what it left out.
3. With more than one quest database installed, `/cqltest rounds` runs it once with each of them enabled alone,
   reloading between rounds (click Reload UI when it asks), and then puts your AddOns list back. `/cqltest stop`
   ends the rounds early.

Each run is also kept in the self-test's saved variables, which the game writes at the next `/reload`.

## License

MIT
