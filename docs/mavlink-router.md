# MAVLink Router Dependency

`mavlink-router` is a separate upstream project. It is not part of ArduPilot and it is not maintained by this project.

## Upstream source

Repository:

```text
https://github.com/mavlink-router/mavlink-router
```

The upstream project builds `mavlink-routerd`, installs a systemd service, and uses the following default configuration locations:

```text
/etc/mavlink-router/main.conf
/etc/mavlink-router/config.d/
```

This project only adds its own endpoint files under `config.d`; it does not replace the router service or upstream configuration model.

## Debian package availability

The upstream repository publishes source code and build instructions. It does not publish an official Debian package through GitHub Packages or a Debian APT repository.

The `ardupilot-swarm` Debian package declares:

```text
Depends: mavlink-router
```

Therefore, a Debian package named `mavlink-router` must already be available from one of the APT repositories configured on the target host. Installing `mavlink-router` directly from source does not satisfy this Debian package dependency.

Recommended deployment model:

1. Maintain `mavlink-router` as a separate build/package project.
2. Clone a pinned upstream tag or commit.
3. Build a Debian package named `mavlink-router`.
4. Publish it to the same hosted APT repository used for `ardupilot-swarm`, or another repository configured on the target host.
5. Publish `ardupilot-swarm` after the router package is available.

APT can then resolve both packages normally:

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm
```

## Upstream source build

The upstream project currently documents these Debian/Ubuntu build prerequisites:

```bash
sudo apt-get install git meson ninja-build pkg-config gcc g++ systemd
```

Typical upstream build and installation commands are:

```bash
git clone https://github.com/mavlink-router/mavlink-router.git
cd mavlink-router
git submodule update --init --recursive
meson setup build . --buildtype=release
ninja -C build
sudo ninja -C build install
```

For reproducible deployment, use a pinned tag or commit rather than building an unpinned `master` branch.

## Expected installation

Before installing or running the swarm, verify:

```bash
command -v mavlink-routerd
systemctl cat mavlink-router.service
```

Expected runtime components include:

```text
mavlink-routerd
mavlink-router.service
/etc/mavlink-router/main.conf
/etc/mavlink-router/config.d/
```

The swarm installer adds:

```text
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
```

The ground-controller helper adds:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

## Current packaging boundary

The projects have deliberately separate responsibilities:

```text
mavlink-router package
  owns mavlink-routerd and mavlink-router.service

ardupilot-swarm package
  depends on mavlink-router
  builds ArduPilot SITL after package installation
  adds router endpoint configuration
  installs swarm scripts and ardupilot-swarm.service
```

This prevents the swarm package from silently cloning and compiling an unrelated routing daemon during installation.
