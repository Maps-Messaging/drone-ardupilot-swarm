# MAVLink Router Source Build and Swarm Endpoints

`mavlink-router` is built from its upstream source repository and installed with its normal systemd service. This project adds configuration under `/etc/mavlink-router/config.d`; it does not replace the upstream service model.

## Upstream source

```text
Repository: https://github.com/mavlink-router/mavlink-router
Default ref: v4
```

The installer builds with Meson and Ninja using:

```text
Source:      $HOME/mavlink-router
Build tree:  $HOME/.cache/ardupilot-swarm/mavlink-router-build
```

The build tree is outside the Git checkout so generated files do not make the upstream repository dirty.

## Local ArduPlane endpoints

The installer generates:

```text
/etc/mavlink-router/config.d/20-ardupilot-swarm.conf
```

with three UDP server endpoints:

| Endpoint | Address | Port | MAVLink system ID |
|---|---|---:|---:|
| `usv1` | 127.0.0.1 | 14440 | 1 |
| `usv2` | 127.0.0.1 | 14450 | 2 |
| `usv3` | 127.0.0.1 | 14460 | 3 |

The address, endpoint names, and ports are rendered from `/etc/ardupilot-swarm/ardupilot-swarm.conf`. The router ports must remain aligned with the corresponding arrays used by `start-ardupilot-swarm`.

## Ground-controller endpoint

Configure the remote ground controller separately:

```bash
sudo ardupilot-swarm-configure-gcs GROUND_CONTROLLER_ADDRESS 14550
```

This helper manages:

```text
/etc/mavlink-router/config.d/90-ground-controller.conf
```

Show or remove it with:

```bash
sudo ardupilot-swarm-configure-gcs --show
sudo ardupilot-swarm-configure-gcs --remove
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

An existing `/etc/mavlink-router/main.conf` is preserved. The installer creates it only when it does not exist.

## Verification

```bash
command -v mavlink-routerd
systemctl cat mavlink-router.service
sudo cat /etc/mavlink-router/config.d/20-ardupilot-swarm.conf
sudo systemctl restart mavlink-router.service
sudo systemctl status mavlink-router.service
```

The generated swarm file should contain three `[UdpEndpoint ...]` sections using ports `14440`, `14450`, and `14460`.

## Updating

`ardupilot-swarm-update` uses the repository, ref, and directory stored in the runtime configuration. It refuses local changes in the MAVLink Router checkout before updating.

## Uninstall boundary

A normal uninstall removes the swarm-managed router endpoint files but leaves the source-installed MAVLink Router binary and service because other MAVLink applications may use them.
