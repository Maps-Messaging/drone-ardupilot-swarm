# ArduPilot Swarm Installer

A standalone host installer for the ArduPilot SITL environment.

It follows the normal installation model rather than replacing it:

- ArduPilot is cloned from its upstream Git repository and built in a normal working directory.
- `mavlink-router` is installed as its own Debian/Ubuntu package.
- Router endpoints are added under `/etc/mavlink-router/config.d`.
- Start and stop scripts are installed under `/usr/local/bin`.
- A single systemd unit invokes those scripts.
- The proprietary ArduPilot parameter file is supplied separately and is never included in this project.

## Project layout

```text
config/      Runtime and mavlink-router templates
scripts/     Installed start, stop and configuration commands
systemd/     systemd unit template
install.sh   First installation and idempotent reinstall
update.sh    Update ArduPilot and reinstall project-managed files
uninstall.sh Remove project-managed files
Makefile     Validation and source distribution
```

## Validate and build the distribution

```bash
make validate
make dist
```

The archive is written to `dist/ardupilot-swarm-<version>.tar.gz`.

## Install

Run the installer as the account that will own and run ArduPilot. Do not invoke the installer itself with `sudo`; it requests sudo only for package and system-file operations.

```bash
./install.sh
```

Defaults:

```text
ArduPilot repository: https://github.com/ArduPilot/ardupilot.git
ArduPilot ref:        master
ArduPilot directory:  $HOME/ardupilot
Build:                SITL ArduPlane
Local router port:    14480
System ID:            1
SITL instance:        10
```

A different branch, tag or commit can be selected during the first installation:

```bash
./install.sh --ref ArduPlane-stable
```

A different source directory can also be selected:

```bash
./install.sh --ardupilot-dir /srv/ardupilot
```

The installer enables `ardupilot-swarm.service` but does not start it on the first installation because the proprietary parameter file is deliberately absent.

## Supply the parameter file

The file is obtained through the company’s normal secure delivery mechanism and copied into place by the end user:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm
```

Installed location:

```text
/etc/ardupilot-swarm/drone.parm
```

It is installed as `root:<runtime group>` with mode `0640`.

To replace the file and restart the swarm immediately:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm --restart
```

A direct copy is also possible:

```bash
sudo install -m 0640 -o root -g "$(id -gn)" \
  /path/to/drone.parm \
  /etc/ardupilot-swarm/drone.parm
```

No `.parm` file is allowed in the project tree; `make validate` enforces this.

## Configure the ground controller

The installer creates only the local router endpoint used by the SITL instance. The end user adds the deployment-specific ground controller later:

```bash
sudo ardupilot-swarm-configure-gcs 10.140.62.146 14550
```

This writes:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

and restarts `mavlink-router.service`.

Show or remove the current endpoint:

```bash
sudo ardupilot-swarm-configure-gcs --show
sudo ardupilot-swarm-configure-gcs --remove
```

The project does not edit the router’s systemd unit. It uses the router’s normal configuration files:

```text
/etc/mavlink-router/main.conf
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
/etc/mavlink-router/config.d/90-ground-controller.conf
```

An existing `main.conf` is preserved.

## Start and stop

```bash
sudo systemctl start ardupilot-swarm.service
sudo systemctl stop ardupilot-swarm.service
sudo systemctl status ardupilot-swarm.service
```

The service runs the existing tmux-style wrappers:

```text
/usr/local/bin/start-ardupilot-swarm
/usr/local/bin/stop-ardupilot-swarm
```

Attach to the running session as the runtime user:

```bash
tmux attach -t ardupilot-swarm
```

## Runtime configuration

Deployment values live in:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf
```

The installer preserves this file during updates. It contains the source directory and ref, vehicle identity, local router endpoint, initial location, parameter-file path and tmux names.

After changing the local router address or port, rerun the updater so the router drop-in and service files are regenerated:

```bash
./update.sh --skip-build
```

## Update

Run from an updated checkout of this project as the same account that owns the ArduPilot source tree:

```bash
./update.sh
```

The updater:

1. Stops the swarm if it is active.
2. Refuses to continue if the ArduPilot working tree has local changes.
3. Fetches the configured branch, tag or commit.
4. Updates submodules.
5. Rebuilds ArduPlane SITL.
6. Reinstalls project-managed scripts, service and router drop-in.
7. Restarts the swarm only if it was running before the update.

Refresh the upstream build prerequisites when required:

```bash
./update.sh --refresh-prerequisites
```

## Uninstall

Remove only project-managed service, commands and router endpoints:

```bash
./uninstall.sh
```

The runtime configuration, proprietary parameter file and ArduPilot source tree are preserved.

Remove those as well:

```bash
./uninstall.sh --purge
```

The `mavlink-router` package itself is not removed because it remains an independent installation.
