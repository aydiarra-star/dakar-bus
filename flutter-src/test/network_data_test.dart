import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:dakar_bus/services/data_service.dart';

/// GROUPE 1 (Step 4B) — conformité de la DONNÉE ACTIVE.
///
/// Ces tests figent le §5, le §6 et le §7 : le réseau JSON actuel est la
/// source de vérité, TER = 13 gares, BRT = 23 stations. Toute régression
/// ultérieure (retour aux 12 gares historiques, retour aux 11/12 stations
/// historiques, réintroduction de Keur Massar dans le TER) fait rougir ce
/// fichier.
///
/// Données de référence : gh-pages 94a84b6070569bed708b8e779b9e70b7c9dafa45,
/// fichier assets/assets/data/dakar_network.json,
/// md5 81c778f4644dcf5e1cf4ae25879218f0, 59 189 octets.

/// Les 13 gares TER dans l'ordre Dakar -> Diamniadio, tel qu'imposé par le §6.
const List<String> kTer13 = <String>[
  'stop_dakar_ter',
  'stop_colobane',
  'stop_hann',
  'stop_dalifort_ter',
  'stop_baux_maraichers',
  'stop_pikine',
  'stop_thiaroye',
  'stop_yeumbeul',
  'stop_keur_mbaye_fall',
  'stop_pnr',
  'stop_rufisque',
  'stop_bargny',
  'stop_diamniadio',
];

/// Les 23 stations SunuBRT de B1 dans l'ordre Guédiawaye -> Petersen.
const List<String> kBrtB123 = <String>[
  'stop_brt_23_guediawaye',
  'stop_brt_22_gadaye',
  'stop_brt_21_golf_nord',
  'stop_brt_20_fith_mith',
  'stop_brt_19_dalal_jamm',
  'stop_brt_18_golf_sud',
  'stop_brt_17_ndingala',
  'stop_brt_16_parcelles_assainies',
  'stop_brt_15_croisement_22',
  'stop_brt_14_police_parcelles',
  'stop_brt_13_grand_medine',
  'stop_brt_12_thiandoum',
  'stop_brt_11_scat_urbam',
  'stop_brt_10_khar_yallah',
  'stop_brt_09_liberte_6',
  'stop_brt_08_liberte_5',
  'stop_brt_07_sacre_coeur',
  'stop_brt_06_liberte_1',
  'stop_brt_05_grand_dakar',
  'stop_brt_04_dial_diop',
  'stop_brt_03_obelisque',
  'stop_brt_02_mosquee',
  'stop_brt_01_petersen',
];

/// Les 7 stations directes de B2 Express.
///
/// AUDIT DONNÉES 2026-09-24 — séquence corrigée.
/// AVANT : 23, 19, 16 (Parcelles), 13, 09 (Liberté 6), 03, 01.
/// APRÈS : 23, 19, 13, 07 (Sacré-Cœur), 05 (Grand Dakar), 03, 01.
/// RAISON : l'ancienne liste figeait une hypothèse fausse. Le communiqué
///   SunuBRT du 30/09/2024 (lancement de B2 semi-express) nomme les 7 stations :
///   Papa Guèye Fall, Place de la Nation, Grand Dakar, Sacré-Cœur, Grand Médine,
///   Dalal Jam, Préfecture de Guédiawaye. Parcelles et Liberté 6 n'en font pas
///   partie. Les 7 stations restent une sous-séquence ordonnée de B1.
/// SOURCE : https://www.rts.sn/actualite/detail/a-la-une/sunubrt-lance-la-phase-2-avec-sept-nouvelles-stations-et-la-ligne-semi-express-b2
const List<String> kBrtB27 = <String>[
  'stop_brt_23_guediawaye',
  'stop_brt_19_dalal_jamm',
  'stop_brt_13_grand_medine',
  'stop_brt_07_sacre_coeur',
  'stop_brt_05_grand_dakar',
  'stop_brt_03_obelisque',
  'stop_brt_01_petersen',
];

const String kTerRouteId = 'ter_dakar_diamniadio';
const String kBrtB1Id = 'brt_b1_guediawaye_petersen';
const String kBrtB2Id = 'brt_b2_express';

TransportRoute routeOf(DataService ds, String id) =>
    ds.routes.firstWhere((TransportRoute r) => r.id == id);

BusStop? findStop(DataService ds, String id) {
  final List<BusStop> m = ds.stops.where((BusStop s) => s.id == id).toList();
  return m.isEmpty ? null : m.first;
}

Future<DataService> loadActive() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DataService ds = DataService();
  await ds.loadNetworkData();
  expect(ds.isLoaded, true);
  // Garde : si l'asset n'était pas lu, le repli en dur donnerait 6/5.
  expect(ds.stops.length, 117, reason: 'la DONNÉE ACTIVE doit être chargée');
  return ds;
}

void main() {
  group('TER — 13 gares (§6)', () {
    test('la ligne TER compte exactement 13 gares', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kTerRouteId).stopIds.length, 13);
    });

    test('ordre exact Dakar -> Diamniadio', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kTerRouteId).stopIds, orderedEquals(kTer13));
    });

    test('ordre inverse exact Diamniadio -> Dakar', () async {
      final ds = await loadActive();
      final forward = routeOf(ds, kTerRouteId).stopIds;
      final reverse = forward.reversed.toList();
      expect(reverse.first, 'stop_diamniadio');
      expect(reverse.last, 'stop_dakar_ter');
      expect(reverse, orderedEquals(kTer13.reversed.toList()));
      // L'inversion est une bijection : mêmes gares, aucun ajout ni perte.
      expect(reverse.length, forward.length);
      expect(reverse.toSet(), forward.toSet());
    });

    test('Gare TER Keur Massar est ABSENTE du TER', () async {
      final ds = await loadActive();
      final ter = routeOf(ds, kTerRouteId);
      expect(ter.stopIds.contains('stop_keur_massar'), false);
      // Aucun nom de gare TER ne doit mentionner Keur Massar.
      for (final id in ter.stopIds) {
        final s = findStop(ds, id);
        expect(s, isNotNull, reason: 'référence TER non résolue : $id');
        expect(s!.name.toLowerCase().contains('keur massar'), false,
            reason: 'gare TER interdite par le §6 : ${s.name}');
      }
    });

    test('stop_keur_massar subsiste comme arrêt, desservi hors TER', () async {
      // Le retrait de Keur Massar porte sur le PÉRIMÈRE TER, pas sur l'arrêt :
      // la décision de l'auteur (commit gh-pages a0ae515c4d) est explicite —
      // « Keur Massar reste desservi par AFTU/DDD/TATA ».
      final ds = await loadActive();
      expect(findStop(ds, 'stop_keur_massar'), isNotNull);
      final servedBy = ds.routes
          .where((r) => r.stopIds.contains('stop_keur_massar'))
          .map((r) => r.operatorId)
          .toSet();
      expect(servedBy.contains('ter'), false);
      expect(servedBy.isNotEmpty, true);
    });

    test('Dalifort est présente', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kTerRouteId).stopIds.contains('stop_dalifort_ter'),
          true);
      expect(findStop(ds, 'stop_dalifort_ter'), isNotNull);
    });

    test('PNR est présente', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kTerRouteId).stopIds.contains('stop_pnr'), true);
      expect(findStop(ds, 'stop_pnr'), isNotNull);
    });

    test('terminus Dakar et Diamniadio', () async {
      final ds = await loadActive();
      final ter = routeOf(ds, kTerRouteId);
      expect(ter.stopIds.first, 'stop_dakar_ter');
      expect(ter.stopIds.last, 'stop_diamniadio');
    });

    test('le libellé long annonce 13 gares, pas 14', () async {
      // La donnée historique annonçait « 14 gares » pour 12 listées.
      final ds = await loadActive();
      final ln = routeOf(ds, kTerRouteId).longName;
      expect(ln.contains('13 gares'), true, reason: ln);
      expect(ln.contains('14 gares'), false, reason: ln);
    });
  });

  group('BRT — 23 stations (§7)', () {
    test('B1 compte exactement 23 stations', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kBrtB1Id).stopIds.length, 23);
    });

    test('ordre exact Guédiawaye -> Petersen', () async {
      final ds = await loadActive();
      expect(routeOf(ds, kBrtB1Id).stopIds, orderedEquals(kBrtB123));
    });

    test('ordre inverse exact Petersen -> Guédiawaye', () async {
      final ds = await loadActive();
      final forward = routeOf(ds, kBrtB1Id).stopIds;
      final reverse = forward.reversed.toList();
      expect(reverse.first, 'stop_brt_01_petersen');
      expect(reverse.last, 'stop_brt_23_guediawaye');
      expect(reverse, orderedEquals(kBrtB123.reversed.toList()));
      expect(reverse.toSet(), forward.toSet());
    });

    test('B2 Express compte 7 stations, toutes incluses dans B1', () async {
      final ds = await loadActive();
      final b2 = routeOf(ds, kBrtB2Id).stopIds;
      expect(b2, orderedEquals(kBrtB27));
      expect(b2.length, 7);
      final b1 = routeOf(ds, kBrtB1Id).stopIds.toSet();
      for (final id in b2) {
        expect(b1.contains(id), true, reason: '$id absente de B1');
      }
    });

    test('le modèle historique de 11/12 stations n est PAS la source', () async {
      // Garde-fou du §7 : ne jamais réintroduire l'ancien corridor.
      final ds = await loadActive();
      final b1 = routeOf(ds, kBrtB1Id);
      expect(b1.stopIds.length, isNot(11));
      expect(b1.stopIds.length, isNot(12));
      // L'ancien espace d'identifiants n'est plus celui du corridor BRT.
      for (final legacy in <String>[
        'stop_guediawaye',
        'stop_parcelles_u26',
        'stop_petersen',
        'stop_liberte6',
        'stop_sacre_coeur',
        'stop_obelisque'
      ]) {
        expect(b1.stopIds.contains(legacy), false,
            reason: 'identifiant historique réintroduit dans B1 : $legacy');
      }
      // Le corridor actif utilise l'espace numéroté stop_brt_NN_*.
      expect(b1.stopIds.every((id) => id.startsWith('stop_brt_')), true);
    });

    test('le libellé long de B1 annonce 23 stations, pas 14 km', () async {
      final ds = await loadActive();
      final ln = routeOf(ds, kBrtB1Id).longName;
      expect(ln.contains('23 stations'), true, reason: ln);
      expect(ln.contains('14km'), false, reason: ln);
    });
  });

  group('Intégrité du réseau actif', () {
    test('toutes les références d arrêt de toutes les lignes existent',
        () async {
      final ds = await loadActive();
      final ids = ds.stops.map((s) => s.id).toSet();
      for (final r in ds.routes) {
        for (final sid in r.stopIds) {
          expect(ids.contains(sid), true,
              reason: 'ligne ${r.id} référence un arrêt inexistant : $sid');
        }
      }
    });

    test('identifiants d arrêt et de ligne uniques', () async {
      final ds = await loadActive();
      expect(ds.stops.map((s) => s.id).toSet().length, ds.stops.length);
      expect(ds.routes.map((r) => r.id).toSet().length, ds.routes.length);
    });

    test('tous les arrêts actifs valident DakarBounds', () async {
      // C'est le test qui aurait rougi avec les bornes historiques : 4 arrêts
      // actifs étaient rejetés, dont 3 gares TER.
      final ds = await loadActive();
      for (final s in ds.stops) {
        expect(DakarBounds.isValid(LatLng(s.latitude, s.longitude)), true,
            reason:
                'arrêt actif rejeté par DakarBounds : ${s.id} (${s.latitude}, ${s.longitude})');
      }
    });

    test('aucun arrêt actif n est à (0,0)', () async {
      final ds = await loadActive();
      for (final s in ds.stops) {
        expect(s.latitude == 0.0 && s.longitude == 0.0, false,
            reason: 'arrêt sans coordonnées : ${s.id}');
      }
    });

    test('les 13 gares TER valident DakarBounds', () async {
      final ds = await loadActive();
      for (final id in kTer13) {
        final s = findStop(ds, id);
        expect(s, isNotNull, reason: 'gare TER introuvable : $id');
        expect(DakarBounds.isValid(LatLng(s!.latitude, s.longitude)), true,
            reason: 'gare TER rejetée par DakarBounds : $id');
      }
    });

    test('les 23 stations BRT valident DakarBounds', () async {
      final ds = await loadActive();
      for (final id in kBrtB123) {
        final s = findStop(ds, id);
        expect(s, isNotNull, reason: 'station BRT introuvable : $id');
        expect(DakarBounds.isValid(LatLng(s!.latitude, s.longitude)), true,
            reason: 'station BRT rejetée par DakarBounds : $id');
      }
    });

    test('data_trust des arrêts actifs connu du modèle', () async {
      // AUDIT DONNÉES 2026-09-24.
      // AVANT : le modèle ne connaissait que OFFICIAL, FIELD_OBSERVATION et
      //         ESTIMATED.
      // APRÈS : UNVERIFIED est ajouté à l'enum DataTrust.
      // RAISON : 20 arrêts étaient marqués OFFICIAL sans aucune source. Les
      //         laisser OFFICIAL serait faux ; les passer en ESTIMATED aussi
      //         (ce ne sont pas des estimations). L'intention du test —
      //         aucune valeur de data_trust ignorée par le modèle — est
      //         conservée ; seule la liste des valeurs connues s'allonge.
      final ds = await loadActive();
      for (final s in ds.stops) {
        expect(
          s.dataTrust == DataTrust.official ||
              s.dataTrust == DataTrust.fieldObservation ||
              s.dataTrust == DataTrust.estimated ||
              s.dataTrust == DataTrust.unverified,
          true,
          reason: 'data_trust non pris en charge pour ${s.id}',
        );
      }
    });
  });
}
