# NetBird with routed sources

The NetBird client, built from upstream releases with one patch: when
`NB_ALLOW_ROUTED_SOURCES=true` is set, hosts behind a routing peer are treated
like the routing peer itself. Every policy rule whose source is a routing peer
also matches the prefixes that peer routes.

Stock NetBird only admits peer IPs as sources, so hosts behind a routing peer
(here, the OpenConnect clients in `10.66.16.0/20` behind `svpn.sculk.ltd`) can
be reached from the mesh but can't open connections to mesh peers. Without the
variable the build behaves like upstream.

## Controlling access with policies

Put the routing peer in its own group, say `svpn`, and write policies from that
group as you would for any peer:

| Source | Destination | Protocol | Ports  | Action |
|--------|-------------|----------|--------|--------|
| `svpn` | `idp`       | TCP      | 443    | Accept |
| `svpn` | `servers`   | All      |        | Accept |

VPN clients then reach `idp` on 443 only, and nothing on port 22. The same
policies also cover the routing peer's own traffic, since the clients and the
routing peer now share one identity.

- Remove or narrow the default `All → All` policy. While the routing peer is in
  `All`, that policy lets VPN clients reach every peer.
- Install the patched build on the **destination** peers (`idp`, `servers`).
  Those are the ones that filter inbound traffic; the routing peer can keep the
  stock client.
- Destination peers still need the route back to the routed prefix, so the
  route must be distributed to them.

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
stops applying or its tests fail the run fails; rebase the patch onto the new tag
and push it.
