# SAP MII Workbench on macOS

Sets up an Apple Silicon Mac so that a `Workbench.jsp` downloaded from SAP MII opens
the MII Workbench.

## Before you start

- Apple Silicon Mac (M1 or newer)
- [Homebrew](https://brew.sh) installed
- Network access to your MII server (usually the company network or VPN)

## Install (one time, about 5 minutes)

1. Download or clone this repo, e.g. into `~/Downloads/mii-workbench-macos-kit`.
2. Open **Terminal** and run:
   ```bash
   cd ~/Downloads/mii-workbench-macos-kit
   ./install.sh
   ```
   Enter your Mac password when Homebrew asks (needed for Java and OpenWebStart).

The installer:

| What | Where |
|---|---|
| OpenWebStart, Azul Zulu 8 (native Java 8), `duti` | via Homebrew |
| Launcher script | `~/bin/mii-workbench` |
| Right-click fix (built from `agent/PopupTriggerFix.java`) | `~/.config/mii-workbench/mac-popup-fix.jar` |
| Double-click app, default app for `.jsp` | `~/Applications/MII Workbench.app` |
| OpenWebStart setting `ows.jvm.manager.versionRange=1.8*` | `~/.config/icedtea-web/deployment.properties` |

Running it again is safe.

## Daily use

1. Open the Workbench from the MII menu → `Workbench.jsp` lands in **Downloads**.
2. **Double-click** it.
3. Answer **Yes** to every security prompt. If you say No, parts of the Workbench
   (e.g. the actions add-on) don't load.

Each `Workbench.jsp` contains a logon ticket that is valid for about 8 hours, so the
launcher **deletes it from Downloads** once it has read it (older `Workbench*.jsp`
downloads too). To relaunch, download a fresh one from MII. To keep the files, start
with `MII_KEEP_JSP=1 ~/bin/mii-workbench`.

If macOS shows *"Apple could not verify … is free of malware"*, click **Done**, never
*Move to Trash*. The Workbench still opens.

## Why this is needed

On Windows the Workbench starts through Java Web Start. On a Mac there are four
problems, and the kit works around each one:

1. **No Java Web Start.** It was removed from Java. Replacement: OpenWebStart.
2. **OpenWebStart crashes on new Java (16+), silently.** It runs on Java 8 instead.
3. **A bug in MII's own files.** Some add-on files leave the trailing `/` off the
   server address, which makes the server port (`:50000`) get dropped. The launcher
   downloads those files and repairs them before every start.
4. **Right-click menus never open.** The Workbench only opens its menu when a
   right-click is *released*, which is how Windows reports it. macOS reports the
   *press* instead. A small Java agent (`mac-popup-fix.jar`) changes the Mac events to
   the Windows behaviour. No SAP files are changed.

## Troubleshooting

- **Log of the last launch:** `~/Library/Logs/mii-workbench.log`. The first line shows
  which Java ran, and `Picked up JAVA_TOOL_OPTIONS` shows the right-click fix loaded.
- **Jar downloads fail:** check the VPN, or a proxy that intercepts TLS, first.
- **Disk use:** the launcher log is overwritten on every launch, and OpenWebStart's own
  logging stays off. If the downloaded Workbench jars in `~/.cache/icedtea-web/cache` pass
  500 MB, the launcher clears them (set `MII_CACHE_MAX_MB` to change the limit). The
  Workbench's Java (~360 MB) lives in `~/.cache/icedtea-web/jvm-cache`. The log notes when
  older copies pile up there; remove them in *OpenWebStart Settings*.
- **Start by hand:** `~/bin/mii-workbench ~/Downloads/Workbench.jsp`
- **Optional: SapMachine 11 instead of Zulu 8:**
  ```bash
  brew install --cask sap/sapmachine/sapmachine11-jdk
  echo sapmachine11 > ~/.config/mii-workbench/java    # back: echo zulu8 > …
  ```
  Java 17 and later won't work (see point 2).
- **Remove:** delete `~/Applications/MII Workbench.app`, `~/bin/mii-workbench` and
  `~/.config/mii-workbench`.

## Disclaimer

Community project, not affiliated with or endorsed by SAP. SAP and SAP MII are
trademarks of SAP SE. No SAP software is included or modified: the kit only launches
what your own MII server delivers.
