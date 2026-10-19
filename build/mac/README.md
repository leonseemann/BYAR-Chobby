# BAR launcher for macOS

This fork builds BAR's launcher for Apple Silicon Macs the way
`.github/workflows/launcher.yml` builds the Linux and Windows launchers: the
launcher from spring-launcher (here leonseemann/spring-launcher, branch
`mac-support`, until macOS support is upstream) with `dist_cfg` on top. The app
holds only the launcher. On start it downloads the macOS engine from
github.com/leonseemann/RecoilEngine releases and the game through the engine's
pr-downloader. It updates itself from this fork's releases.

## Files

- `build/mac/build.sh`: builds `BAR.app`, DMG, zip and `latest-mac.yml`.
  BAR's artwork stays out of the app, it has no license for redistribution.
- `build/mac/make_config.py`: writes the macOS launcher config from
  `dist_cfg/config.json`. The macOS setups ("Alpha", "Engine Test") are the
  Linux ones with the newest macOS engine release (tag
  `<engine version>-mac.<n>`) of the same engine version.
- `build/mac/version_info.js`: renderer extension showing the launcher and
  engine version in the footer.

## Releases and engine updates

- `.github/workflows/launcher_mac.yml` builds every push and PR. A manual run
  signs, notarizes and publishes the launcher as release `v1.<commits>.0`.
- `.github/workflows/publish_config_mac.yml` runs hourly. It writes the config
  from BAR's current `dist_cfg/config.json` to the `launcher-config` branch,
  which launchers read on every start. So BAR's engine switches and new macOS
  engine releases need no launcher release.
- The branch `mac` is BAR's master plus this port as linear commits; it is
  rebased onto master by hand before a launcher release.

## AI assistance

The macOS port of the launcher was written with Claude Code (Anthropic):
- the darwin support on spring-launcher's `mac-support`
- the macOS config generator, build, signing and notarization workflows

The human contributor (Leon Seemann) set the goals, made the decisions,
reviewed the changes and tested the launcher on their Mac: install from the
DMG, self-update, engine and game downloads, starting games.
