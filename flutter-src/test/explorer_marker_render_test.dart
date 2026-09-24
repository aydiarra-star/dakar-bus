import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dakar_bus/main.dart';

/// PREUVE DE RENDU — CORRECTIF ARRÊTS TER/BRT (carte principale Explorer).
///
/// Les tests de `ter_brt_route_data_test.dart` prouvent que la fonction pure
/// `explorerMapMarkerStops()` retourne 13 gares TER + 23 stations BRT. Ils ne
/// prouvent PAS que ces marqueurs atteignent le `MarkerLayer` **rendu** dans
/// la carte principale. C'est l'objet de CE fichier :
///
///   1. pomper la VRAIE `ExplorerPage` (même arbre que l'écran d'accueil :
///      `MainShell`, page 0 de l'`IndexedStack`) ;
///   2. retrouver l'unique `FlutterMap` rendu sur cet écran ;
///   3. vérifier ce qui est TRANSMIS à son `MarkerLayer` (contrat du
///      correctif : 13 TER + 23 BRT dans les quatre cas) ;
///   4. vérifier ce qui est RENDU dans l'arbre de la carte (containers
///      circulaires des marqueurs). flutter_map n'instancie que les marqueurs
///      situés dans le viewport (`pixelBounds`, culling intégré de
///      `MarkerLayer.build`) : présence dans l'arbre = visibilité à l'écran ;
///      un marqueur transmis mais hors de la fenêtre visible est donc
///      légitimement absent de l'arbre (cas de Diamniadio, caméra GPS).
///   5. dérouler les CAS A (« Tous »), B (filtre TER), C (filtre BRT),
///      D (GPS actif).
///
/// Hermétique : TOUTES les requêtes HTTP du test (tuiles OSM, OSRM) sont
/// servies par un faux client renvoyant un PNG 1×1 en 200 — plus aucune
/// exception réseau ne peut remonter, et les couches tuiles/polylignes sont
/// réellement construites.
///
/// Aucune donnée : les arrêts proviennent uniquement de
/// `assets/data/dakar_network.json` via `prepareNetwork()` (donnée active,
/// jamais le repli en dur).

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
  final Map<String, String> _values = <String, String>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name] = value.toString();

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name] = value.toString();

  @override
  String? value(String name) => _values[name];

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach((String k, String v) => action(k, <String>[v]));

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
  final HttpHeaders headers = _PngHeaders();

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

/// Pompes de l'écran Explorer, sous zone HTTP hermétique (PNG 200 partout).
///
/// Budget large (40×5 s puis 8×5 s d'horloge VIRTUELLE) pour laisser
/// `_loadDynamicRoutes` et `_lazyLoadRemainingRoutes` (OSRM — répond PNG en
/// test, repli immédiat sur les points directs de la ligne) vider tous leurs
/// timers : aucun timer ne doit rester en attente à la fin du test.
Future<void> pumpExplorer(
  WidgetTester tester, {
  LatLng? userPosition,
  GpsState gpsState = GpsState.idle,
  String? gpsMessage,
  void Function()? mutate,
}) {
  return HttpOverrides.runZoned(() async {
    // Filtrage du bruit hors périmètre : plus aucune requête réseau réelle
    // n'échoue (zone PNG ci-dessous), mais il reste les avertissements de
    // layout DEBUG préexistants des listes de cartes (« RenderFlex
    // overflowed », silencieux en release, hors périmètre du correctif
    // marqueurs). Tout autre FlutterError reste remonté.
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
      mutate?.call();
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
    } finally {
      FlutterError.onError = previous;
    }
  }, createHttpClient: (SecurityContext? _) => _PngHttpClient());
}

/// Active le VRAI chip de filtre de l'écran Explorer (même `onTap` que l'appui
/// utilisateur). Le rayon de chips — `SizedBox(height: 40, child: ListView)` —
/// est unique à l'écran ; les `GestureDetector` des marqueurs ne contiennent
/// aucun `Text`.
void tapChip(WidgetTester tester, String label) {
  final Finder chipsRow = find.byWidgetPredicate(
    (Widget w) => w is SizedBox && w.height == 40.0 && w.child is ListView,
  );
  expect(chipsRow, findsOneWidget,
      reason: 'le rayon de chips de filtres est unique');
  final Finder chip = find.descendant(
    of: chipsRow,
    matching: find.widgetWithText(GestureDetector, label),
  );
  expect(chip, findsOneWidget, reason: 'chip « $label » présent une seule fois');
  final GestureDetector detector = tester.widget<GestureDetector>(chip);
  detector.onTap!();
}

/// Le `FlutterMap` rendu et sa couche de marqueurs d'arrêts (première couche
/// `MarkerLayer` des enfants de la carte ; la couche position utilisateur,
/// ajoutée ensuite, est exclue).
(FlutterMap, MarkerLayer) renderedMapAndStopsLayer(WidgetTester tester) {
  final List<FlutterMap> maps =
      tester.widgetList<FlutterMap>(find.byType(FlutterMap)).toList();
  expect(maps.length, 1, reason: 'une seule FlutterMap est rendue dans Explorer');
  final FlutterMap map = maps.first;
  final List<MarkerLayer> layers = map.children.whereType<MarkerLayer>().toList();
  expect(layers, isNotEmpty, reason: 'une couche marqueurs doit exister');
  return (map, layers.first);
}

/// Marqueurs TRANSMIS à la couche, par couleur (contrat du correctif).
int transmittedByColor(MarkerLayer layer, Color color) =>
    layer.markers.where((Marker m) {
      final Container c = (m.child as GestureDetector).child as Container;
      return (c.decoration as BoxDecoration).color == color;
    }).length;

/// Marqueurs RENDUS dans l'arbre de la carte, par couleur (disques
/// `BoxDecoration(shape: circle, color: …)` instanciés sous le `FlutterMap`).
int renderedByColor(WidgetTester tester, Color color) => find
    .descendant(
      of: find.byType(FlutterMap),
      matching: find.byWidgetPredicate((Widget w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration as BoxDecoration).color == color),
    )
    .evaluate()
    .length;

/// Total des marqueurs rendus (toutes couleurs) sous la carte.
int renderedTotal(WidgetTester tester) => find
    .descendant(
      of: find.byType(FlutterMap),
      matching: find.byWidgetPredicate((Widget w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle),
    )
    .evaluate()
    .length;

void main() {
  setUpAll(() async {
    await prepareNetwork();
  });

  testWidgets(
      'CAS A — « Tous » : 13 gares TER + 23 stations BRT transmis au '
      'MarkerLayer et rendus dans la carte Explorer', (WidgetTester tester) async {
    await pumpExplorer(tester);

    final (FlutterMap map, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    expect(map.children.whereType<MarkerLayer>().length, 1,
        reason: 'sans GPS, une seule couche marqueurs (les arrêts)');

    debugPrint('[RENDER-TEST][CAS A] transmis: ter=${transmittedByColor(stops, AppColors.ter)} '
        'brt=${transmittedByColor(stops, AppColors.brt)} total=${stops.markers.length} | '
        'rendus: ter=${renderedByColor(tester, AppColors.ter)} '
        'brt=${renderedByColor(tester, AppColors.brt)} total=${renderedTotal(tester)}');

    expect(transmittedByColor(stops, AppColors.ter), 13,
        reason: '13 gares TER officielles transmises au MarkerLayer');
    expect(transmittedByColor(stops, AppColors.brt), 23,
        reason: '23 stations BRT officielles transmises au MarkerLayer');
    // 58 = 36 officiels TER+BRT + 22 arrêts de proximité des autres réseaux.
    // AVANT PR #20 : 57 (36 + 21) — 12 arrêts de démonstration TER/BRT
    // occupaient encore des places parmi les 30 « à proximité » du centre de
    // Dakar et étaient ensuite écartés de la couche (sans `stopId`). Sans les
    // listes de démo (source unique dakar_network.json), une place de plus
    // revient à un arrêt réel d'un autre réseau. Le flux « à proximité »
    // (rayon, plafond 30, tri) est inchangé.
    expect(stops.markers.length, 58,
        reason: '36 officiels TER+BRT + 22 arrêts de proximité des autres '
            'réseaux (flux « à proximité » inchangé)');

    expect(renderedByColor(tester, AppColors.ter), 13,
        reason: '13 marqueurs TER instanciés dans la carte (viewport initial)');
    expect(renderedByColor(tester, AppColors.brt), 23,
        reason: '23 marqueurs BRT instanciés dans la carte (viewport initial)');
    expect(renderedTotal(tester), inInclusiveRange(36, 58),
        reason: 'au moins les 36 officiels ; le reste selon le culling du '
            'viewport initial');
  });

  testWidgets(
      'CAS B — filtre TER : exactement 13 gares transmises et rendues, '
      'aucune station BRT', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      mutate: () => tapChip(tester, 'TER'),
    );

    final (FlutterMap _, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    debugPrint('[RENDER-TEST][CAS B] transmis: ter=${transmittedByColor(stops, AppColors.ter)} '
        'brt=${transmittedByColor(stops, AppColors.brt)} total=${stops.markers.length} | '
        'rendus: ter=${renderedByColor(tester, AppColors.ter)} '
        'brt=${renderedByColor(tester, AppColors.brt)} total=${renderedTotal(tester)}');

    expect(transmittedByColor(stops, AppColors.ter), 13);
    expect(transmittedByColor(stops, AppColors.brt), 0);
    expect(renderedByColor(tester, AppColors.ter), 13,
        reason: '13 marqueurs TER rendus sur la carte');
    expect(renderedByColor(tester, AppColors.brt), 0);
    expect(renderedTotal(tester), 13,
        reason: 'rien d\'autre que les 13 gares officielles sur la carte');
  });

  testWidgets(
      'CAS C — filtre BRT : exactement 23 stations transmises et rendues, '
      'aucune gare TER', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      mutate: () => tapChip(tester, 'BRT'),
    );

    final (FlutterMap _, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    debugPrint('[RENDER-TEST][CAS C] transmis: ter=${transmittedByColor(stops, AppColors.ter)} '
        'brt=${transmittedByColor(stops, AppColors.brt)} total=${stops.markers.length} | '
        'rendus: ter=${renderedByColor(tester, AppColors.ter)} '
        'brt=${renderedByColor(tester, AppColors.brt)} total=${renderedTotal(tester)}');

    expect(transmittedByColor(stops, AppColors.brt), 23);
    expect(transmittedByColor(stops, AppColors.ter), 0);
    expect(renderedByColor(tester, AppColors.brt), 23,
        reason: '23 marqueurs BRT rendus sur la carte');
    expect(renderedByColor(tester, AppColors.ter), 0);
    expect(renderedTotal(tester), 23,
        reason: 'rien d\'autre que les 23 stations officielles sur la carte');
  });

  testWidgets(
      'CAS D — GPS actif : 13 TER + 23 BRT toujours transmis au MarkerLayer, '
      'rendus dans le viewport (au plus la gare la plus orientée, Diamniadio, '
      'peut être hors fenêtre par culling flutter_map)',
      (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      userPosition: const LatLng(14.7167, -17.4677),
      gpsState: GpsState.granted,
    );

    final (FlutterMap map, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    expect(map.children.whereType<MarkerLayer>().length, 2,
        reason: 'avec GPS : couche arrêts + couche position utilisateur');
    debugPrint('[RENDER-TEST][CAS D] transmis: ter=${transmittedByColor(stops, AppColors.ter)} '
        'brt=${transmittedByColor(stops, AppColors.brt)} total=${stops.markers.length} | '
        'rendus: ter=${renderedByColor(tester, AppColors.ter)} '
        'brt=${renderedByColor(tester, AppColors.brt)} total=${renderedTotal(tester)}');

    expect(transmittedByColor(stops, AppColors.ter), 13,
        reason: 'le GPS ne retire aucune gare de la couche — garantie '
            'explorerMapMarkerStops, hors plafond de proximité');
    expect(transmittedByColor(stops, AppColors.brt), 23);
    expect(stops.markers.length, 58,
        reason: '36 officiels + 22 arrêts de proximité (voir CAS A)');

    expect(renderedByColor(tester, AppColors.brt), 23,
        reason: '23 stations BRT rendues avec GPS actif');
    expect(renderedByColor(tester, AppColors.ter), inInclusiveRange(12, 13),
        reason: 'les gares TER rendues avec GPS actif — Diamniadio, la plus '
            'orientée, peut sortir de la fenêtre (culling flutter_map, la '
            'caméra est centrée sur l\'utilisateur) ; elle reste transmise');
    expect(renderedTotal(tester), greaterThanOrEqualTo(35));

    // Le marqueur de position utilisateur est présent en plus des arrêts.
    expect(renderedByColor(tester, AppColors.primary), 1,
        reason: 'le marqueur de position utilisateur reste affiché');
  });

  // ===========================================================================
  // CORRECTION GPS HORS ZONE — exploration de Dakar depuis la France
  // ===========================================================================

  testWidgets(
      'CAS E — position réelle en France : carte ouverte sur Dakar, bandeau '
      'hors zone, réseaux consultables, aucune distance de milliers de km',
      (WidgetTester tester) async {
    const LatLng paris = LatLng(48.8566, 2.3522);
    await pumpExplorer(
      tester,
      userPosition: paris,
      gpsState: GpsState.granted,
      gpsMessage: GpsResolver.outOfCoverageMessage,
    );

    // 1) L'ouverture est centrée sur Dakar, indépendamment du GPS français.
    final (FlutterMap map, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    expect(DakarBounds.isValid(map.options.initialCenter), isTrue,
        reason: 'la carte doit s\'ouvrir sur la zone de données Dakar');
    expect(map.options.initialCenter, isNot(paris),
        reason: 'aucun centrage initial sur la position française');
    expect(
        PositionValidity.isPlausible(map.options.initialCenter) &&
            DakarBounds.isValid(map.options.initialCenter),
        isTrue);

    // 2) Le bandeau existant affiche le message de couverture exigé (§3).
    expect(find.text(GpsResolver.outOfCoverageMessage), findsOneWidget,
        reason: 'bandeau « Vous êtes hors de la zone de couverture Dakar Bus »');

    // 3) L'exploration des réseaux reste complète (TER + BRT garantis).
    expect(transmittedByColor(stops, AppColors.ter), 13,
        reason: '13 gares TER consultables depuis la France');
    expect(transmittedByColor(stops, AppColors.brt), 23,
        reason: '23 stations BRT consultables depuis la France');
    expect(stops.markers.length, 58,
        reason: 'mêmes 58 marqueurs que l\'ouverture sans GPS (CAS A)');

    // 4) Les couches marqueurs existent : arrêts + position réelle (hors
    //    viewport, le centre étant Dakar) — la position n'est pas écrasée.
    expect(map.children.whereType<MarkerLayer>().length, 2,
        reason: 'couche arrêts + couche position utilisateur (réelle, France)');

    // 5) Aucune distance « plusieurs milliers de kilomètres » affichée comme
    //    proximité utile dans les cartes d'arrêt VISIBLES (la couverture
    //    exhaustive de TOUS les arrêts réels est vérifiée par le test pur
    //    « toutes les distances réelles » de out_of_coverage_test.dart).
    final RegExp anyKm = RegExp(r'(\d+(?:\.\d+)?) km');
    final List<String> allTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => (t.data ?? '').trim())
        .toList();
    for (final String t in allTexts) {
      for (final Match m in anyKm.allMatches(t)) {
        final double km = double.parse(m.group(1)!);
        expect(km, lessThan(100),
            reason: 'distance affichée depuis la France : "$t" — aucune '
                'distance de milliers de km ne doit apparaître');
      }
    }
  });

  testWidgets(
      'CAS F — GPS refusé : carte ouverte sur Dakar, réseaux consultables, '
      'bandeau de permission affiché', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      gpsState: GpsState.denied,
      gpsMessage: 'Permission GPS refusée.',
    );

    final (FlutterMap map, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    expect(DakarBounds.isValid(map.options.initialCenter), isTrue,
        reason: 'sans position, l\'ouverture reste sur Dakar');
    expect(find.text('Permission GPS refusée.'), findsOneWidget,
        reason: 'bandeau d\'erreur GPS existant visible');

    expect(transmittedByColor(stops, AppColors.ter), 13);
    expect(transmittedByColor(stops, AppColors.brt), 23);
    expect(stops.markers.length, 58,
        reason: 'consultation complète sans GPS réel');
    expect(renderedTotal(tester), greaterThanOrEqualTo(35),
        reason: 'les arrêts sont réellement rendus dans le viewport de Dakar');
  });

  testWidgets(
      'CAS G — filtres réseaux utilisables depuis la France (TER affiché, '
      'aucun BRT)', (WidgetTester tester) async {
    const LatLng paris = LatLng(48.8566, 2.3522);
    await pumpExplorer(
      tester,
      userPosition: paris,
      gpsState: GpsState.granted,
      gpsMessage: GpsResolver.outOfCoverageMessage,
      mutate: () => tapChip(tester, 'TER'),
    );

    final (FlutterMap _, MarkerLayer stops) = renderedMapAndStopsLayer(tester);
    expect(transmittedByColor(stops, AppColors.ter), 13,
        reason: 'filtre TER consultable hors zone comme en zone');
    expect(transmittedByColor(stops, AppColors.brt), 0);
    expect(renderedByColor(tester, AppColors.ter), 13);
  });
}
