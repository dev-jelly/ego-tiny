# Install or upgrade ego tiny

Read this file only when `ego-browser` is not found, when `ego-browser skill` reports an unknown command, or when the user asks to install ego tiny. For day-to-day browser work, run `ego-browser skill` and follow its output.

The ego-browser skill depends on the ego tiny browser: the `ego-browser` command is provided by the ego tiny app. Once ego tiny is installed and you've completed onboarding, no additional setup is normally needed.

ego tiny website: https://lite.ego.app/

## Upgrade an older ego tiny

If `ego-browser` exists but `ego-browser skill` reports `Unknown command: skill`, the installed ego tiny is older than this skill. Ask the user for approval, then run:

```bash
ego-browser upgrade
```

If `upgrade` is also an unknown command, reinstall with the steps for the user's operating system. Then continue with "After installing: confirm `ego-browser` is available" in that file.

## Install

The install steps, the commands that confirm the installation, and the troubleshooting differ by operating system. Read the file for the machine you are running on and follow it to the end:

- macOS: [install-macos.md](install-macos.md)
- Windows: [install-windows.md](install-windows.md)
- Other platforms: there is no installer. Have the user check https://lite.ego.app/ for a build; if none exists, ego-browser is not available on this machine.

## Onboarding

Onboarding is a step the user completes in the GUI, on every platform:

- Choose to import data from Chrome or another browser as needed.
- Onboarding registers the `ego-browser` command on the PATH.

After the app opens, wait for the user to confirm they've finished onboarding before continuing. The per-platform file explains how to confirm the command is available afterwards.

## After that, return to the original task

Once the environment is ready, return to the user's original task: run `ego-browser skill` and follow its output.
