# Changelog

## 0.3.3

- Added `ardupilot-swarm-configure-maps` to configure, inspect, or remove the managed Maps MAVLink Router endpoint.
- Changed the default Maps endpoint and protocol interface from UDP port `14550` to `14430`, avoiding the three drone input ports `14440`, `14450`, and `14460`.
- Preserves Maps endpoint configuration written by `ardupilot-swarm-configure-maps` during package upgrades.
- Updated package installation, validation, uninstall cleanup, and operator documentation for the new helper.

## 0.3.2

- Standardised the managed Maps MAVLink Router endpoint as `/etc/mavlink-router/config.d/50-maps.conf`.
- Removes the previous `/etc/mavlink-router/config.d/30-maps.conf` during package upgrades to prevent duplicate `maps` endpoints.
- Added a Maps Messaging MAVLink interface example listening on `udp://0.0.0.0:14550/`.
- Documented that a single Maps MAVLink interface receives all three vehicle streams while preserving MAVLink system IDs `1`, `2`, and `3`.
- Updated validation and uninstall cleanup for both the legacy and current Maps endpoint filenames.

## 0.3.1

- Added the managed Maps MAVLink Router endpoint at `127.0.0.1:14550`.
- Installs `/etc/mavlink-router/config.d/30-maps.conf` from the Debian package and restarts MAVLink Router when it is already active.
- Updated the swarm start wrapper to detect and use ArduPilot's Python virtual environment on Ubuntu 24.04 and other venv-based installations.
- Added persistent per-vehicle startup logs under `~/.local/state/ardupilot-swarm`.
- Added startup verification so systemd fails when any SITL process exits immediately instead of reporting a successful empty tmux session.
- Preserves dead tmux panes long enough for the wrapper to detect failures and report the recent vehicle log output.
- Updated package upgrades to refresh the installed start wrapper and ground-controller helper on configured hosts.
- Removes the managed Maps endpoint and startup logs during uninstall and purge respectively.

## 0.3.0

- Changed the default runtime from one ArduPlane SITL instance to three fixed-wing ArduPlane vehicles.
- Added system IDs `1`, `2`, and `3` using SITL instances `10`, `11`, and `12`.
- Added local MAVLink Router endpoints on UDP ports `14440`, `14450`, and `14460`.
- Added separate tmux windows named `usv1`, `usv2`, and `usv3`.
- Added a managed ArduPilot patch that disables fixed-wing launch throttle suppression while operating in GUIDED mode.
- Applies the managed patch only while building ArduPlane and restores the upstream checkout afterward.
- Continues loading the externally supplied `/etc/ardupilot-swarm/drone.parm` file unchanged for every vehicle.
- Added migration of the previous scalar single-vehicle runtime configuration to the new three-vehicle array format.
- Added package and validation checks for the patch, fixed-wing frame, system IDs, router ports, and array lengths.
- Added installation of the official Tailscale package and service while leaving tailnet authentication for manual post-install configuration.
- Added installation of the latest available `maps`, `maps-apps`, and `maps-drone` packages from the configured APT repository without pinning package versions.

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
