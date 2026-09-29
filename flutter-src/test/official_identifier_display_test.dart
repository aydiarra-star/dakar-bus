// LOT 3 — IDENTIFIANTS OFFICIELS DES LIGNES (restitution).
//
// `official_identifier_status` existe dans `dakar_network.json` sur 22 routes
// Tata/DDD (15 CONFLICTING, 7 MISSING) et leurs trois champs compagnons. Ces
// métadonnées étaient parsées nulle part : l'application présentait donc le
// `short_name` d'une ligne contestée comme un numéro établi.
//
// Ces tests vérifient que le verdict est (a) lu depuis la source, (b) porté
// jusqu'à la fiche de ligne, (c) restitué en avertissement quand il est
// CONFLICTING ou MISSING, et jamais inventé pour les autres lignes.
import 'dart:convert';
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/reliability.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load() =>
    json.decode(File('assets/data/dakar_network.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, dynamic> data = _load();
  final List<Map<String, dynamic>> routes =
      (data['routes'] as List).cast<Map<String, dynamic>>();

  group('official_identifier_status — source', () {
    test('22 routes portent le verdict : 15 CONFLICTING, 7 MISSING', () {
      final List<Map<String, dynamic>> withStatus = routes
          .where((Map<String, dynamic> r) => r['official_identifier_status'] != null)
          .toList();
      expect(withStatus, hasLength(22));
      final Map<String, int> byStatus = <String, int>{};
      for (final Map<String, dynamic> r in withStatus) {
        final String k = r['official_identifier_status'] as String;
        byStatus[k] = (byStatus[k] ?? 0) + 1;
      }
      expect(byStatus['CONFLICTING'], 15);
      expect(byStatus['MISSING'], 7);
      expect(byStatus.containsKey('CONFIRMED'), isFalse);
    });

    test('chaque verdict porte une note non vide et le champ observé', () {
      for (final Map<String, dynamic> r in routes) {
        if (r['official_identifier_status'] == null) continue;
        expect((r['official_identifier_note'] as String?)?.trim(), isNotEmpty,
            reason: '${r['id']}');
        expect(r['official_number_observed'], isA<bool>(), reason: '${r['id']}');
      }
    });

    test('une ligne dont le numéro appartient à un autre opérateur est CONFLICTING',
        () {
      for (final Map<String, dynamic> r in routes) {
        final String? belongs = r['official_number_belongs_to'] as String?;
        if (belongs != null) {
          expect(r['official_identifier_status'], 'CONFLICTING',
              reason: '${r['id']} → $belongs');
        }
      }
    });
  });

  group('official_identifier_status — modèle Dart', () {
    test('verdict relu fidèlement, statut inconnu jamais promu CONFIRMED', () {
      final TransportRoute tata218 = TransportRoute.fromJson(
          routes.firstWhere((Map<String, dynamic> r) => r['id'] == 'tata_218'));
      expect(tata218.officialIdentifierStatus, OfficialIdentifierStatus.conflicting);
      expect(tata218.officialNumberObserved, isTrue);
      expect(tata218.officialNumberBelongsTo, 'DDD');
      expect(tata218.hasConfirmedOfficialIdentifier, isFalse);

      final TransportRoute ddd14 = TransportRoute.fromJson(
          routes.firstWhere((Map<String, dynamic> r) => r['id'] == 'ddd_14'));
      expect(ddd14.officialIdentifierStatus, OfficialIdentifierStatus.missing);
      expect(ddd14.officialNumberObserved, isFalse);
      expect(ddd14.officialNumberBelongsTo, isNull);
    });

    test('une route sans verdict lit UNKNOWN, jamais CONFIRMED', () {
      final Map<String, dynamic> ter = routes
          .firstWhere((Map<String, dynamic> r) => r['id'] == 'ter_dakar_diamniadio');
      final TransportRoute t = TransportRoute.fromJson(ter);
      expect(t.officialIdentifierStatus, OfficialIdentifierStatus.unknown);
      expect(t.hasConfirmedOfficialIdentifier, isFalse);
    });

    test('fromString : valeur inconnue → UNKNOWN', () {
      expect(OfficialIdentifierStatusLabel.fromString('PEUT_ETRE'),
          OfficialIdentifierStatus.unknown);
      expect(OfficialIdentifierStatusLabel.fromString(null),
          OfficialIdentifierStatus.unknown);
      expect(OfficialIdentifierStatusLabel.fromString('CONFLICTING'),
          OfficialIdentifierStatus.conflicting);
    });

    test('aller-retour toJson conserve les quatre champs', () {
      final Map<String, dynamic> src =
          routes.firstWhere((Map<String, dynamic> r) => r['id'] == 'tata_219');
      final TransportRoute t = TransportRoute.fromJson(src);
      final Map<String, dynamic> back = t.toJson();
      expect(back['official_identifier_status'], src['official_identifier_status']);
      expect(back['official_identifier_note'], src['official_identifier_note']);
      expect(back['official_number_observed'], src['official_number_observed']);
      expect(back['official_number_belongs_to'], src['official_number_belongs_to']);
    });
  });

  group('official_identifier_status — restitution', () {
    test('libellé : CONFLICTING et MISSING en ont un, CONFIRMED/UNKNOWN non', () {
      expect(
          ReliabilityLabel.officialIdentifierLabel(OfficialIdentifierStatus.conflicting),
          isNotNull);
      expect(ReliabilityLabel.officialIdentifierLabel(OfficialIdentifierStatus.missing),
          isNotNull);
      expect(ReliabilityLabel.officialIdentifierLabel(OfficialIdentifierStatus.confirmed),
          isNull);
      expect(ReliabilityLabel.officialIdentifierLabel(OfficialIdentifierStatus.unknown),
          isNull);
    });

    test('une fiche de ligne Tata contestée expose l\'avertissement', () async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      // `stop_mermoz` est desservi par tata_218 (CONFLICTING) et d'autres lignes.
      // On résout directement la fiche par la route Tata via fromOperator.
      final DetailedRoute? r = DetailedRoute.fromOperator('tata');
      expect(r, isNotNull);
      expect(r!.officialIdentifierStatus, OfficialIdentifierStatus.conflicting);
      expect(r.identifierWarning, isNotNull);
      expect(r.integrityWarnings, contains(r.identifierWarning));
    });

    test('le TER (aucun verdict) n\'expose aucun avertissement d\'identifiant', () async {
      if (!appDataService.isLoaded) await appDataService.loadNetworkData();
      integrateNetworkDataForTest();

      final DetailedRoute? r = DetailedRoute.fromOperator('ter');
      expect(r, isNotNull);
      expect(r!.officialIdentifierStatus, OfficialIdentifierStatus.unknown);
      expect(r.identifierWarning, isNull);
      expect(r.integrityWarnings, isEmpty);
    });
  });
}
