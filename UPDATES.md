# Keeping the panels across Mainsail updates 🔄

> **Prerequisite**: the fork is installed and working — see the
> [README install guide](README.md#install--from-stock-mainsail-to-the-panels) first.
> This document only covers **updates**.

## The problem

`[update_manager mainsail]` blindly installs whatever its source repo publishes. Out of the box it
follows official mainsail-crew releases — so the next time you click "update" in the Update
Manager, stock Mainsail is written over `~/mainsail` and **the panels are erased**.

## The fix — your own private update channel (~15 minutes, once)

Point the Update Manager at a repo that only ever contains **your** patched build: a free
**private** GitHub repository, followed by your printer through a read-only deploy key. From then
on:

- updating from the Mainsail UI installs *your* build — the panels can never be erased;
- when mainsail-crew publishes a new release, one script run rebases the patch on it and refreshes
  your channel.

Your channel is **yours**: nobody else's printer should ever depend on it, and yours must never
depend on somebody else's (including this repository — it ships no releases on purpose).
Moonraker's `git_repo` updater + a read-only deploy key are what make a private repo work.

> ✅ / ⚠️ **Battle-tested status (2026-08-19):** the channel mechanism itself has been exercised
> for real — push to the channel → Update Manager sees it → update applied from the UI, verified
> end-to-end. What has **not** run for real yet is the rebase onto a *newer* official release
> (v2.18.2 is still the latest). Read the script's output rather than firing and forgetting.

### What you need

- A GitHub account (a free one — private repositories are free).
- The computer you built with in the README (with `git` configured to push to your GitHub).
- A printer running Mainsail through Moonraker.

### Step 0 — Back up first (do not skip)

Same rule as the install: [README Step 0](README.md#step-0--back-up-first-do-not-skip) —
a saved `moonraker.conf` and a tarball of `~/mainsail`, **before** touching anything, and
**never while a print is running**.

### Step 1 — Create your private channel repository

On GitHub: **New repository** → name it e.g. `mainsail-dist` → **Private** → create it empty
(no README).

### Step 2 — Build and push to your channel

On your computer, from the clone you made in the README:

```bash
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
`v2.18.2-0` (git describe), valid, clean. Reload the page twice (service worker cache). This is
what you should get:

<p align="center">
  <img src="docs/fork/update-manager.png" width="75%" alt="Expected result: Update Manager showing the mainsail entry served by your private channel, valid and clean">
</p>

From now on a stock release can never overwrite the panels: your printer only ever installs what
**you** pushed to **your** channel.

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

If upstream modified one of the 3 patched files, the rebase stops and tells you exactly where —
the patch is ~25 lines, so conflicts stay small and readable.

## Going back to stock Mainsail

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

*Disclaimer and credits: see the [README](README.md#disclaimer).*
