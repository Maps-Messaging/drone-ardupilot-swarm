# Changelog

## 0.2.3

- Added `python3-pip` to the target-host prerequisite installation.
- Explicitly installs and verifies `empy==3.3.4` before building ArduPilot.
- Prevents a stale prerequisite marker from allowing the ArduPilot build to fail later with a missing `em` module.

## 0.2.2

- Removed the unavailable Debian dependency on `mavlink-router`.
- Added target-host cloning, Meson/Ninja build and source installation of MAVLink Router.
- Pinned the default MAVLink Router ref to upstream tag `v4`.
- Added configurable MAVLink Router repository ref and source directory.
- Updated the updater to rebuild and reinstall MAVLink Router before rebuilding ArduPilot.
- Kept the MAVLink Router build directory outside its Git checkout to preserve clean updates.
- Updated Debian metadata and documentation for the source-build installation model.

## 0.2.1

- Documented MAVLink Router as a separate upstream project and Debian package dependency.
- Added the upstream repository, source-build prerequisites, expected service/configuration paths, and package verification commands.
- Clarified that an upstream source installation does not satisfy `Depends: mavlink-router`.
- Documented the recommended separate MAVLink Router package and Nexus publication workflow.

## 0.2.0

- Added Debian package generation for the standalone host installer.
- Added installed `ardupilot-swarm-install`, `ardupilot-swarm-update`, and `ardupilot-swarm-uninstall` commands.
- Added Nexus APT publication with replacement of an existing matching package version.
- Added Buildkite Debian build artifacts and release publication to `maps-drone-repo`.
- Kept ArduPilot compilation outside Debian maintainer scripts so it runs as the selected runtime user.

## 0.1.1

- Replaced deployment-specific vehicle naming with generic drone naming.
- Renamed the default parameter file to `/etc/ardupilot-swarm/drone.parm`.
- Renamed the tmux window and MAVLink router endpoint to `drone`.
- Added validation to reject deployment-specific naming.

## 0.1.0

- Added idempotent host installer and updater.
- Added ArduPilot clone, prerequisite installation and ArduPlane SITL build.
- Added native `mavlink-router` package installation and configuration drop-ins.
- Added delayed ground-controller configuration helper.
- Added external proprietary parameter-file installation helper.
- Added tmux start/stop scripts and a systemd service.
- Added validation, source distribution and Buildkite pipeline.
