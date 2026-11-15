"""Render the listing's chat screenshots from the addon's own output.

    python3 tools/screenshots.py

The chat text comes from tools/scene.lua: the addon's chat filter, run on SkillUp Forever's headless Forever client
(forever_sim). FOREVER_SIM_REPO points at a skillup-forever clone whose sim cache was fetched once with
`python3 tools/forever_sim/fetch.py` (default: a clone next to this repository). The lines are drawn with
forever-core's wowmock (FOREVER_CORE, default: a forever-core clone next to this repository) in the client's chat
font and class colours, fetched from wago.tools for wowmock's pinned build and cached under ~/.cache/wowmock/.
Needs luajit and Pillow. Player names are made up; quest names, IDs and levels are QuestieDB 1.1.1's.

The tooltip screenshots in docs/screenshots are in-game captures, not renders.
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "docs" / "screenshots"
SIM_REPO = Path(os.environ.get("FOREVER_SIM_REPO", REPO.parent / "skillup-forever")).expanduser()
FOREVER_CORE = Path(os.environ.get("FOREVER_CORE", REPO.parent / "forever-core")).expanduser()
SIM_CACHE = Path(
    os.environ.get("QUESTLINKS_SIM_CACHE", Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "questlinks-sim")
).expanduser()

if not (FOREVER_CORE / "tools" / "wowmock" / "wowmock.py").is_file():
    sys.exit(f"wowmock.py not found under {FOREVER_CORE}; set FOREVER_CORE to a forever-core checkout")
sys.path.insert(0, str(FOREVER_CORE / "tools" / "wowmock"))
import wowmock  # noqa: E402

LEVEL = 30  # the reader's level, which the link colours are relative to
CHANNEL_TAG = "[1. General - The Barrens] "
CHANNEL = wowmock.rgb("ffc0c0")  # the client's default colour for numbered channels, as captured in game
CHAT_FONT = wowmock.Font(wowmock.ARIALN, 14, CHANNEL, (1, -1))  # ChatFontNormal, from NumberFont_Shadow_Med
CHAT_ALPHA = 0.25  # DEFAULT_CHATFRAME_ALPHA
LINE = 16
PAD = 6
LABEL_FONT = wowmock.FONTS["GameFontNormal"]
LABEL_GAP = 6
PANEL_GAP = 18

# (name, class, message); every quest here is one QuestieDB 1.1.1 has at the level given. Only the green and grey
# bands depend on the client's UnitQuestTrivialLevelRange, which the sim stubs: green is 5 below LEVEL, green for any
# range of 5 or more, and grey is 13 below.
BEFORE_AFTER = [
    ("Torvash", "SHAMAN", "anyone doing [[34] Raptor Mastery (194)]?"),
    ("Kelvara", "DRUID", "LF2M [[32] The Kolkar of Desolace (1362)]"),
    ("Mossbrook", "WARRIOR", "where does [[17] The Spirits of Stonetalon (1061)] start?"),
]
DIFFICULTY = [
    ("Brakka", "WARRIOR", "LFG [[36] Raptor Mastery (195)]"),
    ("Torvash", "SHAMAN", "anyone doing [[34] Raptor Mastery (194)]?"),
    ("Kelvara", "DRUID", "where does [[30] The Barrens Port (1039)] end?"),
    ("Sarnik", "MAGE", "need 2 more for [[25] Stonetalon Standstill (25)]"),
    ("Mossbrook", "PRIEST", "[[17] The Spirits of Stonetalon (1061)] is a nice one"),
]

HYPERLINK = re.compile(r"\|H[^|]*\|h|\|h")


def sim_env():
    """The environment tests/run.sh gives the scenarios: a private sim cache linked to the clone's downloads."""
    if not (SIM_REPO / "tools" / "forever_sim" / "sim.lua").is_file():
        sys.exit(f"forever_sim not found under {SIM_REPO} (set FOREVER_SIM_REPO)")
    (SIM_CACHE / "taint").mkdir(parents=True, exist_ok=True)
    for name in ("wow-ui-source", "data", "db2"):
        source = SIM_REPO / "tools" / ".cache" / "forever_sim" / name
        if not source.exists():
            sys.exit(f"missing {source}: run python3 tools/forever_sim/fetch.py in {SIM_REPO}")
        link = SIM_CACHE / name
        if link.is_symlink() or link.exists():
            link.unlink()
        link.symlink_to(source)
    env = dict(os.environ)
    env.update(
        FOREVER_SIM=f"{SIM_REPO / 'tools' / 'forever_sim'}/",
        QUESTLINKS_SIM_CACHE=str(SIM_CACHE),
        QUESTLINKS_SCENE_LEVEL=str(LEVEL),
    )
    return env


def filtered(messages):
    """[(before, after)] for each message, from the addon's chat filter in the sim."""
    result = subprocess.run(
        ["luajit", str(REPO / "tools" / "scene.lua")],
        input="".join(f"{message}\n" for message in messages),
        text=True,
        capture_output=True,
        check=True,
        env=sim_env(),
    )
    rows = [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]
    if len(rows) != len(messages):
        sys.exit(f"scene.lua gave {len(rows)} lines for {len(messages)} messages:\n{result.stdout}{result.stderr}")
    return [(row["before"], row["after"]) for row in rows]


def class_colors(ui):
    return {
        row["Filename"]: "ff{:02x}{:02x}{:02x}".format(
            int(row["ClassColorR"]), int(row["ClassColorG"]), int(row["ClassColorB"])
        )
        for row in ui.wago.db2("ChrClasses")
    }


def chat_line(colors, name, class_name, body):
    """A channel message as the chat frame prints it, with the name in its class colour."""
    return f"{CHANNEL_TAG}[|c{colors[class_name]}{name}|r]: {HYPERLINK.sub('', body)}"


def text_width(ui, lines):
    probe = ui.canvas(1, 1)
    return max(probe.text_width(line, CHAT_FONT) for line in lines) + 2 * PAD


def chat_panel(ui, lines, label, width=None):
    width = width or text_width(ui, lines)
    top = LABEL_FONT.height + LABEL_GAP
    height = len(lines) * LINE + 2 * PAD
    canvas = ui.canvas(width, top + height)
    canvas.text(0, 0, label, LABEL_FONT)
    canvas.fill(0, top, width, height, (0, 0, 0, CHAT_ALPHA))
    for index, line in enumerate(lines):
        canvas.text(PAD, top + PAD + index * LINE + (LINE - CHAT_FONT.height) / 2, line, CHAT_FONT)
    return canvas


def before_after_scene(ui, colors):
    rows = filtered([message for _, _, message in BEFORE_AFTER])
    plain = [chat_line(colors, name, cls, row[0]) for (name, cls, _), row in zip(BEFORE_AFTER, rows, strict=True)]
    linked = [chat_line(colors, name, cls, row[1]) for (name, cls, _), row in zip(BEFORE_AFTER, rows, strict=True)]
    width = text_width(ui, plain + linked)
    before = chat_panel(ui, plain, "Without Clickable Quest Links: plain text from Questie", width)
    after = chat_panel(ui, linked, "With Clickable Quest Links: links you can click", width)
    return wowmock.scene(ui, [(before, 0, 0), (after, 0, before.height + PANEL_GAP)])


def difficulty_scene(ui, colors):
    rows = filtered([message for _, _, message in DIFFICULTY])
    panel = chat_panel(
        ui,
        [chat_line(colors, name, cls, row[1]) for (name, cls, _), row in zip(DIFFICULTY, rows, strict=True)],
        f"Colored by difficulty for a level {LEVEL} character",
    )
    return wowmock.scene(ui, [(panel, 0, 0)])


def main():
    ui = wowmock.Ui(scale=int(os.environ.get("SCALE", "2")))
    colors = class_colors(ui)
    for name, render in (("before-after", before_after_scene), ("difficulty-colors", difficulty_scene)):
        path = OUT / f"{name}.png"
        render(ui, colors).save(path)
        print(path.relative_to(REPO))


if __name__ == "__main__":
    main()
