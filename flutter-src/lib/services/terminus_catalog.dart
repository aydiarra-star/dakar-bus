/// Chantier DDD / AFTU / TATA — chargement du référentiel pôles & terminus.
///
/// Lit `assets/data/reference/ddd_aftu_poles_terminus.json`, généré par
/// `scripts/build-ddd-aftu-terminus.mjs` à partir des feeds PassBi déjà
/// intégrés. Aucune donnée TER/BRT, aucun horaire, aucun routage n'est touché.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/terminus_pole.dart';

class TerminusCatalog {
  static const String assetPath =
      'assets/data/reference/ddd_aftu_poles_terminus.json';

  DddAftuTerminusReference? _reference;
  bool _loaded = false;

  bool get isLoaded => _loaded;
  DddAftuTerminusReference? get reference => _reference;
  List<TerminusPole> get poles => _reference?.poles ?? const <TerminusPole>[];

  /// Chargement non bloquant : un asset illisible laisse le catalogue vide
  /// (jamais de pôle fabriqué, jamais de plantage).
  Future<void> load() async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      _reference = DddAftuTerminusReference.fromJson(
          json.decode(raw) as Map<String, dynamic>);
      _loaded = true;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Référentiel pôles/terminus DDD-AFTU indisponible : $e');
    }
  }

  /// Pôles affichables sur la carte : coordonnées valides uniquement.
  List<TerminusPole> mappablePoles({bool terminalsOnly = true}) => poles
      .where((p) => !terminalsOnly || p.isTerminal)
      .where((p) => p.coordinatesStatus != PoleCoordinatesStatus.rejected)
      .toList();

  /// Terminus (départ ou arrivée) documentés d'une ligne, par identifiant feed.
  List<RouteTerminus> terminusForRoute(
      DddAftuTerminusReference ref, String routeId) {
    final out = <RouteTerminus>[];
    for (final network in <String>['ddd', 'aftu']) {
      final routes = (ref.raw[network]?['routes'] as List<dynamic>?) ?? const [];
      for (final r in routes) {
        if ((r as Map<String, dynamic>)['routeId'] == routeId) {
          for (final t in (r['terminus'] as List<dynamic>)) {
            out.add(RouteTerminus.fromJson(t as Map<String, dynamic>));
          }
        }
      }
    }
    return out;
  }
}
