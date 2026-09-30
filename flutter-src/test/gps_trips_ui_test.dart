// Chantier « Recherche + GPS + Routage » — intégration UI du routage GPS.
//
// Preuve que l'écran Trajets expose réellement le GPS comme ENTRÉE du routage :
//   * bouton « Partir de ma position (GPS) » ;
//   * panneau « Autour de vous » (arrêts réels + mobilités) ;
//   * calcul d'itinéraire depuis la position vers la destination saisie ;
//   * messages honnêtes quand le GPS est absent ou la destination inconnue.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:dakar_bus/main.dart' as app;

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
    app.integrateNetworkSearchCatalogForTest();
  });

  // Position de service : Parcelles Assainies.
  const LatLng parcelles = LatLng(14.76269, -17.42431);

  /// Instant de référence FIXE (heure de Dakar) pour des rendus déterministes.
  ///
  /// Les horaires affichés proviennent des `stop_times` RÉELS du feed : à
  /// l'heure courante de la CI, le dernier départ réel peut être passé (le feed
  /// BRT s'arrête à ~21 h 56), et l'écran affiche alors honnêtement « Horaire
  /// indisponible ». Fixer l'instant de référence ne fabrique AUCUNE donnée :
  /// c'est la même lecture du feed, datée à midi — l'assertion ne dépend plus de
  /// l'heure d'exécution.
  final DateTime refAt = DateTime.utc(2026, 9, 30, 12, 0);

  Widget bootTrips({LatLng? position, app.GpsState gpsState = app.GpsState.idle}) =>
      MaterialApp(
        home: app.TripsPage(
          userPosition: position,
          gpsState: gpsState,
          onRequestLocation: () async {},
          at: refAt,
        ),
      );

  /// Zone HTTP hermétique (aucune requête réseau réelle pendant les tests).
  Future<void> pumpTrips(
    WidgetTester tester, {
    LatLng? position,
    app.GpsState gpsState = app.GpsState.idle,
    Future<void> Function(WidgetTester tester)? action,
  }) {
    return HttpOverrides.runZoned(() async {
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        final String text = details.exception.toString();
        const List<String> noise = <String>[
          'statusCode: 400',
          'HTTP request failed',
          'SocketException',
          'ClientException',
          'Failed host lookup',
          'RenderFlex overflowed',
        ];
        if (noise.any(text.contains)) return;
        previous?.call(details);
      };
      try {
        await tester.pumpWidget(bootTrips(position: position, gpsState: gpsState));
        await tester.pump();
        if (action != null) await action(tester);
      } finally {
        FlutterError.onError = previous;
      }
    }, createHttpClient: (SecurityContext? _) => _NoopHttpClient());
  }

  testWidgets('le bouton GPS est présent sur l\'écran Trajets', (tester) async {
    await pumpTrips(tester);
    expect(find.text('Partir de ma position (GPS)'), findsOneWidget);
    expect(find.text('Rechercher mon itinéraire'), findsOneWidget);
  });

  testWidgets('sans position GPS, le bouton explique qu\'il faut l\'activer',
      (tester) async {
    await pumpTrips(tester, action: (t) async {
      await t.ensureVisible(find.text('Partir de ma position (GPS)'));
      await t.pump();
      await t.tap(find.text('Partir de ma position (GPS)'));
      await t.pump();
    });
    expect(
      find.textContaining('Activez le GPS'),
      findsOneWidget,
    );
  });

  testWidgets('avec position GPS, « Autour de vous » liste des arrêts réels',
      (tester) async {
    await pumpTrips(
      tester,
      position: parcelles,
      gpsState: app.GpsState.granted,
    );
    expect(find.text('Autour de vous'), findsOneWidget);
    expect(find.textContaining('arrêts réels'), findsOneWidget);
    // Les mobilités réellement disponibles autour de Parcelles.
    expect(find.textContaining('DDD'), findsWidgets);
  });

  testWidgets('position → destination : un itinéraire réel est calculé',
      (tester) async {
    await pumpTrips(
      tester,
      position: parcelles,
      gpsState: app.GpsState.granted,
      action: (t) async {
        // Destination saisie : Keur Mbaye Fall.
        await t.enterText(find.byType(TextField).at(1), 'Keur Mbaye Fall');
        await t.pump();
        await t.ensureVisible(find.text('Partir de ma position (GPS)'));
        await t.pump();
        await t.tap(find.text('Partir de ma position (GPS)'));
        // Laisse le délai de recherche (300 ms) s'écouler.
        await t.pump(const Duration(milliseconds: 400));
        await t.pump(const Duration(seconds: 1));
      },
    );
    expect(find.text('Itinéraires proposés'), findsOneWidget);
    expect(find.textContaining('position GPS'), findsOneWidget);
    // Au moins un itinéraire : la carte affiche « correspondance(s) ».
    expect(find.textContaining('correspondance'), findsWidgets);
  });

  testWidgets('destination inconnue : aucun itinéraire n\'est inventé',
      (tester) async {
    await pumpTrips(
      tester,
      position: parcelles,
      gpsState: app.GpsState.granted,
      action: (t) async {
        await t.enterText(find.byType(TextField).at(1), 'zzz-introuvable-zzz');
        await t.pump();
        await t.ensureVisible(find.text('Partir de ma position (GPS)'));
        await t.pump();
        await t.tap(find.text('Partir de ma position (GPS)'));
        await t.pump();
      },
    );
    expect(find.textContaining('Destination introuvable'), findsOneWidget);
    expect(find.text('0 résultat(s)'), findsOneWidget,
        reason: 'aucun itinéraire ne doit être inventé');
    expect(find.textContaining('correspondance(s)'), findsNothing);
  });

  testWidgets('les arrêts proches proposés sont tous des arrêts réels du '
      'référentiel', (tester) async {
    await pumpTrips(
      tester,
      position: parcelles,
      gpsState: app.GpsState.granted,
    );
    // Chaque arrêt listé dans « Autour de vous » existe réellement dans le
    // référentiel natif du réseau annoncé.
    final nearby = app.appDataService.accessPointsNear(
      lat: 14.76269,
      lon: -17.42431,
    );
    expect(nearby.length, greaterThan(1));
    for (final p in nearby) {
      final ids = app.appDataService.passBiSource
          .nativeStops(p.network)
          .map((s) => s.stopId)
          .toSet();
      expect(ids, contains(p.stopId),
          reason: '${p.network}:${p.stopId} doit exister dans le feed');
    }
  });
}

/// Client HTTP no-op : aucune requête réseau réelle pendant les tests.
class _NoopHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      throw const SocketException('no network in test');

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
