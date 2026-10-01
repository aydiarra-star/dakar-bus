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
  Map<String, String>? _labelByFeedRouteId;

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

  /// Libellé public DOCUMENTÉ d'un `route_id` de feed (ex. « DDD 5 » pour
  /// `DDD_05`), `null` si aucune ligne publique ne le documente.
  ///
  /// Un `route_id` interne n'est jamais converti en numéro public : seul le
  /// raccordement établi par le référentiel ([PublicBusLine.feedRouteIds]) est
  /// une preuve. Sans raccordement → `null` (l'appelant n'affiche que le mode).
  String? publicLabelForFeedRouteId(String feedRouteId) {
    final Map<String, String>? index = _labelByFeedRouteId;
    if (index == null) return null;
    return index[feedRouteId];
  }

  void _indexLabels() {
    final Map<String, String> index = <String, String>{};
    for (final PublicBusLine line in publicLines) {
      for (final String feedRouteId in line.feedRouteIds) {
        index[feedRouteId] = line.publicLabel;
      }
    }
    _labelByFeedRouteId = index;
  }

  Future<void> load() async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      _reference = PublicBusLineReference.fromJson(
          json.decode(raw) as Map<String, dynamic>);
      _loaded = true;
      _loadError = null;
      _indexLabels();
    } catch (e) {
      // Un asset illisible laisse le référentiel vide — jamais de ligne
      // fabriquée, jamais de plantage. La cause est conservée pour l'UI.
      _loadError = e.toString();
      _reference = null;
      _loaded = false;
      _labelByFeedRouteId = null;
      // ignore: avoid_print
      print('⚠️ Référentiel public des lignes AFTU/DDD indisponible : $e');
    }
  }
}
