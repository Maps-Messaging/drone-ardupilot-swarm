# ArduPilot Swarm Package: Setup and Usage

This guide installs and operates three fixed-wing ArduPlane SITL vehicles using the same external parameter file as the physical deployment.

## 1. Default deployment

| tmux window | SITL instance | MAVLink system ID | Router port |
| ----------- | ------------: | ----------------: | ----------: |
| `usv1`      |            10 |                 1 |       14440 |
| `usv2`      |            11 |                 2 |       14450 |
| `usv3`      |            12 |                 3 |       14460 |

Every vehicle starts as:

```text
ArduPlane firmware
plane frame
external parameter overlay
```

The launcher does not select Rover, motorboat, or any other simulation model.

## 2. Configure the APT repository

The Maps Messaging repository signing key is installed globally at:

```text
sudo curl -fsSL https://repository.mapsmessaging.io/repository/public_key/daily/apt_daily_key.gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg

/etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg
```

Inspect the installed key and confirm that it contains signing key `7CC22EEB40CC8C4D`:

```bash
gpg --show-keys --with-subkey-fingerprint /etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg
```

Create `/etc/apt/sources.list.d/maps-drone.list` containing:

```text
deb [arch=all] https://repository.mapsmessaging.io/repository/maps-drone-repo stable main
```

Then run:

```bash
sudo apt-get update
apt-cache policy ardupilot-swarm
```

Do not add a `signed-by` option pointing at a different keyring. That would prevent APT from using the globally trusted Maps Messaging key. Do not use `trusted=yes` or disable APT signature verification.

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

## 7. Install the parameter file

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

## 8. Configure MAVLink Router

The three drones send MAVLink to MAVLink Router on localhost ports `14440`, `14450`, and `14460`. MAVLink Router forwards the combined stream to Maps and the configured ground controller while preserving MAVLink system IDs `1`, `2`, and `3`.

### Configure Maps

Configure Maps on localhost port `14430`:

```bash
sudo ardupilot-swarm-configure-maps 127.0.0.1 14430
```

This creates:

```text
/etc/mavlink-router/config.d/50-maps.conf
```

Maps must have one MAVLink UDP listener on port `14430`. Show or remove the router destination with:

```bash
sudo ardupilot-swarm-configure-maps --show
sudo ardupilot-swarm-configure-maps --remove
```

### Configure the ground controller

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
sudo ardupilot-swarm-configure-maps --show
sudo ardupilot-swarm-configure-gcs --show
```

## 9. Start the swarm

```bash
sudo systemctl start ardupilot-swarm.service
sudo systemctl status ardupilot-swarm.service
```

Attach to the tmux session as the runtime user:

```bash
tmux attach -t ardupilot-swarm
```

The session contains windows `usv1`, `usv2`, and `usv3`.

## 10. Stop or restart

```bash
sudo systemctl stop ardupilot-swarm.service
sudo systemctl restart ardupilot-swarm.service
```

Stopping the service kills the complete `ardupilot-swarm` tmux session.

## 11. Runtime configuration

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

## 12. Upgrade from the single-vehicle configuration

After upgrading the Debian package, run:

```bash
ardupilot-swarm-update
```

A pre-0.3.0 scalar configuration is backed up to:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf.pre-0.3.0
```

The installer then appends the default three-vehicle array configuration while preserving the existing user, paths, source refs, router address, parameter path, altitude, heading, and wipe setting.

## 13. Verify operation

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

## 14. Troubleshooting

### APT reports `NO_PUBKEY 7CC22EEB40CC8C4D`

The globally installed Maps Messaging key is missing, unreadable, or the repository source has a `signed-by` option that points somewhere else. Confirm the keyring and source definition:

```bash
sudo chmod 0644 /etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg
gpg --show-keys --with-subkey-fingerprint /etc/apt/trusted.gpg.d/mapsmessaging-apt.gpg
cat /etc/apt/sources.list.d/maps-drone.list
sudo apt-get update
apt-cache policy ardupilot-swarm
```

The source must not contain `signed-by`; it should be:

```text
deb [arch=all] https://repository.mapsmessaging.io/repository/maps-drone-repo stable main
```

The `Unable to locate package ardupilot-swarm` error normally follows this signature failure because APT disables the repository and does not download its package index.

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

## 15. Typical installation

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm

ardupilot-swarm-install

dpkg-query -W maps maps-apps maps-drone
sudo tailscale up
sudo ardupilot-swarm-install-parameters ~/Downloads/drone.parm
sudo ardupilot-swarm-configure-maps 127.0.0.1 14430
sudo ardupilot-swarm-configure-gcs 10.140.62.146 14550
sudo systemctl enable --now ardupilot-swarm.service

sudo systemctl status mavlink-router.service
sudo systemctl status ardupilot-swarm.service
```
