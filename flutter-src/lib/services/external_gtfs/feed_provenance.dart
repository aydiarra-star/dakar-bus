// Provenance et validité d'un feed externe — miroir Dart de
// lib/external-gtfs/provenance.js. Un feed est CURRENT uniquement si sa
// fenêtre de validité couvre la date interrogée ET que son statut déclaré le
// permet ; le statut déclaré ne peut jamais être amélioré par le calcul.

import 'gtfs_time.dart';

/// Catégories de source (qui publie).
class SourceTypes {
  static const String institutional = 'SOURCE_INSTITUTIONAL';
  static const String application = 'SOURCE_APPLICATION';
  static const String openData = 'OPEN_DATA';
  static const String community = 'COMMUNITY';
  static const String unknown = 'UNKNOWN';

  /// Libellé de manifeste → catégorie.
  static const Map<String, String> labels = <String, String>{
    'OFFICIAL_STATIC_CURRENT': institutional,
    'OFFICIAL_STATIC': institutional,
    'OFFICIAL_CURRENT': institutional,
    'SOURCE_INSTITUTIONAL': institutional,
    'SOURCE_APPLICATION': application,
    'SOURCE_APPLICATION_CURRENT': application,
    'OPEN_DATA': openData,
    'OPEN_DATA_CURRENT': openData,
    'COMMUNITY': community,
  };
}

class Validity {
  static const String current = 'CURRENT';
  static const String historical = 'HISTORICAL';
  static const String future = 'FUTURE';
  static const String unknown = 'UNKNOWN';
  static const List<String> all = <String>[current, historical, future, unknown];
}

/// Niveaux de provenance d'une réponse horaire (du plus au moins fiable).
class ProvenanceLevels {
  static const String officialCurrent = 'OFFICIAL_CURRENT';
  static const String officialStaticCurrent = 'OFFICIAL_STATIC_CURRENT';
  static const String sourceApplicationCurrent = 'SOURCE_APPLICATION_CURRENT';
  static const String openDataCurrent = 'OPEN_DATA_CURRENT';
  static const String estimated = 'ESTIMATED';
  static const String historicalReference = 'HISTORICAL_REFERENCE';
  static const String unknown = 'UNKNOWN';
}

/// Statut de validité d'une fenêtre [validFrom, validTo] à une date.
String classifyValidity(String? validFrom, String? validTo, String asOf) {
  if (validFrom == null || validTo == null) return Validity.unknown;
  String from;
  String to;
  String day;
  try {
    from = normalizeServiceDate(validFrom);
    to = normalizeServiceDate(validTo);
    day = normalizeServiceDate(asOf);
  } on FormatException {
    return Validity.unknown;
  }
  if (from.compareTo(to) > 0) return Validity.unknown;
  if (day.compareTo(from) < 0) return Validity.future;
  if (day.compareTo(to) > 0) return Validity.historical;
  return Validity.current;
}

class FeedValidity {
  const FeedValidity({
    required this.validFrom,
    required this.validTo,
    required this.status,
    required this.asOf,
    this.coversQueryDate,
  });

  final String? validFrom;
  final String? validTo;
  final String status;
  final String? asOf;
  final bool? coversQueryDate;
}

class FeedProvenance {
  FeedProvenance({
    required this.source,
    String? sourceType,
    String? feedVersion,
    this.validFrom,
    this.validTo,
    String? declaredStatus,
    this.authority,
    String? sourceId,
    this.network,
    this.role,
    this.license,
    this.url,
    this.sha256,
    this.retrievedAt,
    this.publishedAt,
  })  : sourceTypeLabel = sourceType ?? 'UNKNOWN',
        sourceType = SourceTypes.labels[sourceType ?? ''] ?? SourceTypes.unknown,
        feedVersion = feedVersion ?? '',
        declaredStatus = Validity.all.contains(declaredStatus)
            ? declaredStatus!
            : Validity.unknown,
        sourceId = sourceId ?? '$source:${feedVersion ?? ''}' {
    if (source.isEmpty) throw ArgumentError('FeedProvenance : source obligatoire');
  }

  /// Construit la provenance depuis une entrée de feed-manifest.json.
  factory FeedProvenance.fromManifestEntry(Map<String, dynamic> entry) {
    String? s(String key) {
      final Object? v = entry[key];
      return v?.toString();
    }

    return FeedProvenance(
      source: s('source') ?? '',
      sourceType: s('source_type'),
      feedVersion: s('feed_version') ?? s('version'),
      validFrom: s('valid_from'),
      validTo: s('valid_to'),
      declaredStatus: s('status'),
      authority: s('authority'),
      sourceId: s('id'),
      network: s('network'),
      role: s('role'),
      license: s('license'),
      url: s('url'),
      sha256: s('sha256'),
      retrievedAt: s('retrieved_at'),
      publishedAt: s('published_at'),
    );
  }

  final String source;
  final String sourceTypeLabel;
  final String sourceType;
  final String feedVersion;
  final String? validFrom;
  final String? validTo;
  final String declaredStatus;
  final String? authority;
  final String sourceId;
  final String? network;
  final String? role;
  final String? license;
  final String? url;
  final String? sha256;
  final String? retrievedAt;
  final String? publishedAt;

  /// Statut à une date : jamais meilleur que le statut déclaré.
  String validityStatusOn(String asOf) {
    final String computed = classifyValidity(validFrom, validTo, asOf);
    if (declaredStatus == Validity.historical) return Validity.historical;
    if (declaredStatus == Validity.unknown) {
      return computed == Validity.current ? Validity.unknown : computed;
    }
    return computed;
  }

  bool isCurrentOn(String asOf) => validityStatusOn(asOf) == Validity.current;

  /// La fenêtre couvre la date (indépendamment du statut déclaré).
  bool coversDate(String date) =>
      classifyValidity(validFrom, validTo, date) == Validity.current;

  FeedValidity validityOn(String asOf, [String? queryDate]) {
    String? iso;
    try {
      iso = toIsoDate(asOf);
    } on FormatException {
      iso = null;
    }
    return FeedValidity(
      validFrom: validFrom,
      validTo: validTo,
      status: validityStatusOn(asOf),
      asOf: iso,
      coversQueryDate: queryDate == null ? null : coversDate(queryDate),
    );
  }
}
