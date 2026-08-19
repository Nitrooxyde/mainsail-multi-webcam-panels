# Mainsail multi-webcam fork 📷📷

> **In one sentence**: stock Mainsail can only show **one** webcam panel on the dashboard —
> this fork shows **one panel per camera**, each fully independent (its own camera, its own
> collapsed/expanded state, its own position in the layout).

Based on [Mainsail](https://github.com/mainsail-crew/mainsail) by mainsail-crew, GPL-3.0.
This feature has been requested upstream since 2023
([#1661](https://github.com/mainsail-crew/mainsail/issues/1661),
[#758](https://github.com/mainsail-crew/mainsail/issues/758)) but was never implemented.

<p align="center">
  <img src="docs/fork/panel1.png" width="49%" alt="Webcam panel 1 showing its own source, here an iframe dashboard">
  <img src="docs/fork/panel2.png" width="49%" alt="Webcam panel 2 showing another camera">
</p>

*(live camera streams are blurred in the screenshots that show them — your dashboard shows the real feeds)*

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

## Installation — your own private update channel (~15 minutes)

This project has two halves, and only one of them is public:

- **The patch** (this repository): what gives Mainsail one dashboard panel per webcam. Public,
  for everyone.
- **The update channel**: the repo your printer's `[update_manager mainsail]` actually follows, so
  that Mainsail updates install the patched build instead of erasing it. That one is **yours and
  private** — nobody else's printer should ever depend on it, and yours should never depend on
  somebody else's. Moonraker's `git_repo` updater + a read-only deploy key make a private repo work.

> ✅ / ⚠️ **Battle-tested status (2026-08-19):** the channel mechanism itself has been exercised for
> real — push to the channel → Update Manager sees it → update applied from the UI, verified
> end-to-end. What has **not** run for real yet is the rebase onto a *newer* official release
> (v2.18.2 is still the latest). Read the script's output rather than firing and forgetting.

### What you need

- A GitHub account (a free one — private repositories are free).
- A computer with `git`, `node`/`npm` and `python3` — a PC, a WSL shell, a Mac. **Not the printer.**
- A printer running Mainsail through Moonraker.

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

### Step 1 — Create your private channel repository

On GitHub: **New repository** → name it e.g. `mainsail-dist` → **Private** → create it empty
(no README).

### Step 2 — Build the patched Mainsail and push it to your channel

On your computer:

```bash
git clone https://github.com/Nitrooxyde/mainsail-multi-webcam-panels.git
cd mainsail-multi-webcam-panels
CHANNEL=https://github.com/you/mainsail-dist.git ./scripts/update_channel.sh v2.18.2
```

`v2.18.2` is the official Mainsail release the patch gets applied on — check
[upstream releases](https://github.com/mainsail-crew/mainsail/releases) for the current one.
The script rebases the patch onto that release, builds, and pushes the finished build to **your**
channel repo (branch `main`, tagged). Optionally fork this repository first and set
`SOURCE=https://github.com/you/your-fork.git` — then you do not even depend on this repo staying up.

### Step 3 — Give your printer read-only access to the channel

On the printer (one-time):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/mainsail_dist_deploy -N "" -C "moonraker-mainsail-dist"
cat >> ~/.ssh/config <<'EOF'

Host github.com-mainsail-dist
    HostName github.com
    User git
    IdentityFile ~/.ssh/mainsail_dist_deploy
    IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts
cat ~/.ssh/mainsail_dist_deploy.pub
```

Copy the printed public key, then on GitHub: your channel repo → **Settings** → **Deploy keys** →
**Add deploy key** → paste it, leave **Allow write access unchecked** (read-only). Test from the
printer: `ssh -T git@github.com-mainsail-dist` should greet you with the repo name.

### Step 4 — Put the channel build in place

On the printer (you made the Step 0 backup, right?):

```bash
git clone git@github.com-mainsail-dist:you/mainsail-dist.git ~/mainsail.new
mv ~/mainsail ~/mainsail.old && mv ~/mainsail.new ~/mainsail
```

### Step 5 — Point Moonraker at the channel

Edit `~/printer_data/config/moonraker.conf` and replace the `[update_manager mainsail]` section:

```ini
[update_manager mainsail]
type: git_repo
path: ~/mainsail
origin: git@github.com-mainsail-dist:you/mainsail-dist.git
primary_branch: main
is_system_service: False
```

### Step 6 — Restart and verify

```bash
sudo systemctl restart moonraker
```

In Mainsail: **Machine** → **Update Manager** — the "mainsail" entry now reads something like
`v2.18.2-0` (git describe), valid, clean. Reload the page twice (service worker cache). From now
on a stock release can never overwrite the panels: your printer only ever installs what **you**
pushed to **your** channel.

> ⚠️ **Same rule for OrcaSlicer**: Orca's *Device* tab embeds Mainsail with its own cache.
> After an update, reload it twice (or clear Orca's cache).

---

## Keeping up with official Mainsail

Your printer follows your channel, so a new official release does **not** reach it on its own —
that is exactly what protects the panels. When mainsail-crew publishes, say, `v2.18.3`:

```bash
CHANNEL=https://github.com/you/mainsail-dist.git ./scripts/update_channel.sh v2.18.3
```

The script fetches the **official** `v2.18.3` tag from `mainsail-crew/mainsail`, replays the
multiwebcam patch on top of it, rebuilds, and pushes the result to your channel. Then update from
the Mainsail UI as usual (printer idle, Step 0 backup first, double reload after).

If upstream modified one of the 4 patched files, the rebase stops and tells you exactly where —
the patch is ~27 lines, so conflicts stay small and readable.

### Going back to stock Mainsail

Restore the stock `[update_manager mainsail]` section in `moonraker.conf`:

```ini
[update_manager mainsail]
type: web
channel: stable
repo: mainsail-crew/mainsail
path: ~/mainsail
```

then `rm -rf ~/mainsail && mkdir ~/mainsail`, restart Moonraker, and update from the Update
Manager (it reinstalls official Mainsail). Nothing else to clean up.

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

## Disclaimer

- **Unofficial fork, and no support.** This project is not affiliated with, endorsed by, or supported
  by [mainsail-crew](https://github.com/mainsail-crew). Do **not** open issues about this fork on
  their tracker, and do not ask them to support a printer running it — their maintainers owe you
  nothing here. Issues are closed on this repository too: it is published as source to fork and read,
  not as a supported product. You are on your own — which is exactly why Step 0 (backup) and your own
  fork matter.
- **This repository ships no releases and no binaries.** It is source and documentation. Your
  printer's updates only ever come from **your own private channel repository** — never from here,
  never from anyone else's. Pointing `[update_manager mainsail]` at this repository is explicitly
  **not** supported.
- **No warranty.** Provided "as is", without warranty of any kind, express or implied, as stated in
  sections 15 and 16 of the [GPL-3.0](LICENSE) this fork inherits. You install and run it on your own
  machine, at your own risk.
- **Back up before every change** — see [Step 0](#step-0--back-up-first-do-not-skip). A saved
  `moonraker.conf` and a tarball of `~/mainsail` turn any problem into a two-minute rollback.
- **Your machine stays yours.** This fork only changes Mainsail's web interface: it never touches
  `printer.cfg`, kinematics, heaters or any Klipper setting. It remains your responsibility to keep
  your printer, its configuration and its prints in a safe state — including never updating mid-print.

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
