#!/usr/bin/env bash
# Runs the Clickable Quest Links scenario tests on SkillUp Forever's headless Forever client (forever_sim).
#
#   tests/run.sh                 # every scenario
#   tests/run.sh "shift-click"   # scenarios whose name contains the text
#
# Needs luajit and a clone of github.com/cjber/skillup-forever whose sim cache was fetched once with
# `python3 tools/forever_sim/fetch.py`. FOREVER_SIM_REPO points at the clone; by default it is a skillup-forever
# folder next to this repository. CI pins the commit the tests were last run against (.github/workflows/ci.yml).
# The sim writes rewritten Blizzard code to its cache, so this keeps a private one that links to the clone's
# downloads instead of writing into the clone.
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

export FOREVER_SIM="$repo/tools/forever_sim/"
export QUESTLINKS_SIM_CACHE="$cache"
cd "$here"
exec luajit questlinks_test.lua "$@"
