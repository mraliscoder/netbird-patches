# NetBird with routed sources

The NetBird client, built from upstream releases with one patch: when
`NB_ALLOW_ROUTED_SOURCES=true` is set, a peer accepts inbound traffic on the
WireGuard interface from the prefixes of the network routes it has installed.

Stock NetBird only admits peer IPs as sources, so hosts behind a routing peer
(here, the OpenConnect clients in `10.66.16.0/20`) can be reached from the mesh
but can't open connections to mesh peers. Without the variable the build behaves
like upstream.

## Installing on a peer

```sh
curl -fsSL https://github.com/mraliscoder/netbird-patches/releases/latest/download/install.sh | sudo sh
```

The script swaps the binary (the old one stays next to it as `netbird.orig`),
sets the variable through `netbird service reconfigure`, and holds the package
so updates don't restore the stock binary. To go back:

```sh
sudo netbird service stop
sudo mv "$(command -v netbird).orig" "$(command -v netbird)"
sudo netbird service reconfigure --service-env NB_ALLOW_ROUTED_SOURCES=false
sudo netbird service start
sudo apt-mark unhold netbird
```

## Releases

`.github/workflows/build.yml` checks for a new upstream release every day and
publishes `<tag>-routedsrc` with binaries for amd64, arm64 and arm. If a patch
stops applying the run fails; rebase the patch onto the new tag and push it.

Every allowed prefix can reach the peer on any port, so only turn the variable on
for peers whose routes lead to networks you trust.
