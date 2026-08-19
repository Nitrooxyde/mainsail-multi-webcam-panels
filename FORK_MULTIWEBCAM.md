# Mainsail multi-webcam fork 📷📷

> **In one sentence**: stock Mainsail can only show **one** webcam panel on the dashboard —
> this fork shows **one panel per camera**, each fully independent (its own camera, its own
> collapsed/expanded state, its own position in the layout).

Based on [Mainsail](https://github.com/mainsail-crew/mainsail) by mainsail-crew, GPL-3.0.
This feature has been requested upstream since 2023
([#1661](https://github.com/mainsail-crew/mainsail/issues/1661),
[#758](https://github.com/mainsail-crew/mainsail/issues/758)) but was never implemented.

<p align="center">
  <img src="docs/fork/panel1.png" width="49%" alt="Webcam panel 1 showing its own camera">
  <img src="docs/fork/panel2.png" width="49%" alt="Webcam panel 2 showing another camera">
</p>

*(camera streams are blurred in all screenshots — your dashboard will show the live feeds)*

---

## What the fork changes

| Stock Mainsail | This fork |
|---|---|
| One single "Webcam" panel; multiple cameras = a grid or a dropdown inside that one panel | One panel **per camera**: "Webcam", "Webcam 2", "Webcam 3", … |
| — | Each panel remembers **its own** selected camera |
| — | Each panel collapses / moves / hides **independently** |
| Adding a camera just adds it to the single panel's grid | Adding a camera in Moonraker makes **a new panel appear automatically** |

The number of panels **scales automatically** with the number of cameras configured in
Mainsail/Moonraker. There is **nothing to configure**: no file to edit, no rebuild.

---

## Step-by-step usage guide

### Step 1 — Pick a camera for each panel

A panel with no camera assigned yet shows the "All" grid (every camera at once).
Click the **dropdown at the top right of the panel** and pick its camera.
The choice is saved per panel — you will not have to do it again.

<p align="center">
  <img src="docs/fork/panel-dropdown.png" width="60%" alt="Per-panel camera dropdown">
</p>

### Step 2 — Move, collapse or hide a panel

Every webcam panel behaves like any other Mainsail panel:

1. Open **Settings** (cog icon, top right) → **Dashboard**.
2. The "Webcam", "Webcam 2", … panels appear in the list: drag to reorder,
   click the checkbox to hide the ones you don't want.

<p align="center">
  <img src="docs/fork/settings-dashboard.png" width="75%" alt="Webcam and Webcam 2 in the dashboard layout editor">
</p>

### Step 3 — Add a 3rd or 4th camera

1. **Settings** → **Webcams** → add your camera (exactly like on stock Mainsail).
2. Done. A "Webcam 3" panel appears on the dashboard automatically.
   Don't want it as a separate card? Hide it (Step 2) — the camera stays available
   in the other panels' dropdowns.

---

## Installation

> Already running Mainsail? Installing the fork = **one line changed in
> `moonraker.conf`** + one update from the UI. Nothing else.

1. On your Klipper machine (Pi), open `~/printer_data/config/moonraker.conf` and find the
   `[update_manager mainsail]` section. Change the `repo:` line:

   ```ini
   [update_manager mainsail]
   type: web
   channel: stable
   repo: Nitrooxyde/mainsail-multi-webcam-panels    # ← instead of mainsail-crew/mainsail
   path: ~/mainsail
   ```

2. Restart Moonraker (printer idle):

   ```bash
   sudo systemctl restart moonraker
   ```

3. In Mainsail: **Machine** → **Update Manager** card → update "mainsail".
   The update manager now downloads this fork — and will keep doing so on every
   future update (the fork can no longer be overwritten by a stock release).

<p align="center">
  <img src="docs/fork/update-manager.png" width="60%" alt="Update Manager with the fork up to date">
</p>

4. **Reload the page twice** (F5, then F5 again). Mainsail is an offline-capable web app:
   the first reload installs the new version in the background, the second one displays it.

> ⚠️ **Same rule for OrcaSlicer**: Orca's *Device* tab embeds Mainsail with its own cache.
> After an update, reload it twice (or clear Orca's cache) to see the new version.

### Going back to stock Mainsail

Put `repo: mainsail-crew/mainsail` back in `moonraker.conf`, restart Moonraker,
then update from the Update Manager. Nothing else to clean up.

---

## Staying up to date with upstream Mainsail

Your Moonraker now tracks this fork instead of `mainsail-crew/mainsail`. That is precisely what
stops an official release from overwriting the patch — but it also means a new Mainsail version
does **not** reach your printer on its own. It reaches you once the patch has been rebased onto
that release and published as a release here (or in your own fork, see below).

> ⚠️ **Not battle-tested yet.** This fork was cut from **v2.18.2**, which is still the latest
> upstream release, so the rebase-and-publish flow described here has never run against a real
> new version. Read the script's output rather than firing and forgetting, and please open an
> issue if something breaks — it will save the next person.

### If you just use this fork

Nothing to do. When a new release is published here, Mainsail's Update Manager offers it like any
other update: install it with the printer idle, then **reload the page twice** (service worker
cache). Upstream releases are listed [here](https://github.com/mainsail-crew/mainsail/releases) —
if this fork ever lags behind one you need, open an issue.

### If you want to be your own maintainer

Nothing in this repository is tied to my account — you can run the whole pipeline yourself and
never wait on me:

1. **Fork this repository** on GitHub, keeping the `multiwebcam` branch.
2. Clone your fork on a machine with `git`, `node`/`npm`, `python3` and an authenticated
   [`gh`](https://cli.github.com/) CLI (the account must own your fork).
3. Run it against the upstream release you want:

   ```bash
   FORK=you/your-fork ./scripts/update_fork_mainsail.sh v2.18.3
   ```

   The script rebases the patch onto the official tag, **rewrites the fork identity inside
   `release_info.json` to your own owner/repo**, builds, packs `mainsail.zip`, and publishes the
   release with its title equal to the tag. It never touches your printer.

4. Point your printer at your own fork: `repo: you/your-fork` in `[update_manager mainsail]`,
   restart Moonraker, update from the UI.

If upstream modified one of the 4 patched files, the rebase stops and tells you exactly where —
the patch is ~27 lines, so conflicts stay small and readable.

Two rules that must never be broken (learned the hard way):

- The GitHub release **title** must be **exactly the tag** (`v2.18.3`): Moonraker reads the remote
  version from the release *title*, not from the tag. A different title = "update available" shown
  forever.
- `release_info.json` must carry the **owner and name of the repo Moonraker points at**. Moonraker
  compares `repo:` with `<project_owner>/<project_name>` and, on mismatch, raises an anomaly and
  silently falls back to the repo it detected — which is why step 3 rewrites that identity for you.

---

## Under the hood (for the curious)

The patch is **tiny — 4 files, ~27 lines** — because it reuses a mechanism Mainsail
already ships: the multi-instance macro-group panels (`macrogroup_<id>`).

| File | Role |
|---|---|
| `src/store/gui/getters.ts` | declares the `webcam_2`…`webcam_N` panels (N = number of cameras) |
| `src/components/panels/WebcamPanel.vue` | `panelId` prop: "Webcam N" title, camera selection and collapse state stored **per panel** |
| `src/components/mixins/dashboard.ts` | panel name and icon in the layout editor |
| `src/plugins/build-release_info.ts` | fork identity in `release_info.json` (for the update manager) |

Each panel's camera selection is stored in the Moonraker database
(`gui.view.webcam.currentCam`) under a per-panel key — which is why it survives page
reloads and updates.

Full diff: [official v2.18.2 → multiwebcam branch](https://github.com/mainsail-crew/mainsail/compare/v2.18.2...Nitrooxyde:mainsail-multi-webcam-panels:multiwebcam)

---

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
  adds ~27 lines on top of their work; everything else that makes Mainsail good is theirs.
