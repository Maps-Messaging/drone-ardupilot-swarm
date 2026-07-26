# ArduPilot Swarm Package: Setup and Usage

This guide installs and operates three fixed-wing ArduPlane SITL vehicles using the same external parameter file as the physical deployment.

## 1. Default deployment

| tmux window | SITL instance | MAVLink system ID | Router port |
|---|---:|---:|---:|
| `usv1` | 10 | 1 | 14440 |
| `usv2` | 11 | 2 | 14450 |
| `usv3` | 12 | 3 | 14460 |

Every vehicle starts as:

```text
ArduPlane firmware
plane frame
external parameter overlay
```

The launcher does not select Rover, motorboat, or any other simulation model.

## 2. Configure the APT repository

Create `/etc/apt/sources.list.d/maps-drone.list` containing:

```text
deb [signed-by=/usr/share/keyrings/mapsmessaging-archive-keyring.gpg] https://repository.mapsmessaging.io/repository/maps-drone-repo stable main
```

Then run:

```bash
sudo apt-get update
apt-cache policy ardupilot-swarm
```

## 3. Install the package

```bash
sudo apt-get install ardupilot-swarm
```

The Debian package installs the management project. It does not compile ArduPilot from a maintainer script.

## 4. Build the host runtime

Run as the account that will own the source trees and tmux session:

```bash
ardupilot-swarm-install
```

Do not run that command with `sudo`. The installer invokes `sudo` only where system-level access is required.

The installer:

1. Installs the required Debian or Ubuntu tools.
2. Adds the official Tailscale APT repository, installs `tailscale`, and starts `tailscaled.service`.
3. Installs the latest available `maps`, `maps-apps`, and `maps-drone` packages from the configured Maps Messaging APT repository.
4. Installs and verifies `empy==3.3.4`.
5. Clones and builds MAVLink Router.
6. Clones ArduPilot and builds the `plane` SITL target.
7. Applies the packaged GUIDED throttle patch during the ArduPlane build.
8. Reverses the patch after the build so the ArduPilot checkout remains clean.
9. Installs the runtime scripts and systemd unit.
10. Generates three local MAVLink Router endpoints.

Default source locations:

```text
$HOME/mavlink-router
$HOME/ardupilot
```

## 5. Install Maps packages

`ardupilot-swarm-install` installs these packages from the already configured Maps Messaging APT repository:

```text
maps
maps-apps
maps-drone
```

The installer uses package names rather than the versioned `.deb` path. No version is pinned, so APT installs the current repository candidate and future upgrades are handled normally:

```bash
sudo apt-get update
sudo apt-get install --only-upgrade maps maps-apps maps-drone
```

Verify the installed packages with:

```bash
dpkg-query -W maps maps-apps maps-drone
```

## 6. Configure Tailscale

The installer installs Tailscale from its official stable APT repository and enables and starts:

```text
tailscaled.service
```

It deliberately does not authenticate the host. Configure the tailnet connection after the installer completes:

```bash
sudo tailscale up
```

Add deployment-specific options such as `--hostname`, tags, routes, or Tailscale SSH only when they have been decided for the target environment.

Verify the daemon before authentication:

```bash
systemctl status tailscaled.service
```

After authentication, verify the connection with:

```bash
tailscale status
```

## 7. Managed GUIDED throttle patch

The patch is stored in the installer package at:

```text
patches/ardupilot/0001-allow-guided-throttle-before-takeoff.patch
```

It changes only `Plane::suppress_throttle()` in `ArduPlane/servos.cpp`. In GUIDED mode it clears `throttle_suppressed` and returns without applying the normal fixed-wing launch detection.

This prevents a low-altitude, low-speed virtual vehicle from behaving as though it has landed or has not launched. The patch does not modify the parameter file or select a different vehicle model.

If the selected ArduPilot ref changes enough that the patch no longer applies, the installer stops before building and reports the incompatibility.

## 8. Install the parameter file

The package deliberately contains no `.parm` file. Install the supplied physical-autopilot parameters unchanged:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm
```

Destination:

```text
/etc/ardupilot-swarm/drone.parm
```

To replace the file and restart immediately:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm --restart
```

The start script applies the same file to all three instances with `--add-param-file`. The explicit `--sysid` command-line value remains different for each vehicle.

## 9. Configure the ground controller

```bash
sudo ardupilot-swarm-configure-gcs 10.140.62.146 14550
```

This creates:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

The installer-generated local endpoints are in:

```text
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
```

Inspect them:

```bash
sudo cat /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
sudo ardupilot-swarm-configure-gcs --show
```

## 10. Start the swarm

```bash
sudo systemctl start ardupilot-swarm.service
sudo systemctl status ardupilot-swarm.service
```

Attach to the tmux session as the runtime user:

```bash
tmux attach -t ardupilot-swarm
```

The session contains windows `usv1`, `usv2`, and `usv3`.

## 11. Stop or restart

```bash
sudo systemctl stop ardupilot-swarm.service
sudo systemctl restart ardupilot-swarm.service
```

Stopping the service kills the complete `ardupilot-swarm` tmux session.

## 12. Runtime configuration

Edit:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf
```

The vehicle-specific values are arrays:

```bash
WINDOW_NAMES=("usv1" "usv2" "usv3")
INSTANCE_NUMBERS=("10" "11" "12")
SYSTEM_IDS=("1" "2" "3")
ROUTER_PORTS=("14440" "14450" "14460")
HOME_LATITUDES=("59.467300" "59.467327" "59.467300")
HOME_LONGITUDES=("24.828300" "24.828300" "24.828353")
```

All arrays must contain the same number of entries. The start script and installer reject incomplete configurations.

## 13. Upgrade from the single-vehicle configuration

After upgrading the Debian package, run:

```bash
ardupilot-swarm-update
```

A pre-0.3.0 scalar configuration is backed up to:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf.pre-0.3.0
```

The installer then appends the default three-vehicle array configuration while preserving the existing user, paths, source refs, router address, parameter path, altitude, heading, and wipe setting.

## 14. Verify operation

Check the services and generated configuration:

```bash
systemctl status tailscaled.service
systemctl status mavlink-router.service
systemctl status ardupilot-swarm.service
sudo cat /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
tmux list-windows -t ardupilot-swarm
```

Confirm the three MAVLink heartbeats report system IDs `1`, `2`, and `3`.

For the GUIDED throttle fix, command a vehicle while it is near home altitude and moving below 5 m/s. It should continue to produce throttle rather than entering fixed-wing launch suppression.

## 15. Troubleshooting

### The managed patch does not apply

The selected ArduPilot ref has changed around `Plane::suppress_throttle()`. Update the patch or select a compatible ref. The installer intentionally refuses to guess its way through an upstream safety change.

### The service reports a missing parameter file

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm
```

### Only one vehicle starts

Check that the installed runtime configuration contains the array fields and that all arrays have three entries:

```bash
sudo grep -E '^(WINDOW_NAMES|INSTANCE_NUMBERS|SYSTEM_IDS|ROUTER_PORTS|HOME_LATITUDES|HOME_LONGITUDES)=' /etc/ardupilot-swarm/ardupilot-swarm.conf
```

### Router traffic is missing

Confirm the generated endpoint file contains ports `14440`, `14450`, and `14460`, then restart the router:

```bash
sudo cat /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
sudo systemctl restart mavlink-router.service
```

### Inspect an individual vehicle

```bash
tmux attach -t ardupilot-swarm
```

Select the corresponding `usv1`, `usv2`, or `usv3` window.

## 16. Typical installation

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm

ardupilot-swarm-install

dpkg-query -W maps maps-apps maps-drone
sudo tailscale up
sudo ardupilot-swarm-install-parameters ~/Downloads/drone.parm
sudo ardupilot-swarm-configure-gcs 10.140.62.146 14550
sudo systemctl enable --now ardupilot-swarm.service

sudo systemctl status mavlink-router.service
sudo systemctl status ardupilot-swarm.service
```
