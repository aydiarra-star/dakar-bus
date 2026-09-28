# Lot 4.21 — Intégration PassBi DDD / AFTU / TATA

**Date : 2026-09-28** · **Branche :** `arena/01a0e53c-dakar-bus` · **Base :** `4a7f7bd` (Lot 4.20, PR #37)

---

## 0. Résumé exécutif

Le problème constaté en production — « DDD / AFTU : Horaire indisponible » — n'était **pas** un problème de
données. Les feeds PassBi DDD et AFTU contiennent des routes, trips, stops, stop_times et services actifs, et
**52 des 53 routes DDD** et **71 des 73 routes AFTU** permettent de calculer un prochain départ réel.

La cause était une **confusion entre deux notions distinctes** dans le moteur :

| Notion | Portée par (avant) | Effet |
|---|---|---|
| Identité publique de la ligne | `crosswalk.json` → `status == 'MAPPED'` | DDD : 0/53 · AFTU : 1/73 confirmées |
| Disponibilité d'un horaire | le même champ `MAPPED` (garde-fou implicite) | l'identité non résolue **bloquait** l'horaire |

`ScheduleProvider.departureAt()` exigeait un mapping de route `MAPPED` **et** un mapping d'arrêt issu du même
crosswalk. Comme le crosswalk n'a confirmé aucune identité DDD et une seule (AFTU_3), les 314 029 stop_times DDD
et 677 918 stop_times AFTU étaient **inaccessibles** : l'application affichait « Horaire indisponible » alors que
la donnée permettait de calculer un départ. C'est exactement le cas que le §2 du lot interdit de traiter comme
une absence de données.

**Correctif :** un **chemin natif PassBi** (`PassBiSource → ScheduleProvider → DepartureInfo → UI`) exploite les
métadonnées réelles du feed, avec un champ `identity_status` **distinct** du statut horaire (§3).

**Résultat mesuré** (CI du commit `992a32d`) : `flutter analyze` → 0 issue · `flutter test` → **481/481** ·
`flutter build web` → succès · `npm test` → **82/82** · `TER BRT data validation` → succès.

| Réseau | Routes | Horaires calculables | Identité publique confirmée | Traitement Lot 4.21 |
|---|---|---|---|---|
| TER   | 6  | 6/6   | 6/6   | inchangé (crosswalk) |
| BRT   | 2  | 2/2   | 2/2   | inchangé (crosswalk) |
| DDD   | 53 | **52/53** | 0/53  | **chemin natif PassBi** |
| AFTU  | 73 | **71/73** | 1/73  | **chemin natif PassBi** |
| TATA  | —  | —     | —     | **aucun feed PassBi : aucune route fabriquée (§6)** |

---

## 1. Audit PassBi DDD / AFTU

Méthode : lecture directe des données **déjà intégrées** au dépôt
(`flutter-src/assets/data/passbi/{ddd,aftu,ter,brt,crosswalk}.json`). **Aucun téléchargement.**
Reproductible : `node scripts/audit-passbi-ddd-aftu.mjs --md DDD` (idem `AFTU`).

### 1.1 DDD — `flutter-src/assets/data/passbi/ddd.json`

- agence **Dakar Dem Dikk** · source `gtfs_Dem_Dikk.zip` (PassBi, `PUBLIC_GTFS`)
- `source_url = https://raw.githubusercontent.com/impactsolutionsas/passbi_core/.../gtfs_Dem_Dikk.zip`
  (valeur exacte dans `meta.source_url`) · `date_source = 2026-02-10`
- **53 routes** · 1 277 arrêts (1 186 appelés) · **9 529 trips** · **314 029 stop_times**
- services : `FULL(127)`, `LAV(31)`, `SAMEDI(32)`, `DIMANCHE(64)` · 40 exceptions datées
- `route_type = 3` (bus) · `direction_id` réel = `0` / `1` · `headsign` vide dans le feed
- **52 routes avec horaires calculables** · 1 route sans `stop_time` : `DDD_323`

| network | route_id | short | long | trips | stops | stop_times | boardable | schedule_available | identity | UI_mapping | first | last | reason |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DDD | DDD_01 | D1LP | DDD_01_LECLERC_PARCELLES-ASSAINIES | 208 | 83 | 8825 | 8617 | YES | UNCONFIRMED | UNCONFIRMED | 05:50 | 22:55 | HORAIRES_CALCULABLES |
| DDD | DDD_02 | D2DL | DDD_02_DAROUKHANE_LECLERC | 172 | 102 | 8902 | 8730 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:52 | HORAIRES_CALCULABLES |
| DDD | DDD_04 | D4DL | DDD_04_DIEUPPEUL_LECLERC | 156 | 71 | 5691 | 5535 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:23 | HORAIRES_CALCULABLES |
| DDD | DDD_05 | D5GP | DDD_05_GUEDIAWAYE_PALAIS1 | 216 | 71 | 7905 | 7689 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:29 | HORAIRES_CALCULABLES |
| DDD | DDD_06 | D6CP | DDD_06_CAMBERENE_PALAIS2 | 163 | 108 | 8986 | 8823 | YES | UNCONFIRMED | UNCONFIRMED | 05:45 | 22:51 | HORAIRES_CALCULABLES |
| DDD | DDD_07 | D7OP | DDD_07_OUAKAM_PALAIS-02 | 298 | 70 | 10728 | 10430 | YES | UNCONFIRMED | UNCONFIRMED | 05:45 | 22:01 | HORAIRES_CALCULABLES |
| DDD | DDD_08 | D8PL | DDD_08_AEROPORT-LSS_PALAIS-02 | 202 | 95 | 9803 | 9601 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:26 | HORAIRES_CALCULABLES |
| DDD | DDD_09 | D9P0 | DDD_09_LIBERTE-06_PALAIS-02 | 237 | 64 | 7818 | 7581 | YES | UNCONFIRMED | UNCONFIRMED | 05:50 | 21:59 | HORAIRES_CALCULABLES |
| DDD | DDD_10 | D10LP | DDD_10_LIBERTE 5_PALAIS-02 | 185 | 62 | 5894 | 5709 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:26 | HORAIRES_CALCULABLES |
| DDD | DDD_11 | D11KL | DDD_11_KEUR MASSAR_LAT DIOR | 186 | 95 | 9031 | 8845 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:25 | HORAIRES_CALCULABLES |
| DDD | DDD_12 | D12GP | DDD_12_Guediawaye_Palais-1 | 196 | 117 | 11659 | 11463 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:32 | HORAIRES_CALCULABLES |
| DDD | DDD_13 | D13T0 | DDD_13_PALAIS-02_TERMINUS-DIEUPPEUL | 206 | 47 | 5052 | 4846 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 21:51 | HORAIRES_CALCULABLES |
| DDD | DDD_15 | D15PR | DDD_15_PALAIS1_RUFISQUE | 208 | 86 | 9170 | 8962 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:43 | HORAIRES_CALCULABLES |
| DDD | DDD_16 | D16MP | DDD_16_MALIKA_PALAIS1 | 204 | 85 | 8844 | 8640 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:10 | HORAIRES_CALCULABLES |
| DDD | DDD_18 | D18D | DDD_18_DIEUPEUL | 39 | 43 | 1677 | 1638 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:08 | HORAIRES_CALCULABLES |
| DDD | DDD_20 | D20D | DDD_20_DIEUPEUL | 39 | 45 | 1755 | 1716 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:08 | HORAIRES_CALCULABLES |
| DDD | DDD_23 | D23P2 | DDD_23_PALAIS-2_PARCELLE-ASSAINIES | 196 | 104 | 11082 | 10886 | YES | UNCONFIRMED | UNCONFIRMED | 05:50 | 22:42 | HORAIRES_CALCULABLES |
| DDD | DDD_102 | D102CC | DDD_102_CAMBERENE_COLOBANE | 225 | 69 | 7974 | 7749 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:27 | HORAIRES_CALCULABLES |
| DDD | DDD_103 | D103AC | DDD_103_AEROPORT_COLOBANE | 225 | 65 | 7551 | 7326 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:19 | HORAIRES_CALCULABLES |
| DDD | DDD_105 | D105CP | DDD_105_CAMBERENE_PETERSEN | 225 | 52 | 5976 | 5751 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:23 | HORAIRES_CALCULABLES |
| DDD | DDD_111 | D111LY | DDD_111_LECLERC_YOFF | 225 | 58 | 6759 | 6534 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:22 | HORAIRES_CALCULABLES |
| DDD | DDD_121 | D121LS | DDD_121_LECLERC_SCAT URBAM | 225 | 66 | 7668 | 7443 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:10 | HORAIRES_CALCULABLES |
| DDD | DDD_208 | D208BR | DDD_208_BAYAKH_RUFISQUE | 170 | 63 | 5525 | 5355 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 22:43 | HORAIRES_CALCULABLES |
| DDD | DDD_210 | D210TM | DDD_210_BAUX-MARAICHERS_TIVAOUNE-PEULH | 161 | 67 | 5541 | 5380 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:42 | HORAIRES_CALCULABLES |
| DDD | DDD_213 | D213DR | DDD_213_DIEUPPEUL_RUFISQUE | 161 | 94 | 7728 | 7567 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:29 | HORAIRES_CALCULABLES |
| DDD | DDD_217 | D217OT | DDD_217_OUAKAM_THIAROYE | 192 | 124 | 11844 | 11656 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:07 | HORAIRES_CALCULABLES |
| DDD | DDD_218 | D218AT | DDD_218_AEROPORT-LSS_THIAROYE | 153 | 67 | 5268 | 5115 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 21:14 | HORAIRES_CALCULABLES |
| DDD | DDD_219 | D219DO | DDD_219_DAROUKHANE_OUAKAM | 188 | 117 | 11183 | 10995 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:31 | HORAIRES_CALCULABLES |
| DDD | DDD_220 | D220DR | DDD_220_DAROUKHANE_RUFISQUE | 156 | 72 | 5768 | 5612 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 21:52 | HORAIRES_CALCULABLES |
| DDD | DDD_221 | D221AG | DDD_221_ALMADIES_GADAYE | 159 | 106 | 8579 | 8420 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:02 | HORAIRES_CALCULABLES |
| DDD | DDD_223 | D223DP | DDD_223_DAROUKHANE_PETERSEN | 129 | 49 | 3306 | 3177 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 21:57 | HORAIRES_CALCULABLES |
| DDD | DDD_227 | D227TM | DDD_227_KEUR-MASSAR_TERMINUS-PARCELLES | 181 | 82 | 7595 | 7414 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 22:03 | HORAIRES_CALCULABLES |
| DDD | DDD_228 | D228RY | DDD_228_RUFISQUE_YENNE | 113 | 54 | 3164 | 3051 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 21:59 | HORAIRES_CALCULABLES |
| DDD | DDD_231 | D231BJ | DDD_231_BAUX-MARAICHERS_JAXAAY | 161 | 71 | 5863 | 5702 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:02 | HORAIRES_CALCULABLES |
| DDD | DDD_232 | D232AB | DDD_232_AEROPORT_BAUX-MARAICHERS | 136 | 70 | 4896 | 4760 | YES | UNCONFIRMED | UNCONFIRMED | 06:20 | 21:32 | HORAIRES_CALCULABLES |
| DDD | DDD_233 | D233 M | DDD_233_BAUX-MARAICHERS_ Palais-1 | 129 | 78 | 5160 | 5031 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 21:59 | HORAIRES_CALCULABLES |
| DDD | DDD_234 | D234JL | DDD_234_JAXAAY_LECLERC | 138 | 67 | 4768 | 4630 | YES | UNCONFIRMED | UNCONFIRMED | 05:30 | 23:09 | HORAIRES_CALCULABLES |
| DDD | DDD_301 | D301MP | DDD_301_MEDINA_PARCELLES | 288 | 49 | 7344 | 7056 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 19:47 | HORAIRES_CALCULABLES |
| DDD | DDD_305 | D305PY | DDD_305_PALAIS-2_YOFF | 288 | 43 | 6480 | 6192 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 19:53 | HORAIRES_CALCULABLES |
| DDD | DDD_308 | D308OP | DDD_308_OUAKAM_PATTE-D'OIE | 288 | 43 | 6336 | 6048 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 19:40 | HORAIRES_CALCULABLES |
| DDD | DDD_311 | D311TT | DDD_311_THIAROYE_TIV-PEULH | 82 | 17 | 697 | 656 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 21:32 | HORAIRES_CALCULABLES |
| DDD | DDD_315 | D315RY | DDD_315_RUFISQUE_YENNE | 288 | 43 | 6480 | 6192 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 19:49 | HORAIRES_CALCULABLES |
| DDD | DDD_319 | D319SL | DDD_319_OUAKAM_SICAP-LIBERTE-6 | 288 | 45 | 6768 | 6480 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 19:39 | HORAIRES_CALCULABLES |
| DDD | DDD_323 | D323PT | DDD_323_GUEULE-TAPEE_PARCELLE-ASSAINIE | 288 | 0 | 0 | 0 | NO | UNCONFIRMED | UNCONFIRMED | - | - | AUCUN_STOP_TIME_DANS_LE_FEED |
| DDD | DDD_401 | D401AO | DDD_401_AIBD_OUAKAM | 58 | 51 | 1578 | 1520 | YES | UNCONFIRMED | UNCONFIRMED | 00:00 | 23:52 | HORAIRES_CALCULABLES |
| DDD | DDD_402 | D402AT | DDD_402_AIBD_THIAROYE | 147 | 52 | 3948 | 3801 | YES | UNCONFIRMED | UNCONFIRMED | 05:45 | 22:58 | HORAIRES_CALCULABLES |
| DDD | DDD_403 | D403AP | DDD_403_AIBD_PARCELLES-ASSAINIES | 69 | 57 | 2037 | 1968 | YES | UNCONFIRMED | UNCONFIRMED | 00:00 | 23:55 | HORAIRES_CALCULABLES |
| DDD | DDD_404 | D404AL | DDD_404_AIBD_LECLERC | 88 | 8 | 440 | 352 | YES | UNCONFIRMED | UNCONFIRMED | 00:00 | 23:59 | HORAIRES_CALCULABLES |
| DDD | DDD_405 | D405AD | DDD_405_AIBD_DIEUPPEUL | 90 | 33 | 1581 | 1491 | YES | UNCONFIRMED | UNCONFIRMED | 00:15 | 23:57 | HORAIRES_CALCULABLES |
| DDD | DDD_501 | D501GP | DDD_501_GARE-DE-DAKAR_PALAIS-2 | 300 | 16 | 2700 | 2400 | YES | UNCONFIRMED | UNCONFIRMED | 06:40 | 23:09 | HORAIRES_CALCULABLES |
| DDD | DDD_502 | D502CU | DDD_502_COLOBANE-UCAD-COLOBANE | 52 | 15 | 780 | 728 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 23:26 | HORAIRES_CALCULABLES |
| DDD | DDD_503 | D503CB | DDD_503_COLOBANE-BELAIR-COLOBANE | 52 | 8 | 416 | 364 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 23:18 | HORAIRES_CALCULABLES |
| DDD | DDD_504 | D504DS | DDD_504_GARE-DE-DIAMNIADIO_SPHERE MINISTERIELLE | 300 | 8 | 1506 | 1206 | YES | UNCONFIRMED | UNCONFIRMED | 05:45 | 23:03 | HORAIRES_CALCULABLES |

### 1.2 AFTU — `flutter-src/assets/data/passbi/aftu.json`

- agence **Association de Financement des Professionnels du transport Urbain** · source `gtfs_AFTU.zip`
- `date_source = 2026-02-10` · `valid_from = 20220101` · `valid_to = 20231231` (mode ROLLING documenté)
- **73 routes** · 2 401 arrêts (2 237 appelés) · **11 077 trips** · **677 918 stop_times**
- services : `FULL(127)`, `LAV(31)`, `SAMEDI(32)`, `DIMANCHE(64)` · 40 exceptions datées
- **71 routes avec horaires calculables** · 2 routes sans horaire : `AFTU_47` (0 trip), `AFTU_52` (0 stop_time)

| network | route_id | short | long | trips | stops | stop_times | boardable | schedule_available | identity | UI_mapping | first | last | reason |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AFTU | AFTU_1 | A1HL | AFTU_1_HLM-GR-YOFF_LAT-DIOR | 114 | 90 | 5250 | 5136 | YES | UNCONFIRMED | UNCONFIRMED | 06:33 | 20:27 | HORAIRES_CALCULABLES |
| AFTU | AFTU_2 | A2PP | AFTU_2_Parcelles-Assainies_Petersen | 149 | 98 | 7447 | 7298 | YES | UNCONFIRMED | UNCONFIRMED | 06:22 | 20:34 | HORAIRES_CALCULABLES |
| AFTU | AFTU_3 | A3PY | AFTU_3_Petersen_Yoff | 175 | 119 | 10592 | 10417 | YES | CONFIRMED | aftu_8,aftu_11 | 04:55 | 20:37 | HORAIRES_CALCULABLES |
| AFTU | AFTU_4 | A4PY | AFTU_4_Petersen_Yoff | 171 | 78 | 6840 | 6669 | YES | UNCONFIRMED | UNCONFIRMED | 05:38 | 20:29 | HORAIRES_CALCULABLES |
| AFTU | AFTU_5 | A5PP | AFTU_5_Parcelles-Assainies_Petersen | 169 | 91 | 7857 | 7688 | YES | UNCONFIRMED | UNCONFIRMED | 06:13 | 20:28 | HORAIRES_CALCULABLES |
| AFTU | AFTU_24 | A24NU | AFTU_24_Notaire_UCAD | 152 | 96 | 7440 | 7288 | YES | UNCONFIRMED | UNCONFIRMED | 05:07 | 20:31 | HORAIRES_CALCULABLES |
| AFTU | AFTU_25 | A25PP | AFTU_25_Parcelle-Assainies_Petersen | 183 | 80 | 7503 | 7320 | YES | UNCONFIRMED | UNCONFIRMED | 05:56 | 20:30 | HORAIRES_CALCULABLES |
| AFTU | AFTU_26 | A26PP | AFTU_26_Parcelle-Assainies_Poste-Thiaroye | 182 | 80 | 7374 | 7192 | YES | UNCONFIRMED | UNCONFIRMED | 06:00 | 20:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_27 | A27GP | AFTU_27_Guediawaye MB_Petersen | 126 | 74 | 4760 | 4634 | YES | UNCONFIRMED | UNCONFIRMED | 06:12 | 20:39 | HORAIRES_CALCULABLES |
| AFTU | AFTU_28 | A28HP | AFTU_28_Hamo VI_Petersen | 132 | 60 | 4162 | 4030 | YES | UNCONFIRMED | UNCONFIRMED | 05:31 | 20:44 | HORAIRES_CALCULABLES |
| AFTU | AFTU_29 | A29MP | AFTU_29_Malibu_Petersen | 182 | 113 | 10444 | 10262 | YES | UNCONFIRMED | UNCONFIRMED | 05:10 | 20:40 | HORAIRES_CALCULABLES |
| AFTU | AFTU_30 | A30CG | AFTU_30_Colobane_Gadaye | 135 | 133 | 9109 | 8974 | YES | UNCONFIRMED | UNCONFIRMED | 05:29 | 21:26 | HORAIRES_CALCULABLES |
| AFTU | AFTU_31 | A31ST | AFTU_31_Sham_Thiaroye-kao | 160 | 47 | 3525 | 3450 | YES | UNCONFIRMED | UNCONFIRMED | 06:07 | 20:37 | HORAIRES_CALCULABLES |
| AFTU | AFTU_32 | A32DS | AFTU_32_Daroukhane_Sham | 138 | 118 | 8300 | 8162 | YES | UNCONFIRMED | UNCONFIRMED | 05:32 | 20:43 | HORAIRES_CALCULABLES |
| AFTU | AFTU_33 | A33CD | AFTU_33_Colobane_Daroukane | 127 | 122 | 7871 | 7744 | YES | UNCONFIRMED | UNCONFIRMED | 05:38 | 21:14 | HORAIRES_CALCULABLES |
| AFTU | AFTU_34 | A34LN | AFTU_34_LAT-DIOR_Nord-Foire | 170 | 95 | 8236 | 8066 | YES | UNCONFIRMED | UNCONFIRMED | 06:08 | 20:30 | HORAIRES_CALCULABLES |
| AFTU | AFTU_35 | A35NP | AFTU_35_Ngor_Pikine-Texaco | 177 | 96 | 8695 | 8518 | YES | UNCONFIRMED | UNCONFIRMED | 05:12 | 20:26 | HORAIRES_CALCULABLES |
| AFTU | AFTU_36 | A36DN | AFTU_36_Daroukhane_Ngor | 166 | 150 | 12616 | 12450 | YES | UNCONFIRMED | UNCONFIRMED | 05:27 | 21:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_37 | A37AU | AFTU_37_APIX_UCAD | 103 | 201 | 10437 | 10334 | YES | UNCONFIRMED | UNCONFIRMED | 05:59 | 21:51 | HORAIRES_CALCULABLES |
| AFTU | AFTU_38 | A38GS | AFTU_38_Guediawaye_Sahm | 136 | 61 | 3965 | 3900 | YES | UNCONFIRMED | UNCONFIRMED | 06:15 | 20:40 | HORAIRES_CALCULABLES |
| AFTU | AFTU_39 | A39DL | AFTU_39_Diamalaye_Lat Dior | 126 | 133 | 8496 | 8370 | YES | UNCONFIRMED | UNCONFIRMED | 05:49 | 21:15 | HORAIRES_CALCULABLES |
| AFTU | AFTU_40 | A40MP | AFTU_40_Mbao_Petersen | 113 | 101 | 5813 | 5700 | YES | UNCONFIRMED | UNCONFIRMED | 05:23 | 21:07 | HORAIRES_CALCULABLES |
| AFTU | AFTU_41 | A41GP | AFTU_41_Guediawaye_Petersen | 123 | 60 | 3180 | 3127 | YES | UNCONFIRMED | UNCONFIRMED | 06:24 | 20:34 | HORAIRES_CALCULABLES |
| AFTU | AFTU_42 | A42GO | AFTU_42_Gadaye_Ouakam | 161 | 131 | 10712 | 10551 | YES | UNCONFIRMED | UNCONFIRMED | 05:26 | 20:52 | HORAIRES_CALCULABLES |
| AFTU | AFTU_43 | A43CO | AFTU_43_Comico_Ouakam | 137 | 162 | 11234 | 11097 | YES | UNCONFIRMED | UNCONFIRMED | 05:04 | 21:50 | HORAIRES_CALCULABLES |
| AFTU | AFTU_44 | A44MO | AFTU_44_Mbao_Ouakam | 190 | 109 | 10547 | 10357 | YES | UNCONFIRMED | UNCONFIRMED | 04:48 | 21:28 | HORAIRES_CALCULABLES |
| AFTU | AFTU_45 | A45kP | AFTU_45_kounoune_Parcelles Assainies | 143 | 191 | 13831 | 13688 | YES | UNCONFIRMED | UNCONFIRMED | 05:35 | 21:49 | HORAIRES_CALCULABLES |
| AFTU | AFTU_46 | A46GL | AFTU_46_Guediawaye_Lat Dior | 140 | 69 | 4623 | 4556 | YES | UNCONFIRMED | UNCONFIRMED | 06:28 | 21:01 | HORAIRES_CALCULABLES |
| AFTU | AFTU_47 | A47LA | AFTU_47_Lat Dior_Almadies | 0 | 0 | 0 | 0 | NO | UNCONFIRMED | UNCONFIRMED | - | - | AUCUN_DEPART_CALCULABLE |
| AFTU | AFTU_48 | A48LR | AFTU_48_Lat Dior_Rufisque | 238 | 101 | 11902 | 11664 | YES | UNCONFIRMED | UNCONFIRMED | 06:13 | 21:15 | HORAIRES_CALCULABLES |
| AFTU | AFTU_49 | A49GN | AFTU_49_Gadaye_Ngor | 147 | 179 | 13370 | 13223 | YES | UNCONFIRMED | UNCONFIRMED | 05:24 | 21:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_50 | A50MP | AFTU_50_Malicka_Petersen | 135 | 108 | 7416 | 7281 | YES | UNCONFIRMED | UNCONFIRMED | 05:25 | 21:33 | HORAIRES_CALCULABLES |
| AFTU | AFTU_51 | A51BJ | AFTU_51_Baux Maraichers_Jaxaay | 157 | 142 | 11301 | 11144 | YES | UNCONFIRMED | UNCONFIRMED | 05:37 | 20:45 | HORAIRES_CALCULABLES |
| AFTU | AFTU_52 | A52BJ | AFTU_52_Baux Maraichers_Jaxaay | 190 | 0 | 0 | 0 | NO | UNCONFIRMED | UNCONFIRMED | - | - | AUCUN_STOP_TIME_DANS_LE_FEED |
| AFTU | AFTU_53 | A53KS | AFTU_53_KEUR MASSAR_Sebikotane | 176 | 87 | 7569 | 7482 | YES | UNCONFIRMED | UNCONFIRMED | 05:39 | 21:19 | HORAIRES_CALCULABLES |
| AFTU | AFTU_54 | A54MU | AFTU_54_M T O A_UCAD | 199 | 122 | 12324 | 12125 | YES | UNCONFIRMED | UNCONFIRMED | 05:31 | 20:49 | HORAIRES_CALCULABLES |
| AFTU | AFTU_55 | A55PR | AFTU_55_Petersen_Rufisque | 188 | 82 | 7852 | 7664 | YES | UNCONFIRMED | UNCONFIRMED | 05:37 | 21:37 | HORAIRES_CALCULABLES |
| AFTU | AFTU_56 | A56JP | AFTU_56_Jaxaaye_Petersen | 170 | 85 | 7434 | 7264 | YES | UNCONFIRMED | UNCONFIRMED | 05:24 | 21:57 | HORAIRES_CALCULABLES |
| AFTU | AFTU_57 | A57LR | AFTU_57_LIBERTE 5_Rufisque Gouye Mouride  | 172 | 54 | 4374 | 4293 | YES | UNCONFIRMED | UNCONFIRMED | 05:02 | 21:17 | HORAIRES_CALCULABLES |
| AFTU | AFTU_58 | A58CS | AFTU_58_Comico_Sahm | 171 | 88 | 7611 | 7440 | YES | UNCONFIRMED | UNCONFIRMED | 05:18 | 21:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_59 | A59cD | AFTU_59_cite gendarmerie_Diamalaye | 162 | 219 | 17991 | 17829 | YES | UNCONFIRMED | UNCONFIRMED | 05:41 | 22:00 | HORAIRES_CALCULABLES |
| AFTU | AFTU_60 | A60bC | AFTU_60_bargny_Colobane | 183 | 90 | 8326 | 8143 | YES | UNCONFIRMED | UNCONFIRMED | 05:09 | 20:48 | HORAIRES_CALCULABLES |
| AFTU | AFTU_61 | A61Km | AFTU_61_KEUR MASSAR_mamelles | 180 | 125 | 11423 | 11243 | YES | UNCONFIRMED | UNCONFIRMED | 05:21 | 21:43 | HORAIRES_CALCULABLES |
| AFTU | AFTU_62 | A62gy | AFTU_62_gueule tapee_youssou mbergane | 139 | 164 | 11555 | 11416 | YES | UNCONFIRMED | UNCONFIRMED | 05:08 | 22:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_63 | A63SR | AFTU_63_Stade-Amitié_Rufisque | 117 | 144 | 8540 | 8423 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 21:19 | HORAIRES_CALCULABLES |
| AFTU | AFTU_64 | A64dg | AFTU_64_diamniadio_guediawaye | 166 | 159 | 13359 | 13193 | YES | UNCONFIRMED | UNCONFIRMED | 05:41 | 21:07 | HORAIRES_CALCULABLES |
| AFTU | AFTU_65 | A65Ck | AFTU_65_Colobane_kounoune | 141 | 126 | 8990 | 8849 | YES | UNCONFIRMED | UNCONFIRMED | 05:53 | 22:02 | HORAIRES_CALCULABLES |
| AFTU | AFTU_66 | A66gY | AFTU_66_gorom_Yoff | 136 | 204 | 14214 | 14078 | YES | UNCONFIRMED | UNCONFIRMED | 05:34 | 21:31 | HORAIRES_CALCULABLES |
| AFTU | AFTU_67 | A67Ot | AFTU_67_Ouakam_thiawlene | 115 | 150 | 8731 | 8616 | YES | UNCONFIRMED | UNCONFIRMED | 05:34 | 21:19 | HORAIRES_CALCULABLES |
| AFTU | AFTU_68 | A68st | AFTU_68_sebikotane_tally diallo | 189 | 130 | 12474 | 12285 | YES | UNCONFIRMED | UNCONFIRMED | 06:05 | 20:48 | HORAIRES_CALCULABLES |
| AFTU | AFTU_69 | A69Dn | AFTU_69_Diamalaye_namora | 126 | 65 | 3705 | 3648 | YES | UNCONFIRMED | UNCONFIRMED | 07:15 | 21:18 | HORAIRES_CALCULABLES |
| AFTU | AFTU_70 | A70dd | AFTU_70_darouhane_diaxaye | 162 | 111 | 9171 | 9009 | YES | UNCONFIRMED | UNCONFIRMED | 05:51 | 21:15 | HORAIRES_CALCULABLES |
| AFTU | AFTU_71 | A71cK | AFTU_71_claudel_KEUR MASSAR | 144 | 103 | 7530 | 7386 | YES | UNCONFIRMED | UNCONFIRMED | 05:40 | 21:32 | HORAIRES_CALCULABLES |
| AFTU | AFTU_72 | A72ks | AFTU_72_kounoune_Guédiawaye | 157 | 179 | 14209 | 14052 | YES | UNCONFIRMED | UNCONFIRMED | 05:51 | 21:27 | HORAIRES_CALCULABLES |
| AFTU | AFTU_73 | A73LP | AFTU_73_Lac Rose_POSTE THIAROYE | 230 | 155 | 18051 | 17821 | YES | UNCONFIRMED | UNCONFIRMED | 05:33 | 21:52 | HORAIRES_CALCULABLES |
| AFTU | AFTU_74 | A74bS | AFTU_74_bargny_SOCABECK | 152 | 172 | 13224 | 13072 | YES | UNCONFIRMED | UNCONFIRMED | 05:59 | 21:16 | HORAIRES_CALCULABLES |
| AFTU | AFTU_75 | A75CM | AFTU_75_Colobane_MALIKA | 134 | 152 | 10304 | 10170 | YES | UNCONFIRMED | UNCONFIRMED | 05:24 | 21:20 | HORAIRES_CALCULABLES |
| AFTU | AFTU_76 | A76AS | AFTU_76_ASSURANCE_SIPRESS | 150 | 133 | 10123 | 9973 | YES | UNCONFIRMED | UNCONFIRMED | 06:12 | 21:35 | HORAIRES_CALCULABLES |
| AFTU | AFTU_77 | A77CL | AFTU_77_CITE TACCO_LIBERTE 5 | 167 | 107 | 9039 | 8872 | YES | UNCONFIRMED | UNCONFIRMED | 06:11 | 21:20 | HORAIRES_CALCULABLES |
| AFTU | AFTU_78 | A78DL | AFTU_78_DIAMAGUENE_LIBERTE 5 | 140 | 104 | 7406 | 7266 | YES | UNCONFIRMED | UNCONFIRMED | 05:31 | 20:39 | HORAIRES_CALCULABLES |
| AFTU | AFTU_79 | A79Cg | AFTU_79_CAMBERENE2_gorom | 131 | 192 | 12707 | 12576 | YES | UNCONFIRMED | UNCONFIRMED | 05:32 | 21:19 | HORAIRES_CALCULABLES |
| AFTU | AFTU_80 | A80DD | AFTU_80_DAROU THIOUB_Diamalaye | 136 | 207 | 14207 | 14071 | YES | UNCONFIRMED | UNCONFIRMED | 05:14 | 21:32 | HORAIRES_CALCULABLES |
| AFTU | AFTU_81 | A81BT | AFTU_81_BEAUX MARAICHER_TAWFEKH | 132 | 165 | 11085 | 10953 | YES | UNCONFIRMED | UNCONFIRMED | 05:15 | 21:39 | HORAIRES_CALCULABLES |
| AFTU | AFTU_82 | A82CL | AFTU_82_CITE COMICO_Lat Dior | 136 | 96 | 6631 | 6495 | YES | UNCONFIRMED | UNCONFIRMED | 05:36 | 21:22 | HORAIRES_CALCULABLES |
| AFTU | AFTU_83 | A83AZ | AFTU_83_ARAFAT_ZONE CAPTAGE | 225 | 181 | 20679 | 20454 | YES | UNCONFIRMED | UNCONFIRMED | 05:26 | 21:47 | HORAIRES_CALCULABLES |
| AFTU | AFTU_84 | A84JU | AFTU_84_Jaxaay_UCAD | 191 | 148 | 14189 | 13998 | YES | UNCONFIRMED | UNCONFIRMED | 05:51 | 21:53 | HORAIRES_CALCULABLES |
| AFTU | AFTU_85 | A85LL | AFTU_85_Lac Rose_LIBERTE5 | 188 | 98 | 17117 | 16929 | YES | UNCONFIRMED | UNCONFIRMED | 06:30 | 22:03 | HORAIRES_CALCULABLES |
| AFTU | AFTU_86 | A86TT | AFTU_86_THIAROYE_TOUBAB DJALAW | 131 | 131 | 8652 | 8521 | YES | UNCONFIRMED | UNCONFIRMED | 05:35 | 21:17 | HORAIRES_CALCULABLES |
| AFTU | AFTU_87 | A87BM | AFTU_87_BAMBIBOR COMICO_MASSALIKOU | 100 | 137 | 6944 | 6844 | YES | UNCONFIRMED | UNCONFIRMED | 05:33 | 21:35 | HORAIRES_CALCULABLES |
| AFTU | AFTU_88 | A88KL | AFTU_88_KEUR MASSAR_LIBERTE5 | 105 | 157 | 8331 | 8226 | YES | UNCONFIRMED | UNCONFIRMED | 06:37 | 21:29 | HORAIRES_CALCULABLES |
| AFTU | AFTU_89 | A89bT | AFTU_89_bargny_TAWFEKH | 131 | 106 | 7079 | 6948 | YES | UNCONFIRMED | UNCONFIRMED | 05:45 | 20:42 | HORAIRES_CALCULABLES |
| AFTU | AFTU_90 | A90TD | AFTU_90_THOAROYE-AZUR_DENI BIRAME NDAO | 155 | 162 | 12710 | 12555 | YES | UNCONFIRMED | UNCONFIRMED | 06:05 | 21:34 | HORAIRES_CALCULABLES |
| AFTU | AFTU_91 | A91AD | AFTU_91_APIX_DOUGAR | 103 | 139 | 7210 | 7107 | YES | UNCONFIRMED | UNCONFIRMED | 06:10 | 21:31 | HORAIRES_CALCULABLES |

### 1.3 TATA — `§6 : aucune donnée PassBi exploitable`

Vérifications effectuées **sur les données réellement présentes** :

| Recherche | Résultat |
|---|---|
| Feed TATA autonome (`PassBiSource.assetFiles`) | **absent** — 4 feeds seulement : TER, BRT, DDD, AFTU |
| Occurrence de « tata » dans `agency`, `meta`, `route_id`, `short_name`, `long_name`, noms d'arrêts, `trip_id`, `direction_id`, `headsign` des 4 feeds | **0 occurrence** (`passBiTataMentions()` → vide) |
| Champ explicite `mode` / `vehicle_type` / `network` / `agency` par route | **inexistant dans le format compact** : une route ne porte que `id`, `short`, `long`, `type` |
| `route_type` | 2 (rail) pour le TER, 3 (bus) pour BRT/DDD/AFTU — aucun type « minibus » |
| Identités TATA du référentiel dakar (7 lignes) | crosswalk `UNMAPPED` / `RESEAU_ABSENT_DU_FEED`, `pbRouteIds` **vide** |

**Conclusion : TATA n'est pas disponible comme réseau GTFS PassBi autonome.** Aucune route TATA n'a été
fabriquée, aucun horaire TATA n'est produit, aucune correspondance TATA n'a été créée. Le filtre TATA reste
strictement sur le référentiel dakar (`dakar_network.json`) et ses arrêts restent honnêtement `UNKNOWN`
(`RESEAU_ABSENT_DU_FEED`).

### 1.4 Crosswalk (rappel) — identités publiques du référentiel dakar

105 identités, **5 MAPPED** seulement :

| identité dakar | réseau | route(s) PassBi | méthode | arrêts mappés |
|---|---|---|---|---|
| `ter_dakar_diamniadio` | TER | 6 routes (sens + branches) | `IDENTITY_OFFICIELLE` | 13 |
| `brt_b1_guediawaye_petersen` | BRT | `B1` | `IDENTITY_OFFICIELLE` | 21 |
| `brt_b2_express` | BRT | `B2` | `IDENTITY_OFFICIELLE` | 7 |
| `aftu_8` | AFTU | `AFTU_3` | `TERMINI_MATCH` (0,92) | 2 |
| `aftu_11` | AFTU | `AFTU_3` | `TERMINI_MATCH` (0,92) | 1 |

100 identités restent `UNMAPPED` : 82 `IDENTITE_NON_CONFIRMEE` (12 DDD + 70 AFTU) et 18
`RESEAU_ABSENT_DU_FEED` (13 `new_commune_*` + 5 `tata_*`).
**Ce crosswalk n'est pas modifié par le lot** : il documente l'identité publique des 105 lignes du référentiel
dakar, il ne conditionne plus l'exploitation des horaires PassBi.

---

## 2. Ce qui a changé (architecture)

```
AVANT (chemin unique)
  référentiel dakar (route, arrêt)
    → crosswalk route MAPPED ?  ── NON (DDD/AFTU) ──► UNKNOWN « Horaire indisponible »
                                 └ OUI ─► stop mapping ─► nextDepartureSec

APRÈS (deux chemins, mêmes briques aval)
  A. référentiel dakar          → crosswalk → ScheduleProvider.departureAt      (inchangé : TER, BRT, aftu_8/11)
  B. référentiel NATIF PassBi   → PassBiSource.nextNativeDeparture
                                  → ScheduleProvider.departureAtPassBiStop     (nouveau : DDD, AFTU)
                                  → DepartureInfo { status, identityStatus, lineLabel, unresolvedReason }
                                  → Stop / Explorer / RoutePlanner / UI
```

**Le chemin B n'utilise AUCUNE identité dakar.** Il lit la route et l'arrêt **du feed**, et affiche
`identity_status = UNCONFIRMED` avec les métadonnées PassBi réelles : `route_id`, `short_name`, `long_name`.
Aucun nom commercial, aucune origine/destination, aucun numéro de ligne n'est déduit (§2).

### 2.1 Séparation `identity_status` ≠ disponibilité horaire (§3)

Nouveau champ `IdentityStatus { confirmed, unconfirmed }` porté par `DepartureInfo`, **distinct** de
`ScheduleStatus` :

- `identity_status = UNCONFIRMED` + `status = SCHEDULED` → **cas normal** pour DDD/AFTU (ex. `DDD_01`, `DDD_217`) ;
- `identity_status = CONFIRMED` + `status = SCHEDULED` → TER, BRT, `AFTU_3` ;
- `identity_status = CONFIRMED` + `status = UNKNOWN` → identité confirmée mais aucun départ calculable
  (ex. arrêt mappé hors service) ;
- `identity_status = UNCONFIRMED` + `status = UNKNOWN` → aucune identité dakar ne peut porter d'horaire ET aucun
  départ natif n'est calculable (voir §5).

### 2.2 Fichiers modifiés

| Fichier | Nature |
|---|---|
| `flutter-src/lib/models/departure_info.dart` | `IdentityStatus`, `UnresolvedReason`, champs `identityStatus` / `identityNote` / `lineLabel` / `unresolvedReason`, `withUnresolvedReason()` |
| `flutter-src/lib/services/gtfs/gtfs_source.dart` | `routeIndexesByStop` (desserte réelle par `stop_times`), `nextDepartureAmong()` (prochaine départ parmi un ensemble de routes, route gagnante remontée), `routeIndexesCalling()` — `nextDepartureSec()` **inchangé** |
| `flutter-src/lib/services/gtfs/passbi_source.dart` | `PassBiRouteSummary` (audit §1), `PassBiStopRef`, `PassBiNetworkAvailability`, `routeSummaries()`, `identityStatusOf()`, `nativeStops()`, `searchNativeStops()`, `nextNativeDeparture()`, `tataMentions()`, `normalizeName()` |
| `flutter-src/lib/services/schedule_provider.dart` | `departureAtPassBiStop()` (chemin natif), `identityLabelFor()`, `unresolvedReasonFor()` ; le chemin dakar `departureAt()` est **inchangé** hors annotation d'identité/raison |
| `flutter-src/lib/services/eta_calculator.dart` | `computePassBi()`, propagation de la raison d'UNKNOWN ; hiérarchie SCHEDULED → ESTIMATED → UNKNOWN **inchangée** |
| `flutter-src/lib/services/data_service.dart` | écriture native : `passBiRouteSummaries()`, `passBiAudit()`, `passBiNativeStops()`, `passBiNetworkAvailability()`, `passBiTataMentions()`, `passBiStopSearch()`, `passBiDepartureFor()`, `passBiDepartureForCompositeStop()` |
| `flutter-src/lib/main.dart` | `Stop.passBiStopKey`, référentiel `passBiNativeStops`, `_integratePassBiNativeStops()`, `explorerStopSource()` (filtres DDD/AFTU), second essai natif de `RoutePlanner`, identité de ligne sur les tronçons, `StopCard` (identité PassBi), garde-fou `DetailedRoute.fromStop` |
| `.github/workflows/flutter-verify.yml`, `.github/workflows/flutter-web-build.yml` | branche de session ajoutée aux déclencheurs (analyze/test/build sur la CI) |
| `tests/helpers/passbi-native421.mjs` | miroir Node du chemin natif (port fidèle du Dart) |
| `tests/passbi-ddd-aftu-421.test.js` | tests §11 A–L (npm) |
| `flutter-src/test/passbi_ddd_aftu_421_test.dart` | tests §11 A–L (Flutter) |
| `scripts/audit-passbi-ddd-aftu.mjs` | tableau d'audit reproductible (§1) |
| `docs/INTEGRATION_PASSBI_DDD_AFTU_TATA_4_21_2026-09-28.md` | ce document |

**Non modifiés** : `data/gtfs/`, `scripts/check-arrets.js`, `dakar_network.json`, `crosswalk.json`, `ter.json`,
`brt.json`, `ddd.json`, `aftu.json`, les quatre tables CI existantes, la NavigationBar, l'Explorer (structure),
Trajets (structure), Alertes, Réglages, l'Assistant IA, la carte, les boutons, les couleurs.

---

## 3. DDD — branchement effectif (§4)

Chaîne réellement empruntée :

```
assets/data/passbi/ddd.json
  → PassBiSource (routes, trips, stop_times, services, exceptions)
  → PassBiSource.nextNativeDeparture(network:'DDD', pbStopId, at)
       · candidats = plateforme + plateformes sœurs (lien crosswalk ≤ 30 m, MÊME réseau)
       · routes = celles qui appellent RÉELLEMENT l'arrêt (dérivé des stop_times)
       · GtfsNetwork.nextDepartureAmong : 1 passe/jour, 7 jours glissants,
         départ EMBARQUABLE uniquement (le trip continue), service actif par jour
  → ScheduleProvider.departureAtPassBiStop → DepartureInfo
       · status = SCHEDULED, scheduledTime = date + stop_time réelle
       · estimatedWaitFrom = (départ − maintenant) // 60   → « Prochain départ dans X min »
       · identityStatus = UNCONFIRMED, lineLabel = « Ligne PassBi DDD_217 · D217OT »
  → UI : StopCard, Trajets (tronçons), fiche d'arrêt
```

Aucune logique de fréquence, aucune estimation, aucun `REAL_TIME` : le prochain départ provient toujours d'un
`trip` + `stop_time` PassBi dont le service est actif. Si aucun départ n'est calculable dans le contexte
temporel → `UNKNOWN` (voir §5).

**Filtre DDD de l'Explorer (§7)** : `explorerStopSource('DDD', ...)` ajoute les **1 186 arrêts DDD réellement
desservis** (nom + coordonnées du feed) à la base de filtrage. Le plafond d'affichage (30 arrêts à proximité) et
le rendu cartographique restent inchangés ; `allStops` reste le référentiel dakar (aucune pollution, aucune
régression sur les 56 marqueurs de la carte).

## 4. AFTU — branchement effectif (§5)

Même traitement, données du feed `aftu.json` : **2 237 arrêts réellement desservis**, **71 routes** avec
horaires calculables. `AFTU_3` est la seule route dont l'identité publique est confirmée (crosswalk
`aftu_8` / `aftu_11`) : sur le chemin natif elle affiche `identity_status = CONFIRMED` et son identifiant de
feed, sans que cela change son horaire.

## 5. TATA (§6)

Voir §1.3. Traitement retenu :

- `PassBiSource.networkAvailability('TATA')` → `absentFromFeed` (valeur **dérivée** : aucun asset, donc aucun
  réseau chargé) ;
- `PassBiSource.tataMentions()` → **liste vide** (preuve reproductible, testée) ;
- le **filtre TATA** reste strictement sur le référentiel dakar et ne reçoit **aucun** arrêt natif ;
- les 7 lignes TATA du référentiel dakar restent `UNMAPPED` / `RESEAU_ABSENT_DU_FEED`, `pbRouteIds` vide ;
- aucun horaire TATA, aucune route TATA, aucune correspondance TATA n'est créé.

---

## 6. Filtres, trajets, correspondances, ETA

### 6.1 Filtres (§7)

| Filtre | Source | Résultat |
|---|---|---|
| `Tous`, `TER`, `BRT`, `TATA`, `⭐ Favoris` | `allStops` (référentiel dakar) | **strictement inchangés** |
| `DDD` | `allStops` + 1 186 arrêts PassBi DDD | données DDD PassBi exploitables |
| `AFTU` | `allStops` + 2 237 arrêts PassBi AFTU | données AFTU PassBi exploitables |

Le réseau TATA n'est jamais présenté comme fonctionnel : aucun arrêt TATA n'affiche de départ, la raison
documentaire est `RESEAU_ABSENT_DU_FEED`.

### 6.2 Trajets (§8)

Deux étapes, dans cet ordre :

1. **chemin crosswalk** (existant) — seeds = `passBiStopKeysForDakarStop()` (TER, BRT, aftu_8/11) ;
2. **second essai natif** — uniquement si (1) ne trouve **aucun** trajet : les requêtes saisies sont résolues
   vers les arrêts PassBi dont le **nom réel contient la requête entière** (`searchNativeStops`, correspondance
   stricte, aucune proximité, aucune similarité approchée). Exemple réel :

   `RoutePlanner.plan(fromQuery: 'Terminus Palais 2', toQuery: 'Gare Ter Keur Mbaye Fall', at: 2026-09-28 07:30)`
   → trajet moteur `DDD_15` (`Terminus Palais 2` → `Sonadis`, 07:30:26 → 08:41:54) puis `AFTU_89`
   (`Sonadis` → `Gare Ter Keur Mbaye Fall`, 08:54:30 → 09:07:34), 1 correspondance, **heure réelle du
   `stop_time`** sur chaque tronçon.

Le second essai est **strictement additif** : aucune requête des suites existantes ne peut le déclencher
(vérifié : `gare ter dakar`, `rufisque gare ter`, `ddd ligne 3`, `origin b1`, `destination b1`,
`origine golf nord (b1)`, `destination yoff (aftu)`, `colobane (horizon)`, `diamniadio (horizon)` → 0
correspondance native).

### 6.3 Correspondances (§10)

Aucune correspondance n'est créée par le lot. Le moteur utilise uniquement les liens **déjà documentés** du
crosswalk (nom vérifié + distance) :

| paire | nombre de liens | méthode | distance |
|---|---|---|---|
| DDD ↔ AFTU | **746** | nom identique + proximité, confiance `high` | moyenne ≈ 54 m (max ≤ 500 m) |
| AFTU ↔ AFTU | 471 | idem | ≤ 500 m |
| DDD ↔ DDD | 170 | idem | ≤ 500 m |
| BRT ↔ DDD | 30 · AFTU ↔ BRT 22 · AFTU ↔ TER 19 · DDD ↔ TER 3 · BRT ↔ BRT 21 | idem | ≤ 500 m |

Chaque transition de tronçon est vérifiée en test : arrêt partagé **ou** lien documenté — jamais une proximité
seule. Aucune correspondance DDD ↔ AFTU artificielle.

### 6.4 ETA (§9)

- PassBi GTFS = **SCHEDULED**. Jamais `REAL_TIME`, jamais `DataStatus.live`.
- Départ dans 3 min → `🟢 Prochain départ dans 3 min` ; 9 min → `🟢 Prochain départ dans 9 min`.
- Départ à moins d'une minute → « Prochain départ dans moins d'une minute » (jamais « 0 min »).
- Aucun départ calculable → `UNKNOWN` + raison (§5 ci-dessous).

---

## 7. Tests

### 7.1 Matrice §11 — `tests/passbi-ddd-aftu-421.test.js` (Node, exécuté par `npm test`)

| # | Cas | Vérification |
|---|---|---|
| A | DDD avec prochain départ calculable | `DDD_01` à son premier arrêt **= résultat du moteur Lot 4.19** (contre-vérification indépendante) ; 52/53 routes |
| B | AFTU avec prochain départ calculable | `AFTU_3` **= moteur 4.19** ; 71/73 routes |
| C | DDD sans départ → UNKNOWN | arrêt inconnu (`AUCUN_DEPART_CALCULABLE`), `DDD_323` (`AUCUN_STOP_TIME_DANS_LE_FEED`) |
| D | AFTU sans départ → UNKNOWN | arrêt inconnu, `AFTU_47` (`AUCUN_STOP_TIME_DANS_LE_FEED`) ; feed `AVAILABLE` |
| E | SCHEDULED ≠ REAL_TIME | échantillons DDD/AFTU ; `sourceType = PUBLIC_GTFS` ; `time_semantics` du feed |
| F | ETA dynamique | le libellé suit l'heure, le départ absolu change, aucune ETA figée |
| G | changement de jour | 23:59 → service J+1 daté du lendemain ; `DDD_18` (LAV) reporté le dimanche |
| H | terminus : arrivée ≠ prochain départ | la ligne retenue est **embarquable** (le trip continue) et égale `nextDepartureAbs(rideableOnly)` |
| I | horizon d'embarquement | embarquement ≤ horizon 6 h ; arrivée au-delà conservée (cas prouvé Lot 4.19 C) |
| J | aucune identité inventée | 0 route DDD confirmée ; AFTU : `AFTU_3` seule, rattachée à `aftu_8`/`aftu_11` ; libellé = `Ligne PassBi <route_id>` |
| K | aucun TATA inventé | 0 mention « tata » ; `ABSENT_FROM_FEED` ; 5 identités dakar `UNMAPPED` |
| L | correspondance DDD/AFTU réellement supportée | trajet réel DDD → AFTU ; chaque transition = arrêt partagé ou lien documenté ; 746 liens bornés ≤ 500 m |

### 7.2 `flutter-src/test/passbi_ddd_aftu_421_test.dart` (Flutter, exécuté par la CI)

Même matrice, plus :

- `Stop.passBiStopKey` : nom/coordonnées du feed, `stopId` dakar **nul**, `DetailedRoute.fromStop` → `null` ;
- filtre DDD/AFTU via `explorerStopSource` (et **non-modification** des autres filtres, `same(allStops)`) ;
- `RoutePlanner` : second essai natif, chaque tronçon `SCHEDULED`, identifiant de ligne PassBi réel ;
- `StopCard` (widget) : identité « Ligne PassBi DDD_… » + « Prochain départ dans … », jamais « 0 min », jamais
  « Live », jamais « Horaire indisponible » pour un arrêt natif desservi.

### 7.3 Non-régression (§12)

- `npm test` : **82/82** (63 tests 4.19/4.20 inchangés + 19 tests Lot 4.21), `0` échec ;
- Flutter (CI réelle) : **tests +481 / -0**, `flutter analyze` → **« No issues found! »**,
  `flutter build web` → **succès** ; les 446 tests existants sont **non modifiés** ;
- `data/gtfs/` et `scripts/check-arrets.js` : **non modifiés** ;
- TER, BRT B1, BRT B2, GPS, cartographie, `allStops` (117 arrêts, vérifié en test), 56 marqueurs carte,
  UI : inchangés.

### 7.4 Incidents CI corrigés pendant le lot

| Commit | Constat CI | Correctif |
|---|---|---|
| `66af0ff` | `flutter analyze` : 7 issues (1 `undefined_identifier` `ScheduleStatus` non importé, 5 accumulateurs construits par des fermetures à zéro argument passées à `List.map`, 1 `prefer_const_declarations`) | import ajouté, listes typées `List.filled` / `List.generate`, `const` — **analyze 0 issue** |
| `992a32d` | `flutter test` : 480/481 — le cas K lisait un `allStops` vide (le fichier de test n'intégrait pas le référentiel dakar) | `integrateNetworkDataForTest()` en `setUpAll` + assertion « 117 arrêts, aucune pollution » — **481/481** |

---

## 8. Limites restantes (documentées, non corrigées)

1. **Identité publique des 105 lignes dakar** — 100 identités restent `UNMAPPED` (12 DDD, 70 AFTU, 18 autres).
   Aucun nom commercial DDD/AFTU n'est inventé ; l'affichage utilise `route_id` / `short_name` du feed.
   La résolution documentaire relève du futur Lot 15.
2. **Deux référentiels coexistent** — `allStops` (référentiel dakar, 117 arrêts) et `passBiNativeStops`
   (3 423 arrêts PassBi DDD/AFTU). Ils ne sont pas fusionnés : un test de non-régression impose que tout arrêt
   de `allStops` porte un `stopId` de `dakar_network.json`, et la couche marqueurs en dépend. La fusion est un
   sujet de refonte de référentiel, hors périmètre du lot.
3. **Recherche de l'Explorer** — la barre de recherche privilégie le référentiel dakar ; les arrêts natifs
   PassBi ne sont proposés qu'en complément, après 8 résultats dakar. Le planificateur de Trajets, lui, résout
   les noms d'arrêts PassBi.
4. **Description de réseau de l'Assistant IA** — `AssistantReplies.modeInfo()` décrit toujours le référentiel
   dakar (« Je ne dispose d'aucun horaire ni d'aucune fréquence vérifiés pour ce réseau »). Cette phrase reste
   exacte pour les identités publiques dakar, mais ne reflète pas encore l'exploitation native PassBi. Le §13
   interdit de modifier l'Assistant IA : aucune modification n'a été faite.
5. **Sens de circulation** — le feed DDD/AFTU ne fournit que `direction_id` (`0`/`1`) et un `headsign` vide :
   aucun libellé « origine ↔ destination » n'est affiché sur les tronçons, aucun sens n'est inventé.
6. **Arrêt « en face »** — `OppositeStopService` applique son repli historique (même mode, ≤ 500 m) à partir
   d'un arrêt natif ; ce repli est documenté comme constat F7, non modifié.
7. **Performance de démarrage** — l'intégration native construit 3 423 `Stop` et calcule 126 fiches d'audit
   (≈ 1 M de lignes `stop_times` parcourues). Mesure non instrumentée en release ; aucun impact mesuré sur les
   tests.
8. **`valid_to = 20231231`** — les feeds DDD/AFTU portent une fenêtre d'origine dépassée, conservée telle
   quelle (`meta`). La sémantique **ROLLING** (décision Lot 4.18) est appliquée : le motif hebdomadaire publié
   s'applique comme base de fonctionnement courante, sans falsifier les dates d'origine.

## 9. UNKNOWN restants — explication précise (§15)

Le champ `DepartureInfo.unresolvedReason` porte désormais la raison exacte. Aucun UNKNOWN ne signifie
« identité non résolue alors qu'un horaire est calculable » : ce cas produit `SCHEDULED`.

| Raison | Quand | Exemple vérifié | Pourquoi ce n'est PAS une donnée manquante |
|---|---|---|---|
| `RESEAU_ABSENT_DU_FEED` | aucun feed PassBi pour ce réseau | `tata_50`, `tata_219`, `new_commune_01` | le réseau TATA n'existe pas comme GTFS PassBi ; aucune route n'est fabriquée |
| `IDENTITE_NON_CONFIRMEE` | identité dakar `UNMAPPED` et aucun couple (route, arrêt) PassBi rattachable | `ddd_1` à `stop_colobane`, `aftu_12` | la donnée DDD existe et est exploitée **sous son propre identifiant** (`DDD_01`…) ; rattacher `DDD_01` à `ddd_1` supposerait que « 1 = 01 », ce que le §2 interdit |
| `ARRET_NON_CORRESPONDU` | route mappée mais arrêt sans plateforme PassBi documentée | arrêt dakar hors périmètre | l'arrêt n'a pas de contrepartie documentée : aucune n'est devinée |
| `AUCUN_DEPART_CALCULABLE` | route + arrêt résolus, aucun départ embarquable sur 7 jours | arrêt PassBi hors service à la date demandée | la donnée existe ; le **contexte temporel** ne fournit aucun départ |
| `AUCUN_STOP_TIME_DANS_LE_FEED` | route présente mais sans `stop_time` | `DDD_323` (288 trips, 0 stop_time), `AFTU_52` (190 trips, 0 stop_time), `AFTU_47` (0 trip) | la route existe mais **aucun horaire n'existe dans la donnée source** |
| `SOURCE_PASSBI_INACTIVE` | assets PassBi illisibles/non chargés | mode legacy | défaillance de chargement, jamais une absence de donnée dans le feed |

---

## 10. Validation

| Étape | Résultat |
|---|---|
| `npm test` (local, 2026-09-28) | **82/82** — 19 nouveaux tests Lot 4.21, 63 tests existants inchangés |
| `node scripts/audit-passbi-ddd-aftu.mjs` | tableau §1 reproductible |
| `flutter analyze` (CI) | **No issues found!** (0 issue) |
| `flutter test` (CI) | **tests +481 / -0** (`flutter-verify` + `flutter-web-build`) |
| `flutter build web --release` (CI) | **succès** |
| `TER BRT data validation` (CI) | **succès** |
| Commit de référence validé par la CI | **`992a32d`** — `feat(dakar-bus): enable passbi ddd aftu schedules` (puis 2 correctifs CI `66af0ff`, `992a32d`) |

Le SDK Dart n'étant pas installable dans l'environnement de travail (sortie réseau restreinte vers
`storage.googleapis.com` et `pub.dev`), **aucun résultat Flutter n'est revendiqué sans la CI** : les valeurs
ci-dessus proviennent des check-runs GitHub Actions des quatre workflows du dépôt.

**Commits du lot**

| SHA | Message |
|---|---|
| `848d8bf` | `feat(dakar-bus): enable passbi ddd aftu schedules` |
| `66af0ff` | `fix(dakar-bus): corriger les 7 issues révélées par flutter analyze (CI)` |
| `992a32d` | `fix(dakar-bus): référentiel dakar intégré dans le test 4.21 (CI 480/481)` |

Pull request : **#38** (`arena/01a0e53c-dakar-bus` → `main`).
PR #31 : **non modifiée, non fusionnée.**
