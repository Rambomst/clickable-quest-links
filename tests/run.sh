#!/usr/bin/env bash
# Runs the Clickable Quest Links scenario tests on SkillUp Forever's headless Forever client (forever_sim).
#
#   tests/run.sh                 # every scenario
#   tests/run.sh "shift-click"   # scenarios whose name contains the text
#
# Needs luajit, curl, python3 and a clone of github.com/cjber/skillup-forever whose sim cache was fetched once with
# `python3 tools/forever_sim/fetch.py`. FOREVER_SIM_REPO points at the clone; by default it is a skillup-forever
# folder next to this repository. CI pins the commit the tests were last run against (.github/workflows/ci.yml).
# The sim writes rewritten Blizzard code to its cache, so this keeps a private one that links to the clone's
# downloads instead of writing into the clone. The real QuestieDB the database scenarios read is fetched into the
# same cache once.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="${FOREVER_SIM_REPO:-$(cd "$here/../.." && pwd)/skillup-forever}"
cache="${QUESTLINKS_SIM_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/questlinks-sim}"

if [[ ! -f "$repo/tools/forever_sim/sim.lua" ]]; then
	echo "forever_sim not found under $repo (set FOREVER_SIM_REPO)" >&2
	exit 2
fi
for d in wow-ui-source data db2; do
	if [[ ! -e "$repo/tools/.cache/forever_sim/$d" ]]; then
		echo "missing $repo/tools/.cache/forever_sim/$d: run python3 tools/forever_sim/fetch.py in $repo" >&2
		exit 2
	fi
done

mkdir -p "$cache/taint"
for d in wow-ui-source data db2; do
	ln -sfn "$repo/tools/.cache/forever_sim/$d" "$cache/$d"
done

# The pinned QuestieDB release, checked against its SHA-256 so the scenarios' expected lines match its data.
# REAL_QUESTIEDB points the scenarios at another copy, such as an installed one.
questiedb_version=1.1.1
questiedb_sha256=2527118d861e497fa40bdb6d061883bf09649d5f96e09de6885f578aefbb5e59
if [[ -z "${REAL_QUESTIEDB:-}" ]]; then
	REAL_QUESTIEDB="$cache/addons/QuestieDB-$questiedb_version/QuestieDB"
	if [[ ! -f "$REAL_QUESTIEDB/QuestieDB_Forever.toc" ]]; then
		zip="$cache/addons/QuestieDB-$questiedb_version-Forever.zip"
		mkdir -p "$cache/addons"
		curl -fsSL -o "$zip" \
			"https://github.com/Questie/QuestieDB/releases/download/v$questiedb_version/QuestieDB-$questiedb_version-Forever.zip"
		echo "$questiedb_sha256  $zip" | sha256sum -c --quiet
		python3 -m zipfile -e "$zip" "$cache/addons/QuestieDB-$questiedb_version"
		rm "$zip"
	fi
fi

export FOREVER_SIM="$repo/tools/forever_sim/"
export QUESTLINKS_SIM_CACHE="$cache"
export REAL_QUESTIEDB
cd "$here"
luajit encodingutil_test.lua
exec luajit questlinks_test.lua "$@"
