/// MISSION — RÉFÉRENTIEL PUBLIC DES LIGNES AFTU / TATA / DDD.
///
/// Modèle du référentiel `assets/data/reference/public_bus_lines_dakar.json`,
/// généré par `scripts/build-public-bus-lines.mjs` depuis les sources
/// officielles (docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md) et
/// raccordé aux horaires via les feeds PassBi déjà embarqués.
///
/// Règle absolue : une ligne PUBLIQUE possède toujours un numéro officiel
/// (`operator` + `line_number` + `public_label`). Les identités techniques Tata
/// n'ont aucun numéro : elles vivent dans [PublicBusLineReference.tataAudit] et
/// ne sont jamais exposées comme lignes. Aucune donnée n'est inventée.
library;

/// Réseau d'une ligne publique. TATA est un TYPE DE VÉHICULE, jamais un
/// opérateur : il n'apparaît donc pas ici.
enum PublicLineNetwork { ddd, aftu }

extension PublicLineNetworkLabel on PublicLineNetwork {
  String get code => switch (this) {
        PublicLineNetwork.ddd => 'DDD',
        PublicLineNetwork.aftu => 'AFTU',
      };
}

/// Une ligne publique documentée : numéro officiel, terminus publiés, statuts
/// et raccordement horaire aux feeds.
class PublicBusLine {
  final String operator; // DDD | AFTU
  final String lineNumber; // numéro public officiel (jamais déduit du route_id)
  final String vehicleType; // BUS | TATA (type de véhicule, pas une ligne)
  final String publicLabel; // « AFTU 26 », « DDD 221 »
  final String origin; // terminus publié (ou « NON PUBLIÉE »)
  final String destination;
  final String identityStatus;
  final String routeStatus;
  final String stopsStatus;
  final String scheduleStatus; // dérivé du feed (raccordement réel)
  final String publishedScheduleStatus; // publié par la source (DDD), sinon ''
  final List<String> feedRouteIds; // route_id PassBi raccordés (peut être vide)
  final int tripIdsCount; // trips réels raccordés (0 si non raccordé)
  final List<String> sampleTripIds; // échantillon vérifiable de trip_id
  final List<String> directionIds; // direction_id réels (0/1)
  final int stopTimesCount; // stop_times réels de la ligne
  final bool stopSequencePresent; // stop_sequence présente dans le feed
  final bool stopSequenceStrict; // stop_sequence strictement croissante
  final int servedStopCount; // arrêts réellement desservis (0 si non raccordé)
  final String? unresolvedReason; // cause exacte si non raccordé (sinon null)
  final String source;
  final String verifiedAt;

  const PublicBusLine({
    required this.operator,
    required this.lineNumber,
    required this.vehicleType,
    required this.publicLabel,
    required this.origin,
    required this.destination,
    required this.identityStatus,
    required this.routeStatus,
    required this.stopsStatus,
    required this.scheduleStatus,
    required this.feedRouteIds,
    required this.servedStopCount,
    required this.source,
    required this.verifiedAt,
    this.publishedScheduleStatus = '',
    this.tripIdsCount = 0,
    this.sampleTripIds = const <String>[],
    this.directionIds = const <String>[],
    this.stopTimesCount = 0,
    this.stopSequencePresent = false,
    this.stopSequenceStrict = false,
    this.unresolvedReason,
  });

  /// Une ligne est recherchable/affichable dès qu'elle a un numéro public.
  bool get isPublic => lineNumber.isNotEmpty && publicLabel.isNotEmpty;

  /// La chaîne de raccordement horaire est-elle complète et vérifiable ?
  /// (route_id → trip_id → direction_id → stop_id → stop_sequence → stop_times)
  bool get isScheduleLinked =>
      feedRouteIds.isNotEmpty &&
      tripIdsCount > 0 &&
      directionIds.isNotEmpty &&
      stopTimesCount > 0 &&
      servedStopCount > 0 &&
      stopSequencePresent &&
      scheduleStatus == 'SCHEDULE_AVAILABLE';

  /// Le terminus publié est-il exploitable (≠ constat de non-publication) ?
  bool get hasPublishedTerminus =>
      origin.isNotEmpty && origin != 'NON PUBLIÉE' && destination != 'NON PUBLIÉE';

  factory PublicBusLine.fromJson(Map<String, dynamic> json) => PublicBusLine(
        operator: json['operator'] as String,
        lineNumber: json['line_number'] as String,
        vehicleType: (json['vehicle_type'] ?? '') as String,
        publicLabel: json['public_label'] as String,
        origin: (json['origin'] ?? '') as String,
        destination: (json['destination'] ?? '') as String,
        identityStatus: (json['identity_status'] ?? 'UNKNOWN') as String,
        routeStatus: (json['route_status'] ?? 'UNKNOWN') as String,
        stopsStatus: (json['stops_status'] ?? 'UNKNOWN') as String,
        scheduleStatus: (json['schedule_status'] ?? 'UNKNOWN') as String,
        publishedScheduleStatus: (json['published_schedule_status'] ?? '') as String,
        feedRouteIds:
            List<String>.from(json['feed_route_ids'] as List? ?? const []),
        tripIdsCount: (json['trip_ids_count'] as num?)?.toInt() ?? 0,
        sampleTripIds:
            List<String>.from(json['sample_trip_ids'] as List? ?? const []),
        directionIds:
            List<String>.from(json['direction_ids'] as List? ?? const []),
        stopTimesCount: (json['stop_times_count'] as num?)?.toInt() ?? 0,
        stopSequencePresent: (json['stop_sequence_present'] ?? false) as bool,
        stopSequenceStrict: (json['stop_sequence_strict'] ?? false) as bool,
        servedStopCount: (json['served_stop_count'] as num?)?.toInt() ?? 0,
        unresolvedReason: json['unresolved_reason'] as String?,
        source: (json['source'] ?? '') as String,
        verifiedAt: (json['verified_at'] ?? '') as String,
      );
}

/// Une identité Tata conservée pour audit : AUCUN numéro public, jamais rendue
/// comme une ligne.
class TataIdentityAudit {
  final String routeId;
  final String operator; // toujours AFTU (Tata = type de véhicule)
  final String identityStatus; // CONFLICTING | UNVERIFIED
  final String canonicalStatus;
  final String? internalShortName;

  const TataIdentityAudit({
    required this.routeId,
    required this.operator,
    required this.identityStatus,
    required this.canonicalStatus,
    this.internalShortName,
  });

  factory TataIdentityAudit.fromJson(Map<String, dynamic> json) =>
      TataIdentityAudit(
        routeId: json['route_id'] as String,
        operator: (json['operator'] ?? 'AFTU') as String,
        identityStatus: (json['identity_status'] ?? 'UNVERIFIED') as String,
        canonicalStatus: (json['canonical_status'] ?? '') as String,
        internalShortName: json['internal_short_name'] as String?,
      );
}

/// Le référentiel public complet (AFTU + DDD + registre d'audit Tata).
class PublicBusLineReference {
  final String schema;
  final String generatedAt;
  final Map<String, int> counts;
  final List<PublicBusLine> aftu;
  final List<PublicBusLine> ddd;
  final List<TataIdentityAudit> tataAudit;

  const PublicBusLineReference({
    required this.schema,
    required this.generatedAt,
    required this.counts,
    required this.aftu,
    required this.ddd,
    required this.tataAudit,
  });

  /// Toutes les lignes publiques (DDD + AFTU), tous réseaux confondus.
  List<PublicBusLine> get publicLines => <PublicBusLine>[...ddd, ...aftu];

  /// Lignes publiques NON raccordées aux données horaires réelles.
  /// Doit rester vide pour un chantier terminé (§6/§15/§19).
  List<PublicBusLine> get unresolvedPublicLines =>
      publicLines.where((l) => !l.isScheduleLinked).toList(growable: false);

  factory PublicBusLineReference.fromJson(Map<String, dynamic> json) {
    List<PublicBusLine> parse(String key) => ((json[key] as List?) ?? const [])
        .map((e) => PublicBusLine.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return PublicBusLineReference(
      schema: (json['schema'] ?? '') as String,
      generatedAt: (json['generated_at'] ?? '') as String,
      counts: <String, int>{
        for (final e in ((json['counts'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      },
      aftu: parse('aftu'),
      ddd: parse('ddd'),
      tataAudit: ((json['tata_audit'] as List?) ?? const [])
          .map((e) => TataIdentityAudit.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
