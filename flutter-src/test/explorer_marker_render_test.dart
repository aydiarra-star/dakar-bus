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
///   3. compter les marqueurs **réellement instanciés** dans l'arbre rendu de
///      la carte — flutter_map 6.x n'instancie que les marqueurs situés dans
///      le viewport (`pixelBounds`, culling intégré de `MarkerLayer.build`) :
///      la présence d'un marqueur dans l'arbre équivaut à sa visibilité ;
///   4. dérouler les CAS A (« Tous »), B (filtre TER), C (filtre BRT),
///      D (GPS actif).
///
/// Le comptage s'appuie sur les `Container` circulaires des marqueurs — code
/// d'`ExplorerPage` lui-même, stable — plutôt que sur le wrapper interne de
/// flutter_map (`Positioned` ou autre selon la version).
///
/// Aucune donnée : les arrêts proviennent uniquement de
/// `assets/data/dakar_network.json` via `prepareNetwork()` (donnée active,
/// jamais le repli en dur).

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

/// Pompes de l'écran Explorer.
///
/// Budget large (40×5 s puis 8×5 s d'horloge VIRTUELLE) pour laisser
/// `_loadDynamicRoutes` et `_lazyLoadRemainingRoutes` (OSRM — échoue vite en
/// test via HTTP factice, repli sur les points directs) vider tous leurs
/// timers : aucun timer ne doit rester en attente à la fin du test.
///
/// Les échecs de chargement des tuiles OSM (HTTP factice → 400) sont du
/// bruit ATTENDU en test et ne concernent ni les polylignes ni les marqueurs
/// (couches sœurs indépendantes) : ils sont filtrés, tout autre
/// `FlutterError` reste remonté.
Future<void> pumpExplorer(
  WidgetTester tester, {
  LatLng? userPosition,
  GpsState gpsState = GpsState.idle,
  void Function()? mutate,
}) async {
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final String text = details.exception.toString();
    const List<String> noise = <String>[
      'statusCode: 400',
      'HTTP request failed',
      'SocketException',
      'ClientException',
      'Failed host lookup',
    ];
    if (noise.any(text.contains)) return;
    previous?.call(details);
  };
  try {
    await tester.pumpWidget(bootExplorer(
      userPosition: userPosition,
      gpsState: gpsState,
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
}

Widget bootExplorer({LatLng? userPosition, GpsState gpsState = GpsState.idle}) =>
    MaterialApp(
      home: ExplorerPage(
        userPosition: userPosition,
        gpsState: gpsState,
        gpsMessage: null,
        onRequestLocation: () async {},
      ),
    );

/// Nombre de marqueurs d'arrêts instanciés sous le `FlutterMap` rendu pour
/// une couleur donnée (disques `BoxDecoration(shape: circle, color: …)` des
/// `Marker` construits par `ExplorerPage`).
int countRenderedMarkersByColor(WidgetTester tester, Color color) => find
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

/// Total de marqueurs instanciés (toutes couleurs) sous la carte.
int countAllRenderedMarkers(WidgetTester tester) => find
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
      'CAS A — « Tous » : les 13 gares TER et 23 stations BRT sont instanciées '
      'dans le MarkerLayer rendu de la carte Explorer (viewport initial)',
      (WidgetTester tester) async {
    await pumpExplorer(tester);

    // ÉTAPE 2 — une seule carte FlutterMap sur l'écran Explorer.
    final List<FlutterMap> maps =
        tester.widgetList<FlutterMap>(find.byType(FlutterMap)).toList();
    expect(maps.length, 1,
        reason: 'une seule FlutterMap est rendue dans Explorer');
    final FlutterMap map = maps.first;
    expect(map.children.whereType<MarkerLayer>().length, 1,
        reason: 'une seule couche marqueurs d\'arrêts sur cette carte');

    debugPrint('[RENDER-TEST][CAS A] ter=${countRenderedMarkersByColor(tester, AppColors.ter)} brt=${countRenderedMarkersByColor(tester, AppColors.brt)} total=${countAllRenderedMarkers(tester)} (attendu: ter=13 brt=23 total∈[36,57])');
    expect(countRenderedMarkersByColor(tester, AppColors.ter), 13,
        reason: '13 marqueurs TER rendus dans la carte principale');
    expect(countRenderedMarkersByColor(tester, AppColors.brt), 23,
        reason: '23 marqueurs BRT rendus dans la carte principale');
    expect(countAllRenderedMarkers(tester), inInclusiveRange(36, 57),
        reason: 'au moins les 36 arrêts officiels TER+BRT, au plus 57 avec '
            'les arrêts de proximité des autres réseaux (comportement '
            '« à proximité » inchangé)');
  });

  testWidgets(
      'CAS B — filtre TER : exactement 13 marqueurs TER rendus, aucun BRT, '
      'aucune disparition', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      mutate: () {
        final State<dynamic> st = tester.state(find.byType(ExplorerPage));
        (st as dynamic).setState(() {
          (st as dynamic)._selectedFilter = 'TER';
        });
      },
    );

    debugPrint('[RENDER-TEST][CAS B] ter=${countRenderedMarkersByColor(tester, AppColors.ter)} brt=${countRenderedMarkersByColor(tester, AppColors.brt)} total=${countAllRenderedMarkers(tester)} (attendu: ter=13 brt=0 total=13)');
    expect(countRenderedMarkersByColor(tester, AppColors.ter), 13,
        reason: 'un marqueur par gare officielle');
    expect(countRenderedMarkersByColor(tester, AppColors.brt), 0);
    expect(countAllRenderedMarkers(tester), 13,
        reason: 'rien d\'autre que les 13 gares officielles sur la carte');
  });

  testWidgets(
      'CAS C — filtre BRT : exactement 23 marqueurs BRT rendus, aucune gare '
      'TER', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      mutate: () {
        final State<dynamic> st = tester.state(find.byType(ExplorerPage));
        (st as dynamic).setState(() {
          (st as dynamic)._selectedFilter = 'BRT';
        });
      },
    );

    debugPrint('[RENDER-TEST][CAS C] ter=${countRenderedMarkersByColor(tester, AppColors.ter)} brt=${countRenderedMarkersByColor(tester, AppColors.brt)} total=${countAllRenderedMarkers(tester)} (attendu: ter=0 brt=23 total=23)');
    expect(countRenderedMarkersByColor(tester, AppColors.brt), 23,
        reason: 'un marqueur par station officielle');
    expect(countRenderedMarkersByColor(tester, AppColors.ter), 0);
    expect(countAllRenderedMarkers(tester), 23,
        reason: 'rien d\'autre que les 23 stations officielles sur la carte');
  });

  testWidgets(
      'CAS D — GPS actif : l\'activation du GPS ne fait pas disparaître les '
      'marqueurs TER/BRT de la carte principale', (WidgetTester tester) async {
    await pumpExplorer(
      tester,
      userPosition: const LatLng(14.7167, -17.4677),
      gpsState: GpsState.granted,
    );

    debugPrint('[RENDER-TEST][CAS D] ter=${countRenderedMarkersByColor(tester, AppColors.ter)} brt=${countRenderedMarkersByColor(tester, AppColors.brt)} user=${countRenderedMarkersByColor(tester, AppColors.primary)} (attendu: ter=13 brt=23 user=1)');
    expect(countRenderedMarkersByColor(tester, AppColors.ter), 13,
        reason: 'les 13 gares TER restent rendues avec GPS actif — garantie '
            'explorerMapMarkerStops, hors plafond de proximité');
    expect(countRenderedMarkersByColor(tester, AppColors.brt), 23,
        reason: 'les 23 stations BRT restent rendues avec GPS actif');

    // Le marqueur de position utilisateur (disque AppColors.primary) est
    // présent en plus des arrêts.
    expect(
        countRenderedMarkersByColor(tester, AppColors.primary), 1,
        reason: 'le marqueur de position utilisateur reste affiché');
  });
}
