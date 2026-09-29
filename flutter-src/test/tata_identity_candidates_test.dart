// CHANTIER TATA — PR #48, lot 2.
//
// Preuve que TATA est traité comme TYPE DE VÉHICULE (jamais opérateur/réseau),
// que les correspondances de la liste secondaire restent des CANDIDATS (jamais
// des lignes confirmées), et qu'aucune identité n'est déduite d'un identifiant
// interne.
//
// Aucune donnée horaire n'est touchée : ces tests ne lisent ni stop_times, ni
// DakarClock, ni DepartureInfo, ni ScheduleStatus.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/services/documented_route_identity.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  // ==================================================================
  // 1. Tata est un vehicle_type, jamais un opérateur
  // ==================================================================
  group('1 — Tata est un type de véhicule, pas un opérateur', () {
    test('les candidats déclarent toujours operator = AFTU', () {
      expect(DocumentedRouteRegistry.tataCandidates, isNotEmpty);
      for (final TataLineCandidate c
          in DocumentedRouteRegistry.tataCandidates.values) {
        expect(c.operator, 'AFTU',
            reason: 'TATA n\'est jamais un opérateur (ligne ${c.routeNumber})');
      }
    });

    test('aucune entrée du registre n\'a operator == TATA documenté', () {
      for (final String n in DocumentedRouteRegistry.tataCandidates.keys) {
        final DocumentedRouteIdentity id =
            DocumentedRouteRegistry.resolve(operator: 'TATA', routeNumber: n);
        expect(id.documented, isFalse, reason: 'TATA $n');
        expect(id.publicRouteNumber, isNull, reason: 'TATA $n');
      }
    });

    test('aucun type de véhicule n\'est inventé (carte vide)', () {
      expect(DocumentedRouteRegistry.documentedVehicleTypes, isEmpty);
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '72'), isNull);
    });
  });

  // ==================================================================
  // 2. vehicle_type = TATA seulement si confirmé
  // ==================================================================
  group('2 — vehicle_type = TATA uniquement si confirmé', () {
    test('la règle ne produit « Tata N » que pour un statut documented', () {
      // Seul un statut CONFIRMÉ produit un libellé ; candidates et absences non.
      expect(
          DocumentedRouteRegistry.tataLabelForStatus(
              PublicIdentityStatus.documented, '80'),
          'Tata 80');
      expect(
          DocumentedRouteRegistry.tataLabelForStatus(
              PublicIdentityStatus.candidate, '80'),
          isNull);
      expect(
          DocumentedRouteRegistry.tataLabelForStatus(
              PublicIdentityStatus.unconfirmed, '80'),
          isNull);
    });

    test('en l\'état, aucune ligne n\'est confirmée Tata', () {
      for (final String n in <String>['1', '49', '50', '72', '80', '91']) {
        expect(
            DocumentedRouteRegistry.confirmedTataLabel('AFTU', n), isNull,
            reason: 'AFTU $n ne doit produire aucun libellé Tata sans preuve');
      }
    });
  });

  // ==================================================================
  // 3. Une correspondance secondaire ne devient pas Tata
  // ==================================================================
  group('3 — correspondance secondaire = candidat, jamais confirmé', () {
    test('les 38 numéros de la liste sont des candidats non confirmés', () {
      const List<String> numeros = <String>[
        '1', '2', '3', '4', '5', '24', '25', '26', '27', '28', '29', '30',
        '31', '32', '33', '34', '36', '37', '38', '39', '40', '41', '42', '43',
        '44', '46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56',
        '57', '58',
      ];
      expect(DocumentedRouteRegistry.tataCandidates.length, numeros.length);
      for (final String n in numeros) {
        expect(DocumentedRouteRegistry.tataIdentityStatus('AFTU', n),
            PublicIdentityStatus.candidate,
            reason: 'AFTU $n');
      }
    });

    test('l\'identité candidate n\'expose jamais de numéro public', () {
      final DocumentedRouteIdentity id =
          DocumentedRouteRegistry.resolveTata('AFTU', '49');
      expect(id.status, PublicIdentityStatus.candidate);
      expect(id.documented, isFalse);
      expect(id.publicRouteNumber, isNull);
      expect(id.vehicleType, isNull);
      expect(id.sourceType, IdentitySourceType.secondaryCrossCheck);
    });

    test('un statut non confirmé ne donne jamais de type de véhicule', () {
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '49'), isNull);
      expect(
          DocumentedRouteRegistry.resolve(operator: 'AFTU', routeNumber: '49')
              .vehicleType,
          isNull);
    });
  });

  // ==================================================================
  // 4. tata_218 ne devient jamais « Tata 218 »
  // ==================================================================
  group('4 — un identifiant technique n\'est jamais un numéro de ligne', () {
    test('tata_218 / tata_219 / tata_50 / tata_64 / tata_78 → refusés', () {
      for (final String rid in <String>[
        'tata_218',
        'tata_219',
        'tata_50',
        'tata_64',
        'tata_78',
        'new_commune_11',
        'new_commune_12',
      ]) {
        final DocumentedRouteIdentity id =
            DocumentedRouteRegistry.resolveRouteId('TATA', rid);
        expect(id.documented, isFalse, reason: rid);
        expect(id.publicRouteNumber, isNull, reason: rid);
        expect(id.vehicleType, isNull, reason: rid);
        expect(
            ScheduleProvider.identityLabelFor(
                'TATA', rid, IdentityStatus.unconfirmed),
            'TATA',
            reason: rid);
      }
    });

    test('short_name=218 + operator=tata ne suffit jamais', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('TATA', '218'),
          isNull);
      expect(DocumentedRouteRegistry.confirmedTataLabel('TATA', '218'), isNull);
    });
  });

  // ==================================================================
  // 5. Un numéro de parc DDD (9003) n'est jamais un numéro de ligne
  // ==================================================================
  group('5 — numéro de parc ≠ numéro de ligne', () {
    test('9003 → aucun numéro public, aucun libellé', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '9003'),
          isNull);
      expect(DocumentedRouteRegistry.documentedPublicNumber('AFTU', '9003'),
          isNull);
      expect(DocumentedRouteRegistry.confirmedTataLabel('AFTU', '9003'), isNull);
      expect(
          ScheduleProvider.identityLabelFor(
              'DDD', 'DDD_9003', IdentityStatus.unconfirmed),
          'DDD');
    });
  });

  // ==================================================================
  // 6. DDD : identités documentées uniquement
  // ==================================================================
  group('6 — DDD reste adossé aux identités documentées', () {
    test('numéros publiés acceptés, le reste refusé', () {
      for (final String n in <String>['217', '1', '23', '234', '504A']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', n), n);
      }
      for (final String n in <String>['102', '217bis', '9003', '9999']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', n), isNull,
            reason: n);
      }
    });
  });

  // ==================================================================
  // 7. AFTU : identités documentées uniquement
  // ==================================================================
  group('7 — AFTU reste adossé aux identités documentées', () {
    test('numéros publiés acceptés, le reste refusé', () {
      for (final String n in <String>['49', '54', '72', '80', '91']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('AFTU', n), n);
      }
      for (final String n in <String>['218', '219', '9003']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('AFTU', n), isNull,
            reason: n);
      }
    });
  });

  // ==================================================================
  // 8. Une identité TATA confirmée s'affiche correctement
  // ==================================================================
  group('8 — identité TATA confirmée → « Tata N »', () {
    test('la règle d\'affichage rend « Tata N » pour un statut confirmé', () {
      expect(
          DocumentedRouteRegistry.tataLabelForStatus(
              PublicIdentityStatus.documented, '80'),
          'Tata 80');
      expect(
          DocumentedRouteRegistry.tataLabelForStatus(
              PublicIdentityStatus.documented, '080'),
          'Tata 80',
          reason: 'les zéros de tête sont normalisés');
    });
  });

  // ==================================================================
  // 9. Une identité TATA non confirmée retombe sur AFTU XX
  // ==================================================================
  group('9 — identité TATA non confirmée → repli honnête', () {
    test('AFTU 80 documentée : libellé de ligne = « AFTU 80 », pas « Tata 80 »',
        () {
      final DocumentedRouteIdentity ddd =
          DocumentedRouteRegistry.resolve(operator: 'AFTU', routeNumber: '80');
      expect(ddd.documented, isTrue);
      expect(ddd.publicRouteNumber, '80');
      expect(ddd.vehicleType, isNull,
          reason: 'type de véhicule non établi → pas de « Tata » affiché');
      // Le pipeline d'affichage retombe sur AFTU 80.
      expect(
          ScheduleProvider.identityLabelFor(
              'AFTU', 'AFTU_80', IdentityStatus.unconfirmed),
          'AFTU 80');
      // Et jamais « Tata 80 ».
      expect(DocumentedRouteRegistry.confirmedTataLabel('AFTU', '80'), isNull);
    });

    test('le mode seul est affiché quand l\'identité AFTU n\'est pas documentée',
        () {
      expect(
          ScheduleProvider.identityLabelFor(
              'AFTU', 'AFTU_9001', IdentityStatus.unconfirmed),
          'AFTU');
    });
  });

  // ==================================================================
  // 10. Provenance : terminus croisés avec le feed AFTU (PassBi)
  // ==================================================================
  group('10 — provenance des candidats', () {
    test('chaque candidat porte sa provenance secondaire', () {
      for (final TataLineCandidate c
          in DocumentedRouteRegistry.tataCandidates.values) {
        expect(c.secondaryTerminusA, isNotEmpty, reason: c.routeNumber);
        expect(c.secondaryTerminusB, isNotEmpty, reason: c.routeNumber);
        expect(c.feedTerminusA, isNotEmpty, reason: c.routeNumber);
        expect(c.feedTerminusB, isNotEmpty, reason: c.routeNumber);
        // Aucune preuve officielle : jamais officialPublication.
        expect(c.evidence, isNot(IdentityEvidence.officialPublication));
      }
    });

    test('les terminus du feed AFTU correspondent au feed PassBi réel', () {
      final File feed = File('assets/data/passbi/aftu.json');
      expect(feed.existsSync(), isTrue);
      final String raw = feed.readAsStringSync();
      // PassBi AFTU expose `id`/`short`/`long` : on vérifie la présence des
      // fragments de terminus déclarés par les candidats à correspondance.
      for (final String n in <String>['49', '54', '57', '58']) {
        final TataLineCandidate? c =
            DocumentedRouteRegistry.tataCandidateFor('AFTU', n);
        expect(c, isNotNull, reason: n);
        expect(raw.contains(c!.feedTerminusA), isTrue,
            reason: 'AFTU $n : ${c.feedTerminusA} absent du feed');
      }
    });
  });

  // ==================================================================
  // 11. Aucun changement du calcul des horaires
  // ==================================================================
  group('11 — pipeline horaire non modifié', () {
    test('le registre ne référence aucun composant horaire', () {
      final String code = File('lib/services/documented_route_identity.dart')
          .readAsStringSync()
          .split('\n')
          .where((String l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final String forbidden in <String>[
        'DakarClock',
        'stop_times',
        'StopTime',
        'waitingMinutes',
        'ScheduleStatus',
        'DepartureInfo',
        'frequency',
        'estimatedWait',
      ]) {
        expect(code.contains(forbidden), isFalse,
            reason: 'le registre ne doit pas toucher « $forbidden »');
      }
    });

    test('les fichiers du pipeline horaire ne citent pas le registre TATA', () {
      for (final String path in <String>[
        'lib/services/gtfs/passbi_source.dart',
        'lib/models/departure_info.dart',
      ]) {
        final String code = File(path).readAsStringSync();
        expect(code.contains('tataCandidates'), isFalse, reason: path);
        expect(code.contains('resolveTata'), isFalse, reason: path);
      }
    });
  });
}
