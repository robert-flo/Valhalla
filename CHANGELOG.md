# Changelog

All notable changes to the RaVN hardfork are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
RaVN does not yet publish versioned releases, so completed work remains under
`Unreleased` until the first release is tagged.

## Unreleased

### Added

- Integrated the personal RaVN package set into the core installation
  ([#4](https://github.com/robert-flo/Valhalla/pull/4)).
- Added the `ravn-dot` workflow for managing the personal dotfiles repository
  ([#6](https://github.com/robert-flo/Valhalla/pull/6)).
- Added an assistant for configuring the personal Git environment
  ([#8](https://github.com/robert-flo/Valhalla/pull/8)).
- Added `git-bare-clone` for bootstrapping bare repositories with
  upstream-tracking worktrees ([#12](https://github.com/robert-flo/Valhalla/pull/12)).
- Added deployable Todo, Countdown, localized weather, Spotify, and recording
  controls across the RaVN Waybar layouts
  ([#18](https://github.com/robert-flo/Valhalla/pull/18)).
- Added the repository validation tools and shell utility dependencies to the
  RaVN package manifest ([#19](https://github.com/robert-flo/Valhalla/pull/19)).

### Changed

- Made issue worktree directory and branch names match consistently
  ([#10](https://github.com/robert-flo/Valhalla/pull/10)).
- Adopted a protected, master-only pull request workflow with repository
  validation ([#14](https://github.com/robert-flo/Valhalla/pull/14)).
