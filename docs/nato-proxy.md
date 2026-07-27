# Restricted NATO HTTP Proxy

The AWS Ubuntu host provides an HTTP/HTTPS forward proxy for traffic that must traverse an interactive OpenConnect VPN session.

## Installed packages

The `ardupilot-swarm` Debian package depends on:

- `openconnect`
- `vpnc-scripts`
- `squid`

VPN credentials, authentication groups, MFA, certificates, and the VPN gateway address remain external to this repository.

## Network path

```text
Authorised Tailscale client
        |
        | HTTP proxy 100.87.23.102:3128
        v
AWS Ubuntu host running Squid
        |
        | OpenConnect VPN route
        v
172.16.0.15
```

Squid does not provide a general internet proxy. It accepts only these Tailscale client addresses:

```text
100.70.250.58/32
100.112.27.31/32
100.115.187.97/32
```

The only permitted destination is:

```text
172.16.0.15/32
```

Allowed destination ports are HTTP `80` and HTTPS `443`. HTTPS uses the normal Squid `CONNECT` tunnel and is not decrypted by the proxy.

## Managed files

Repository configuration:

```text
config/squid-nato-proxy.conf
```

Installed configuration:

```text
/etc/squid/squid.conf
```

The package preserves a pre-existing, different Squid configuration once at:

```text
/etc/squid/squid.conf.pre-ardupilot-swarm
```

## Starting the VPN

Start OpenConnect interactively using the gateway and authentication options supplied for the deployment. A typical AnyConnect command is:

```bash
sudo openconnect --protocol=anyconnect --user USERNAME VPN_GATEWAY
```

Do not store passwords, MFA values, private keys, cookies, or VPN gateway details in this repository.

Verify that the NATO destination is routed through the OpenConnect tunnel:

```bash
ip route get 172.16.0.15
```

The selected route should use the OpenConnect tunnel interface.

## Starting Squid

The package starts Squid only when the configured Tailscale listener address is present on the host. After authenticating Tailscale, validate and start the service with:

```bash
sudo squid -k parse
sudo systemctl enable --now squid.service
sudo systemctl restart squid.service
sudo ss -lntp | grep ':3128'
```

The listener should be:

```text
100.87.23.102:3128
```

## Client test

From one of the authorised Tailscale clients:

```bash
curl -v --proxy http://100.87.23.102:3128 https://172.16.0.15/
```

A public internet request through the same proxy must be rejected:

```bash
curl -v --proxy http://100.87.23.102:3128 https://example.com/
```

## Logs

```bash
sudo tail -f /var/log/squid/access.log
sudo journalctl -u squid.service -f
```

A successful request still depends on the OpenConnect session being active and carrying a valid route to `172.16.0.15`.
