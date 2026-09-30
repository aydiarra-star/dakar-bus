/// MISSION — chargement du référentiel public des lignes AFTU / TATA / DDD.
///
/// Lit `assets/data/reference/public_bus_lines_dakar.json`, généré par
/// `scripts/build-public-bus-lines.mjs`. Chargement non bloquant : un asset
/// illisible laisse le référentiel vide (jamais de ligne fabriquée, jamais de
/// plantage). Ce service ne touche ni au TER, ni au BRT, ni aux horaires, ni au
/// routage.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/public_bus_line.dart';

class PublicBusLineCatalog {
  static const String assetPath =
      'assets/data/reference/public_bus_lines_dakar.json';

  PublicBusLineReference? _reference;
  bool _loaded = false;
  String? _loadError;

  bool get isLoaded => _loaded;
  PublicBusLineReference? get reference => _reference;

  /// Cause d'un échec de chargement (asset illisible), sinon `null`. Sert à
  /// distinguer « référentiel vide » de « référentiel non chargé » dans l'UI.
  String? get loadError => _loadError;

  /// Le référentiel est-il exploitable (chargé ET non vide) ?
  bool get isAvailable => _loaded && publicLines.isNotEmpty;

  /// Lignes publiques (DDD + AFTU) — toutes ont un numéro officiel.
  List<PublicBusLine> get publicLines =>
      _reference?.publicLines ?? const <PublicBusLine>[];

  /// Identités Tata conservées pour audit (aucun numéro public).
  List<TataIdentityAudit> get tataAudit =>
      _reference?.tataAudit ?? const <TataIdentityAudit>[];

  Future<void> load() async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      _reference = PublicBusLineReference.fromJson(
          json.decode(raw) as Map<String, dynamic>);
      _loaded = true;
      _loadError = null;
    } catch (e) {
      // Un asset illisible laisse le référentiel vide — jamais de ligne
      // fabriquée, jamais de plantage. La cause est conservée pour l'UI.
      _loadError = e.toString();
      // ignore: avoid_print
      print('⚠️ Référentiel public des lignes AFTU/DDD indisponible : $e');
    }
  }
}
