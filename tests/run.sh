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

# The released quest databases the "real" scenarios read. By default the pinned releases below, checked against their
# SHA-256 so the scenarios' expected lines match their data, unpacked once into $cache/addons/<name>-<version>.
# QUESTLINKS_DATABASES=latest takes each one's newest release instead (needs gh), for the weekly drift check
# (.github/workflows/drift.yml), into $cache/latest/<name>. Only the listed folders are kept, when there are any.
# REAL_QUESTIEDB, REAL_DING, REAL_DONDATA and REAL_POLESTAR point the scenarios at other copies.
#
# name, repository, pinned tag, its asset, the asset's SHA-256, the asset's name in any release, folders to keep
databases="\
QuestieDB Questie/QuestieDB v1.1.1 QuestieDB-1.1.1-Forever.zip \
2527118d861e497fa40bdb6d061883bf09649d5f96e09de6885f578aefbb5e59 QuestieDB-*-Forever.zip
Ding moust4ki/DingGuideWoWForever v1.8.1 Ding-v1.8.1-forever.zip \
d9707c45f42dc95429129e4f476e07d37ee90d6e07e6e84256b390ef685285ea Ding-*-forever.zip
DonData WoW-Forever-Addons/dondata v1.3.0 DonData-v1.3.0.zip \
4409bd481f4b064bac6af488f3ae3cb57dd3a60cfdf3c04ed7f9283343a5127b DonData-*.zip
Polestar fitzforge/polestar v0.3.7.2 Polestar-0.3.7.2.zip \
f13ad9feae7ff75fe3de64d3fa845e69de2f779fd047f9e37795f4fcc54086f1 Polestar-[0-9]*.zip Polestar,Polestar_QuestDB"

unpack() { # zip dest folders
	python3 - "$1" "$2" "$3" <<-'PY'
		import sys, zipfile
		archive, dest, keep = sys.argv[1:]
		keep = [folder for folder in keep.split(",") if folder]
		with zipfile.ZipFile(archive) as z:
		    z.extractall(dest, [m for m in z.namelist() if not keep or m.split("/")[0] in keep])
	PY
	rm "$1"
}

mode="${QUESTLINKS_DATABASES:-pinned}"
declare -A where
summary=""
while read -r name repository pinned asset sum pattern keep; do
	override="REAL_$(tr '[:lower:]' '[:upper:]' <<<"$name")"
	if [[ -n "${!override:-}" ]]; then
		continue
	fi
	if [[ "$mode" == latest ]]; then
		dest="$cache/latest/$name"
		rm -rf "$dest"
		mkdir -p "$dest"
		tag=$(gh release view --repo "$repository" --json tagName --jq .tagName)
		gh release download "$tag" --repo "$repository" --pattern "$pattern" --dir "$dest"
		zips=("$dest"/*.zip)
		if [[ ${#zips[@]} -ne 1 || ! -f "${zips[0]}" ]]; then
			echo "$name $tag: expected one asset matching $pattern, found ${#zips[@]}" >&2
			exit 2
		fi
		echo "$name: newest release $tag (pinned $pinned), $(sha256sum "${zips[0]}" | cut -c1-12)"
		summary+="| $name | $tag | $pinned |"$'\n'
		unpack "${zips[0]}" "$dest" "${keep:-}"
	else
		dest="$cache/addons/$name-${pinned#v}"
		if [[ ! -f "$dest/.complete" ]]; then
			mkdir -p "$cache/addons"
			rm -rf "$dest"
			curl -fsSL -o "$dest.zip" "https://github.com/$repository/releases/download/$pinned/$asset"
			echo "$sum  $dest.zip" | sha256sum -c --quiet
			unpack "$dest.zip" "$dest" "${keep:-}"
			touch "$dest/.complete"
		fi
	fi
	where[$name]=$dest
done <<<"$databases"
if [[ -n "$summary" && -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
	printf '| Database | Newest release | Pinned |\n| --- | --- | --- |\n%s' "$summary" >>"$GITHUB_STEP_SUMMARY"
fi

export FOREVER_SIM="$repo/tools/forever_sim/"
export QUESTLINKS_SIM_CACHE="$cache"
export REAL_QUESTIEDB="${REAL_QUESTIEDB:-${where[QuestieDB]}/QuestieDB}"
export REAL_DING="${REAL_DING:-${where[Ding]}/Ding}"
export REAL_DONDATA="${REAL_DONDATA:-${where[DonData]}/DonData}"
export REAL_POLESTAR="${REAL_POLESTAR:-${where[Polestar]}}"
cd "$here"
luajit encodingutil_test.lua
exec luajit questlinks_test.lua "$@"
