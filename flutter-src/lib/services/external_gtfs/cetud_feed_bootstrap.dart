// Amorçage de la couche CETUD CURRENT côté application (LOT 18 BIS).
//
// Tant qu'aucun feed officiel n'a été obtenu, installé (scripts/gtfs/
// install-cetud-feed.js) puis déclaré comme asset, aucun manifeste n'existe :
// sans fréquence actuelle injectée, le provider n'a aucune source actuelle ;
// l'assistant répond par le
// repli exact « Je n'ai pas actuellement de donnée horaire suffisamment fiable
// pour annoncer un départ précis. ». Aucune donnée horaire n'est embarquée par
// défaut, et PassBi (HISTORICAL) n'est jamais chargé dans l'application.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'feed_provenance.dart';
import 'frequency_source.dart';
import 'gtfs_feed.dart';
import 'gtfs_schedule_service.dart';
import 'transit_data_provider.dart';

/// Chemin d'asset du manifeste (aligné sur data/external/gtfs/cetud/).
const String cetudManifestAsset = 'assets/data/external/cetud/feed-manifest.json';
const String cetudAssetRoot = 'assets/data/external/cetud';
const String cetudManifestSchema = 'dakar-bus/external-gtfs-feed-manifest/v1';

class CetudLayerStatus {
  static const String absent = 'ABSENT';
  static const String currentInstalled = 'CURRENT_INSTALLED';
  static const String installedNotCurrent = 'INSTALLED_NOT_CURRENT';
  static const String invalid = 'INVALID';
}

class CetudBootstrapResult {
  const CetudBootstrapResult({
    required this.provider,
    required this.layerStatus,
    required this.notes,
    required this.asOf,
  });

  final TransitDataProvider provider;
  final String layerStatus;
  final List<String> notes;
  final String asOf;

  bool get hasCurrentSource => layerStatus == CetudLayerStatus.currentInstalled;
}

typedef AssetTextLoader = Future<String> Function(String key);

Future<String> _rootBundleLoader(String key) => rootBundle.loadString(key);

/// Construit le provider commun à partir du manifeste CETUD embarqué (s'il existe).
/// [frequencySources] est indépendant de cette couche : seules des sources
/// documentées CURRENT peuvent être injectées. Aucune n'est fournie par défaut.
///
/// [loadText] permet d'injecter une autre source d'assets (tests).
Future<CetudBootstrapResult> bootstrapCetudFeedLayer({
  AssetTextLoader? loadText,
  DateTime Function()? now,
  Iterable<FrequencySource> frequencySources = const <FrequencySource>[],
}) async {
  final AssetTextLoader load = loadText ?? _rootBundleLoader;
  final TransitDataProvider provider = TransitDataProvider(now: now);
  // Independently documented CURRENT sources survive an absent CETUD manifest.
  // No production frequency is supplied by default; provenance guards apply.
  for (final source in frequencySources) {
    provider.registerSource(source, role: ProviderRoles.currentFrequency);
  }
  final DateTime instant = (now ?? DateTime.now)();
  final String asOf = instant.toUtc().toIso8601String().substring(0, 10);
  final List<String> notes = <String>[];

  String? manifestText;
  try {
    manifestText = await load(cetudManifestAsset);
  } catch (_) {
    manifestText = null;
  }
  if (manifestText == null) {
    notes.add('CETUD CURRENT : ABSENT (aucun manifeste $cetudManifestAsset)');
    return CetudBootstrapResult(
      provider: provider,
      layerStatus: CetudLayerStatus.absent,
      notes: notes,
      asOf: asOf,
    );
  }

  Object? decoded;
  try {
    decoded = jsonDecode(manifestText);
  } on FormatException catch (e) {
    notes.add('manifeste illisible : ${e.message}');
    decoded = null;
  }
  final Map<String, dynamic>? manifest =
      decoded is Map<String, dynamic> ? decoded : null;
  if (manifest == null ||
      manifest['schema'] != cetudManifestSchema ||
      manifest['feeds'] is! List) {
    notes.add('manifeste invalide (schema $cetudManifestSchema attendu)');
    return CetudBootstrapResult(
      provider: provider,
      layerStatus: CetudLayerStatus.invalid,
      notes: notes,
      asOf: asOf,
    );
  }
  final List<dynamic> feeds = manifest['feeds'] as List<dynamic>;
  if (feeds.isEmpty) {
    notes.add('manifeste sans feed');
    return CetudBootstrapResult(
      provider: provider,
      layerStatus: CetudLayerStatus.absent,
      notes: notes,
      asOf: asOf,
    );
  }

  int registeredCurrent = 0;
  int registeredOther = 0;
  int failed = 0;
  for (final dynamic raw in feeds) {
    if (raw is! Map<String, dynamic>) {
      failed++;
      notes.add('entrée de manifeste invalide');
      continue;
    }
    final Map<String, dynamic> entry = raw;
    final String network = (entry['network'] ?? '').toString();
    final String id = (entry['id'] ?? network).toString();
    try {
      final FeedProvenance prov = FeedProvenance.fromManifestEntry(entry);
      final List<String> tables = entry['tables'] is List
          ? (entry['tables'] as List<dynamic>).map((dynamic t) => t.toString()).toList()
          : engineTables;
      final Map<String, String> texts = <String, String>{};
      for (final String table in tables) {
        final String key = '$cetudAssetRoot/${network.toLowerCase()}/$table.txt';
        try {
          texts[table] = await load(key);
        } catch (_) {
          // Table absente de l'asset : la validation signalera les tables requises.
        }
      }
      final GtfsFeed feed = GtfsFeed.fromTexts(texts, prov, network: network);
      final FeedValidation validation = validateFeed(feed);
      if (!validation.ok) {
        failed++;
        notes.add('$id : validation GTFS en échec (${validation.errors.join(' ; ')})');
        continue;
      }
      final String role = _roleFor(entry['role']?.toString());
      provider.registerSource(GtfsScheduleService(feed), role: role);
      final String validity = prov.validityStatusOn(asOf);
      if (role == ProviderRoles.currentOfficial && validity == Validity.current) {
        registeredCurrent++;
        notes.add('$id : CETUD CURRENT enregistré ($validity, ${feed.counts})');
      } else {
        registeredOther++;
        notes.add('$id : enregistré comme $role ($validity) — non utilisé comme source actuelle');
      }
    } catch (e) {
      failed++;
      notes.add('$id : refusé — $e');
    }
  }
  String status;
  if (registeredCurrent > 0) {
    status = CetudLayerStatus.currentInstalled;
  } else if (registeredOther > 0) {
    status = CetudLayerStatus.installedNotCurrent;
  } else if (failed > 0) {
    status = CetudLayerStatus.invalid;
  } else {
    status = CetudLayerStatus.absent;
  }
  debugPrint('CETUD feed layer: $status');
  return CetudBootstrapResult(
    provider: provider,
    layerStatus: status,
    notes: notes,
    asOf: asOf,
  );
}

/// Rôle provider d'après le manifeste : CURRENT_OFFICIAL exige status CURRENT
/// et source institutionnelle (sinon le provider lève et le feed est refusé) ;
/// tout autre rôle est traité comme référence historique.
String _roleFor(String? manifestRole) {
  switch (manifestRole) {
    case 'CURRENT_OFFICIAL':
      return ProviderRoles.currentOfficial;
    case 'CURRENT_APPLICATION':
      return ProviderRoles.currentApplication;
    case 'CURRENT_OPEN_DATA':
      return ProviderRoles.currentOpenData;
    default:
      return ProviderRoles.historicalReference;
  }
}
