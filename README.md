# ArduPilot Swarm Installer

A standalone host installer for an ArduPilot SITL drone swarm.

It builds on the normal upstream installation models rather than replacing them:

- MAVLink Router is cloned from its upstream Git repository, built with Meson/Ninja, and installed with its upstream systemd unit.
- ArduPilot is cloned from its upstream Git repository and built in a normal working directory.
- Router endpoints are added under `/etc/mavlink-router/config.d`.
- Start and stop scripts are installed under `/usr/local/bin`.
- A single systemd unit invokes those scripts.
- The proprietary ArduPilot parameter file is supplied separately and is never included in this project.

## Project layout

```text
config/      Runtime and mavlink-router templates
scripts/     Installed start, stop and configuration commands
systemd/     systemd unit template
install.sh   Build/install MAVLink Router and ArduPilot
update.sh    Update and rebuild both upstream projects
uninstall.sh Remove project-managed files
Makefile     Validation, package and release targets
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

The Debian package contains the installer project and exposes these commands:

```text
ardupilot-swarm-install
ardupilot-swarm-update
ardupilot-swarm-uninstall
```

Installing the Debian package does not compile either upstream project from a Debian maintainer script. The end user runs `ardupilot-swarm-install` as the account that will own the source trees and tmux session. The installer uses `sudo` only for prerequisite packages, `ninja install`, configuration files, and systemd operations.

## Upstream projects

MAVLink Router:

```text
https://github.com/mavlink-router/mavlink-router
```

ArduPilot:

```text
https://github.com/ArduPilot/ardupilot
```

The default MAVLink Router ref is the upstream `v4` tag. Its source-build details and installed paths are documented in [`docs/mavlink-router.md`](docs/mavlink-router.md).

## Install

Install the package from the configured APT repository:

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm
```

Then run the host installer as the account that will own and run ArduPilot. Do not invoke the installer itself with `sudo`:

```bash
ardupilot-swarm-install
```

When working directly from the source checkout, the equivalent command is:

```bash
./install.sh
```

The installer:

1. Installs the MAVLink Router and ArduPilot build prerequisites.
2. Clones or updates MAVLink Router.
3. Builds and installs `mavlink-routerd` and its upstream systemd unit.
4. Clones or updates ArduPilot.
5. Runs ArduPilot's prerequisite installer.
6. Builds SITL ArduPlane.
7. Installs the swarm scripts, router drop-ins and systemd unit.

Defaults:

```text
MAVLink Router repository: https://github.com/mavlink-router/mavlink-router.git
MAVLink Router ref:        v4
MAVLink Router directory:  $HOME/mavlink-router
ArduPilot repository:      https://github.com/ArduPilot/ardupilot.git
ArduPilot ref:             master
ArduPilot directory:       $HOME/ardupilot
ArduPilot build:           SITL ArduPlane
Local router port:         14480
System ID:                 1
SITL instance:             10
```

Select different upstream refs or source directories during installation:

```bash
ardupilot-swarm-install \
  --mavlink-router-ref v4 \
  --mavlink-router-dir /srv/mavlink-router \
  --ref ArduPlane-stable \
  --ardupilot-dir /srv/ardupilot
```

The installer enables `ardupilot-swarm.service` but does not start it on the first installation because the proprietary parameter file is deliberately absent.

## Supply the parameter file

The deployment-specific parameter file is supplied separately and copied into place by the end user:

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

The project does not edit the router's systemd unit. It uses the router's normal configuration files:

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

Deployment and source-build values live in:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf
```

The installer preserves this file during updates. It contains both upstream repository refs/directories, vehicle identity, local router endpoint, initial location, parameter-file path and tmux names.

After changing the local router address or port, rerun the updater so the router drop-in and service files are regenerated:

```bash
ardupilot-swarm-update --skip-build
```

`--skip-build` skips only the ArduPilot compile. MAVLink Router is still rebuilt and installed so its source installation remains current and verifiable.

## Update

After upgrading the Debian package, run the updater as the same account that owns the source trees:

```bash
ardupilot-swarm-update
```

When working directly from the source checkout, the equivalent command is:

```bash
./update.sh
```

The updater:

1. Stops the swarm if it is active.
2. Refuses to continue if either upstream working tree has local changes.
3. Fetches the configured refs and updates submodules.
4. Rebuilds and installs MAVLink Router.
5. Rebuilds ArduPlane SITL unless `--skip-build` is supplied.
6. Reinstalls project-managed scripts, service and router drop-ins.
7. Restarts the swarm only if it was running before the update.

Refresh the ArduPilot prerequisite installer when required:

```bash
ardupilot-swarm-update --refresh-prerequisites
```

## Uninstall

Remove only project-managed service, commands and router endpoints:

```bash
ardupilot-swarm-uninstall
```

When working directly from the source checkout, the equivalent command is:

```bash
./uninstall.sh
```

The runtime configuration, parameter file, upstream source trees and source-installed MAVLink Router remain in place.

Remove the runtime configuration and source trees as well:

```bash
ardupilot-swarm-uninstall --purge
```

The purge removes the source and build directories but does not automatically remove the source-installed MAVLink Router binary or upstream systemd unit. They may be shared with other MAVLink deployments.

## Publish to Nexus

The release target uploads the Debian installer package to the hosted Nexus APT repository. Credentials are supplied through the existing Buildkite secrets and are never written into the project.

```bash
export NEXUS_USER="$(buildkite-agent secret get NEXUS_USER)"
export NEXUS_PASSWORD="$(buildkite-agent secret get NEXUS_PASSWORD)"
make release
```

The default repository is:

```text
maps-drone-repo
```

Override it when required:

```bash
make release NEXUS_REPOSITORY=another-apt-repository
```

The upload script searches Nexus for the same package name and version, deletes matching components, accepts HTTP `204` as a successful deletion, and uploads the new `.deb` through the hosted APT repository endpoint.

Buildkite validates every build and creates the Debian artifacts. Publication runs automatically for `main` builds and tagged builds.
