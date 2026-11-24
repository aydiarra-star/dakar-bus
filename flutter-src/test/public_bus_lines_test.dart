// MISSION — RÉFÉRENTIEL PUBLIC DES LIGNES AFTU / TATA / DDD.
//
// Preuve que le référentiel public expose de VRAIES lignes numérotées, que le
// numéro public n'est jamais déduit d'un identifiant de feed, que les identités
// Tata ne deviennent jamais des lignes, et que le raccordement horaire pointe
// vers des routes réellement présentes dans les feeds.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/main.dart' as app;
import 'package:dakar_bus/models/public_bus_line.dart';
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

  group('AFTU — routes présentes mais sans horaires exploitables', () {
    test('AFTU 47 et 52 restent bloquées sans faux horaires', () {
      final List<PublicBusLine> aftu =
          app.appDataService.publicBusLineCatalog.reference!.aftu;
      const Map<String, String> expectedReasons = <String, String>{
        '47': 'FEED_ROUTE_WITHOUT_TRIP',
        '52': 'FEED_ROUTE_WITHOUT_STOP_TIME',
      };
      for (final entry in expectedReasons.entries) {
        final PublicBusLine line =
            aftu.singleWhere((l) => l.lineNumber == entry.key);
        expect(line.mappingStatus, LineMappingStatus.blocked);
        expect(line.feedRouteIds, <String>['AFTU_${entry.key}']);
        expect(line.scheduleStatus, 'NO_SCHEDULE');
        expect(line.hasRealSchedule, isFalse);
        expect(line.stopTimesCount, 0);
        expect(line.servedStopCount, 0);
        expect(line.blocking, isNotNull);
        expect(line.blocking!.reason, entry.value);
      }
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

    test('les identités DDD confirmées le 24 novembre restent distinctes et non fusionnées', () {
      // Vérification officielle des identités publiques : cela ne prouve pas
      // leur correspondance avec un route_id PassBi. Les variantes A/B restent
      // séparées et sans horaire tant que le feed ne distingue pas ces services.
      const Map<String, List<String>> expected = <String, List<String>>{
        '502A': <String>['COLOBANE', 'UCAD'],
        '502B': <String>['COLOBANE', 'ABASS NDAO'],
        '503A': <String>['COLOBANE', 'MOLE 8'],
        '503B': <String>['COLOBANE', 'HYDROCARBURE'],
        '504A': <String>['GARE DIAMNIADIO', 'SPHERE MINISTERIEL'],
        '504B': <String>['SEBIKOTANE', 'GARE DIAMNIADIO'],
        '15A': <String>['RUFISQUE', 'PALAIS 1'],
        '15B': <String>['RUFISQUE', 'PALAIS 1'],
        '16A': <String>['MALIKA', 'PALAIS 1'],
        '16B': <String>['MALIKA', 'PALAIS 1'],
        '327': <String>['KEUR MASSAR', 'TERMINUS PARCELLES'],
        'TO1': <String>['TAF TAF OUAKAM (TO1) : OUAKAM', 'PALAIS 2'],
      };
      final List<PublicBusLine> ddd =
          app.appDataService.publicBusLineCatalog.reference!.ddd;
      for (final entry in expected.entries) {
        final PublicBusLine line =
            ddd.singleWhere((l) => l.lineNumber == entry.key);
        expect(line.identityStatus, 'CONFIRMED',
            reason: '${line.publicLabel} : identité officielle perdue');
        expect(line.origin, entry.value[0],
            reason: '${line.publicLabel} : origine officielle modifiée');
        expect(line.destination, entry.value[1],
            reason: '${line.publicLabel} : destination officielle modifiée');
        expect(line.mappingStatus, isNot(LineMappingStatus.connected),
            reason: '${line.publicLabel} : raccordement sans preuve PassBi');
        expect(line.feedRouteIds, isEmpty);
        expect(line.hasRealSchedule, isFalse);
      }
    });

    test('les quatre routes DDD mono-directionnelles ne gagnent pas un sens fictif',
        () {
      // Baseline issue des trips du feed : ces routes ne publient chacune
      // qu'un seul direction_id. Ne jamais fabriquer un aller/retour à partir
      // de l'identifiant 0/1 ni du numéro public.
      const Map<String, String> expected = <String, String>{
        '18': '1',
        '20': '0',
        '502': '0',
        '503': '1',
      };
      final List<PublicBusLine> ddd =
          app.appDataService.publicBusLineCatalog.reference!.ddd;
      for (final entry in expected.entries) {
        final PublicBusLine line =
            ddd.singleWhere((l) => l.lineNumber == entry.key);
        expect(line.mappingStatus, LineMappingStatus.connected,
            reason: '${line.publicLabel} doit conserver son raccordement réel');
        expect(line.feedRouteIds, <String>['DDD_${entry.key}']);
        expect(line.directionIds, <String>[entry.value],
            reason: '${line.publicLabel} : ne pas inventer une deuxième direction');
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
        // Départ EXPLOITABLE : ≥ 2 arrêts → au moins un prochain départ
        // calculable. Une ligne CONNECTED mono-arrêt ne serait pas exploitable.
        expect(l.servedStopCount, greaterThanOrEqualTo(2),
            reason: '${l.publicLabel} : aucun départ exploitable (< 2 arrêts)');
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

    // PORTE DE RACCORDEMENT HONNÊTE (§6 / §15 / §19) — une ligne publique
    // OFFICIELLEMENT PUBLIÉE mais non raccordable au feed actuel reste
    // explicitement non raccordée : c'est un état honnête, pas un échec. Ce qui
    // échoue, c'est FABRIQUER un raccordement pour atteindre 100 %. On vérifie
    // donc que la baseline des 16 identités non raccordables reste honnête
    // (présente, non CONNECTED, sans faux horaire) — et jamais « 100 % » obtenu
    // par invention.
    test('les 20 routes PassBi sans identité publique restent hors catalogue', () {
      // Audit du feed : 19 routes DDD et AFTU_90 n'ont pas de correspondance
      // publique prouvée. Elles restent consignées en audit, jamais exposées
      // comme lignes voyageurs et jamais rattachées par simple numéro.
      final Map<String, int> counts =
          app.appDataService.publicBusLineCatalog.reference!.counts;
      expect(counts['feed_routes_without_public_line'], 20);
      expect(counts['ddd_public'], 48);
      expect(counts['aftu_official'], 72);
      expect(counts['connected'], 104);
      expect(counts['unresolved'], 16);
    });

    test('les 16 identités publiées non raccordables restent honnêtes', () {
      const List<String> baseline = <String>[
        'AFTU 47', 'AFTU 52',
        'DDD 502A', 'DDD 502B', 'DDD 503A', 'DDD 503B', 'DDD 504A', 'DDD 504B',
        'DDD TO1', 'DDD TAF', 'DDD TAF TAF', 'DDD 15A', 'DDD 15B',
        'DDD 16A', 'DDD 16B', 'DDD 327',
      ];
      final List<PublicBusLine> all =
          app.appDataService.publicBusLineCatalog.publicLines;
      final Map<String, PublicBusLine> byLabel = <String, PublicBusLine>{
        for (final PublicBusLine l in all) l.publicLabel: l,
      };
      for (final String label in baseline) {
        final PublicBusLine? l = byLabel[label];
        expect(l, isNotNull, reason: '$label : identité publique supprimée');
        expect(l!.mappingStatus, isNot(LineMappingStatus.connected),
            reason: '$label : CONNECTED sans preuve opérationnelle nouvelle');
        expect(l.hasRealSchedule, isFalse, reason: '$label : faux horaire');
        expect(l.scheduleStatus, 'NO_SCHEDULE', reason: '$label : faux horaire');
        expect(l.servedStopCount, 0, reason: '$label : arrêts sans horaire');
        expect(l.stopTimesCount, 0, reason: '$label : stop_times sans horaire');
        expect(l.unresolvedReason, isNotNull, reason: '$label : cause absente');
        expect(l.blocking, isNotNull, reason: '$label : preuve de blocage absente');
      }
      expect(
          app.appDataService.publicBusLineCatalog.reference!
              .unresolvedPublicLines.length,
          baseline.length,
          reason: 'la liste des lignes non raccordées a changé sans preuve');
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

  group('Identité publique ↔ route PassBi — preuve indépendante', () {
    test('seules les identités du registre de preuves sont VERIFIED', () {
      final lines = app.appDataService.publicBusLineCatalog.publicLines;
      expect(lines, hasLength(120));
      final verified = lines.where((l) => l.hasVerifiedFeedIdentity).toList();
      expect(verified, hasLength(25));
      expect(lines.where((l) => l.feedRouteIdentityStatus == 'UNVERIFIED'),
          hasLength(95));
      for (final line in lines) {
        if (line.hasVerifiedFeedIdentity) {
          expect(line.feedRouteIdentityProof, startsWith(
              'data/reference/passbi_route_identity_proofs.json#'));
          expect(line.feedRouteIds, hasLength(1));
        } else {
          expect(line.feedRouteIdentityStatus, 'UNVERIFIED',
              reason: '${line.publicLabel} : preuve indépendante absente');
          expect(line.feedRouteIdentityProof, isNull);
        }
      }
    });

    test('un raccordement horaire non prouvé ne reçoit aucun libellé public', () {
      expect(
        app.appDataService.publicBusLineCatalog.publicLabelForFeedRouteId('AFTU_46'),
        isNull,
      );
      expect(
        app.appDataService.publicBusLineCatalog.publicLabelForFeedRouteId('DDD_502'),
        isNull,
      );
      expect(
        app.appDataService.publicBusLineCatalog.publicLabelForFeedRouteId('AFTU_62'),
        'AFTU 62',
      );
    });

    test('la recherche ne transmet un route_id qu’avec une identité vérifiée', () {
      final entries = NetworkSearchCatalogBuilder.fromPublicLines(
          app.appDataService.publicBusLineCatalog.publicLines);
      NetworkSearchEntry line(String label) => entries.singleWhere(
          (e) => e.kind == NetworkSearchKind.line && e.label == label);
      expect(line('AFTU 62').routeId, 'AFTU_62');
      expect(line('AFTU 46').routeId, isNull);
      expect(line('DDD 502').routeId, isNull);
    });

    test('une ligne vérifiée expose ses vrais arrêts PassBi', () {
      final PublicBusLine line = app.appDataService.publicBusLineCatalog.publicLines
          .singleWhere((l) => l.publicLabel == 'AFTU 62');
      expect(line.hasRealSchedule, isTrue);
      expect(line.hasVerifiedFeedIdentity, isTrue);
      final sequence = app.appDataService.publicLineStopSequence(line);
      expect(sequence, isNotNull);
      expect(sequence!.stops, isNotEmpty);
      expect(sequence.routeId, 'AFTU_62');
    });

    test('les horaires techniques restent présents sans attribution publique', () {
      final PublicBusLine line = app.appDataService.publicBusLineCatalog.publicLines
          .singleWhere((l) => l.publicLabel == 'DDD 502');
      expect(line.hasRealSchedule, isTrue,
          reason: 'la disponibilité horaire PassBi ne doit pas être supprimée');
      expect(line.feedRouteIds, <String>['DDD_502']);
      final summary = app.appDataService.passBiSource.routeSummary('DDD', 'DDD_502');
      expect(summary, isNotNull);
      expect(summary!.servedStops, greaterThan(0));
      expect(app.appDataService.publicLineStopSequence(line), isNull,
          reason: 'les arrêts ne doivent pas être attribués à DDD 502 sans preuve d’identité');
    });

    test('une ligne non raccordée n’a AUCUNE fiche d’arrêts fabriquée', () {
      for (final l in app.appDataService.publicBusLineCatalog.reference!
          .unresolvedPublicLines) {
        expect(app.appDataService.publicLineStopSequence(l), isNull,
            reason: '${l.publicLabel} : fiche fabriquée pour une ligne non raccordée');
      }
    });
  });

  group('Sens des lignes publiques — aucun aller/retour déduit du chiffre', () {
    test('les terminus exacts du trip déterminent aller et retour', () {
      expect(
        publicDirectionLabel(
          directionId: '0',
          firstStopName: 'Petersen',
          lastStopName: 'Rufisque',
          origin: 'Petersen',
          destination: 'Rufisque',
        ),
        'Aller',
      );
      expect(
        publicDirectionLabel(
          directionId: '1',
          firstStopName: 'Rufisque',
          lastStopName: 'Petersen',
          origin: 'Petersen',
          destination: 'Rufisque',
        ),
        'Retour',
      );
    });

    test('un direction_id sans preuve d’orientation reste un sens neutre', () {
      expect(
        publicDirectionLabel(
          directionId: '0',
          firstStopName: 'Gare A',
          lastStopName: 'Gare B',
          origin: 'Petersen',
          destination: 'Rufisque',
        ),
        'Sens 0',
      );
      expect(
        publicDirectionLabel(
          directionId: '1',
          firstStopName: 'Gare B',
          lastStopName: 'Gare A',
          origin: 'NON PUBLIÉE',
          destination: 'NON PUBLIÉE',
        ),
        'Sens 1',
      );
    });
  });
}
