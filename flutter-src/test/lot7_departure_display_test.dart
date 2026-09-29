// LOT 7 — Affichage homogène du prochain passage (toutes mobilités).
//
// Problème corrigé : un départ programmé à moins d'une minute affichait
// « Prochain départ dans moins d'une minute » (et la fiche de ligne colorait ce
// délai avec la couleur du réseau, marron pour le TER). Règle désormais :
//  * tout délai calculable s'affiche « Prochain départ dans X min » avec X
//    entier ≥ 1 (jamais « moins d'une minute », jamais « 0 min ») ;
//  * une estimation encadrée affiche « Passage estimé dans … » (jamais un
//    horaire exact : une fréquence ne fixe pas la phase du prochain véhicule) ;
//  * sans base de calcul : « Horaire indisponible » ;
//  * la couleur du délai est le vert [AppColors.success], INDÉPENDANTE de la
//    couleur graphique du réseau (le TER reste marron).
import 'dart:io';

import 'package:dakar_bus/main.dart';
import 'package:dakar_bus/models/departure_info.dart';
import 'package:dakar_bus/models/transport_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DepartureInfo _scheduled({
  required DateTime departure,
  required DateTime reference,
}) =>
    DepartureInfo.scheduled(
      operator: 'TER Dakar',
      routeId: 'ter_dakar_diamniadio',
      scheduledTime: departure,
      referenceTime: reference,
      source: 'https://www.terdakar.sn/les_horaires_des_trains',
    );

String _codeSansCommentaires() => File('lib/main.dart')
    .readAsStringSync()
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  final DateTime ref = DateTime.utc(2026, 9, 28, 14, 0, 0);

  group('LOT 7 — délai programmé : « Prochain départ dans X min »', () {
    test('5 min, 3 min, 1 min → X entier, jamais 0', () {
      expect(_scheduled(departure: ref.add(const Duration(minutes: 5)), reference: ref).label,
          'Prochain départ dans 5 min');
      expect(_scheduled(departure: ref.add(const Duration(minutes: 3)), reference: ref).label,
          'Prochain départ dans 3 min');
      expect(_scheduled(departure: ref.add(const Duration(minutes: 1)), reference: ref).label,
          'Prochain départ dans 1 min');
    });

    test('départ imminent (< 60 s) → « 1 min », jamais « moins d\'une minute »', () {
      final DepartureInfo info = _scheduled(
          departure: ref.add(const Duration(seconds: 30)), reference: ref);
      expect(info.label, 'Prochain départ dans 1 min');
      expect(info.label, isNot(contains('moins')));
      expect(info.label, isNot(contains('0 min')));
    });

    test('départ à l\'instant présent → « 1 min » (jamais « 0 min »)', () {
      final DepartureInfo info =
          _scheduled(departure: ref, reference: ref);
      expect(info.label, 'Prochain départ dans 1 min');
    });

    test('arrondi vers le haut : une fraction de minute s\'affiche au min sup.',
        () {
      expect(_scheduled(departure: ref.add(const Duration(seconds: 90)), reference: ref).label,
          'Prochain départ dans 2 min');
      expect(_scheduled(departure: DateTime.utc(2026, 9, 28, 14, 11, 25), reference: ref)
          .label,
          'Prochain départ dans 12 min');
    });

    test('départ passé → aucun délai inventé (retour explicite)', () {
      final DepartureInfo info =
          _scheduled(departure: ref.subtract(const Duration(minutes: 2)), reference: ref);
      expect(info.computedRemainingLabel, isNull);
      expect(info.label, 'Départ programmé');
    });
  });

  group('LOT 7 — estimation : jamais un horaire exact', () {
    test('l\'absence de scheduledTime reste « Horaire indisponible »', () {
      const DepartureInfo info = DepartureInfo(
        status: ScheduleStatus.unknown,
        operator: 'AFTU',
        routeId: 'AFTU_1',
        source: 'https://aftu-senegal.org/infos-pratiques',
        sourceType: SourceType.unknown,
        dateSource: null,
        dateVerified: null,
        validFrom: null,
        validTo: null,
        confidence: null,
        frequencyMinutes: null,
        operatingHours: null,
        direction: null,
      );
      expect(info.label, 'Horaire indisponible');
      expect(info.scheduledTime, isNull);
    });

    test('un statut estimate ne produit jamais « Prochain départ »', () {
      final DepartureInfo info = DepartureInfo.fromFrequency(
        const FrequencySource(
          operator: 'SunuBRT',
          routeId: 'brt_b1_guediawaye_petersen',
          routeLabel: 'B1',
          source: 'https://www.sunubrt.sn/brt-1-omnibus/',
          sourceType: SourceType.officialStatic,
          dateSource: null,
          dateVerified: '2026-09-26',
          validFrom: null,
          validTo: null,
          confidence: 0.98,
          status: ScheduleStatus.estimated,
          operatingHours: '06:00–21:00',
          frequencies: <FrequencyWindow>[
            FrequencyWindow(
              weekdays: kMondayToSaturday,
              startMinute: 6 * 60,
              endMinute: 21 * 60,
              frequencyMinutes: 6,
            ),
          ],
        ),
        FrequencyWindow(
          weekdays: kMondayToSaturday,
          startMinute: 6 * 60,
          endMinute: 21 * 60,
          frequencyMinutes: 6,
        ),
        ref,
      );
      expect(info.label, contains('estimé'));
      expect(info.label, isNot(contains('Prochain départ')));
      expect(info.scheduledTime, isNull);
      // Une fréquence documentée n'est ni un FCFA, ni une heure, ni un LIVE.
      expect(info.label, isNot(contains('0 min')));
    });
  });

  group('LOT 7 — couleur du délai indépendante du réseau', () {
    test('le délai programmé/estimé est rendu en AppColors.success, pas en '
        'couleur de réseau', () {
      final String code = _codeSansCommentaires();
      // La fiche de ligne colorait « info.label » avec route.color.
      expect(code.contains('color: info.status == ScheduleStatus.scheduled ? route.color'),
          isFalse,
          reason: 'le délai ne doit plus prendre la couleur du réseau (TER marron)');
      // Les vues StopCard/fiche utilisent le vert pour un délai numérique.
      expect(code.contains('AppColors.success'), isTrue);
    });

    test('la couleur graphique du réseau TER reste marron (non modifiée)', () {
      expect(AppColors.ter, const Color(0xFF8B4513));
    });
  });

  group('LOT 7 — aucune invention ni faux temps réel', () {
    test('aucun libellé ne contient « moins d\'une minute » ni « 0 min »', () {
      final RegExp zeroMin = RegExp(r'(^|[^0-9])0 min');
      for (int minutes = 0; minutes <= 400; minutes++) {
        final DepartureInfo info = _scheduled(
            departure: ref.add(Duration(minutes: minutes)), reference: ref);
        expect(info.label, isNot(contains('moins')));
        expect(zeroMin.hasMatch(info.label), isFalse, reason: info.label);
        expect(info.label, contains('min'));
      }
    });

    test('jamais LIVE / temps réel / flotte dans le modèle de départ', () {
      final DepartureInfo info =
          _scheduled(departure: ref.add(const Duration(minutes: 4)), reference: ref);
      expect(info.label.toLowerCase(), isNot(contains('live')));
      expect(info.label.toLowerCase(), isNot(contains('temps réel')));
      expect(info.label.toLowerCase(), isNot(contains('flotte')));
    });
  });
}
