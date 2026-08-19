<h1 align="center">Mainsail Multi-Webcam Panels</h1>

<p align="center">
  <b>A <a href="https://github.com/mainsail-crew/mainsail">Mainsail</a> fork for Klipper / Moonraker
  that gives every webcam its own dashboard panel.</b>
</p>

<p align="center">
  "Webcam", "Webcam 2", "Webcam 3"… — one independent panel per camera, each with its own
  camera selection, its own collapsed state and its own position in the layout. Panels appear
  automatically as you add cameras in Moonraker: no dropdown, no split view, no configuration.
</p>

<p align="center">
  <img src="docs/fork/panel1.png" width="45%" alt="Mainsail dashboard: first webcam panel showing its own source, here an iframe dashboard">
  <img src="docs/fork/panel2.png" width="45%" alt="Mainsail dashboard: second independent webcam panel showing another camera">
</p>

*(live camera streams are blurred in the screenshots — your dashboard shows the real feeds)*

**This page is the guide: [install the fork](#install--from-stock-mainsail-to-the-panels) step by
step, then [use the panels](#using-the-panels). One thing lives in a separate document:
[UPDATES.md](UPDATES.md) — how to keep the panels across Mainsail updates.**

---

## What it does

| Stock Mainsail | This fork |
|---|---|
| One single "Webcam" panel; multiple cameras share it through a grid or a dropdown | One panel **per camera**: "Webcam", "Webcam 2", "Webcam 3", … |
| — | Each panel remembers **its own** selected camera |
| — | Each panel collapses / moves / hides **independently** |
| Adding a camera adds it to the single panel's grid | Adding a camera in Moonraker makes **a new panel appear automatically** |

The number of panels scales automatically with the number of cameras configured in Moonraker.
Nothing to configure: no file to edit, no rebuild. Requested upstream since 2022
([#1661](https://github.com/mainsail-crew/mainsail/issues/1661),
[#758](https://github.com/mainsail-crew/mainsail/issues/758)), never implemented.

## What it changes

**3 files, ~25 lines** on top of official Mainsail **v2.18.2**, reusing a mechanism Mainsail
already ships (the multi-instance macro-group panels). Everything else behaves exactly as upstream.

| File | Role |
|---|---|
| `src/store/gui/getters.ts` | declares the `webcam_2`…`webcam_N` panels (N = number of cameras) |
| `src/components/panels/WebcamPanel.vue` | `panelId` prop: "Webcam N" title, camera selection and collapse state stored **per panel** |
| `src/components/mixins/dashboard.ts` | panel name and icon in the layout editor |

Each panel's camera selection is stored in the Moonraker database under a per-panel key — which is
why it survives page reloads and updates. Full diff:
[official v2.18.2 → multiwebcam branch](https://github.com/mainsail-crew/mainsail/compare/v2.18.2...Nitrooxyde:mainsail-multi-webcam-panels:multiwebcam).

---

## Install — from stock Mainsail to the panels

Time: **about 10 minutes.** The build happens on your computer; the printer only receives files.

### What you need

- A computer with `git` and Node.js **20.19+ or 22.12+** (`node --version`) — a PC, a WSL shell,
  a Mac. **Not the printer.**
- A printer running Mainsail through Moonraker, with SSH access. On MainsailOS / KIAUH installs
  the Mainsail web root is `~/mainsail` — if yours differs, check the `root` line in
  `/etc/nginx/sites-available/mainsail` and adapt the paths below.

### Step 0 — Back up first (do not skip)

Everything below is reversible **only if you have a copy**. On the printer:

```bash
cp ~/printer_data/config/moonraker.conf \
   ~/printer_data/config/moonraker.conf.bak_$(date +%Y%m%d_%H%M%S)
tar czf ~/mainsail-backup-$(date +%Y%m%d_%H%M%S).tar.gz -C ~ mainsail
```

Restoring: put the saved `moonraker.conf` back, extract the tarball over `~/mainsail`,
`sudo systemctl restart moonraker`, reload the browser twice.

> **Never install or update while a print is running.**

### Step 1 — Build the patched Mainsail (on your computer)

```bash
git clone https://github.com/Nitrooxyde/mainsail-multi-webcam-panels.git
cd mainsail-multi-webcam-panels
npm ci
npm run build
```

This produces a `dist/` folder: a complete, ready-to-serve Mainsail with the patch applied.
(If the output ends with `zip: not found`, ignore it — the zip is only used for GitHub releases;
`dist/` is all you need.)

### Step 2 — Copy the build to the printer

On your computer (replace `pi@mainsailos.local` with your printer):

```bash
tar czf mainsail-multiwebcam.tar.gz -C dist .
scp mainsail-multiwebcam.tar.gz pi@mainsailos.local:~
```

On the printer:

```bash
mv ~/mainsail ~/mainsail.old_$(date +%Y%m%d_%H%M%S)
mkdir ~/mainsail
tar xzf ~/mainsail-multiwebcam.tar.gz -C ~/mainsail
```

### Step 3 — Reload and check the result

Open Mainsail in the browser and **reload the page twice** — Mainsail is a PWA and the first
reload can still serve the old interface from the service-worker cache. (Same thing for
OrcaSlicer's *Device* tab: it has its own cache, reload it twice too.)

With **two or more webcams** configured (Settings → Webcams), this is what you should get —
a separate "Webcam 2" panel, independent from the first:

<p align="center">
  <img src="docs/fork/panel1.png" width="45%" alt="Expected result: first webcam panel">
  <img src="docs/fork/panel2.png" width="45%" alt="Expected result: second, independent webcam panel">
</p>

With a single webcam configured, the dashboard looks exactly like stock Mainsail — the extra
panels only appear from the second camera on.

> ⚠️ **Installed this way, the panels last only until the next Mainsail update.** Your Update
> Manager still follows official mainsail-crew releases: the next time you click "update" there,
> it reinstalls stock Mainsail over your build and the panels are gone.
> **[UPDATES.md](UPDATES.md)** shows how to make updates install *your* build instead
> (~15 minutes, once).

---

## Using the panels

### Pick a camera for each panel

A panel with no camera assigned yet shows the "All" grid (every camera at once).
Click the **dropdown at the top right of the panel** and pick its camera.
The choice is saved per panel — you will not have to do it again.

<p align="center">
  <img src="docs/fork/panel-dropdown.png" width="60%" alt="Per-panel camera dropdown">
</p>

### Move, collapse or hide a panel

Every webcam panel behaves like any other Mainsail panel:

1. Open **Settings** (cog icon, top right) → **Dashboard**.
2. The "Webcam", "Webcam 2", … panels appear in the list: drag to reorder,
   click the checkbox to hide the ones you don't want.

<p align="center">
  <img src="docs/fork/settings-dashboard.png" width="75%" alt="Webcam and Webcam 2 in the dashboard layout editor">
</p>

### Add a 3rd or 4th camera

1. **Settings** → **Webcams** → add your camera (exactly like on stock Mainsail).
2. Done. A "Webcam 3" panel appears on the dashboard automatically.
   Don't want it as a separate card? Hide it (see above) — the camera stays available
   in the other panels' dropdowns.

---

## Keeping the panels across updates

The install above is deliberately the simplest possible one — but a stock Mainsail update erases
it. The durable setup is a **private update channel**: a free private GitHub repo that holds your
build, which your printer's `[update_manager mainsail]` follows with a read-only deploy key. From
then on, updating from the Mainsail UI installs *your* patched build, and a new official Mainsail
release is one script run away.

📖 **[UPDATES.md](UPDATES.md) — the full step-by-step (~15 minutes, done once).**

## Going back to stock Mainsail

Restore your Step 0 backup (`moonraker.conf` + the `~/mainsail` tarball), restart Moonraker,
reload twice. Or simply let the Update Manager reinstall official Mainsail over `~/mainsail`.
If you set up the private channel, follow
[UPDATES.md → Going back to stock](UPDATES.md#going-back-to-stock-mainsail) instead.

---

## Disclaimer

- **Unofficial fork, and no support.** This project is not affiliated with, endorsed by, or supported
  by [mainsail-crew](https://github.com/mainsail-crew). Do **not** open issues about this fork on
  their tracker, and do not ask them to support a printer running it — their maintainers owe you
  nothing here. Issues are closed on this repository too: it is published as source to fork and read,
  not as a supported product. You are on your own — which is exactly why Step 0 (backup) matters.
- **This repository ships no releases and no binaries.** It is source and documentation. If you set
  up an update channel, it is **your own private repository** — your printer must never depend on
  this one or anyone else's. Pointing `[update_manager mainsail]` at this repository is explicitly
  **not** supported.
- **No warranty.** Provided "as is", without warranty of any kind, express or implied, as stated in
  sections 15 and 16 of the [GPL-3.0](LICENSE) this fork inherits. You install and run it on your own
  machine, at your own risk.
- **Back up before every change** — see [Step 0](#step-0--back-up-first-do-not-skip). A saved
  `moonraker.conf` and a tarball of `~/mainsail` turn any problem into a two-minute rollback.
- **Your machine stays yours.** This fork only changes Mainsail's web interface: it never touches
  `printer.cfg`, kinematics, heaters or any Klipper setting. It remains your responsibility to keep
  your printer, its configuration and its prints in a safe state — including never updating mid-print.

## Credits

Credit where credit is due:

- **Idea, requirements and real-world validation** — [@Nitrooxyde](https://github.com/Nitrooxyde).
  The need for truly independent webcam panels, the requirement that adding a third or fourth panel
  must stay a one-minute job, the decision to fork at all, and the validation on a running Voron 2.4
  are theirs.
- **Design and implementation** — **Claude Opus 5** (Anthropic), running in
  [Claude Code](https://claude.com/claude-code): feasibility study, architecture, the patch itself,
  the build/release pipeline, the screenshots and this documentation.
- **Mainsail** — [mainsail-crew](https://github.com/mainsail-crew/mainsail), GPL-3.0. This fork only
  adds ~25 lines on top of their work; everything else that makes Mainsail good is theirs.

---

<sub>This is a fork of <a href="https://github.com/mainsail-crew/mainsail">Mainsail</a> by
mainsail-crew (GPL-3.0). For everything about Mainsail itself — features, documentation, community —
see the <a href="https://github.com/mainsail-crew/mainsail#readme">upstream README</a> and
<a href="https://docs.mainsail.xyz">docs.mainsail.xyz</a>.</sub>
