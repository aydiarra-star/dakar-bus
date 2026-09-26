# DAKAR BUS — AUDIT DU RÉFÉRENTIEL PUBLIC CETUD (AFTU / DDD)

**Titre :** DAKAR BUS — RÉCUPÉRATION ET AUDIT DU VÉRITABLE RÉFÉRENTIEL PUBLIC CETUD — AFTU + DDD
**Date :** 2026-09-26
**Nature :** Lot 16A — récupération / audit (READ-ONLY sur les données de production)
**Statut :** GTFS CETUD **non publiquement téléchargeable** · aucun fichier GTFS récupéré · **aucune donnée de production modifiée**

Consultations effectuées le **2026-09-26** (UTC), répertoire `/home/user/dakar-bus`.

---

## 0. Résumé exécutif — ce qu'il faut retenir

| Question | Réponse vérifiée |
|---|---|
| Le CETUD mentionne-t-il officiellement l'existence d'un GTFS Dakar ? | **OUI** — explicitement, sur `cetud.sn/observatoire/systeme-de-donnees/` |
| Ce GTFS est-il **publiquement téléchargeable** depuis les pages CETUD inspectées ? | **NON** — aucun lien, aucun fichier, sur l'ensemble du site vérifié |
| Un fichier GTFS a-t-il été **récupéré** ? | **NON** — 0 fichier, 0 octet, SHA-256 : *sans objet* |
| Les 72 lignes AFTU sont-elles publiquement référencées ? | **OUI** — 72 lignes numérotées, vérifiées nominativement |
| Les 38 lignes DDD sont-elles publiquement référencées ? | **OUI** — listes d'arrêts publiées par l'exploitant |
| Référentiel détaillé complet des arrêts (AFTU) ? | **NON** — aucune source ne publie d'arrêts AFTU |
| Horaires GTFS exploitables ? | **NON** — aucune grille horaire publiée pour AFTU/DDD |
| Données de production modifiées ? | **NON** |

**Conséquence pour la suite :** la cible « référentiel CETUD » reste **légitime et obligatoire**, mais elle n'est aujourd'hui **pas accessible sous forme de fichier machine**. La correspondance identité interne ↔ ligne publique **ne peut donc pas encore être établie** sur un GTFS : elle reste bloquée à l'état documentaire du Lot 15.

---

## A. Sources CETUD

URLs exactes consultées le 2026-09-26, avec le résultat de la consultation.

| # | Source | URL exacte | Résultat |
|---|---|---|---|
| S1 | Système de données (Observatoire) | `https://cetud.sn/observatoire/systeme-de-donnees/` | ✅ consultée — **mentionne le GTFS**, aucun lien de téléchargement |
| S2 | Réseaux de transport (index) | `https://cetud.sn/reseaux-de-transport/` | ✅ consultée — AFTU 72 / 2 300 · DDD 38 / 400 |
| S3 | AFTU | `https://cetud.sn/reseaux-de-transport/aftu/` | ✅ consultée — 72 lignes, 2 300 bus, 14 GIE nommés |
| S4 | DDD | `https://cetud.sn/reseaux-de-transport/ddd/` | ✅ consultée — 38 lignes, 400 autobus |
| S5 | Observatoire (portail) | `https://cetud.sn/observatoire/` | ✅ consultée — renvoie vers S1/S2, aucune donnée téléchargeable |
| S6 | Fiche projet RTC (PDF, 09/2025) | `https://cetud.sn/wp-content/uploads/2025/09/RTC-Fiche-projet.pdf` | ✅ **récupérée et lue** (voir §H) |

### A.1 Ce que la source S1 dit **exactement** du GTFS

Extrait littéral de la page `Système de données`, section « Données d'exploitation TC » :

> **FICHIER GTFS (GÉNÉRAL TRANSIT FEED SPECIFICATION)** — *Le CETUD a procédé à une numérisation du réseau de transport collectif de Dakar à travers la création de fichiers GTFS. Ils contiennent des informations qui permettent de communiquer les horaires, arrêts, itinéraires, trajets, tarifs, services…, dans un objectif de favoriser l'opendata et permettre le développement d'applications mobiles pour les usagers.*

Et sur les données d'exploitation AFTU/DDD :

> **DONNÉES D'EXPLOITATION HORS SAE** — *Il s'agit des données produites à travers l'exploitation des réseaux classiques (AFTU, DDD). Elles proviennent de plateformes dédiées (CAPTRANS) et/ou d'enquêtes auprès des opérateurs.*

**Le GTFS est donc attesté par la source institutionnelle centrale.** Cette attestation ne s'accompagne, sur cette page, d'**aucun** lien de téléchargement, d'aucun nom de fichier, d'aucune URL, d'aucune licence.

### A.2 Tous les liens de téléchargement réellement présents sur le site CETUD

Relevé exhaustif des liens de type « Télécharger / Voir les lignes » trouvés sur les pages consultées :

| Page | Libellé du bouton | Cible réelle | Format |
|---|---|---|---|
| S2 | Voir les lignes (DDD) | `.../2024/11/plan-lignes-ddd.jpeg` | **JPEG** |
| S2 | Voir les lignes (AFTU) | `.../2024/11/plan-lignes-aftu.jpeg` | **JPEG** |
| S2 | Voir les lignes (BRT) | `.../2024/11/sunubrt-guide-du-voyageur-vf.pdf` | PDF |
| S2 | Voir les lignes (TER) | `.../2024/11/Plan-de-la-ligne-TER.pdf` | PDF |
| S3 / S4 | Je télécharge | `plan-lignes-aftu.jpeg` / `plan-lignes-ddd.jpeg` | **JPEG** |
| S1 / S5 | Publications | RTC, plaquette, brochures BRT, bulletins | PDF |

**Aucun de ces liens n'est un GTFS.** Les deux sources « lignes » officielles pour AFTU et DDD sont des **images cartographiques**, pas des fichiers exploitables.

---

## B. AFTU — 72 lignes annoncées par le CETUD

### B.1 Chiffres officiels (S2, S3)

| Indicateur | Valeur CETUD |
|---|---|
| Lignes | **72** |
| Bus | **2 300** |
| Passagers | 320 millions / an |
| Amplitude | 15 h/24, de 6 h à 21 h |
| Structure | 14 GIE (Alhamdoulillah, Avenue du Sénégal, Darou Salam, Diameguene, Diapalanté, Dimbalanté, Khéweul Aéroport, Nayobé, Ndiambour, Ressortissants du Walo, Sante Yalla, Sopelli Transports, Thiaroye Yeumbeul, Transports Mboup) |
| Plan des lignes | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-aftu.jpeg` |
| Site de l'exploitant | `https://www.aftu-senegal.org/` |

### B.2 Référentiel AFTU réellement récupéré — **vérification nominative**

**Découverte du lot :** le site de l'exploitant `https://aftu-senegal.org/infos-pratiques/` publie la **liste numérotée complète** des lignes AFTU de Dakar, avec origine ↔ destination et lien d'itinéraire par ligne.

**Comptage vérifié : 72 lignes numérotées**, exactement dans la plage officielle **1–5, 24–89, 91** :

| Bloc | Numéros | Nombre |
|---|---|---|
| Bloc bas | 1, 2, 3, 4, 5 | 5 |
| Bloc principal | 24 → 83 | 60 |
| Bloc sans page d'itinéraire | 84, 85, 86, 87, 88, 89 | 6 |
| Dernière | 91 | 1 |
| **Total** | **1–5, 24–89, 91** | **72** ✅ |

**Concordance nominative vérifiée** (échantillon contrôlé contre le référentiel canonique rév. 1.1, §A.2 déjà présent dans le dépôt) :

| Ligne | Libellé publié par AFTU (2026-09-26) | Libellé §A.2 (référentiel interne) | Concordance |
|---|---|---|---|
| 1 | LAT DIOR- HLM GRAND YOFF | LAT DIOR- HLM GRAND YOFF | ✅ identique |
| 3 | YOFF - PETERSEN | YOFF - PETERSEN | ✅ identique |
| 4 | YOFF VILLAGE - PETERSEN | YOFF VILLAGE - PETERSEN | ✅ identique |
| 5 | PARCELLES ASSAINIES- PETERSEN | PARCELLES ASSAINIES- PETERSEN | ✅ identique |
| 50 | PETERSEN - MALIKA CIMETIERE | PETERSEN - MALIKA CIMETIERE | ✅ identique |
| 64 | GUEDIAWAYE - RUFISQUE | GUEDIAWAYE - RUFISQUE | ✅ identique |
| 78 | DIAMAGUENE - LIBERTE 5 | DIAMAGUENE - LIBERTE 5 | ✅ identique |
| 84 | UCAD - JAXAAY | UCAD - JAXAAY | ✅ identique |
| 91 | APIX - DOUGAR | APIX - DOUGAR | ✅ identique |

### B.3 Confirmation indépendante d'un constat du référentiel interne

Le référentiel interne (§D item 2) affirmait : « AFTU 84–89, 91 : **aucun itinéraire publié** — `ROUTE_NOT_FOUND` est un fait ».

**Vérification indépendante sur la source exploitant (2026-09-26) :** pour les lignes **84, 85, 86, 87, 88, 89 et 91**, le lien « Voir itinéraire » renvoie vers **la page elle-même** (`https://aftu-senegal.org/infos-pratiques/`), et non vers une page `/map/dakar-urbain-ligne-N/`.

→ **Le constat `ROUTE_NOT_FOUND` est confirmé par la source primaire de l'exploitant.** Aucune reconstruction d'itinéraire n'est justifiée pour ces 7 lignes.

### B.4 Deux anomalies de publication confirmées indépendamment

* **Lignes 27 et 36** : leur lien d'itinéraire est une **URL de prévisualisation** (`?post_type=waymark_map&p=…&preview=true`) — exactement l'anomalie déjà consignée au référentiel §A.5.
* **Site AFTU pollué** : la page d'accueil `aftu-senegal.org` affiche un **module de réservation de démonstration** (Lisbon–Madrid, Prague–Vilnius, tarifs « 26 FCFA per adult »). Cette donnée est **fictive** : elle ne doit jamais entrer dans le référentiel. Le référentiel §E.2 avait déjà écarté ce module — le présent audit le confirme sur la source vive.

### B.5 Ce que la source AFTU **ne publie pas**

Confirmé le 2026-09-26 : **aucun arrêt nommé**, **aucun horaire**, **aucune fréquence**, **aucun `stop_sequence`**, **aucun identifiant au format GTFS**. Le référentiel §A.1 était exact (« Arrêts explicites publiés : **0** · Horaires publiés : **0** · Fréquences publiées : **0** »).

---

## C. DDD — 38 lignes annoncées par le CETUD

### C.1 Chiffres officiels (S2, S4)

| Indicateur | Valeur CETUD |
|---|---|
| Lignes | **38** |
| Autobus | **400** |
| Passagers | 15 millions / jour |
| Amplitude | 15 h/24, de 6 h à 21 h |
| Téléchargement officiel | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-ddd.jpeg` (**JPEG**) |
| Site de l'exploitant | `https://demdikk.sn/` |

### C.2 Référentiel DDD réellement récupéré

Source primaire exploitant : `https://demdikk.sn/reseau-urbain-dakar/` — page intitulée « LIGNES URBAINES — *Cliquez sur une ligne pour voir son itinéraire* ».

**Cette page publie, pour chaque ligne, la séquence d'arrêts nommés.** Lignes relevées dans la consultation (ordre de publication, extrait) :

`LIGNE 1`, `LIGNE 4`, `LIGNE 7`, `LIGNE 8`, `LIGNE 9`, `LIGNE 10`, `LIGNE 13`, `LIGNE 18`, `LIGNE 20`, `LIGNE 23`, `LIGNE 121`, `LIGNE 319`, …

Exemple de séquence complète récupérée (LIGNE 1 : TERMINUS PARCELLES ASSAINIES → … → TERMINUS LECLERC, 23 arrêts nommés) :

> Terminus Parcelles Assainies – Sapeur Pompiers – Unités 09 10 15 – Ecole Dior – Terrain Acapes – Unités 22 24 – Marché Grand Médine – Rond point 26 – VDN-Foire – Cité Keur Gorgui – Ecole Normale – UCAD – Rond point Sham – Marché Tilène – Poste Médina – Difoncé – Sandaga – Avenue George Pompidou – Place de l'Indépendance – Gare TER – Embarcadère – Terminus Leclerc

**Concordance avec le référentiel interne :** la LIGNE 1 publiée (PARCELLES ASSAINIES ↔ PLACE LECLERC) est bien **contradictoire** avec l'itinéraire interne de `ddd_1` (Colobane ↔ Yoff Pêcheurs) — le conflit `ddd_1` du Lot §9-1 est **confirmé sur la source primaire**.

### C.3 Anomalies confirmées indépendamment

* **LIGNE 18 publiée deux fois** à l'identique sur la page exploitant → confirme le référentiel §E.2 (« DDD 18 : bloc d'itinéraire **publié deux fois** »).
* **LIGNE 23 : en-tête « PARCELLES ASSAINIES ↔ PALAIS 1 » mais dernier arrêt publié « Terminus Palais 2 »** → confirme exactement le conflit officiel §E.1 (conflit **conservé**, non arbitré).
* **LIGNE 18 et LIGNE 20** ont le même intitulé « DIEUPPEUL ↔ CENTRE-VILLE » avec des arrêts différents → confirme §D item 7 (deux boucles distinctes).

### C.4 Variantes A/B

Le CETUD **ne publie pas** de référentiel détaillé des variantes. Les variantes `15A/15B`, `16A/16B`, `502A/502B`, `503A/503B`, `504A/504B` restent **non fusionnées** et **non intégrées** : aucune source CETUD consultée ne fournit leur différenciation. Conformément à la consigne §6, elles restent `UNVERIFIED` / `CONFLICTING` selon le cas établi au Lot §9-1.

---

## D. GTFS

### D.1 Bloc de réponse obligatoire (§12 de la consigne)

```
GTFS CETUD mentionné officiellement :
OUI

GTFS CETUD publiquement téléchargeable depuis les pages inspectées :
NON

URL exacte :
AUCUNE — aucun lien de téléchargement de GTFS n'existe sur les pages consultées.
(Aucune URL n'est inventée ni devinée.)

Accès :
restreint / à demander — les données d'exploitation AFTU et DDD proviennent de
CAPTRANS et/ou d'enquêtes opérateurs (S1). Le site ne publie ni licence, ni
endpoint, ni archive.

Fichiers réellement récupérés :
AUCUN (0 fichier GTFS, 0 octet)

72 AFTU publiquement référencées :
OUI — 72 lignes numérotées vérifiées (1–5, 24–89, 91) sur aftu-senegal.org

38 DDD publiquement référencées :
OUI — le CETUD annonce 38 ; l'exploitant publie les lignes urbaines avec arrêts
(consultation partielle de la liste)

Référentiel détaillé complet des arrêts :
NON — AFTU : aucun arrêt publié. DDD : arrêts publiés pour les lignes urbaines listées,
sans coordonnées, sans séquence machine, sans identifiants GTFS.

Horaires GTFS :
NON — aucune grille horaire AFTU/DDD publiée.
```

### D.2 Version du feed

**Indéterminable** : aucun fichier n'a été obtenu, donc aucune `feed_info.txt`, aucune `feed_start_date` / `feed_end_date`, aucune `feed_version`.

### D.3 SHA-256

**Sans objet** — aucun fichier récupéré. Aucune empreinte n'est inventée.

### D.4 Date de récupération

**Sans objet** — aucune récupération de fichier n'a eu lieu.

### D.5 Preuves de non-disponibilité (6 vérifications indépendantes)

Chacune de ces vérifications porte sur **le site CETUD lui-même** (accessibles depuis l'environnement d'audit) :

| # | Vérification | Méthode | Résultat |
|---|---|---|---|
| 1 | Recherche du mot « GTFS » sur tout le site | `https://cetud.sn/?s=gtfs` | **« Il semble que nous ne pouvons pas trouver ce que vous cherchez. »** — 0 résultat |
| 2 | Recherche « gtfs » dans la médiathèque WordPress | `https://cetud.sn/wp-json/wp/v2/media?search=gtfs` | **`[]`** — 0 média |
| 3 | Recherche de **tout** fichier ZIP du site | `https://cetud.sn/wp-json/wp/v2/media?mime_type=application/zip` | **`[]`** — **aucune archive ZIP n'existe** dans la médiathèque |
| 4 | Recherche « gtfs » dans les contenus (articles, pages, observatoire) | `https://cetud.sn/wp-json/wp/v2/search?search=gtfs&subtype=post,page,observatoire` | **`[]`** — 0 contenu |
| 5 | Existence d'un portail de données dédié | résolution DNS de `data.cetud.sn`, `opendata.cetud.sn`, `gtfs.cetud.sn`, `observatoire.cetud.sn`, `api.cetud.sn`, `geo.cetud.sn`, `sig.cetud.sn` | **aucun n'est résolu** — seul `cetud.sn` existe |
| 6 | Référentiel public de feeds pour l'Afrique (DT4A) | `https://git.digitaltransport4africa.org/places` | **accès authentifié requis** (page de connexion) — non téléchargeable sans compte |

**Lecture de ces preuves.** Les vérifications 1 à 4 interrogent les **index du site lui-même** : si le CETUD publiait un GTFS, un nom de fichier ou un lien apparaîtrait dans sa recherche, sa médiathèque ou son API de contenus. Les résultats sont **négatifs et concordants**. La vérification 3 est la plus forte : **le site du CETUD n'héberge aucune archive ZIP**, donc aucune archive GTFS — un GTFS étant, par définition, un ZIP.

**Ce que ces preuves ne disent pas :** elles n'établissent **pas** que le GTFS n'existe pas. La source S1 atteste du contraire : il **a été créé**. Elles établissent qu'il **n'est pas publié en téléchargement libre** sur le site institutionnel.

### D.6 Contrainte technique de l'environnement d'audit (à ne pas confondre)

Distinction explicite, pour éviter toute confusion entre deux faits différents :

| Fait | Nature | Portée |
|---|---|---|
| Aucun lien GTFS sur les pages CETUD (vérifications 1–6) | **propriété de la source** | Conclusion sur la **publication** du GTFS |
| L'environnement d'audit ne peut pas télécharger de fichiers binaires | **limite de l'outillage** | N'affecte **pas** la conclusion ci-dessus |

Détail mesuré de la contrainte : sortie réseau générale du bac à sable indisponible (`curl` → `OpenSSL SSL_connect: SSL_ERROR_SYSCALL` vers `cetud.sn`, `www.google.com`, `transport.data.gouv.fr`, `demdikk.sn`, `aftu-senegal.org` ; seule l'API GitHub répond `http=200`). Les pages web ont été lues via l'outil de récupération de la plateforme, qui **atteint bien** `cetud.sn`. En revanche, les **fichiers binaires** (JPEG, PDF joints aux pages) ne sont pas récupérables : la tentative de lecture de `plan-lignes-aftu.jpeg` renvoie **HTTP 500**.

**Conséquence honnête :** je **ne peux pas** calculer le SHA-256 des plans officiels ni archiver leur contenu. Cela **n'explique pas** l'absence de GTFS (qui est un constat sur la source), mais **limite** la constitution de preuves locales.

---

## E. Plans officiels

| Plan | URL exacte | Existe | Contenu vérifié | SHA-256 | Archive locale |
|---|---|---|---|---|---|
| **AFTU** | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-aftu.jpeg` | ✅ **OUI** (lié depuis S2 et S3, bouton « Je télécharge ») | non analysable ici (binaire) | **non calculable** | **non** |
| **DDD** | `https://cetud.sn/wp-content/uploads/2024/11/plan-lignes-ddd.jpeg` | ✅ **OUI** (lié depuis S2 et S4, bouton « Je télécharge ») | non analysable ici (binaire) | **non calculable** | **non** |

**Portée documentaire de ces plans, telle qu'exigée par la consigne :** un plan cartographique **prouve l'existence d'un identifiant représenté sur le plan**. Il **ne permet pas** de reconstruire les arrêts, l'ordre complet des arrêts, les horaires, les `trips`, ni les calendriers. Aucune donnée n'a été déduite de ces cartes dans ce lot, et **aucun `stop_times` n'a été reconstruit à partir d'un tracé cartographique** — cette pratique reste formellement interdite.

**Substitut exploité (supérieur au plan) :** pour l'AFTU, la **liste numérotée textuelle** de l'exploitant (§B.2) fournit la même information d'identifiant que le plan, dans un format exploitable et **daté**. C'est cette source qui est retenue comme preuve des identifiants publics AFTU.

---

## F. Comparaison Dakar Bus / CETUD — **aucune donnée modifiée**

Comparaison **documentaire** (aucune écriture, `dakar_network.json` non modifié dans ce lot) :

| Axe | Référence publique CETUD / exploitant | Référentiel interne Dakar Bus | Écart |
|---|---|---|---|
| Lignes AFTU | **72** (1–5, 24–89, 91) | `aftu_1..aftu_72` + `new_commune_03..10` = **80 routes** | +8 identités internes hors référentiel public |
| Correspondance AFTU interne ↔ public | non publiée | non établie | **0 correspondance prouvée** (Lot 15) |
| Lignes DDD | **38** | **15 routes** DDD dans le jeu de données | le jeu de données **ne représente pas** les 38 lignes |
| Identifiants DDD publiés | 48 identifiants dans le référentiel canonique (dont variantes) | 15 routes | représentativité partielle |
| Arrêts AFTU | **aucun publié** | arrêts internes non sourcés | non comparable |
| Arrêts DDD | publiés pour les lignes urbaines (sans coordonnées) | arrêts internes | non comparable |
| Horaires | **aucun** pour AFTU/DDD | `schedule_status = UNKNOWN` sur 105/105 | **cohérent : rien à importer** |
| Temps réel | SAE pour BRT/TER ; rien pour AFTU/DDD | aucun | cohérent |

**Point de méthode décisif (règle §15 de la consigne) :** à partir de ce lot, **le référentiel interne Dakar Bus n'est plus considéré comme la source permettant de déterminer le numéro public d'une ligne dès lors qu'une donnée de référence existe**. Le numéro public d'une ligne AFTU doit désormais provenir du référentiel public AFTU/CETUD, et non du suffixe de l'identifiant interne.

**Conséquence immédiate, et elle est importante :** les 54 `CONFLICTING` et 26 `MISSING` établis au Lot 15 restent **valides en l'état** (aucune source nouvelle ne les contredit), mais **la correspondance internationale identité interne ↔ ligne publique reste impossible** sans le GTFS ou sans accès aux données CAPTRANS. Le Lot 15 a donc bien consigné des statuts, **pas** des correspondances — ce qui est exactement la bonne conclusion.

---

## G. Tata — traitement documentaire

Le présent audit **ne modifie pas** le traitement Tata établi aux Lots §9-1 et 15, et ne crée **aucun** réseau Tata indépendant.

Ce que les sources publiques permettent et ne permettent pas :

| Affirmation | Statut |
|---|---|
| « Tata » désigne des minibus exploités dans l'écosystème AFTU | ✅ cohérent avec S1 (« transports en commun par **minibus** ») et avec la page S3 (AFTU = opérateurs privés) |
| Il existerait un « réseau Tata numéroté » publié | ❌ **aucune** source consultée ne le publie |
| `tata_64` correspondrait à **AFTU 64** | ❌ **non démontré** — AFTU 64 est publiée « GUEDIAWAYE - RUFISQUE » (§B.2) ; aucune source ne relie l'identité interne `tata_64` à cette ligne |
| `tata_218` / `tata_219` correspondraient à **DDD 218 / 219** | ❌ **non démontré** — même raison |

**Décision documentaire :** conserver `network = AFTU`, `service_category = TATA` **uniquement si une source le démontre**. Aucune source consultée ne le démontre pour une identité Tata nommée. En conséquence, les 7 identités Tata **restent inchangées** : 5 `CONFLICTING` + 2 `MISSING`, `official_number_belongs_to` inchangé, **aucun remappage**.

---

## H. RTC — 14 lignes futures, séparées

Source : **`https://cetud.sn/wp-content/uploads/2025/09/RTC-Fiche-projet.pdf`** — *Fiche projet : Restructuration globale du réseau de transport en commun de Dakar*, 23/09/2025 (PDF **récupéré et lu**).

### H.1 Contenu vérifié de la fiche

| Rubrique | Donnée relevée |
|---|---|
| Objet | Mise en place d'un réseau de bus **complémentaire** aux projets BRT et TER |
| **1ʳᵉ phase en chiffres** | **14 lignes** du réseau prioritaire · **222 km** · **15 terminus** · 30 km de voirie · 9 carrefours équipés · 2 ateliers-dépôts (Ouakam, Keur Massar) · **400 bus GNC** · **400 000 voyageurs/jour** |
| Rabattement | « Le réseau prioritaire assurera plus de **80 %** des rabattements TER & BRT » |
| Investissement | Projet global 2023-2030 : **650 milliards FCFA HT** · **1ʳᵉ phase : 268 milliards** |
| Financement 1ʳᵉ phase | État du Sénégal, BEI, AFD, KfW |
| Maîtrise d'ouvrage | CETUD (projet global), AGEROUTE (aménagements urbains) |
| **Mise en service** | **décembre 2026** (travaux juin 2025 → mai 2027 ; exploitation contractualisée juil. 2023 → mars 2026) |
| Annexes | Annexe 2 : réseau global restructuré, **32 lignes** · **Annexe 3 : 1ʳᵉ phase, 14 lignes** |

### H.2 Traitement

**RTC est un projet de restructuration, pas un réseau en service.** Décision appliquée :

* ❌ **aucune** fusion des 14 lignes RTC avec les 72 lignes AFTU ou les 38 lignes DDD ;
* ❌ **aucune** introduction des lignes RTC comme lignes actuelles ;
* ❌ **aucune** création de route RTC dans `dakar_network.json` ;
* ✅ les 14/32 lignes sont consignées ici comme **corpus FUTURE séparé**, rattaché au projet, avec sa source, sa date et son calendrier.

La seule trace exploitable de RTC dans le jeu de données actuel reste **documentaire** (mention du projet), et aucune identité RTC n'y est intégrée.

---

## I. Limites — ce qui n'est pas publiquement récupérable

| # | Limite | Nature | Contournement employé |
|---|---|---|---|
| L1 | **GTFS CETUD non publié en téléchargement** | limite de la source | aucun — pas de substitut admis (§11 de la consigne) |
| L2 | Aucun arrêt, horaire, fréquence AFTU publiés | limite de la source | aucun |
| L3 | Arrêts DDD publiés **sans coordonnées** ni identifiants GTFS | limite de la source | aucun |
| L4 | Plans officiels au format image, non analysables ici (binaire inaccessible) | limite d'outillage | liste textuelle exploitant substituée pour les identifiants AFTU |
| L5 | Pas de SHA-256 possible sur les plans / aucun GTFS à hacher | conséquence de L1+L4 | aucune empreinte inventée |
| L6 | DT4A (dépôt GitLab de feeds africains) exige un compte | limite de la source | aucun |
| L7 | Aucun flux temps réel AFTU/DDD | limite de la source | aucun — `realtime_status` reste non renseigné |
| L8 | CAPTRANS est une plateforme d'exploitation, non un portail open data public | limite de la source | aucun |

**Ces limites ne sont pas contournées, et aucun substitut (OSM, Moovit, Google, données internes, correspondance par numéro ou par géographie) n'a été utilisé comme référentiel CETUD.** Aucun lien n'a été fabriqué ni deviné.

---

## J. Recommandation technique

### J.1 Principe

Le référentiel CETUD devient la **cible de référence** pour l'identification publique des lignes AFTU et DDD. Tant qu'il n'est pas disponible sous forme de fichier, **aucune correspondance automatique ne doit être produite**. La chaîne cible est :

```
GTFS CETUD (source de vérité, à obtenir)
      ↓  ingestion outillée, horodatée, hachée (SHA-256) et archivée
Transit Data Layer  (couche interne, isolée du jeu de données public)
      ↓  route · trip · stop · stop_time · shape · calendar
Table de correspondance  (internal_id ↔ route_id CETUD)
      ↓  statut de preuve explicite par champ
Dakar Bus  →  itinéraire  →  Assistant
```

### J.2 Comment obtenir réellement le référentiel

| Voie | Action | Statut |
|---|---|---|
| **V1** | Demander le GTFS au CETUD — contact publié : `observatoire@cetud.sn` / `cetud@cetud.sn` / +221 33 828 92 91 / +221 33 859 47 20 | **voie principale recommandée** |
| **V2** | Demander l'accès aux données d'exploitation AFTU/DDD via **CAPTRANS** (la source S1 désigne CAPTRANS comme plateforme dédiée) | recommandée, complémentaire |
| **V3** | Solliciter le compte DT4A (dépôt GitLab) et vérifier si un jeu Dakar y est publié | à tenter |
| **V4** | Suivre la mise en service RTC (déc. 2026) : un GTFS RTC complet est probable à cette échéance | à surveiller |
| **V5** | Ré-interroger périodiquement les index du site CETUD (les 4 requêtes du §D.5 sont automatisables) | **détection automatique d'une publication future** |

### J.3 Ingestion à prévoir (pour le lot futur, **non déclenché ici**)

1. **Télécharger** l'archive et **figer** `sha256`, URL exacte, date de récupération, `feed_info` (version et période de validité).
2. **Stocker le GTFS brut hors du jeu de données public** (répertoire d'archive dédié, versionné par empreinte), jamais écrasé silencieusement.
3. **Isoler** la couche « Transit Data Layer » du fichier consommé par l'application : aucune donnée GTFS brute ne doit être exposée directement.
4. **Construire la correspondance sur preuve** : `internal_id ↔ route_id` uniquement si `route_short_name` + `agency` + terminus + itinéraire concordent ; sinon laisser `MISSING` / `CONFLICTING`. Le contrôle `scripts/check-line-identities.js` (`npm run check:identites`) est déjà en place pour **interdire** toute correspondance fondée sur une ressemblance ; il devra être étendu au champ `route_id` plutôt que remplacé.
5. **Réconcilier les variantes** (`15A/15B`, `16A/16B`, `502A/502B`, `503A/503B`, `504A/504B`) sur la base des `trip`/`stop_sequence` du GTFS **uniquement** — jamais sur la proximité des numéros.
6. **Ne pas convertir une fréquence en horaire** : `schedule_status` ne passera à `SCHEDULED` que si le GTFS fournit des `stop_times` réels pour la ligne concernée.
7. **Ne pas écraser la géométrie interne** par les `shapes.txt` du GTFS sans lot dédié : la question géométrique reste séparée (règle reconduite des Lots 13/14/15).

### J.4 Bénéfice usager visé (consigne §10)

L'objectif — que l'usager puisse **identifier le numéro de ligne à chercher sur le véhicule** (« AFTU 64 », « DDD 16A ») et pas seulement une paire origine → destination — **n'est pas atteignable dans ce lot** : il exige le GTFS (numéro + direction + arrêt de montée + séquence d'arrêts + arrêt de descente). Il le devient dès que **V1 ou V2** aboutit, et le pipeline du §J.1 est alors directement applicable.

---

## K. Validation et intégrité

| Contrôle | Résultat |
|---|---|
| `npm test` | **24/24**, 0 échec, exit 0 |
| `npm run check:identites` | **CONFORME**, exit 0 |
| `npm run transit:layer:check` | **script inexistant** — non exécutable (signalé, non contourné) |
| `npm run validate:data` | **exit 1** — 11 lignes de constats, **294 occurrences pondérées** (inchangé depuis le Lot 14 BIS) |
| `flutter test` | **NON EXÉCUTÉ** — `flutter`/`dart` absents de l'environnement |
| `git status` | **propre** — un seul fichier ajouté par ce lot (le présent rapport) |
| `dakar_network.json` | **NON modifié** dans ce lot (empreinte du Lot 15 conservée) |
| `data/gtfs/shapes.txt` | **NON modifié** — SHA-256 `80a84ebad85ae58e1081e5308e709bd0262dcdd383c1532a80169396091f27eb` |

**Aucune donnée de production n'a été modifiée. Aucune PR. `main` non touchée.**

---

## L. Rapport final

```
DAKAR BUS — LOT 16A — ÉTAT FINAL
Nature                             : audit / récupération READ-ONLY

GTFS CETUD mentionné officiellement : OUI (source S1, citation littérale §A.1)
GTFS CETUD publiquement téléchargeable : NON (6 vérifications indépendantes, §D.5)
URL exacte du GTFS                  : AUCUNE — aucun lien trouvé, aucun lien inventé
Accès                               : restreint / à demander (CAPTRANS + CETUD)
Fichiers GTFS récupérés             : AUCUN (0 fichier, 0 octet)
SHA-256 des GTFS récupérés          : SANS OBJET
Version du feed                     : INDÉTERMINABLE
Date de récupération                : SANS OBJET

Routes CETUD récupérées (identifiants)  : 72 (AFTU, liste numérotée exploitant)
  dont AFTU                             : 72  (1–5, 24–89, 91) — vérifiées nominativement
  dont DDD                              : annoncées 38 par CETUD ; listes d'arrêts
                                          publiées par l'exploitant pour les lignes urbaines
Routes RTC                          : 14 (1ʳᵉ phase) / 32 (réseau global) — corpus FUTURE séparé
Arrêts AFTU publiés                 : 0
Horaires AFTU/DDD publiés           : 0
Plans officiels                     : 2 URL exactes relevées (JPEG), archivage local impossible ici

Données de production modifiées     : NON
shapes.txt modifié                  : NON
PR créée                            : NON
main touchée                        : NON

npm test                            : 24/24, 0 échec
npm run check:identites             : CONFORME, exit 0
npm run transit:layer:check         : script inexistant — non exécutable
npm run validate:data               : exit 1, 294 constats (inchangé)
flutter test                        : NON EXÉCUTÉ — outil absent de l'environnement
```

### L.1 Ce qui a été vérifié

* l'existence **officiellement attestée** d'un GTFS CETUD, par citation littérale de la source institutionnelle ;
* l'**absence de publication** de ce GTFS, par 6 vérifications indépendantes dont l'absence de toute archive ZIP dans la médiathèque du site ;
* les **72 lignes AFTU** nommément, dans la plage officielle **1–5, 24–89, 91**, avec concordance sur 9 libellés ;
* la confirmation indépendante du constat `ROUTE_NOT_FOUND` sur les lignes **84–89 et 91** ;
* les chiffres CETUD **72 / 2 300 / 38 / 400**, lus sur les pages officielles ;
* la confirmation indépendante de 4 anomalies déjà consignées (lignes 27/36, page DDD 18 dupliquée, conflit DDD 23, intitulés DDD 18/20) ;
* le contenu de la **fiche projet RTC** (14 lignes, 222 km, 15 terminus, 400 bus GNC, mise en service déc. 2026).

### L.2 Ce qui reste **absent** et bloquant

* le **fichier GTFS** lui-même (arrêts, horaires, `stop_sequence`, `shapes`, calendriers) ;
* toute **correspondance** entre une identité interne Dakar Bus et une ligne publique ;
* la possibilité d'afficher à l'usager **le numéro de ligne à chercher sur le véhicule** ;
* le **SHA-256** de tout artefact CETUD.

### L.3 Conclusion

Le CETUD **a numérisé** le réseau et **le dit publiquement** : le GTFS existe. Mais il **ne le publie pas** en téléchargement libre sur les pages inspectées : le site institutionnel n'héberge **aucune archive**, et ses deux sources « lignes » pour AFTU et DDD sont des **images**. En revanche, la **liste numérotée des 72 lignes AFTU** est récupérable nominativement chez l'exploitant, et elle **corrobore exactement** le référentiel interne déjà audité.

Il n'y a donc **rien à importer** dans ce lot, et c'est un résultat — pas un échec : **le référentiel interne n'est pas remplacé, il est confirmé**. La correspondance identité ↔ ligne publique doit être obtenue par **demande directe au CETUD / CAPTRANS** (voies V1/V2), puis ingérée selon le pipeline du §J.1, sans jamais recourir à une inférence.

---

*Fin de l'audit du référentiel public CETUD — Lot 16A. Aucune donnée de production modifiée. Le Lot 17 n'est pas engagé.*
