#!/usr/bin/env bash
# =============================================================================
# LOT 16 BIS — Reproduction de la récupération des sources externes
# (docs/AUDIT_FEEDS_CETUD_PASSBI_2026-09-26.md)
#
# Ce script NE MODIFIE RIEN dans le dépôt Dakar Bus : il télécharge dans un
# répertoire de travail ($WORK, défaut ./_fetch) et vérifie les empreintes
# SHA-256 consignées dans manifest.json.
#
# Deux blocs :
#   1. PassBi (SOURCE_APPLICATION) — dépôts GitHub publics, épinglés au commit
#      audité. Réalisé le 2026-09-26 depuis le bac à sable (seul github.com
#      était joignable).
#   2. CETUD / DDD (SOURCE_INSTITUTIONAL / opérateur) — fichiers publiés sur
#      cetud.sn et demdikk.sn. Les hôtes cetud.sn / demdikk.sn N'ÉTAIENT PAS
#      joignables en HTTP direct depuis le bac à sable : les commandes sont
#      fournies pour reproduction hors bac à sable. Les tailles/dimensions
#      attendues proviennent de l'API REST WordPress des deux sites.
#
# Usage : bash audit/external-feeds/fetch_sources.sh [répertoire_de_travail]
# =============================================================================
set -euo pipefail

WORK="${1:-./_fetch}"
mkdir -p "$WORK"
cd "$WORK"

echo "== 1. PassBi — impactsolutionsas/passbi_core @ 4de3d96e0c602ff2bdf718901d35c0f9d8098e96 =="
if [ ! -d passbi_core ]; then
  git clone --quiet https://github.com/impactsolutionsas/passbi_core.git
fi
git -C passbi_core checkout --quiet 4de3d96e0c602ff2bdf718901d35c0f9d8098e96
git -C passbi_core log -1 --format='commit %H (%cI) — gtfs_folder/ ajouté par %h' -- gtfs_folder/ || true

echo "-- vérification SHA-256 des 4 ZIP GTFS (valeurs de manifest.json) --"
sha256sum -c - <<'EOF'
7fae6b438de6177ff1d777546684e83c8882927b67efa4645dbecca3d77af428  passbi_core/gtfs_folder/gtfs_AFTU.zip
578323c9fa4375313d57c4120071da3d0da499eb9216e5a4a22a28ffae707159  passbi_core/gtfs_folder/gtfs_Dem_Dikk.zip
f5e27b7ee446d52a6c32961db3684637cb0ebb319bb80883c82bcc47104e46c4  passbi_core/gtfs_folder/gtfs_BRT.zip
09cb31f4291b28aae072b9b053dc31d06154a7eeb8c212b4bc08825823197408  passbi_core/gtfs_folder/gtfs_TER.zip
b8cba8a1cd3abb012266d240fcc1dfab99798afc03690f5ab55e21ac3b063bd7  passbi_core/docs/api/openapi.yaml
EOF

echo "== 1b. PassBi — impactsolutionsas/passbi-gtfs-v1 @ 59438b4c69ea61e546f752ad880d8dee7e470d3e (seconde copie, fixtures re-datées) =="
if [ ! -d passbi-gtfs-v1 ]; then
  git clone --quiet https://github.com/impactsolutionsas/passbi-gtfs-v1.git
fi
git -C passbi-gtfs-v1 checkout --quiet 59438b4c69ea61e546f752ad880d8dee7e470d3e
ls passbi-gtfs-v1/fixtures/

echo "== 2. CETUD / DDD — artefacts cartographiques (à exécuter HORS bac à sable) =="
# Page DDD du CETUD : bouton « Télécharger les lignes et horaires »
#   → image JPEG (média WordPress n° 1668, 1282×905, 87 217 octets, téléversé 2024-12-03)
# Page AFTU du CETUD : bouton « Télécharger le plan des lignes »
#   → image JPEG (média WordPress n° 1667, 1282×905, 88 338 octets, téléversé 2024-12-03)
# Copie publiée par l'opérateur DDD lui-même (média WordPress n° 3938, 1282×905,
#   87 217 octets, téléversé 2023-01-16) — c'est cette copie (mêmes taille et
#   dimensions que celle du CETUD) qui a pu être obtenue le 2026-09-26 et qui est
#   conservée sous source/cetud/plan-lignes-ddd.jpeg
#   (SHA-256 6c40333cb4423e5bf4b33422eb70e20e08ab67c0c5d629ac06f901bbaf74f0f8).
mkdir -p cetud
for u in \
  "https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-ddd.jpeg" \
  "https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-aftu.jpeg" \
  "https://cetud.sn/wp-content/uploads/2024/11/sunubrt-guide-du-voyageur-vf.pdf" \
  "https://cetud.sn/wp-content/uploads/2024/11/Plan-de-la-ligne-TER.pdf" \
  "https://demdikk.sn/wp-content/uploads/2023/01/plan-lignes-ddd.jpeg" ; do
  f="cetud/$(echo "$u" | sed -E 's#https?://##; s#/#_#g')"
  if curl -fsSL --max-time 60 -o "$f" "$u"; then
    printf '%s  %s  %s octets\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$u" "$(stat -c %s "$f")"
  else
    echo "ÉCHEC (hôte injoignable depuis cet environnement ?) : $u"
  fi
done

echo "== Métadonnées WordPress (lecture seule, API REST publique) =="
echo "  https://cetud.sn/wp-json/wp/v2/media/1668   (plan-lignes-ddd.jpeg)"
echo "  https://cetud.sn/wp-json/wp/v2/media/1667   (plan-lignes-aftu.jpeg)"
echo "  https://demdikk.sn/wp-json/wp/v2/media/3938 (plan-lignes-ddd.jpeg, copie opérateur)"
echo "Terminé. Aucun fichier du dépôt Dakar Bus n'a été modifié."
