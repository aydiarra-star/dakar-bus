# Chantier TATA — identification enrichie (PR #48, lot 2)

**Date** : 2026-09-29 · **Nature** : audit **en lecture seule** des sources + registre d'identité
**Périmètre** : identification UI TATA. **Aucune donnée horaire touchée.**

---

## 0. Règle absolue respectée

Le pipeline horaire validé reste **strictement inchangé** :

```
PassBi → route → trip → direction → arrêt → stop_times → DakarClock
       → calcul X min → DepartureInfo → Explorer
```

Ne sont **pas** modifiés : parsers, données PassBi, `stop_times`, calculs de
minutes, `DakarClock`, mappings horaires, statuts `SCHEDULED` / `ESTIMATED` /
`UNKNOWN`, moteur de routage, GPS, sources de données.

Le lot ne touche que **deux fichiers de présentation** (`main.dart`,
`schedule_provider.dart`, dans leur partie identité d'affichage) et **un
registre de données** (`documented_route_identity.dart`).

---

## 1. Hiérarchie des sources appliquée

| Niveau | Sources | Usage |
|---|---|---|
| 1 — officiel | CETUD (`cetud.sn/reseaux-de-transport/`), AFTU (`aftu-senegal.org/infos-pratiques/`) | référence réseau, numéros de ligne **AFTU/DDD** |
| 2 — apps mobilité | PassBi, Bus Bii (`busbii.com`) | preuve **seulement** si la ligne TATA y est exposée explicitement |
| 3 — secondaire | covoiturage.sn / Scribd (liste « Tata N ») | **correspondance candidate uniquement**, jamais preuve |

---

## 2. Constat prouvé : aucune ligne TATA n'est documentée

| # | Constat | Preuve |
|---|---|---|
| 1 | « Tata » est un **type de véhicule** (marque), pas un opérateur ni un réseau | ITF/ILO 2020 (`S-I1`) ; référentiel interne §B ; `dakar_network.json` : Tata = catégorie de service AFTU |
| 2 | Aucune source officielle ne nomme un véhicule TATA par ligne | audit 3A : **0 `CONFIRMED`** (15 `CONFLICTING`, 7 `MISSING`) |
| 3 | Le feed PassBi AFTU ne porte **aucun** champ `vehicle_type`/`network`/`agency` | `aftu.json` = `id`/`short`/`long`/`type` uniquement ; `PassBiSource.tataMentions()` vide |
| 4 | Bus Bii annonce des itinéraires « TATA » mais **n'expose aucune route numérotée** consultable | `busbii.com` (page marketing) ; fiche store MWM |
| 5 | Le numéro « 218 » de `tata_218` appartient en réalité à **DDD 218** | audit 3A §6.1 |

**Conclusion** : TATA reste un type de véhicule. **Aucune ligne TATA n'est
`CONFIRMED`.** Aucun numéro TATA n'est fabriqué.

---

## 3. Enrichissement livré (sans invention)

| Élément | Contenu | Effet UI |
|---|---|---|
| `PublicIdentityStatus` | `documented` / `candidate` / `unconfirmed` | distingue preuve et correspondance |
| `IdentityEvidence` | `officialPublication`, `mobilityApp`, `terminusCrossCheck`, `fieldObservation`, `none` | trace l'adossement |
| `tataCandidates` | **38** correspondances secondaires (terminus) croisées avec le feed AFTU | conservées, **jamais affichées** |
| `documentedVehicleTypes` | **vide** (l'ancienne hypothèse « AFTU 72/80 = Tata » n'était pas sourcée) | plus de type de véhicule inventé |
| `confirmedTataLabel` / `tataLabelForStatus` | `null` sauf statut `documented` | prêt pour une future preuve admissible |
| `routeLabel` / `identityLabelFor` | identité TATA confirmée → « Tata N » ; sinon repli AFTU/DDD documenté ou mode | **jamais** « Tata 218 » |

### Hiérarchie visuelle conservée (Explorer)

```
DDD / AFTU / TATA  →  numéro de ligne (si documenté)
Direction / destination
Arrêt
X min
```

---

## 4. Tests ajoutés (`test/tata_identity_candidates_test.dart`, 20 tests)

1. Tata = type de véhicule, `operator` toujours `AFTU` ;
2. `vehicle_type = TATA` seulement si confirmé ;
3. correspondance secondaire = candidat, jamais confirmé ;
4. `tata_218` ne devient jamais « Tata 218 » ;
5. numéro de parc (`9003`) ≠ numéro de ligne ;
6. DDD : identités documentées uniquement ;
7. AFTU : identités documentées uniquement ;
8. identité TATA confirmée → « Tata N » ;
9. identité TATA non confirmée → repli « AFTU 80 » ;
10. provenance : terminus croisés avec le feed PassBi AFTU réel ;
11. **pipeline horaire non modifié** : le registre ne référence aucun composant
    horaire (`DakarClock`, `stop_times`, `ScheduleStatus`, `DepartureInfo`,
    `frequency`…) et les fichiers du pipeline ne citent pas le registre TATA.

---

## 5. Vérification finale

| Commande | Résultat |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **678 tests passés** |
| `flutter build web --release --base-href /dakar-bus/` | **✓ Built build/web** |

**Critère de non-régression horaire** : le registre d'identité ne contient
aucune référence au calcul des minutes ; le diff de `schedule_provider.dart` se
limite au libellé d'affichage ; aucun `0 min`, « moins d'une minute » ni horaire
inventé n'est introduit.
