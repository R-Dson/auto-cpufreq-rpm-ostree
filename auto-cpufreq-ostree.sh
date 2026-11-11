#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (e.g., sudo $0)." >&2
    exit 1
fi

install_auto_cpufreq() {
    for cmd in git python3; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: '$cmd' is required but not installed." >&2
            exit 1
        fi
    done

    echo "[1/6] Stopping existing service and masking conflicting daemons..."
    systemctl stop auto-cpufreq power-profiles-daemon tuned 2>/dev/null || true
    systemctl mask power-profiles-daemon tuned 2>/dev/null || true

    echo "[2/6] Preparing paths in /var/opt and /usr/local..."
    mkdir -p /var/opt/auto-cpufreq /usr/local/bin /usr/local/share/auto-cpufreq/scripts
    ln -sfn /var/opt/auto-cpufreq /var/opt/auto-cpufreq/current
    python3 -m venv /var/opt/auto-cpufreq/venv

    TMPDIR=$(mktemp -d /tmp/auto-cpufreq-XXXXXX)
    trap 'rm -rf "$TMPDIR"' RETURN

    echo "[3/6] Fetching repository and installing dependencies..."
    git clone https://github.com/AdnanHodzic/auto-cpufreq.git "$TMPDIR"
    /var/opt/auto-cpufreq/venv/bin/python -m pip install --upgrade pip wheel setuptools
    /var/opt/auto-cpufreq/venv/bin/python -m pip install --force-reinstall "$TMPDIR"

    echo "[4/6] Installing helper scripts and CLI symlink..."
    # Keep an existing wrapper-managed unit in sync with the adapted template.
    local managed_unit=false
    if cmp -s /usr/local/share/auto-cpufreq/scripts/auto-cpufreq.service \
              /etc/systemd/system/auto-cpufreq.service; then
        managed_unit=true
    fi
    cp -r "$TMPDIR"/scripts/* /usr/local/share/auto-cpufreq/scripts/
    sed -i 's|/opt/auto-cpufreq|/var/opt/auto-cpufreq|g' \
        /usr/local/share/auto-cpufreq/scripts/auto-cpufreq.service
    if "$managed_unit"; then
        cp /usr/local/share/auto-cpufreq/scripts/auto-cpufreq.service \
           /etc/systemd/system/auto-cpufreq.service
    fi
    chmod +x /usr/local/share/auto-cpufreq/scripts/*
    ln -sf /var/opt/auto-cpufreq/venv/bin/auto-cpufreq /usr/local/bin/auto-cpufreq

    echo "[5/6] Setting SELinux contexts..."
    chcon -R -t bin_t /var/opt/auto-cpufreq/venv/bin
    restorecon -Rv /usr/local &>/dev/null || true

    echo "[6/6] Installing and starting systemd service..."
    /var/opt/auto-cpufreq/venv/bin/auto-cpufreq --install
    restorecon -Rv /usr/local/bin &>/dev/null || true
    chcon -R -t bin_t /var/opt/auto-cpufreq/venv/bin

    # Interactive configuration prompt
    read -r -p "Write recommended power profile settings to /etc/auto-cpufreq.conf? [Y/n] " reply || reply=""
    reply="${reply:-y}"
    if [[ ! "$reply" =~ ^[Nn] ]]; then
        local config_source=""
        if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
            config_source="$(dirname -- "${BASH_SOURCE[0]}")/auto-cpufreq.conf"
        fi
        if [[ ! -f "$config_source" ]]; then
            config_source="$TMPDIR/auto-cpufreq.conf"
            python3 - "$config_source" <<'PYTHON'
import sys
from urllib.request import urlretrieve

urlretrieve(
    "https://raw.githubusercontent.com/R-Dson/auto-cpufreq-rpm-ostree/refs/heads/main-oma/auto-cpufreq.conf",
    sys.argv[1],
)
PYTHON
        fi
        install -m 644 "$config_source" /etc/auto-cpufreq.conf
        echo "Configuration written to /etc/auto-cpufreq.conf."
    else
        echo "Skipping configuration file creation."
    fi

    systemctl restart auto-cpufreq

    if systemctl is-active --quiet auto-cpufreq; then
        echo "Success: auto-cpufreq daemon is active and running."
    else
        echo "Failure: Service failed to start. Check 'systemctl status auto-cpufreq'." >&2
        exit 1
    fi
}

remove_auto_cpufreq() {
    echo "[1/4] Stopping and removing auto-cpufreq daemon..."
    if command -v auto-cpufreq &>/dev/null; then
        auto-cpufreq --remove &>/dev/null || true
    fi
    systemctl stop auto-cpufreq 2>/dev/null || true
    systemctl disable auto-cpufreq 2>/dev/null || true
    rm -f /etc/systemd/system/auto-cpufreq.service
    systemctl daemon-reload
    systemctl reset-failed auto-cpufreq 2>/dev/null || true

    echo "[2/4] Removing files, directories, and symlinks..."
    rm -rf /var/opt/auto-cpufreq \
           /usr/local/share/auto-cpufreq \
           /var/log/auto-cpufreq.log
    rm -f /usr/local/bin/auto-cpufreq \
          /usr/local/bin/cpufreqctl.auto-cpufreq \
          /usr/local/bin/auto-cpufreq-install \
          /usr/local/bin/auto-cpufreq-remove \
          /etc/auto-cpufreq.conf

    echo "[3/4] Unmasking and restoring native power management daemon..."
    systemctl unmask tuned power-profiles-daemon 2>/dev/null || true
    systemctl daemon-reload

    if systemctl cat tuned.service &>/dev/null; then
        systemctl enable --now tuned
        echo "Restored native daemon: tuned"
    elif systemctl cat power-profiles-daemon.service &>/dev/null; then
        systemctl enable --now power-profiles-daemon
        echo "Restored native daemon: power-profiles-daemon"
    else
        echo "Warning: Neither tuned nor power-profiles-daemon unit files were found." >&2
    fi

    echo "[4/4] Verifying removal..."
    if command -v auto-cpufreq &>/dev/null; then
        echo "Failure: auto-cpufreq binary is still present in PATH." >&2
        exit 1
    fi

    if systemctl is-active --quiet tuned || systemctl is-active --quiet power-profiles-daemon; then
        echo "Success: auto-cpufreq removed completely and native power tuning is active."
    else
        echo "Warning: Native power management daemon is not currently active." >&2
        exit 1
    fi
}

case "${1:-install}" in
    install|--install|-i)
        install_auto_cpufreq
        ;;
    remove|--remove|-r|uninstall|--uninstall)
        remove_auto_cpufreq
        ;;
    *)
        echo "Usage: sudo $0 [install | --remove]" >&2
        exit 1
        ;;
esac
