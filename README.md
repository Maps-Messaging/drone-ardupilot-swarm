# ArduPilot Fixed-Wing Swarm Installer

This repository packages the host-side installation and runtime tooling for three ArduPlane SITL vehicles. The virtual vehicles use the normal ArduPlane fixed-wing `plane` frame and load the same externally supplied parameter file as the physical autopilot deployment.

The package does not contain the deployment parameter file and does not modify it.

## Default swarm

| Window | SITL instance | MAVLink system ID | Local router port |
|---|---:|---:|---:|
| `usv1` | 10 | 1 | 14440 |
| `usv2` | 11 | 2 | 14450 |
| `usv3` | 12 | 3 | 14460 |

Each vehicle starts with:

```text
-v ArduPlane -f plane
```

No alternate simulation model is selected.

## Managed ArduPilot patch

ArduPlane normally suppresses automatic throttle while it believes a fixed-wing aircraft is still on the ground. The physical deployment uses GUIDED mode near home altitude and below the normal launch-speed threshold, so an unmodified SITL instance can suppress throttle and drift away from its commanded waypoint.

The package includes:

```text
patches/ardupilot/0001-allow-guided-throttle-before-takeoff.patch
```

The installer verifies and applies the patch immediately before building ArduPlane. The patch makes `Plane::suppress_throttle()` return unsuppressed in GUIDED mode. It is reversed after the build so the upstream ArduPilot checkout remains clean.

The patch does not change parameters, vehicle type, frame, AUTO behaviour, RTL behaviour, landing suppression, parachute suppression, or general ArduPilot failsafes.

## Project layout

```text
config/      Runtime and MAVLink Router templates
docs/        Supporting documentation
patches/     Managed upstream ArduPilot source patches
scripts/     Installed runtime and configuration commands
systemd/     systemd unit template
install.sh   Build and install MAVLink Router and patched ArduPlane
update.sh    Update and rebuild both upstream projects
uninstall.sh Remove project-managed files
```

## Validate and build

```bash
make validate
make dist
make deb
```

Build outputs:

```text
dist/ardupilot-swarm-<version>.tar.gz
dist/ardupilot-swarm_<version>_all.deb
dist/ardupilot-swarm_<version>_all.deb.sha256
```

## Install

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm
ardupilot-swarm-install
```

Run `ardupilot-swarm-install` as the account that will own the source trees and tmux session, not with `sudo`.

The installer builds MAVLink Router and ArduPlane SITL, applies the managed GUIDED throttle patch for the ArduPlane build, installs the runtime scripts, writes three local router endpoints, and enables the systemd services.

## Parameter file

Install the supplied physical-autopilot parameter file unchanged:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm
```

Installed location:

```text
/etc/ardupilot-swarm/drone.parm
```

The start script passes the file to all three vehicles with `--add-param-file`. It also passes explicit command-line system IDs `1`, `2`, and `3`.

No `.parm` file is allowed in this repository.

## Configure the ground controller

```bash
sudo ardupilot-swarm-configure-gcs 10.140.62.146 14550
```

This writes:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

The three local SITL endpoints are written to:

```text
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
```

## Start and stop

```bash
sudo systemctl start ardupilot-swarm.service
sudo systemctl stop ardupilot-swarm.service
sudo systemctl status ardupilot-swarm.service
```

Attach to the tmux session:

```bash
tmux attach -t ardupilot-swarm
```

Switch between the `usv1`, `usv2`, and `usv3` windows with the normal tmux window controls.

## Runtime configuration

Configuration is stored in:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf
```

Vehicle-specific values are Bash arrays. All vehicle arrays must contain the same number of entries.

Upgrading a pre-0.3.0 installation preserves the original file as:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf.pre-0.3.0
```

and appends the default three-vehicle configuration.

## Update

```bash
ardupilot-swarm-update
```

The updater refuses unrelated local changes in either upstream checkout. The managed ArduPilot patch is applied only for the build and is removed afterward.

## Full operating guide

See [`ardupilot-swarm-setup-and-usage.md`](ardupilot-swarm-setup-and-usage.md).
