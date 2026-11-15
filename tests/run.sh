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
# downloads instead of writing into the clone. The released quest databases the "real" scenarios read are fetched
# into the same cache once.
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

# The released quest databases, pinned and checked against their SHA-256 so the scenarios' expected lines match their
# data, each unpacked into $cache/addons/<name>-<version> once (only the listed folders, when there are any).
# REAL_QUESTIEDB, REAL_DING, REAL_DONDATA and REAL_POLESTAR point the scenarios at other copies.
fetch() { # name version url sha256 [folder...]
	local dest="$cache/addons/$1-$2" url=$3 sum=$4
	shift 4
	if [[ -f "$dest/.complete" ]]; then
		return
	fi
	mkdir -p "$cache/addons"
	rm -rf "$dest"
	curl -fsSL -o "$dest.zip" "$url"
	echo "$sum  $dest.zip" | sha256sum -c --quiet
	python3 - "$dest.zip" "$dest" "$@" <<-'PY'
		import sys, zipfile
		archive, dest, *keep = sys.argv[1:]
		with zipfile.ZipFile(archive) as z:
		    z.extractall(dest, [m for m in z.namelist() if not keep or m.split("/")[0] in keep])
	PY
	rm "$dest.zip"
	touch "$dest/.complete"
}
releases=https://github.com
[[ -n "${REAL_QUESTIEDB:-}" ]] || fetch QuestieDB 1.1.1 \
	"$releases/Questie/QuestieDB/releases/download/v1.1.1/QuestieDB-1.1.1-Forever.zip" \
	2527118d861e497fa40bdb6d061883bf09649d5f96e09de6885f578aefbb5e59
[[ -n "${REAL_DING:-}" ]] || fetch Ding 1.8.1 \
	"$releases/moust4ki/DingGuideWoWForever/releases/download/v1.8.1/Ding-v1.8.1-forever.zip" \
	d9707c45f42dc95429129e4f476e07d37ee90d6e07e6e84256b390ef685285ea
[[ -n "${REAL_DONDATA:-}" ]] || fetch DonData 1.3.0 \
	"$releases/WoW-Forever-Addons/dondata/releases/download/v1.3.0/DonData-v1.3.0.zip" \
	4409bd481f4b064bac6af488f3ae3cb57dd3a60cfdf3c04ed7f9283343a5127b
[[ -n "${REAL_POLESTAR:-}" ]] || fetch Polestar 0.3.7.2 \
	"$releases/fitzforge/polestar/releases/download/v0.3.7.2/Polestar-0.3.7.2.zip" \
	f13ad9feae7ff75fe3de64d3fa845e69de2f779fd047f9e37795f4fcc54086f1 Polestar Polestar_QuestDB

export FOREVER_SIM="$repo/tools/forever_sim/"
export QUESTLINKS_SIM_CACHE="$cache"
export REAL_QUESTIEDB="${REAL_QUESTIEDB:-$cache/addons/QuestieDB-1.1.1/QuestieDB}"
export REAL_DING="${REAL_DING:-$cache/addons/Ding-1.8.1/Ding}"
export REAL_DONDATA="${REAL_DONDATA:-$cache/addons/DonData-1.3.0/DonData}"
export REAL_POLESTAR="${REAL_POLESTAR:-$cache/addons/Polestar-0.3.7.2}"
cd "$here"
luajit encodingutil_test.lua
exec luajit questlinks_test.lua "$@"
