import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';

void main() {
  Stop fixture(String name, String mode, List<String> networks) => Stop(
        name: name,
        direction: 'Dir. Dakar',
        distanceMeters: 0,
        departureMinutesFromMidnight: const <int>[],
        icon: Icons.directions_bus,
        color: AppColors.primary,
        location: const LatLng(14.7, -17.4),
        modeLabel: mode,
        networkIds: networks,
      );

  test('les couleurs identiques ne mélangent pas les filtres réseau', () {
    final List<Stop> source = <Stop>[
      fixture('Gare TER', 'TER', const <String>['ter']),
      fixture('Station BRT', 'BRT', const <String>['brt']),
      fixture('Arrêt DDD', 'DDD', const <String>['ddd']),
      fixture('Pôle TER/BRT', 'TER', const <String>['ter', 'brt']),
    ];

    expect(source.every((Stop s) => s.color == AppColors.primary), isTrue);
    for (final String network in <String>['ter', 'brt', 'ddd']) {
      final List<Stop> filtered = explorerBaseStopsForFilter(
        selectedFilter: network.toUpperCase(),
        favoriteStopNames: const <String>{},
        source: source,
      );
      expect(filtered.every((Stop s) => s.servesNetwork(network)), isTrue);
    }
    expect(
      explorerBaseStopsForFilter(
        selectedFilter: 'TER',
        favoriteStopNames: const <String>{},
        source: source,
      ).map((Stop s) => s.name).toSet(),
      <String>{'Gare TER', 'Pôle TER/BRT'},
    );
    expect(
      explorerBaseStopsForFilter(
        selectedFilter: 'BRT',
        favoriteStopNames: const <String>{},
        source: source,
      ).map((Stop s) => s.name).toSet(),
      <String>{'Station BRT', 'Pôle TER/BRT'},
    );
  });

  test('un arrêt partagé conserve toutes ses appartenances réseau', () {
    final Stop shared = fixture('Pôle', 'TER', const <String>['ter'])
        .copyWith(networkIds: const <String>['brt', 'ter']);

    expect(shared.servesNetwork('ter'), isTrue);
    expect(shared.servesNetwork('brt'), isTrue);
    expect(shared.servesNetwork('ddd'), isFalse);
  });

  test('les arrêts historiques sans identifiants gardent le repli modeLabel', () {
    final Stop legacy = fixture('Ancienne gare', 'TER', const <String>[]);
    expect(legacy.servesNetwork('ter'), isTrue);
    expect(legacy.servesNetwork('brt'), isFalse);
  });
}
