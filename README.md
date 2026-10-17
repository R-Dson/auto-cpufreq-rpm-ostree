# auto-cpufreq for rpm-ostree Distros

Installs and configures [`auto-cpufreq`](https://github.com/AdnanHodzic/auto-cpufreq) as a system daemon on immutable/atomic systems (Project Bluefin, Fedora Silverblue, Kinoite, Bazzite, Aurora) without modifying the read-only `/usr` tree or layering packages.

## Prerequisites

- `sudo` privileges
- `git`
- `python3` (with `venv` support)
- `policycoreutils` (`chcon` and `restorecon`)

*(Note: Conflicting services such as `tuned` and `power-profiles-daemon` are detected, stopped, and masked automatically by the script.)*

---

## Installation

1. Save the management script:
```bash
chmod +x auto-cpufreq-ostree.sh
```

2. Run the installer (defaults to install/update):
```bash
sudo ./auto-cpufreq-ostree.sh
```

3. Check Live monitoring & stats
```bash
auto-cpufreq --stats
```

---

## Uninstallation

Removes all binaries, virtual environments, scripts, and unmasks/restores the native power management daemon (`tuned` or `power-profiles-daemon`):

```bash
sudo ./auto-cpufreq-ostree.sh --remove
```
