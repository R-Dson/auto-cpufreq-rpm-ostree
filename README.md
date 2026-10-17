# auto-cpufreq for rpm-ostree Distros

Installs and configures `auto-cpufreq` as a system daemon on immutable/atomic systems (Project Bluefin, Fedora Silverblue, Kinoite, Bazzite, Aurora) without modifying the read-only `/usr` tree or layering packages.

## Prerequisites

* **Host packages** (installed by default on Bluefin and Fedora Silverblue):
  * `git`
  * `python3` (with standard library `venv`)
  * `policycoreutils` (`chcon`, `restorecon`)
* **Privileges**: Root/sudo access.
* **Network**: Active internet connection to fetch the upstream repository and build wheels.

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

---

## Monitoring & Configuration

* **Live monitoring & stats:**
```bash
  auto-cpufreq --stats
```

* **Custom settings:**
Create or modify `/etc/auto-cpufreq.conf` (applied automatically by the daemon).

---

## Uninstallation

Removes all binaries, virtual environments, scripts, and unmasks/restores the native power management daemon (`tuned` or `power-profiles-daemon`):

```bash
  sudo ./auto-cpufreq-ostree.sh --remove
```

