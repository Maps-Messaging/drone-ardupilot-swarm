# ArduPilot Swarm Package: Setup and Usage

This guide describes how to configure the APT repository, install the `ardupilot-swarm` package, build the ArduPilot and MAVLink Router environments, supply the deployment parameter file, configure the ground-control endpoint, and operate the swarm through systemd.

## 1. Prerequisites

The target host should be a supported Ubuntu or Debian system with:

- `sudo` access
- Network access to the Nexus APT repository
- Network access to GitHub for cloning ArduPilot and MAVLink Router
- Sufficient disk space for both source trees and their build output

The package installs the management scripts first. The actual ArduPilot and MAVLink Router source builds are performed afterward by `ardupilot-swarm-install`.

## 2. Configure the APT repository

Create the APT source file:

```bash
sudo nano /etc/apt/sources.list.d/maps-drone.list
```

Add:

```text
deb [signed-by=/usr/share/keyrings/mapsmessaging-archive-keyring.gpg] https://repository.mapsmessaging.io/repository/maps-drone-repo stable main
```

The signing key must already exist at:

```text
/usr/share/keyrings/mapsmessaging-archive-keyring.gpg
```

If the key is supplied separately, install it before running `apt-get update`.

Update the local package index:

```bash
sudo apt-get update
```

Confirm that APT can see the package:

```bash
apt-cache policy ardupilot-swarm
```

Expected result:

```text
ardupilot-swarm:
  Installed: (none)
  Candidate: 0.2.3
```

The version shown may be newer than `0.2.3`.

## 3. Install the package

Install the package from the configured Nexus repository:

```bash
sudo apt-get install ardupilot-swarm
```

This installs the management tooling. It does not immediately clone and compile ArduPilot.

## 4. Build the runtime environment

Run the installer as the normal runtime user, not as `root`:

```bash
ardupilot-swarm-install
```

The installer performs the following work:

1. Installs required Ubuntu or Debian packages.
2. Installs `python3-pip`.
3. Installs and verifies `empy==3.3.4`.
4. Clones and builds MAVLink Router.
5. Installs `mavlink-routerd` and its systemd unit.
6. Clones and builds ArduPilot SITL.
7. Installs the swarm start and stop scripts.
8. Installs the `ardupilot-swarm.service` systemd unit.
9. Configures the local MAVLink Router endpoint.
10. Reloads systemd and enables the swarm service.

The source trees are normally created under the runtime user's home directory:

```text
~/mavlink-router
~/ardupilot
```

The MAVLink Router build directory is normally stored under:

```text
~/.cache/ardupilot-swarm/mavlink-router-build
```

The installation can take some time because both projects are compiled locally.

### Important

The swarm systemd unit does not exist until `ardupilot-swarm-install` completes successfully.

After installation, verify:

```bash
ls -l \
  /etc/systemd/system/ardupilot-swarm.service \
  /usr/local/bin/start-ardupilot-swarm \
  /usr/local/bin/stop-ardupilot-swarm
```

Also verify MAVLink Router:

```bash
command -v mavlink-routerd
systemctl cat mavlink-router.service
```

## 5. Install the proprietary parameter file

The package does not contain the deployment parameter file.

The required destination is:

```text
/etc/ardupilot-swarm/drone.parm
```

Use the supplied helper command:

```bash
sudo ardupilot-swarm-install-parameters /path/to/company-supplied.parm
```

For example:

```bash
sudo ardupilot-swarm-install-parameters ~/Downloads/drone.parm
```

Verify the installed file:

```bash
sudo ls -l /etc/ardupilot-swarm/drone.parm
```

The file should only be readable by the appropriate administrative/runtime users.

### Manual alternative

The file may also be copied directly:

```bash
sudo install \
  -o root \
  -g root \
  -m 0600 \
  /path/to/company-supplied.parm \
  /etc/ardupilot-swarm/drone.parm
```

Do not rename the destination unless the swarm configuration and start script are changed to match it.

## 6. Configure the ground-control endpoint

The ground-control address is deployment-specific and is not known when the package is built.

Configure it after installation:

```bash
sudo ardupilot-swarm-configure-gcs <gcs-host> <gcs-port>
```

For example:

```bash
sudo ardupilot-swarm-configure-gcs 192.168.1.50 14550
```

The command writes the MAVLink Router endpoint configuration under:

```text
/etc/mavlink-router/config.d/
```

Inspect the generated configuration:

```bash
sudo ls -l /etc/mavlink-router/config.d/
sudo cat /etc/mavlink-router/config.d/*gcs*
```

Restart MAVLink Router after changing the endpoint:

```bash
sudo systemctl restart mavlink-router.service
```

Check its status:

```bash
sudo systemctl status mavlink-router.service
```

## 7. Start the swarm

Before starting the service, confirm that:

- `ardupilot-swarm-install` completed successfully
- `/etc/ardupilot-swarm/drone.parm` exists
- the GCS endpoint is configured
- `mavlink-router.service` is running

Enable and start the swarm:

```bash
sudo systemctl enable --now ardupilot-swarm.service
```

Check status:

```bash
sudo systemctl status ardupilot-swarm.service
```

Follow logs:

```bash
sudo journalctl -u ardupilot-swarm.service -f
```

The swarm is normally started inside a tmux session. List sessions with:

```bash
tmux ls
```

## 8. Stop and restart the swarm

Stop:

```bash
sudo systemctl stop ardupilot-swarm.service
```

Start:

```bash
sudo systemctl start ardupilot-swarm.service
```

Restart:

```bash
sudo systemctl restart ardupilot-swarm.service
```

Disable automatic startup:

```bash
sudo systemctl disable ardupilot-swarm.service
```

The service calls:

```text
/usr/local/bin/start-ardupilot-swarm
/usr/local/bin/stop-ardupilot-swarm
```

## 9. Update the installation

Refresh the APT package:

```bash
sudo apt-get update
sudo apt-get install --only-upgrade ardupilot-swarm
```

Then update and rebuild the source environments:

```bash
ardupilot-swarm-update
```

The updater refreshes and rebuilds both:

- MAVLink Router
- ArduPilot

Check service status after the update:

```bash
sudo systemctl status mavlink-router.service
sudo systemctl status ardupilot-swarm.service
```

Restart if required:

```bash
sudo systemctl restart mavlink-router.service
sudo systemctl restart ardupilot-swarm.service
```

## 10. Remove the installation

Stop the swarm:

```bash
sudo systemctl stop ardupilot-swarm.service
```

Run the supplied uninstall command:

```bash
ardupilot-swarm-uninstall
```

Remove the Debian package:

```bash
sudo apt-get remove ardupilot-swarm
```

Use `purge` only when the local package configuration should also be removed:

```bash
sudo apt-get purge ardupilot-swarm
```

Do not remove `/etc/ardupilot-swarm/drone.parm` unless the proprietary parameter file is no longer required.

## 11. Verification checklist

Run:

```bash
apt-cache policy ardupilot-swarm
command -v mavlink-routerd
test -x /usr/local/bin/start-ardupilot-swarm
test -x /usr/local/bin/stop-ardupilot-swarm
test -f /etc/systemd/system/ardupilot-swarm.service
sudo test -f /etc/ardupilot-swarm/drone.parm
systemctl is-enabled mavlink-router.service
systemctl is-enabled ardupilot-swarm.service
systemctl status mavlink-router.service
systemctl status ardupilot-swarm.service
```

## 12. Troubleshooting

### Package cannot be found

Check the APT source:

```bash
cat /etc/apt/sources.list.d/maps-drone.list
```

Refresh package metadata:

```bash
sudo apt-get update
apt-cache policy ardupilot-swarm
```

### `ardupilot-swarm.service` does not exist

The environment installer has not completed successfully.

Run:

```bash
ardupilot-swarm-install 2>&1 | tee ~/ardupilot-swarm-install.log
```

The service is installed only after MAVLink Router and ArduPilot build successfully.

### Python reports `No module named pip`

Install pip:

```bash
sudo apt-get install -y python3-pip
```

Current package versions should handle this automatically.

### ArduPilot reports that `empy==3.3.4` is required

Install it as the runtime user:

```bash
python3 -m pip install \
  --user \
  --break-system-packages \
  empy==3.3.4
```

Then rerun:

```bash
ardupilot-swarm-install
```

Current package versions should perform this installation automatically.

### Parameter file is missing

Check:

```bash
sudo test -r /etc/ardupilot-swarm/drone.parm
```

Install it:

```bash
sudo ardupilot-swarm-install-parameters /path/to/drone.parm
```

### MAVLink Router is not running

Check:

```bash
sudo systemctl status mavlink-router.service
sudo journalctl -u mavlink-router.service -n 200 --no-pager
```

Verify the configuration:

```bash
sudo find /etc/mavlink-router -maxdepth 2 -type f -print
```

### Swarm service starts and exits

Check the parameter file and ArduPilot binary:

```bash
sudo test -r /etc/ardupilot-swarm/drone.parm
test -x "$HOME/ardupilot/build/sitl/bin/arduplane"
```

Review logs:

```bash
sudo journalctl -u ardupilot-swarm.service -n 200 --no-pager
```

## 13. Typical complete installation

```bash
sudo apt-get update
sudo apt-get install ardupilot-swarm

ardupilot-swarm-install

sudo ardupilot-swarm-install-parameters ~/Downloads/drone.parm
sudo ardupilot-swarm-configure-gcs 192.168.1.50 14550

sudo systemctl restart mavlink-router.service
sudo systemctl enable --now ardupilot-swarm.service

sudo systemctl status mavlink-router.service
sudo systemctl status ardupilot-swarm.service
```
