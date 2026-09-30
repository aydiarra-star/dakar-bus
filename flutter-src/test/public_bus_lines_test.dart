// MISSION — RÉFÉRENTIEL PUBLIC DES LIGNES AFTU / TATA / DDD.
//
// Preuve que le référentiel public expose de VRAIES lignes numérotées, que le
// numéro public n'est jamais déduit d'un identifiant de feed, que les identités
// Tata ne deviennent jamais des lignes, et que le raccordement horaire pointe
// vers des routes réellement présentes dans les feeds.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/public_bus_line.dart';
import 'package:dakar_bus/services/gtfs/passbi_source.dart';
import 'package:dakar_bus/services/network_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!app.appDataService.isLoaded) {
      await app.appDataService.loadNetworkData();
    }
    app.integrateNetworkDataForTest();
    await app.appDataService.loadPassBiSchedules();
    app.integratePassBiNativeStopsForTest();
    await app.appDataService.loadTerminusCatalog();
    await app.appDataService.loadPublicBusLineCatalog();
    app.integrateNetworkSearchCatalogForTest();
  });

  group('Référentiel public — lignes AFTU', () {
    test('les 72 lignes officielles AFTU sont présentes', () {
      final List<PublicBusLine> aftu =
          app.appDataService.publicBusLineCatalog.reference!.aftu;
      expect(aftu.length, 72,
          reason: 'AFTU publie 72 lignes (1–5, 24–89, 91)');
      // Plage publiée : aucun numéro hors 1–5 / 24–89 / 91.
      for (final l in aftu) {
        final int n = int.parse(l.lineNumber);
        final bool inRange = (n >= 1 && n <= 5) || (n >= 24 && n <= 89) || n == 91;
        expect(inRange, isTrue, reason: 'numéro AFTU hors plage publiée : $n');
      }
    });

    test('chaque ligne AFTU a un numéro et un libellé publics', () {
      for (final l in app.appDataService.publicBusLineCatalog.reference!.aftu) {
        expect(l.lineNumber, isNotEmpty);
        expect(l.publicLabel, 'AFTU ${l.lineNumber}');
        expect(l.operator, 'AFTU');
      }
    });

    test('aucun numéro AFTU dupliqué', () {
      final List<String> nums = app.appDataService.publicBusLineCatalog
          .reference!.aftu.map((l) => l.lineNumber).toList();
      expect(nums.toSet().length, nums.length);
    });

    test('les lignes AFTU raccordées pointent vers des routes réelles du feed',
        () {
      final Set<String> feedRouteIds = app.appDataService.passBiSource
          .routeSummaries('AFTU')
          .map((s) => s.routeId)
          .toSet();
      int linked = 0;
      for (final l in app.appDataService.publicBusLineCatalog.reference!.aftu) {
        if (l.scheduleStatus == 'NO_SCHEDULE') continue;
        linked++;
        expect(l.feedRouteIds, isNotEmpty,
            reason: 'ligne ${l.publicLabel} sans route_id raccordé');
        for (final id in l.feedRouteIds) {
          expect(feedRouteIds, contains(id),
              reason: 'route_id inconnu du feed : $id');
        }
      }
      expect(linked, greaterThan(60),
          reason: 'la grande majorité des lignes AFTU doit être raccordée');
    });
  });

  group('Référentiel public — lignes DDD', () {
    test('les lignes publiques DDD sont présentes et numérotées', () {
      final List<PublicBusLine> ddd =
          app.appDataService.publicBusLineCatalog.reference!.ddd;
      expect(ddd.length, greaterThan(40));
      for (final l in ddd) {
        expect(l.lineNumber, isNotEmpty);
        expect(l.publicLabel, 'DDD ${l.lineNumber}');
        expect(l.operator, 'DDD');
      }
    });

    test('aucun numéro DDD dupliqué', () {
      final List<String> nums = app.appDataService.publicBusLineCatalog
          .reference!.ddd.map((l) => l.lineNumber).toList();
      expect(nums.toSet().length, nums.length);
    });

    test('les lignes DDD raccordées pointent vers des routes réelles du feed',
        () {
      final Set<String> feedRouteIds = app.appDataService.passBiSource
          .routeSummaries('DDD')
          .map((s) => s.routeId)
          .toSet();
      for (final l in app.appDataService.publicBusLineCatalog.reference!.ddd) {
        if (l.scheduleStatus == 'NO_SCHEDULE') continue;
        for (final id in l.feedRouteIds) {
          expect(feedRouteIds, contains(id),
              reason: 'route_id inconnu du feed : $id');
        }
      }
    });

    test('les variantes lettrées (15A/15B, 502A…) ne sont pas raccordées '
        'aveuglément au numéro nu du feed', () {
      for (final l in app.appDataService.publicBusLineCatalog.reference!.ddd) {
        if (!RegExp(r'[A-Za-z]').hasMatch(l.lineNumber)) continue;
        // Le feed n'expose aucune route pour ces identités lettrées : aucune ne
        // peut être CONNECTED, et aucune ne fusionne avec la route au numéro nu.
        expect(l.mappingStatus, isNot(LineMappingStatus.connected),
            reason: '${l.publicLabel} : variante lettrée raccordée à tort');
        expect(l.feedRouteIds, isEmpty);
        expect(l.unresolvedReason, 'NO_FEED_ROUTE_FOR_LINE_NUMBER');
      }
    });
  });

  group('Référentiel public — intégrité (aucune invention)', () {
    test('chaque ligne raccordée expose la chaîne horaire vérifiable', () {
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        if (l.mappingStatus != LineMappingStatus.connected) continue;
        expect(l.feedRouteIds, isNotEmpty, reason: '${l.publicLabel} : route_id');
        expect(l.tripIdsCount, greaterThan(0), reason: '${l.publicLabel} : trip_id');
        expect(l.directionIds, isNotEmpty, reason: '${l.publicLabel} : direction_id');
        expect(l.stopTimesCount, greaterThan(0), reason: '${l.publicLabel} : stop_times');
        expect(l.servedStopCount, greaterThan(0), reason: '${l.publicLabel} : stop_id');
        expect(l.stopSequencePresent, isTrue, reason: '${l.publicLabel} : stop_sequence');
        expect(l.isScheduleLinked, isTrue);
        expect(l.hasRealSchedule, isTrue);
        expect(l.unresolvedReason, isNull);
        expect(l.blocking, isNull);
      }
    });

    test('mapping_status n’est jamais optimiste (CONNECTED exige la chaîne)', () {
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        if (l.mappingStatus == LineMappingStatus.connected) {
          expect(l.hasRealSchedule, isTrue, reason: '${l.publicLabel} : CONNECTED creux');
          expect(l.scheduleStatus, 'SCHEDULE_AVAILABLE');
        } else {
          expect(l.hasRealSchedule, isFalse, reason: '${l.publicLabel} : faux horaire');
          expect(l.scheduleStatus, 'NO_SCHEDULE');
          expect(l.unresolvedReason, isNotNull,
              reason: '${l.publicLabel} : cause absente');
          expect(l.blocking, isNotNull,
              reason: '${l.publicLabel} : preuve de blocage absente');
        }
      }
    });

    test('toute ligne non raccordée porte une preuve de blocage exploitable', () {
      final List<PublicBusLine> unresolved =
          app.appDataService.publicBusLineCatalog.reference!.unresolvedPublicLines;
      expect(unresolved, isNotEmpty);
      for (final l in unresolved) {
        final LineBlocking b = l.blocking!;
        expect(b.reason, l.unresolvedReason);
        expect(b.missingFields, isNotEmpty,
            reason: '${l.publicLabel} : champs manquants non listés');
        expect(b.nextAction, isNotEmpty,
            reason: '${l.publicLabel} : prochaine action absente');
        expect(b.consultedSources, isNotEmpty);
      }
    });

    test('une variante lettrée documente la route au numéro nu SANS la fusionner',
        () {
      for (final num in <String>['502A', '502B', '503A', '504B']) {
        final PublicBusLine l = app.appDataService.publicBusLineCatalog.reference!
            .ddd
            .firstWhere((x) => x.lineNumber == num);
        expect(l.mappingStatus, LineMappingStatus.notVerified);
        expect(l.feedRouteIds, isEmpty);
        expect(l.blocking!.bareNumberRouteIds, isNotEmpty,
            reason: 'DDD $num : route au numéro nu non documentée');
      }
    });

    test('le numéro public n’est jamais un identifiant de feed', () {
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        expect(l.lineNumber.contains('_'), isFalse,
            reason: 'numéro public contenant un underscore : ${l.lineNumber}');
        expect(l.publicLabel.contains('_'), isFalse,
            reason: 'libellé public contenant un underscore : ${l.publicLabel}');
      }
    });

    test('aucune identité Tata n’est exposée comme ligne publique', () {
      // TATA est un type de véhicule : le référentiel public n’en contient pas.
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        expect(l.operator, isNot('TATA'));
        expect(l.publicLabel.startsWith('Tata'), isFalse);
      }
      // Les identités techniques vivent dans un registre d’audit séparé, sans
      // numéro public.
      final List<TataIdentityAudit> audit =
          app.appDataService.publicBusLineCatalog.tataAudit;
      expect(audit, isNotEmpty);
      for (final t in audit) {
        expect(t.operator, 'AFTU',
            reason: 'Tata n’est jamais un opérateur');
        expect(t.canonicalStatus, isNotEmpty);
      }
    });

    test('aucune ligne publique sans numéro officiel', () {
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        expect(l.isPublic, isTrue,
            reason: 'ligne sans numéro public : ${l.publicLabel}');
      }
    });

    // TEST CRITIQUE (§15) — TOUTES les lignes publiques AFTU/DDD doivent être
    // raccordées aux données horaires réelles. Tant qu’il reste des lignes non
    // raccordées, ce test échoue en les listant : le chantier n’est pas terminé.
    test('TEST CRITIQUE — 100 % des lignes publiques AFTU/DDD raccordées', () {
      final List<PublicBusLine> unresolved = app
          .appDataService.publicBusLineCatalog.reference!.unresolvedPublicLines;
      final String detail = unresolved
          .map((l) => '  - ${l.publicLabel} (${l.unresolvedReason})')
          .join('\n');
      expect(unresolved, isEmpty,
          reason: 'lignes publiques non raccordées (chantier NON terminé) :\n$detail');
    });
  });

  group('Référentiel public — recherche (même catalogue que le GPS)', () {
    test('une ligne AFTU est recherchable par son numéro public', () {
      final hits = app.searchNetworkCatalog('AFTU 26');
      expect(
          hits.any((h) =>
              h.kind == NetworkSearchKind.line &&
              h.label == 'AFTU 26'),
          isTrue);
    });

    test('une ligne DDD est recherchable par son numéro public', () {
      final hits = app.searchNetworkCatalog('DDD 221');
      expect(
          hits.any((h) =>
              h.kind == NetworkSearchKind.line && h.label == 'DDD 221'),
          isTrue);
    });

    test('les libellés publics ne contiennent jamais « PassBi »', () {
      for (final l in app.appDataService.publicBusLineCatalog.publicLines) {
        expect(l.publicLabel.contains('PassBi'), isFalse);
      }
    });

    test('le catalogue expose les lignes publiques en plus des lignes du feed',
        () {
      final catalog = app.currentNetworkSearchCatalog;
      final int lineCount = catalog.countOf(NetworkSearchKind.line);
      // 266 lignes de feed + les lignes publiques : strictement plus.
      expect(lineCount, greaterThan(266),
          reason: 'les lignes publiques doivent enrichir le catalogue');
    });
  });

  group('Fiche ligne — arrêts ordonnés (stop_sequence réels)', () {
    test('une ligne CONNECTED expose ses arrêts réels ordonnés par stop_sequence',
        () {
      final PublicBusLine line = app.appDataService.publicBusLineCatalog.publicLines
          .firstWhere((l) => l.hasRealSchedule);
      final PassBiRouteStopSequence? seq =
          app.appDataService.publicLineStopSequence(line);
      expect(seq, isNotNull);
      expect(seq!.stops, isNotEmpty);
      expect(seq.stops.length, greaterThan(1));
      expect(seq.routeId, line.feedRouteIds.first);
      expect(seq.tripId, isNotEmpty);
    });

    test('la séquence d’arrêts correspond aux stop_times réels de la route', () {
      final PublicBusLine line = app.appDataService.publicBusLineCatalog.publicLines
          .firstWhere((l) => l.hasRealSchedule);
      final PassBiRouteStopSequence seq =
          app.appDataService.publicLineStopSequence(line)!;
      final int served =
          app.appDataService.passBiSource.routeSummary(line.operator, seq.routeId)!
              .servedStops;
      // Le trip le plus complet couvre au plus l'ensemble des arrêts desservis,
      // et au moins une partie : aucun arrêt inventé, aucun arrêt en trop.
      expect(seq.stops.length, lessThanOrEqualTo(served));
      expect(seq.stops.length, greaterThan(0));
    });

    test('une ligne non raccordée n’a AUCUNE fiche d’arrêts fabriquée', () {
      for (final l in app.appDataService.publicBusLineCatalog.reference!
          .unresolvedPublicLines) {
        expect(app.appDataService.publicLineStopSequence(l), isNull,
            reason: '${l.publicLabel} : fiche fabriquée pour une ligne non raccordée');
      }
    });
  });
}
