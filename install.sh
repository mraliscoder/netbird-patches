#!/bin/sh
# Replaces the NetBird client binary on this peer with the patched build and
# turns on applying routing peers' policies to the hosts they route.
#
# The peer must already run NetBird installed the usual way; this only swaps
# the binary and adds the service environment variable.
#
#   curl -fsSL https://github.com/mraliscoder/netbird-patches/releases/latest/download/install.sh | sudo sh
#   sudo RELEASE=v0.60.0-routedsrc sh install.sh     # a specific release
#
# For a private repository set GITHUB_TOKEN to a token that can read it.

set -eu

REPO="${REPO:-mraliscoder/netbird-patches}"
RELEASE="${RELEASE:-latest}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root" >&2
    exit 1
fi

case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    armv7l | armv6l) arch=arm ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

target="$(command -v netbird || true)"
if [ -z "$target" ]; then
    echo "NetBird isn't installed; install it first with the official installer" >&2
    exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh_curl() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$@"
    else
        curl -fsSL "$@"
    fi
}

if [ "$RELEASE" = latest ]; then
    api="https://api.github.com/repos/$REPO/releases/latest"
else
    api="https://api.github.com/repos/$REPO/releases/tags/$RELEASE"
fi
# flattened to one line so the asset's url and name can be matched together
gh_curl "$api" | tr -d '\n' > "$tmp/release.json"

# Release assets go through the API so a token works for private repositories
download() {
    url="$(grep -o "\"url\": *\"[^\"]*/releases/assets/[0-9]*\"[^}]*\"name\": *\"$1\"" "$tmp/release.json" \
        | head -n1 | sed 's/"url": *"\([^"]*\)".*/\1/')"
    if [ -z "$url" ]; then
        echo "Asset $1 not found in release $RELEASE of $REPO" >&2
        exit 1
    fi
    gh_curl -H "Accept: application/octet-stream" -o "$tmp/$1" "$url"
}

download "netbird_linux_$arch"
download SHA256SUMS
(cd "$tmp" && grep " netbird_linux_$arch\$" SHA256SUMS | sha256sum -c -)

netbird service stop || true
cp "$target" "$target.orig"
install -m 0755 "$tmp/netbird_linux_$arch" "$target"

# reconfigure keeps the saved install parameters, adds the variable and starts
# the service again if it was running; it was stopped above, so start it here
netbird service reconfigure --service-env NB_ALLOW_ROUTED_SOURCES=true
netbird service start

# keep the package manager from putting the stock binary back
if command -v apt-mark >/dev/null 2>&1 && dpkg -s netbird >/dev/null 2>&1; then
    apt-mark hold netbird
elif command -v dnf >/dev/null 2>&1 && rpm -q netbird >/dev/null 2>&1; then
    dnf versionlock add netbird 2>/dev/null \
        || echo "Warning: install dnf-plugin-versionlock or exclude netbird from updates" >&2
fi

echo "Installed $("$target" version); the previous binary is at $target.orig"
