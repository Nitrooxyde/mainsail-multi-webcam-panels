#!/usr/bin/env bash
# =============================================================================
# update_fork_mainsail.sh — rebase le fork multiwebcam sur une release upstream
#                           et publie la release GitHub consommée par Moonraker
#
# Usage    : ./update_fork_mainsail.sh v2.18.3
# Prérequis: WSL WorkStation, gh authentifié (compte Nitrooxyde), node/npm.
# Effet    : release https://github.com/Nitrooxyde/mainsail-multi-webcam-panels/releases/tag/<tag>
#            avec l'asset mainsail.zip. Ensuite l'update se fait DEPUIS L'UI
#            Mainsail (update manager) — ce script ne touche jamais au Pi.
#
# Règles à ne pas violer (apprises le 2026-08-19) :
#  - Le TITRE de la release DOIT être exactement le tag (ex: "v2.18.3") :
#    Moonraker lit remote_version dans le champ *name* de la release, pas le
#    tag. Un titre différent = "update disponible" éternel dans Mainsail.
#  - Schéma du fork : tag vX.Y.Z = upstream vX.Y.Z + patch multiwebcam
#    (le tag est déplacé/forcé sur notre commit rebasé).
# =============================================================================
set -euo pipefail

TAG="${1:?usage: $0 <tag upstream, ex: v2.18.3>}"
FORK="Nitrooxyde/mainsail-multi-webcam-panels"
UPSTREAM="https://github.com/mainsail-crew/mainsail.git"
WORK="$(mktemp -d /tmp/mainsail-fork-update.XXXXXX)"
trap 'echo "(workdir conservé pour inspection : $WORK)"' ERR

echo "[1/7] Clone du fork (branche multiwebcam)"
git clone --branch multiwebcam "https://github.com/${FORK}.git" "$WORK/mainsail"
cd "$WORK/mainsail"

echo "[2/7] Fetch upstream + tag cible $TAG"
git remote add upstream "$UPSTREAM"
git fetch upstream "refs/tags/${TAG}:refs/tags/upstream-${TAG}" --no-tags

echo "[3/7] Rebase du patch multiwebcam sur $TAG"
if ! git rebase "upstream-${TAG}"; then
    echo "ÉCHEC REBASE : conflit à résoudre à la main dans $WORK/mainsail"
    echo "puis : git rebase --continue && relancer les étapes 4-7 manuellement."
    exit 1
fi

echo "[4/7] Build"
npm ci --prefer-offline --no-audit --no-fund
npm run build
grep -q "\"version\":\"${TAG}\"" dist/release_info.json \
    || { echo "ÉCHEC : release_info.json ne porte pas ${TAG}"; exit 1; }
grep -q '"project_owner":"Nitrooxyde"' dist/release_info.json \
    || { echo "ÉCHEC : project_owner != Nitrooxyde (patch perdu au rebase ?)"; exit 1; }
# project_name DOIT valoir le nom du repo : Moonraker compare 'repo:' de moonraker.conf avec
# owner/project_name du release_info.json installé -> mismatch = anomalie + fallback repo détecté.
grep -q '"project_name":"mainsail-multi-webcam-panels"' dist/release_info.json \
    || { echo "ÉCHEC : project_name != mainsail-multi-webcam-panels (patch perdu au rebase ?)"; exit 1; }

echo "[5/7] mainsail.zip (python3, zip absent de WSL)"
python3 - <<'EOF'
import zipfile, os
os.chdir('dist')
with zipfile.ZipFile('mainsail.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk('.'):
        for f in files:
            p = os.path.join(root, f)
            if os.path.normpath(p) == 'mainsail.zip':
                continue
            z.write(p, os.path.relpath(p, '.'))
print('zip OK,', len(z.namelist()), 'fichiers')
EOF

echo "[6/7] Push branche + tag sur le fork"
git push origin multiwebcam --force-with-lease
git tag -f "$TAG"
git push origin "$TAG" --force

echo "[7/7] Release GitHub (titre == tag, OBLIGATOIRE)"
gh release create "$TAG" dist/mainsail.zip -R "$FORK" \
    --title "$TAG" \
    --notes "Mainsail ${TAG} + panels webcam independants (branche multiwebcam rebasée)."

rm -rf "$WORK"
echo
echo "TERMINÉ. Sur le Pi : Mainsail > Update Manager affichera ${TAG} —"
echo "mettre à jour depuis l'UI comme d'habitude (imprimante au repos)."
