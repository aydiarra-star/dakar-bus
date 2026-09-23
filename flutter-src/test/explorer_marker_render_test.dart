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
///   1. pomper la VRAIE `ExplorerPage` (même arbre que l'écran d'accueil,
///      `MainShell` page 0 de l'`IndexedStack`) ;
///   2. retrouver l'unique `FlutterMap` rendu ;
///   3. compter les marqueurs **réellement instanciés** dans l'arbre (les
///      `Positioned(width: 24)` de la couche) — flutter_map 6.x n'instancie
///      que les marqueurs dans le viewport (`pixelBounds`, culling intégré
///      de `MarkerLayer.build`) : la présence dans l'arbre équivaut à la
///      visibilité à l'écran ;
///   4. vérifier leurs offsets pixel (left/top) dans le viewport de la carte ;
///   5. dérouler les CAS A (« Tous »), B (filtre TER), C (filtre BRT),
///      D (GPS actif).
///
/// Aucune donnée : les arrêts proviennent uniquement de
/// `assets/data/dakar_network.json` via `prepareNetwork()` (donnée active,
/// jamais le repli).

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

Widget bootExplorer({LatLng? userPosition, GpsState gpsState = GpsState.idle}) =>
    MaterialApp(
      home: ExplorerPage(
        userPosition: userPosition,
        gpsState: gpsState,
        gpsMessage: null,
        onRequestLocation: () async {},
      ),
    );

/// Avance l'horloge virtuelle pour laisser `_loadDynamicRoutes` /
/// `_lazyLoadRemainingRoutes` (OSRM, échoue vite en test) vider leurs timers.
Future<void> pumpStable(WidgetTester tester) async {
  for (int i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 2500));
  }
}

/// Marqueurs d'arrêts réellement instanciés sous le `FlutterMap` rendu :
/// `Positioned(width: 24, height: 24)` avec un `GestureDetector` (le marqueur
/// utilisateur, width 22, est exclu).
List<Positioned> renderedStopMarkers(WidgetTester tester) =>
    tester
        .widgetList<Positioned>(find.descendant(
          of: find.byType(FlutterMap),
          matching: find.byWidgetPredicate((Widget w) =>
              w is Positioned &&
              w.width == 24.0 &&
              w.height == 24.0 &&
              w.child is GestureDetector),
        ))
        .toList();

/// Couleur du disque d'un marqueur rendu (Container → BoxDecoration).
Color markerColorOf(Positioned p) =>
    ((((p.child as GestureDetector).child) as Container).decoration
            as BoxDecoration)
        .color as Color;

int countColor(List<Positioned> markers, Color color) =>
    markers.where((Positioned p) => markerColorOf(p) == color).length;

void main() {
  setUpAll(() async {
    await prepareNetwork();
  });

  testWidgets(
      'CAS A — « Tous » : les 13 gares TER et 23 stations BRT sont instanciées '
      'dans le MarkerLayer rendu de la carte Explorer, dans le viewport',
      (WidgetTester tester) async {
    await tester.pumpWidget(bootExplorer());
    await pumpStable(tester);

    // ÉTAPE 2 — une seule carte FlutterMap sur l'écran Explorer.
    final List<FlutterMap> maps =
        tester.widgetList<FlutterMap>(find.byType(FlutterMap)).toList();
    expect(maps.length, 1,
        reason: 'une seule FlutterMap est rendue dans Explorer');
    final FlutterMap map = maps.first;
    expect(map.children.whereType<MarkerLayer>().length, 1,
        reason: 'une seule couche marqueurs d\'arrêts sur cette carte');

    final List<Positioned> markers = renderedStopMarkers(tester);
    expect(countColor(markers, AppColors.ter), 13,
        reason: '13 marqueurs TER rendus dans la carte');
    expect(countColor(markers, AppColors.brt), 23,
        reason: '23 marqueurs BRT rendus dans la carte');
    expect(markers.length, greaterThanOrEqualTo(36),
        reason: 'au moins les 36 arrêts officiels TER+BRT (plus les '
            'arrêts de proximité des autres réseaux, inchangés)');

    // Visibilité : offsets pixel dans le viewport (double contrôle du
    // culling intégré de flutter_map ; carte 800×260 dans la surface de test
    // 800×600, tolérance = taille d'un marqueur).
    for (final Positioned p in markers) {
      expect(p.left! >= -24.0 && p.left! <= 824.0, true,
          reason: 'marqueur TER/BRT hors largeur visible: left=${p.left}');
      expect(p.top! >= -24.0 && p.top! <= 284.0, true,
          reason: 'marqueur TER/BRT hors hauteur visible: top=${p.top}');
    }
  });

  testWidgets('CAS B — filtre TER : exactement 13 marqueurs TER rendus, '
      'aucun BRT, aucune disparition', (WidgetTester tester) async {
    await tester.pumpWidget(bootExplorer());
    await pumpStable(tester);

    // Même chemin que le chip « TER » (onTap → setState(_selectedFilter)).
    final State<dynamic> st = tester.state(find.byType(ExplorerPage));
    (st as dynamic).setState(() {
      (st as dynamic)._selectedFilter = 'TER';
    });
    await tester.pump(const Duration(milliseconds: 400));

    final List<Positioned> markers = renderedStopMarkers(tester);
    expect(markers.length, 13,
        reason: 'un marqueur par gare officielle, rien d\'autre');
    expect(countColor(markers, AppColors.ter), 13);
    expect(countColor(markers, AppColors.brt), 0);
  });

  testWidgets('CAS C — filtre BRT : exactement 23 marqueurs BRT rendus, '
      'aucune gare TER', (WidgetTester tester) async {
    await tester.pumpWidget(bootExplorer());
    await pumpStable(tester);

    final State<dynamic> st = tester.state(find.byType(ExplorerPage));
    (st as dynamic).setState(() {
      (st as dynamic)._selectedFilter = 'BRT';
    });
    await tester.pump(const Duration(milliseconds: 400));

    final List<Positioned> markers = renderedStopMarkers(tester);
    expect(markers.length, 23,
        reason: 'un marqueur par station officielle, rien d\'autre');
    expect(countColor(markers, AppColors.brt), 23);
    expect(countColor(markers, AppColors.ter), 0);
  });

  testWidgets('CAS D — GPS actif : l\'activation du GPS ne fait pas '
      'disparaître les marqueurs TER/BRT', (WidgetTester tester) async {
    await tester.pumpWidget(bootExplorer(
      userPosition: const LatLng(14.7167, -17.4677),
      gpsState: GpsState.granted,
    ));
    await pumpStable(tester);

    final List<Positioned> markers = renderedStopMarkers(tester);
    expect(countColor(markers, AppColors.ter), 13,
        reason: 'les 13 gares TER restent rendues avec GPS actif '
            '(garantie explorerMapMarkerStops, hors plafond de proximité)');
    expect(countColor(markers, AppColors.brt), 23,
        reason: 'les 23 stations BRT restent rendues avec GPS actif');

    // Le marqueur de position utilisateur (width 22) est bien présent
    // en plus des arrêts.
    expect(
        find.descendant(
          of: find.byType(FlutterMap),
          matching: find.byWidgetPredicate(
              (Widget w) => w is Positioned && w.width == 22.0),
        ),
        findsOneWidget);
  });
}
