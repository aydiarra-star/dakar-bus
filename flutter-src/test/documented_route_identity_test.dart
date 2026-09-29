// CHANTIER IDENTITÉ PUBLIQUE — PR #48.
//
// Preuve que l'identité publique DDD / AFTU / TATA est basée UNIQUEMENT sur une
// identité DOCUMENTÉE, et qu'aucune ligne n'est inventée ou déduite d'un
// identifiant interne.
//
//   source documentée → identité validée → affichage
//   aucune preuve    → identité publique = null → repli honnête (mode réseau)
//
// Aucune donnée horaire n'est touchée : ces tests ne lisent ni stop_times, ni
// DakarClock, ni DepartureInfo.
import 'package:flutter_test/flutter_test.dart';

import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/services/documented_route_identity.dart';
import 'package:dakar_bus/services/schedule_provider.dart';

void main() {
  group('DDD — numéro public affiché seulement s\'il est documenté', () {
    test('DDD 217 → autorisé (demdikk.sn/info-voyageurs)', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '217'), '217');
      final DocumentedRouteIdentity id =
          DocumentedRouteRegistry.resolveRouteId('DDD', 'DDD_217');
      expect(id.documented, isTrue);
      expect(id.publicRouteNumber, '217');
      expect(id.source, DocumentedRouteRegistry.demdikkSource);
      expect(id.sourceType, IdentitySourceType.operatorPublication);
      expect(ScheduleProvider.identityLabelFor(
          'DDD', 'DDD_217', IdentityStatus.unconfirmed), 'DDD 217');
    });

    test('DDD 213 → autorisé', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '213'), '213');
      expect(ScheduleProvider.identityLabelFor(
          'DDD', 'DDD_213', IdentityStatus.unconfirmed), 'DDD 213');
    });

    test('DDD 1 → autorisé', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '1'), '1');
      expect(ScheduleProvider.identityLabelFor(
          'DDD', 'DDD_01', IdentityStatus.unconfirmed), 'DDD 1');
    });

    test('DDD <identifiant inconnu> → aucun numéro public inventé', () {
      for (final String unknown in <String>['102', '111', '301', '401', '9999']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', unknown),
            isNull, reason: unknown);
        expect(
            ScheduleProvider.identityLabelFor(
                'DDD', 'DDD_$unknown', IdentityStatus.unconfirmed),
            'DDD',
            reason: 'DDD_$unknown ne doit produire que le mode');
      }
    });
  });

  group('AFTU — numéro public affiché seulement s\'il est documenté', () {
    test('AFTU 54 → autorisé (aftu-senegal.org/infos-pratiques)', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('AFTU', '54'), '54');
      final DocumentedRouteIdentity id =
          DocumentedRouteRegistry.resolveRouteId('AFTU', 'AFTU_54');
      expect(id.documented, isTrue);
      expect(id.publicRouteNumber, '54');
      expect(id.source, DocumentedRouteRegistry.aftuSource);
      expect(id.sourceType, IdentitySourceType.operatorWebsite);
      expect(ScheduleProvider.identityLabelFor(
          'AFTU', 'AFTU_54', IdentityStatus.unconfirmed), 'AFTU 54');
    });

    test('AFTU <identifiant inconnu> → aucun numéro public inventé', () {
      // 6 à 23 et 90 ne sont PAS publiés par l'AFTU : aucun numéro.
      for (final String unknown in <String>['6', '10', '20', '23', '90']) {
        expect(DocumentedRouteRegistry.documentedPublicNumber('AFTU', unknown),
            isNull, reason: unknown);
        expect(
            ScheduleProvider.identityLabelFor(
                'AFTU', 'AFTU_$unknown', IdentityStatus.unconfirmed),
            'AFTU',
            reason: 'AFTU_$unknown ne doit produire que le mode');
      }
    });
  });

  group('TATA — type de véhicule, jamais une ligne inventée', () {
    test('Tata + ligne documentée (type de véhicule) → autorisé', () {
      // Seules les lignes AFTU 72 et 80 sont documentées comme minibus Tata.
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '72'), 'Tata');
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '80'), 'Tata');
    });

    test('Tata + ligne non documentée → refusé', () {
      // L'association type de véhicule n'est pas généralisée.
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '54'), isNull);
      expect(DocumentedRouteRegistry.documentedVehicleType('AFTU', '50'), isNull);
      expect(DocumentedRouteRegistry.documentedVehicleType('DDD', '217'), isNull);
    });

    test('operator=tata + route_id arbitraire → refusé', () {
      // « operator == tata + num == 218 » ne donne JAMAIS « Tata 218 ».
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
        // Le feed a un route_id « tata_218 » : il n'est jamais présenté.
        expect(
            ScheduleProvider.identityLabelFor(
                'TATA', rid, IdentityStatus.unconfirmed),
            'TATA',
            reason: rid);
      }
    });

    test('aucune ligne TATA n\'est inventée dans le référentiel affiché', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('TATA', '218'),
          isNull);
      expect(DocumentedRouteRegistry.documentedPublicNumber('TATA', '50'),
          isNull);
    });
  });

  group('Véhicule — un numéro de parc n\'est jamais un numéro de ligne', () {
    test('9003 ne devient jamais « DDD 9003 »', () {
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '9003'),
          isNull);
      expect(
          ScheduleProvider.identityLabelFor(
              'DDD', 'DDD_9003', IdentityStatus.unconfirmed),
          'DDD');
      // Le libellé ne contient jamais le numéro de parc.
      expect(
          ScheduleProvider.identityLabelFor(
              'DDD', 'DDD_9003', IdentityStatus.unconfirmed),
          isNot(contains('9003')));
    });

    test('l\'extraction d\'un route_id n\'autorise jamais un numéro non listé', () {
      expect(DocumentedRouteRegistry.numberFromRouteId('DDD_9003'), '9003');
      expect(DocumentedRouteRegistry.numberFromRouteId('tata_218'), '218');
      expect(DocumentedRouteRegistry.numberFromRouteId('AFTU_54'), '54');
      // L'extraction seule ne vaut pas preuve : elle est confrontée au registre.
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '9003'),
          isNull);
      expect(DocumentedRouteRegistry.documentedPublicNumber('TATA', '218'),
          isNull);
    });
  });

  group('Registre — normalisation et intégrité', () {
    test('les numéros documentés sont exactement ceux des sources citées', () {
      // Échantillon des deux sources, y compris variantes lettrées.
      for (final String n in <String>[
        '1', '4', '7', '8', '9', '10', '13', '18', '20', '23', '121',
        '2', '5', '6', '11', '12', '15A', '15B', '16A', '16B',
        '208', '213', '217', '218', '219', '220', '221', '227', '228',
        '232', '233', '234', '501', '502A', '502B', '503A', '503B',
        '504A', '504B',
      ]) {
        expect(DocumentedRouteRegistry.dddPublicNumbers.contains(n), isTrue,
            reason: 'DDD $n doit être documenté');
      }
      for (final String n in <String>['1', '5', '24', '49', '54', '72', '89', '91']) {
        expect(DocumentedRouteRegistry.aftuPublicNumbers.contains(n), isTrue,
            reason: 'AFTU $n doit être documenté');
      }
    });

    test('une variante lettrée n\'est pas confondue avec le numéro nu', () {
      // 15A/15B sont documentés, « 15 » nu ne l'est pas (ambigu).
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '15A'), '15A');
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '15B'), '15B');
      expect(DocumentedRouteRegistry.documentedPublicNumber('DDD', '15'), isNull);
    });

    test('l\'identité non documentée ne porte ni numéro ni type de véhicule', () {
      final DocumentedRouteIdentity id =
          DocumentedRouteRegistry.resolve(operator: 'Tata', routeNumber: '218');
      expect(id.documented, isFalse);
      expect(id.publicRouteNumber, isNull);
      expect(id.vehicleType, isNull);
    });
  });

  group('Pipeline horaire — non-régression (identité ≠ horaire)', () {
    test('un identifiant interne confirmé garde son identité documentée', () {
      // Le crosswalk BRT reste la seule source d'identité « confirmée ».
      expect(
          ScheduleProvider.identityLabelFor(
              'BRT', 'B1', IdentityStatus.confirmed),
          'BRT B1');
    });

    test('le libellé d\'identité ne contient jamais d\'horaire', () {
      for (final String label in <String>[
        ScheduleProvider.identityLabelFor(
            'DDD', 'DDD_217', IdentityStatus.unconfirmed),
        ScheduleProvider.identityLabelFor(
            'AFTU', 'AFTU_54', IdentityStatus.unconfirmed),
        ScheduleProvider.identityLabelFor(
            'TATA', 'tata_218', IdentityStatus.unconfirmed),
      ]) {
        expect(label, isNot(contains('min')));
        expect(label, isNot(contains('PassBi')));
      }
    });

    test('les route_id réels des feeds donnent les identités documentées', () {
      // DDD : seuls les numéros publiés par demdikk.sn obtiennent un numéro.
      expect(DocumentedRouteRegistry.resolveRouteId('DDD', 'DDD_01').documented,
          isTrue);
      expect(DocumentedRouteRegistry.resolveRouteId('DDD', 'DDD_217').documented,
          isTrue);
      expect(DocumentedRouteRegistry.resolveRouteId('DDD', 'DDD_234').documented,
          isTrue);
      for (final String rid in <String>[
        'DDD_102', 'DDD_111', 'DDD_301', 'DDD_401', 'DDD_504',
      ]) {
        expect(DocumentedRouteRegistry.resolveRouteId('DDD', rid).documented,
            isFalse, reason: rid);
      }
      // AFTU : trous réels du feed (6–23) → non documentés.
      expect(DocumentedRouteRegistry.resolveRouteId('AFTU', 'AFTU_54').documented,
          isTrue);
      for (final String rid in <String>[
        'AFTU_6', 'AFTU_10', 'AFTU_20', 'AFTU_23',
      ]) {
        expect(DocumentedRouteRegistry.resolveRouteId('AFTU', rid).documented,
            isFalse, reason: rid);
      }
      // BRT : identité publique « B1 »/« B2 » (crosswalk).
      expect(DocumentedRouteRegistry.resolveRouteId('BRT', 'B1').documented,
          isTrue);
      expect(DocumentedRouteRegistry.resolveRouteId('BRT', 'B1').publicRouteNumber,
          'B1');
      // Les identifiants internes BRT `brt_b1_*` ne sont PAS « BRT 1 ».
      expect(
          DocumentedRouteRegistry.documentedPublicNumber('BRT', '1'), isNull);
    });

    test('le registre ne référence aucune donnée horaire', () {
      // Garde-fou : le registre n'expose que des identités publiques.
      expect(DocumentedRouteRegistry.sourcesCheckedAt, isNotEmpty);
      expect(DocumentedRouteRegistry.demdikkSource, contains('demdikk.sn'));
      expect(DocumentedRouteRegistry.aftuSource, contains('aftu-senegal.org'));
    });
  });
}
