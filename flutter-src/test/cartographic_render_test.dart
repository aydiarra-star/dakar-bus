import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';

/// OPTIMISATION CARTOGRAPHIQUE — diagnostic double ligne BRT (CAS A),
/// densité de marqueurs au zoom et taille des marqueurs.
///
/// Périmètre : **rendu uniquement**. La correction GPS de PR #24
/// (`GpsResolver`, `PositionValidity`, `DakarBounds`, `isWithinServiceZone`,
/// `initialCenter`, `didUpdateWidget`, message hors zone) n'est pas touchée ;
/// `assets/data/dakar_network.json` n'est pas modifié (verrouillé ailleurs à
/// 59 189 octets, SHA-256 `e59f05b0…`, et re-verrouillé ici par structure).
///
/// Ce fichier prouve :
///
///  1. **CAS A (double ligne verte BRT)** — sur les données réelles, les
///     7 stations de `BRT B2 Express` sont une sous-séquence exacte et
///     ordonnée des 23 stations de `BRT B1` ; le rendu calé sur le sous-tracé
///     conteneur fait coïncider les deux polylignes (aucune coordonnée
///     créée, aucune ligne supprimée). Ni CAS B (points dupliqués — refuté),
///     ni CAS C (géométrie incohérente — refutée) : les données restent
///     intactes.
///  2. **Densité non destructive au zoom** — la transmission au `MarkerLayer`
///     est identique quel que soit le zoom (58 marqueurs à l'aperçu, toujours
///     58 après déplacement) ; seul l'empan visuel (opacité/échelle) varie,
///     monotone et sans bascule binaire.
///  3. **Taille** — empan 20 px (cible 18-20), couleurs/icônes/clics inchangés.
///
/// Hermétique : TOUTES les requêtes HTTP (tuiles OSM, OSRM) sont servies par
/// un faux client renvoyant un PNG 1×1 en 200.

/// PNG 1×1 transparent (servi comme tuile/route factice).
const String _kPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
final Uint8List _pngBytes = base64Decode(_kPngBase64);

class _PngHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _PngRequest(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PngRequest implements HttpClientRequest {
  _PngRequest(this.uri);

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _PngHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = 0;

  @override
  Future<HttpClientResponse> close() async => _PngResponse();

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PngHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  int contentLength = 0;

  @override
  bool chunkedTransferEncoding = false;

  @override
  bool persistentConnection = true;

  @override
  ContentType? contentType;

  @override
  String? host;

  @override
  int? port;

  @override
  List<String>? operator [](String name) => _values[name];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_values[name] ??= <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = <String>[value.toString()];
  }

  @override
  void remove(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name]?.remove(value.toString());
  }

  @override
  void removeAll(String name, {bool preserveHeaderCase = false}) {
    _values.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  void clear() => _values.clear();

  @override
  bool containsKey(String name, {bool preserveHeaderCase = false}) =>
      _values.containsKey(name);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PngResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _pngBytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => true;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _PngHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_pngBytes)
          .listen(onData, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> prepareNetwork() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!appDataService.isLoaded) {
    await appDataService.loadNetworkData();
  }
  expect(appDataService.isLoaded, true);
  expect(appDataService.stops.length, 117,
      reason: 'la DONNÉE ACTIVE doit être chargée, pas le repli en dur');
  integrateNetworkDataForTest();
}

Widget bootExplorer({
  LatLng? userPosition,
  GpsState gpsState = GpsState.idle,
  String? gpsMessage,
}) =>
    MaterialApp(
      home: ExplorerPage(
        userPosition: userPosition,
        gpsState: gpsState,
        gpsMessage: gpsMessage,
        onRequestLocation: () async {},
      ),
    );

/// Pompes de l'écran Explorer, sous zone HTTP hermétique (PNG 200 partout) —
/// même budget d'horloge virtuelle que `explorer_marker_render_test.dart`
/// pour vider `_loadDynamicRoutes` et `_lazyLoadRemainingRoutes`.
Future<void> pumpExplorer(
  WidgetTester tester, {
  LatLng? userPosition,
  GpsState gpsState = GpsState.idle,
  String? gpsMessage,
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
      await tester.pumpWidget(bootExplorer(
        userPosition: userPosition,
        gpsState: gpsState,
        gpsMessage: gpsMessage,
      ));
      for (int i = 0; i < 40; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
    } finally {
      FlutterError.onError = previous;
    }
  }, createHttpClient: (SecurityContext? _) => _PngHttpClient());
}

Map<String, dynamic> _networkJson() => jsonDecode(
        File('assets/data/dakar_network.json').readAsStringSync())
    as Map<String, dynamic>;

/// Reconstruit, depuis le JSON réel, le `TransitRoute` de rendu d'une ligne
/// BRT (couleur verte officielle) — mêmes points que `_integrateNetworkData`.
TransitRoute _brtRouteFromJson(Map<String, dynamic> json, String routeId) {
  final Map<String, Map<String, dynamic>> stopsById =
      <String, Map<String, dynamic>>{
    for (final dynamic s in json['stops'] as List)
      (s as Map<String, dynamic>)['id'] as String: s,
  };
  final Map<String, dynamic> route = (json['routes'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((Map<String, dynamic> r) => r['id'] == routeId);
  final List<LatLng> points = (route['stops'] as List)
      .map((dynamic sid) {
        final Map<String, dynamic> s = stopsById[sid as String]!;
        return LatLng((s['latitude'] as num).toDouble(),
            (s['longitude'] as num).toDouble());
      })
      .toList();
  return TransitRoute(
    name: route['short_name'] as String,
    code: route['short_name'] as String,
    type: route['type'] as String,
    color: AppColors.brt,
    points: points,
  );
}

bool _samePolylinePoints(List<LatLng> a, List<LatLng> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}

/// Empan (opacité) réellement posé sur un marqueur rendu.
double? _markerOpacity(Marker m) {
  final Widget? child = m.child;
  return child is Opacity ? child.opacity : null;
}

/// Descend jusqu'au `Container` circulaire du marqueur (Opacity → Transform →
/// GestureDetector → Container) pour lire sa couleur réseau.
Color? _markerColor(Marker m) {
  Widget? w = m.child;
  while (w != null) {
    if (w is Opacity) {
      w = w.child;
    } else if (w is Transform) {
      w = w.child;
    } else if (w is GestureDetector) {
      w = w.child;
    } else if (w is Container && w.decoration is BoxDecoration) {
      return (w.decoration as BoxDecoration).color;
    } else {
      return null;
    }
  }
  return null;
}

MarkerLayer _stopsLayer(WidgetTester tester) {
  final List<MarkerLayer> layers = tester
      .widgetList<FlutterMap>(find.byType(FlutterMap))
      .single
      .children
      .whereType<MarkerLayer>()
      .toList();
  expect(layers.length, 1, reason: 'sans GPS, une seule couche de marqueurs');
  return layers.single;
}

void main() {
  setUpAll(() async {
    await prepareNetwork();
  });

  group('CAS A — double ligne BRT : diagnostic sur données réelles', () {
    test(
        'les 7 stations de B2 Express sont une sous-séquence exacte et '
        'ordonnée des 23 stations de B1 (indices 0,4,7,10,14,20,22)', () {
      final Map<String, dynamic> json = _networkJson();
      final TransitRoute b1 = _brtRouteFromJson(json, 'brt_b1_guediawaye_petersen');
      final TransitRoute b2 = _brtRouteFromJson(json, 'brt_b2_express');
      expect(b1.points.length, 23, reason: 'BRT B1 : 23 stations officielles');
      expect(b2.points.length, 7, reason: 'BRT B2 Express : 7 stations officielles');

      final List<int> indices = <int>[];
      int h = 0;
      for (final LatLng p in b2.points) {
        while (h < b1.points.length &&
            (b1.points[h].latitude != p.latitude ||
                b1.points[h].longitude != p.longitude)) {
          h++;
        }
        expect(h, lessThan(b1.points.length),
            reason: 'station B2 absente du tracé B1 — le diagnostic CAS A '
                'ne s’appliquerait plus aux données actuelles');
        indices.add(h);
        h++;
      }
      expect(indices, <int>[0, 4, 7, 10, 14, 20, 22],
          reason: 'sous-séquence exacte démontrée sur la source unique');

      // Aucun point dupliqué dans chaque ligne (CAS B refuté).
      for (final TransitRoute r in <TransitRoute>[b1, b2]) {
        final Set<String> unique = r.points
            .map((LatLng p) => '${p.latitude},${p.longitude}')
            .toSet();
        expect(unique.length, r.points.length,
            reason: 'CAS B refuté : aucun point dupliqué dans ${r.code}');
      }
    });

    test(
        'le rendu de B2 rejoint le sous-tracé complet de B1 (23 sommets) — '
        'les deux polylignes coïncident, sans coordonnée créée', () {
      final Map<String, dynamic> json = _networkJson();
      final TransitRoute b1 = _brtRouteFromJson(json, 'brt_b1_guediawaye_petersen');
      final TransitRoute b2 = _brtRouteFromJson(json, 'brt_b2_express');
      final List<TransitRoute> universe = <TransitRoute>[b1, b2];

      // AVANT (corde directe) : 7 sommets, les 16 stations intermédiaires de
      // B1 sont enjambées → seconde ligne verte parallèle.
      expect(b2.points.length, 7);

      // APRÈS (rendu seul) : sous-tracé conteneur, du premier au dernier
      // sommet partagé (indices 0..22 = tracé complet de B1).
      final List<LatLng> renderedB2 =
          explorerRenderedRoutePoints(b2, universe);
      expect(renderedB2.length, 23,
          reason: 'le rendu de B2 suit le coridoir de B1 (aucune ligne '
              'officielle supprimée, aucun sommet inventé)');
      expect(_samePolylinePoints(renderedB2, b1.points), isTrue,
          reason: 'B1 et B2 rendus identiques → une seule ligne verte visible');

      // Chaque sommet rendu est déjà un sommet du tracé conteneur.
      final Set<String> b1Keys = b1.points
          .map((LatLng p) => '${p.latitude},${p.longitude}')
          .toSet();
      for (final LatLng p in renderedB2) {
        expect(b1Keys.contains('${p.latitude},${p.longitude}'), isTrue,
            reason: 'sommet rendu qui n’existe pas dans B1 : donnée inventée');
      }

      // Sans conteneur, la géométrie de rendu EST la donnée (référence exacte).
      final List<LatLng> renderedB1 = explorerRenderedRoutePoints(b1, universe);
      expect(identical(renderedB1, b1.points), isTrue,
          reason: 'B1 n’a pas de conteneur plus long : points inchangés');
    });

    test(
        'couture pure : couleur différente / non-sous-séquence / sans '
        'conteneur → géométrie inchangée ; conteneur le plus long gagne', () {
      const LatLng a = LatLng(14.70, -17.45);
      const LatLng b = LatLng(14.71, -17.44);
      const LatLng c = LatLng(14.72, -17.43);
      const LatLng d = LatLng(14.73, -17.42);
      const LatLng e = LatLng(14.74, -17.41);
      const LatLng x = LatLng(14.75, -17.40);

      final TransitRoute container = TransitRoute(
          name: 'A',
          code: 'A',
          type: 'BRT',
          color: AppColors.brt,
          points: const <LatLng>[a, b, c]);
      final TransitRoute subset = TransitRoute(
          name: 'A-expr',
          code: 'A-expr',
          type: 'BRT',
          color: AppColors.brt,
          points: const <LatLng>[a, c]);
      final TransitRoute notIncluded = TransitRoute(
          name: 'A2',
          code: 'A2',
          type: 'BRT',
          color: AppColors.brt,
          points: const <LatLng>[a, x]);
      final TransitRoute otherColor = TransitRoute(
          name: 'T',
          code: 'T',
          type: 'BUS',
          color: AppColors.tata,
          points: const <LatLng>[a, c]);
      final TransitRoute longer = TransitRoute(
          name: 'LONG',
          code: 'LONG',
          type: 'BRT',
          color: AppColors.brt,
          points: const <LatLng>[a, b, c, d, e]);

      expect(
          explorerRenderedRoutePoints(
              subset, <TransitRoute>[container, subset]),
          <LatLng>[a, b, c],
          reason: 'sous-séquence → sous-tracé conteneur');
      expect(
          identical(
              explorerRenderedRoutePoints(
                  container, <TransitRoute>[container, subset]),
              container.points),
          isTrue,
          reason: 'conteneur sans plus long : inchangé (même référence)');
      expect(
          identical(
              explorerRenderedRoutePoints(
                  notIncluded, <TransitRoute>[container, notIncluded]),
              notIncluded.points),
          isTrue,
          reason: 'non-sous-séquence (x absent) : aucune substitution');
      expect(
          identical(
              explorerRenderedRoutePoints(
                  subset, <TransitRoute>[otherColor, subset]),
              subset.points),
          isTrue,
          reason: 'couleur différente : aucun couloir d’un autre réseau');
      final List<LatLng> longestWins = explorerRenderedRoutePoints(
          subset, <TransitRoute>[container, longer, subset]);
      expect(_samePolylinePoints(longestWins, longer.points), isTrue,
          reason: 'plusieurs conteneurs → le plus long (tracé le plus riche)');
    });
  });

  group('Rendu des polylignes — une seule ligne verte visible', () {
    testWidgets(
        'B1 et B2 rendues avec la MÊME géométrie (23 pts) et liserre blanche ; '
        'TER unique à 13 pts', (WidgetTester tester) async {
      await pumpExplorer(tester);

      final FlutterMap map =
          tester.widget<FlutterMap>(find.byType(FlutterMap));
      final List<Polyline> polylines =
          map.children.whereType<PolylineLayer>().single.polylines;

      final List<Polyline> greens = polylines
          .where((Polyline p) => p.color == AppColors.brt)
          .toList();
      expect(greens.length, 2,
          reason: 'BRT B1 et BRT B2 sont toujours toutes les deux rendues '
              '(aucune ligne officielle supprimée)');
      for (final Polyline g in greens) {
        expect(g.points.length, 23,
            reason: 'les deux cordes vertes suivent le sous-tracé de B1 : '
                'superposition parfaite, plus de double ligne');
        expect(g.borderColor, Colors.white,
            reason: 'liserre blanche de séparation des superpositions');
        expect(g.borderStrokeWidth, 2);
      }
      expect(_samePolylinePoints(greens[0].points, greens[1].points), isTrue,
          reason: 'géométries vertes identiques → une seule ligne perçue');

      final List<Polyline> ters = polylines
          .where((Polyline p) => p.color == AppColors.ter)
          .toList();
      expect(ters.length, 1, reason: 'un seul tracé TER (aucun doublon)');
      expect(ters.single.points.length, 13,
          reason: 'les 13 gares officielles, invariants');
      expect(ters.single.borderColor, Colors.white);
    });
  });

  group('Densité de marqueurs au zoom — non destructive', () {
    test('structurants (TER/BRT/terminus/correspondence) : plein écran à tout '
        'zoom', () {
      final Stop ter = Stop(
          name: 'Gare TER',
          direction: 'Dir. Diamniadio',
          distanceMeters: 500,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.train,
          color: AppColors.ter,
          location: const LatLng(14.68, -17.44),
          modeLabel: 'TER',
          stopType: StopType.intermediate);
      final Stop brt = Stop(
          name: 'Station BRT',
          direction: 'Dir. Petersen',
          distanceMeters: 300,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus,
          color: AppColors.brt,
          location: const LatLng(14.70, -17.43),
          modeLabel: 'BRT',
          stopType: StopType.boarding);
      final Stop terminus = Stop(
          name: 'Terminus DDD',
          direction: 'Dir. Centre',
          distanceMeters: 400,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus,
          color: AppColors.ddd,
          location: const LatLng(14.71, -17.45),
          modeLabel: 'DDD',
          stopType: StopType.terminus);
      final Stop corresp = Stop(
          name: 'Corresp. Tata',
          direction: 'Dir. Petersen',
          distanceMeters: 400,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus,
          color: AppColors.tata,
          location: const LatLng(14.72, -17.46),
          modeLabel: 'Tata',
          stopType: StopType.correspondence);

      for (final Stop s in <Stop>[ter, brt, terminus, corresp]) {
        expect(explorerStopIsStructuring(s), isTrue, reason: s.name);
        for (final double z in <double>[9, 11.2, 12.5, 13.5, 17]) {
          final ({double opacity, double scale}) v = explorerMarkerVisual(z, s);
          expect(v.opacity, 1.0, reason: '${s.name} @ zoom $z');
          expect(v.scale, 1.0, reason: '${s.name} @ zoom $z');
        }
      }
    });

    test(
        'secondaire : progression monotone 0.25 → 0.55 → 1.0 '
        '(échelle 0.75 → 0.85 → 1.0), aucun retour arrière', () {
      final Stop secondary = Stop(
          name: 'Arrêt AFTU',
          direction: 'Dir. Centre',
          distanceMeters: 500,
          departureMinutesFromMidnight: const <int>[],
          icon: Icons.directions_bus_outlined,
          color: AppColors.aftu,
          location: const LatLng(14.72, -17.44),
          modeLabel: 'AFTU',
          stopType: StopType.boarding);
      expect(explorerStopIsStructuring(secondary), isFalse);

      const List<double> zooms = <double>[9, 11.2, 11.99, 12.0, 12.5, 13.49, 13.5, 14, 17];
      const List<double> expectedOpacity = <double>[
        0.25, 0.25, 0.25, 0.55, 0.55, 0.55, 1.0, 1.0, 1.0,
      ];
      const List<double> expectedScale = <double>[
        0.75, 0.75, 0.75, 0.85, 0.85, 0.85, 1.0, 1.0, 1.0,
      ];
      double lastOpacity = 0;
      for (int i = 0; i < zooms.length; i++) {
        final ({double opacity, double scale}) v =
            explorerMarkerVisual(zooms[i], secondary);
        expect(v.opacity, expectedOpacity[i], reason: 'zoom ${zooms[i]}');
        expect(v.scale, expectedScale[i], reason: 'zoom ${zooms[i]}');
        expect(v.opacity, greaterThanOrEqualTo(lastOpacity),
            reason: 'progression monotone au zoom croissant');
        lastOpacity = v.opacity;
      }
    });

    testWidgets(
        'caméra aperçu (zoom 11.2) : 58 marqueurs TOUJOURS transmis, empan '
        '20 px, opacité exacte = couture — aucun arrêt retiré',
        (WidgetTester tester) async {
      await pumpExplorer(tester);

      final MarkerLayer stops = _stopsLayer(tester);
      expect(stops.markers.length, 58,
          reason: 'transmission identique à avant la phase (36 officiels '
              'TER+BRT + 22 proximité) — non destructif');

      for (final Marker m in stops.markers) {
        expect(m.width, 20, reason: 'empan cible 18-20 px');
        expect(m.height, 20, reason: 'empan cible 18-20 px');
        expect(m.child, isA<Opacity>(),
            reason: 'chaque marqueur porte son empan de densité au zoom');

        // L'arrêt correspondant (la couche ne transmet que des `allStops`).
        final Stop stop = allStops.firstWhere(
            (Stop s) =>
                s.location.latitude == m.point.latitude &&
                s.location.longitude == m.point.longitude,
            orElse: () => throw StateError(
                'marqueur hors allStops : ${m.point}'));
        final ({double opacity, double scale}) expected =
            explorerMarkerVisual(11.2, stop);
        expect(_markerOpacity(m), expected.opacity,
            reason: '${stop.name} : opacité rendue = couture zoom');
        // Couleur réseau intacte (identité visuelle préservée).
        expect(_markerColor(m), stop.color, reason: stop.name);
      }

      // Les gares/stations officielles structurantes restent pleinement
      // visibles à l'aperçu (priorité TER/BRT).
      final Marker terMarker = stops.markers.firstWhere(
          (Marker m) => _markerColor(m) == AppColors.ter);
      expect(_markerOpacity(terMarker), 1.0);
      final Marker brtMarker = stops.markers.firstWhere(
          (Marker m) => _markerColor(m) == AppColors.brt);
      expect(_markerOpacity(brtMarker), 1.0);
    });

    testWidgets(
        'zoom rapproché (move programmatique → 14.0) : secondaires à pleine '
        'visibilité, transmission toujours 58', (WidgetTester tester) async {
      await pumpExplorer(tester);

      final FlutterMap map =
          tester.widget<FlutterMap>(find.byType(FlutterMap));
      // `FlutterMap.mapController` est nullable dans flutter_map v6 ; la carte
      // du test est construite avec `mapController: _mapController` (non nul).
      map.mapController!.move(const LatLng(14.6900, -17.4510), 14.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final MarkerLayer stops = _stopsLayer(tester);
      expect(stops.markers.length, 58,
          reason: 'aucun arrêt retiré de la couche quel que soit le zoom');

      for (final Marker m in stops.markers) {
        expect(_markerOpacity(m), 1.0,
            reason: 'zoom 14 ≥ 13.5 : tous les marqueurs pleinement visibles '
                '(aucun n’a été supprimé pour autant)');
        expect(m.width, 20);
        expect(m.height, 20);
      }
    });
  });

  group('Données intactes (Phase 6/8) — JSON inchangé, réseaux préservés', () {
    test('dakar_network.json : structure verrouillée (117 arrêts, 105 lignes)', () {
      final File file = File('assets/data/dakar_network.json');
      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync().length, 59189,
          reason: 'SHA-256 inchangé côté git (e59f05b0…) ; taille verrouillée '
              'comme dans les tests GPS existants');

      final Map<String, dynamic> json = _networkJson();
      expect((json['stops'] as List).length, 117);
      expect((json['routes'] as List).length, 105);
    });

    test('TER 13 gares, BRT 23 stations, DDD 15 / TATA 7 / AFTU 80 lignes', () {
      final Map<String, dynamic> json = _networkJson();
      final List<Map<String, dynamic>> routes =
          (json['routes'] as List).cast<Map<String, dynamic>>();

      final Map<String, dynamic> ter =
          routes.firstWhere((Map<String, dynamic> r) => r['type'] == 'TER');
      expect((ter['stops'] as List).length, 13,
          reason: 'les 13 gares TER restent présentes');

      final Set<String> brtStopIds = <String>{};
      for (final Map<String, dynamic> r
          in routes.where((Map<String, dynamic> r) => r['operator_id'] == 'brt')) {
        brtStopIds.addAll((r['stops'] as List).cast<String>());
      }
      expect(brtStopIds.length, 23,
          reason: 'les 23 stations BRT uniques restent présentes (B1 ∪ B2)');

      expect(
          routes.where((Map<String, dynamic> r) => r['operator_id'] == 'ddd').length,
          15,
          reason: 'lignes DDD présentes');
      expect(
          routes
              .where((Map<String, dynamic> r) => r['operator_id'] == 'tata')
              .length,
          7,
          reason: 'lignes TATA présentes');
      expect(
          routes
              .where((Map<String, dynamic> r) => r['operator_id'] == 'aftu')
              .length,
          80,
          reason: 'lignes AFTU présentes');
    });

    test('les deux lignes BRT officielles existent toujours séparément', () {
      final Map<String, dynamic> json = _networkJson();
      final List<String> ids = (json['routes'] as List)
          .cast<Map<String, dynamic>>()
          .map((Map<String, dynamic> r) => r['id'] as String)
          .toList();
      expect(ids, contains('brt_b1_guediawaye_petersen'));
      expect(ids, contains('brt_b2_express'),
          reason: 'aucune ligne supprimée des données pour « simplifier » '
              'le rendu');
    });
  });
}
