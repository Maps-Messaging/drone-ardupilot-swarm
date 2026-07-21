# MAVLink Router Source Build

`mavlink-router` is a separate upstream project. It is not part of ArduPilot and is not maintained by this project.

## Upstream source

Repository:

```text
https://github.com/mavlink-router/mavlink-router
```

Default ref used by this installer:

```text
v4
```

The upstream project builds `mavlink-routerd`, installs a systemd service, and uses these default configuration locations:

```text
/etc/mavlink-router/main.conf
/etc/mavlink-router/config.d/
```

This project adds endpoint files under `config.d`; it does not replace the upstream router process or service model.

## Why it is built by the installer

The upstream project publishes source and build instructions rather than an official Debian package in a generally available APT repository. Therefore, the `ardupilot-swarm` Debian package does not declare `Depends: mavlink-router`.

Instead, `ardupilot-swarm-install` performs the source build on the target host:

1. Installs the build prerequisites.
2. Clones or updates the pinned upstream ref.
3. Fetches the MAVLink C-library submodule.
4. Configures a release build with Meson.
5. Builds with Ninja.
6. Installs with `sudo ninja install`.
7. Reloads systemd and verifies the binary and service.

The source tree belongs to the runtime user. Only the final upstream install step runs as root.

## Build prerequisites

The installer installs the upstream Debian/Ubuntu prerequisites:

```bash
sudo apt-get install -y \
  git \
  meson \
  ninja-build \
  pkg-config \
  gcc \
  g++ \
  systemd
```

## Equivalent manual build

The installer performs the equivalent of:

```bash
git clone --recursive \
  --branch v4 \
  https://github.com/mavlink-router/mavlink-router.git \
  "$HOME/mavlink-router"

meson setup \
  --buildtype=release \
  "$HOME/.cache/ardupilot-swarm/mavlink-router-build" \
  "$HOME/mavlink-router"

ninja -C "$HOME/.cache/ardupilot-swarm/mavlink-router-build"
sudo ninja -C "$HOME/.cache/ardupilot-swarm/mavlink-router-build" install
sudo systemctl daemon-reload
```

The build directory is kept outside the Git checkout and recreated for each installation or update, so generated files cannot make the source tree appear modified or preserve stale build state.

## Runtime verification

The installer verifies both components after installation:

```bash
command -v mavlink-routerd
systemctl cat mavlink-router.service
```

The expected source installation normally places the binary under `/usr/local/bin` and registers `mavlink-router.service` in a systemd unit directory.

The installer then enables and starts the upstream service:

```bash
sudo systemctl enable --now mavlink-router.service
```

## Configuration ownership

MAVLink Router owns:

```text
mavlink-routerd
mavlink-router.service
```

The swarm installer manages:

```text
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
```

The ground-controller helper manages:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

The installer creates `/etc/mavlink-router/main.conf` only when it does not already exist. Existing router configuration is preserved.

## Updating

`ardupilot-swarm-update` uses the router repository and ref stored in:

```text
/etc/ardupilot-swarm/ardupilot-swarm.conf
```

The default values are:

```bash
MAVLINK_ROUTER_REPOSITORY="https://github.com/mavlink-router/mavlink-router.git"
MAVLINK_ROUTER_REF="v4"
MAVLINK_ROUTER_DIR="$HOME/mavlink-router"
```

Change the ref through the updater rather than editing the Git checkout manually:

```bash
ardupilot-swarm-update --mavlink-router-ref v4
```

The updater refuses to overwrite local changes in the MAVLink Router working tree.

## Uninstall boundary

A normal swarm uninstall removes only the swarm's router endpoint files. It leaves the source-installed MAVLink Router service and binary in place because they may be used by other MAVLink applications.

A purge removes the cloned source and cached build directory. It still leaves the installed upstream binary and systemd unit in place; remove those separately only when the host no longer uses MAVLink Router.
