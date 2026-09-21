# Dakar Bus — Réseau Multimodal Dakar (TER • BRT • DDD • AFTU • Tata)

Plateforme d’assistance aux transports urbains et de calcul d’itinéraires multimodaux pour la région métropolitaine de Dakar — **92 arrêts, 105 lignes, 5 opérateurs (72 AFTU + 13 communes)**.

![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?logo=flutter)
![Build](https://img.shields.io/badge/Build-passing-success?logo=github)
![Réseau](https://img.shields.io/badge/Réseau-105_lignes_92_arrêts-00B140)
![Version](https://img.shields.io/badge/Version-9.3.0+4-FF8C42)

**🌐 Démo live :** https://aydiarra-star.github.io/dakar-bus/  
**📦 Repo :** https://github.com/aydiarra-star/dakar-bus

---

## 🚀 Nouveautés v9.3.0 (16/09/2026) — 52 nouveaux arrêts communes
- ✅ **52 nouveaux arrêts** : Fass, SICAP, Dieuppeul, Grand Dakar, Rebeuss, Plateau, Fann, Amitié, Sicap Mermoz, Khar Yalla, Maristes, Dalifort, Guinaw Rails, Djida, Mbao, Malika, Keur Ndiaye Lô, Jaxaay, Sangalkam, Bambilor, Sébikotane, Yenne, Tivaouane, Niague, Golf Sud, Médina Gounass, Ndiarème, Sam Notaire, Parcelles U13/U15/U22, Pikine Nord/Est, Thiaroye Mer, Hann Maristes, Keur Gorgui, Ouakam, Ngor Village, Yoff Tonghor, Keur Massar Nord, Rufisque Ouest/Nord, Diamniadio 2, Sébikotane Gare, Bargny Guedj — **92 arrêts totaux** couvrant toutes les communes (Dakar, Pikine, Guédiawaye, Rufisque)
- ✅ **13 nouvelles lignes communes** : DDD Fass-SICAP, DDD Plateau-Fann, AFTU Sicap-Maristes, AFTU Dalifort-Guinaw Rails, etc. — **total 105 routes**

## 🚀 Nouveautés v9.2.0 (16/09/2026) — 72 AFTU complètes
- ✅ **Réseau 72 AFTU** : passage de 20 → 72 lignes AFTU (toutes les lignes officielles, 1→72), total **92 routes** (1 TER + 2 BRT + 12 DDD + 72 AFTU + 5 Tata), 40 stops, 40 Ko JSON
- ✅ **Tests** : 18 tests (DataService, DakarBounds, DistanceHelper) — `flutter test` passe
- ✅ **Qualité** : `_isLoadingRoutes` utilisé (plus de warning), `analysis_options.yaml` corrigé, CI verte

## 🚀 Nouveautés v9.1.0 (16/09/2026)
- ✅ **DataService branché** : `assets/data/dakar_network.json` (22 Ko, 40 routes) → `main.dart` via `appDataService.loadNetworkData()` + `_integrateNetworkData()` (40 stops injectés, déduplication automatique)
- ✅ **Réseau complet** : 1 TER (SETER 12 gares), 2 BRT (SunuBRT 12+6 arrêts), 12 DDD (Dem Dikk), 20 AFTU (72 lignes → 20 représentatives), 5 Tata — 5 opérateurs, 25 OFFICIAL / 15 FIELD_OBSERVATION
- ✅ **Fix 22 erreurs** : `DataService` réécrit (respecte `operatorId/type/stopIds`), `TransportNetwork` wrapper, `pubspec.yaml` déclare `assets/data/dakar_network.json`
- ✅ **CI sécurisée** : `flutter analyze --fatal-infos` bloque les pushes cassés, `build web --base-href "/dakar-bus/"` validé (37s, 23 MB)
- ✅ **Qualité** : `.gitignore` Flutter complet + `analysis_options.yaml` (lints nettoyés, `withOpacity` toléré pour Flutter 3.24.5) + version 9.1.0+2

## 🗺️ Réseau (extrait)

| Opérateur | Lignes | Exemples |
|-----------|--------|----------|
| **TER** (SETER #8B4513) | 1 ligne • 12 gares • 35 km | Dakar → Colobane → Hann → Pikine → Thiaroye → Yeumbeul → Keur Massar → Diamniadio |
| **BRT** (SunuBRT #22C55E) | 2 lignes | **B1** Guédiawaye ↔ Petersen (12 arrêts) • **B2 Express** 6 arrêts |
| **DDD** (Dem Dikk #3B82F6) | 12 lignes | 1,3,7,8,9,10,11,12,14,15,20,23 — Colobane↔Yoff, Sandaga↔Ouakam, Petersen↔Rufisque… |
| **AFTU** (#FF8C42) | 72 lignes complètes | 1→72 — Toutes les lignes officielles AFTU (Parcelles, Guédiawaye, Keur Massar, Yoff, Thiaroye, Médina, Ouakam, Almadies…) |
| **Tata** (#87CEEB) | 5 lignes | 50,64,78,218,219 |

> Tous les arrêts sont dans `DakarBounds` (14.65–14.79 N, -17.55–-17.15 E) et tracés sur `flutter_map` (OSRM pour les lignes non dédiées).

## 🏗️ Architecture

```
lib/
├── main.dart (118k) — UI + _integrateNetworkData() + allStops/demoRoutes
├── models/transport_network.dart — Operator/BusStop/TransportRoute + TransportNetwork wrapper
├── services/data_service.dart — loadNetworkData() (JSON → fallback mémoire)
assets/data/dakar_network.json — 40 stops / 40 routes (22 Ko)
.github/workflows/deploy.yml — Flutter 3.24.5 → analyze → build web → GitHub Pages
```

**Flux DataService → UI :**
```dart
final appDataService = DataService();
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appDataService.loadNetworkData(); // JSON ou fallback
  _integrateNetworkData(); // Stop + TransitRoute injectés dans allStops/demoRoutes
  runApp(const DakarBusApp());
}
```

## 💻 Développement

```bash
git clone https://github.com/aydiarra-star/dakar-bus.git
cd dakar-bus
flutter pub get
flutter analyze          # 18 infos (0 error) attendu
flutter build web --release --base-href "/dakar-bus/"
flutter run -d chrome    # test local
```

**Ajouter une ligne :** édite uniquement `assets/data/dakar_network.json` :
```json
{ "id": "aftu_99", "operator_id": "aftu", "short_name": "AFTU 99",
  "long_name": "Nouveau ↔ Centre", "type": "BUS", "data_trust": "FIELD_OBSERVATION",
  "stops": ["stop_medina","stop_colobane","stop_petersen"] }
```
→ Elle apparaît automatiquement sur la carte.

## 🔧 Fiche technique

- **Framework :** Flutter 3.24.5 (Dart 3.5.4) • `sdk >=3.3.0 <4.0.0`
- **Dépendances :** `flutter_map 6.1.0`, `latlong2 0.9.1`, `geolocator 12.0.0`, `http 1.2.2`
- **Compatibilité :** Web (GitHub Pages), Android, iOS • Responsive + dark mode + favoris + OSRM routing + IA
- **CI :** GitHub Actions `Deploy to GitHub Pages` (analyze + build + upload artifact)

## 📄 Licence

Projet étudiant / prototype — données indicatives + officielles (CETUD, SETER, SunuBRT, DDD). Contributions bienvenues !

