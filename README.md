# PeriCode downloads

Windows installers for [PeriCode](https://periphery.ai), a coding agent for
your terminal that can also operate Windows apps.

## Install or update

Paste this into PowerShell on Windows 10 or 11:

```powershell
irm https://github.com/eddyficial/pericode-releases/releases/latest/download/install.ps1 | iex
```

It downloads the latest installer from the [releases](https://github.com/eddyficial/pericode-releases/releases),
checks it against the published SHA-256 checksum, installs PeriCode for your
user (no admin rights) and adds `pericode` to your PATH. Node.js and Python
are included, so there is nothing to install first. Run the same line again
to update.

Then open a new terminal and run `pericode`. The first run walks you through
signing in to Claude, ChatGPT or GitHub Copilot.

Prefer clicking? Download `PericodeSetup-<version>.exe` from the latest
release and run it.

## Uninstall

Settings > Apps > Installed apps > PeriCode > Uninstall. Your settings in
`%USERPROFILE%\.pericode` are kept.

This repository holds releases only.