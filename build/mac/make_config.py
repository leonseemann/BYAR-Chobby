#!/usr/bin/env python3
"""Writes the launcher config of BAR for macOS.

Defaults, links, server and spring settings come from dist_cfg/config.json,
except the lobby server, which is localhost until macOS is cleared for online
play.
Its setups are replaced by macOS ones derived from the Linux setups, with the
engine from the newest macOS engine release (tag <engine version>-mac.<n>) of
the version that setup uses. The Engine Test setup is left out while it uses
the main engine or has no macOS release yet; exits with 1 if the main setup
has none.

Usage: make_config.py <dist_cfg/config.json> <output config.json>
"""
import copy
import json
import os
import sys
import urllib.request

ENGINE_REPO = "leonseemann/RecoilEngine"
CONFIG_URL = "https://raw.githubusercontent.com/leonseemann/BYAR-Chobby/launcher-config/config.json"


def release_tags():
	"""{engine version: newest release tag} of the macOS engine releases"""
	request = urllib.request.Request(f"https://api.github.com/repos/{ENGINE_REPO}/releases?per_page=100")
	token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
	if token:
		request.add_header("Authorization", f"Bearer {token}")
	with urllib.request.urlopen(request) as response:
		releases = json.load(response)
	releases.sort(key=lambda r: r["published_at"] or "")
	tags = {}
	for r in releases:
		version = r["tag_name"].partition("-mac.")[0]
		if not r["draft"] and any(a["name"] == f"recoil_{version}_arm64-macos.7z" for a in r["assets"]):
			tags[version] = r["tag_name"]
	return tags


def mac_setup(base, package_id, tag):
	version = tag.partition("-mac.")[0]
	# named after the release, so rebuilt engines of the same version are downloaded again
	engine = f"recoil_{tag}"
	setup = copy.deepcopy(base)
	setup["package"].update(id=package_id, platform="darwin")
	setup["config_url"] = CONFIG_URL
	resources = [r for r in setup["downloads"]["resources"] if not r["destination"].startswith("engine/")]
	resources.append({
		"url": f"https://github.com/{ENGINE_REPO}/releases/download/{tag}/recoil_{version}_arm64-macos.7z",
		"destination": f"engine/{engine}",
		"extract": True,
	})
	setup["downloads"]["resources"] = resources
	setup["launch"]["engine"] = engine
	return setup


def find_setup(config, package_id):
	return next((s for s in config["setups"] if s["package"]["id"] == package_id), None)


def engine_version(setup):
	return setup["launch"]["engine"].removeprefix("recoil_")


def main():
	with open(sys.argv[1]) as f:
		config = json.load(f)
	tags = release_tags()

	base = find_setup(config, "manual-linux")
	version = engine_version(base)
	if version not in tags:
		sys.exit(f"no macOS engine release for {version}")
	setups = [mac_setup(base, "manual-mac", tags[version])]

	test_base = find_setup(config, "manual-linux-test-engine")
	if test_base and engine_version(test_base) != version:
		if engine_version(test_base) in tags:
			setups.append(mac_setup(test_base, "manual-mac-test-engine", tags[engine_version(test_base)]))
		else:
			print(f"no macOS engine release for {engine_version(test_base)}, no Engine Test setup", file=sys.stderr)
	config["setups"] = setups
	# not cleared for online play yet; set the address in Settings to play online
	config["json_files"]["chobby_config.json"]["server"]["address"] = "localhost"

	with open(sys.argv[2], "w") as f:
		json.dump(config, f, indent=4)
		f.write("\n")
	print("\n".join(s["package"]["display"] + ": " + s["launch"]["engine"] for s in setups))


main()
