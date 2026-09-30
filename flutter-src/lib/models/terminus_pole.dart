/// Chantier DDD / AFTU / TATA — modèle des pôles et terminus documentés.
///
/// Ce modèle ne touche NI au TER, NI au BRT, NI aux horaires, NI au routage :
/// il expose uniquement la cartographie DDD/AFTU dérivée des feeds PassBi
/// (`assets/data/reference/ddd_aftu_poles_terminus.json`).
///
/// Distinction stricte des concepts (§10) : un même lieu peut être
/// TERMINUS, TRANSIT, GARE_ROUTIERE et POLE_ECHANGE — les rôles sont
/// cumulables et jamais fusionnés.
library;

/// Rôle d'un pôle vis-à-vis des lignes DDD/AFTU.
enum PoleRole {
  /// Une ligne DDD/AFTU commence ou finit réellement à ce pôle.
  terminus,

  /// Des lignes DDD/AFTU desservent un arrêt du pôle SANS y terminer.
  transit,

  /// Gare routière documentée.
  gareRoutiere,

  /// Pôle d'échange documenté.
  poleEchange,
}

/// Statut de documentation d'un pôle ou d'un terminus.
enum PoleStatus {
  /// Terminus réel des trips du feed ET pôle documenté.
  confirmed,

  /// Desserte réelle en transit, sans terminus DDD/AFTU rattaché.
  partial,

  /// Le libellé officiel nomme un terminus que le feed ne dessert pas.
  conflicting,

  /// Aucune desserte DDD/AFTU documentée dans le feed.
  unknown,
}

extension PoleStatusLabel on PoleStatus {
  String toLabel() {
    switch (this) {
      case PoleStatus.confirmed:
        return 'CONFIRMED';
      case PoleStatus.partial:
        return 'PARTIAL';
      case PoleStatus.conflicting:
        return 'CONFLICTING';
      case PoleStatus.unknown:
        return 'UNKNOWN';
    }
  }

  /// Absent ou inconnu → [PoleStatus.unknown] (jamais `confirmed`).
  static PoleStatus fromString(String? value) {
    switch (value) {
      case 'CONFIRMED':
        return PoleStatus.confirmed;
      case 'PARTIAL':
        return PoleStatus.partial;
      case 'CONFLICTING':
        return PoleStatus.conflicting;
      default:
        return PoleStatus.unknown;
    }
  }
}

/// Statut de vérification des coordonnées d'un pôle.
enum PoleCoordinatesStatus {
  /// Coordonnée du pôle confondue avec un arrêt terminus réel du feed.
  confirmedVsFeed,

  /// Le pôle n'a aucun arrêt terminus dans le feed : coordonnée déclarée
  /// conservée telle quelle, jamais certifiée.
  unverified,

  /// La coordonnée déclarée du référentiel projet est trop éloignée de
  /// l'ancrage feed : contradiction conservée, non corrigée.
  conflicting,

  /// Coordonnée rejetée (hors bornes Dakar / océan / 0,0).
  rejected,
}

extension PoleCoordinatesStatusLabel on PoleCoordinatesStatus {
  String toLabel() {
    switch (this) {
      case PoleCoordinatesStatus.confirmedVsFeed:
        return 'CONFIRMED_VS_FEED';
      case PoleCoordinatesStatus.unverified:
        return 'UNVERIFIED';
      case PoleCoordinatesStatus.conflicting:
        return 'CONFLICTING';
      case PoleCoordinatesStatus.rejected:
        return 'REJECTED';
    }
  }

  static PoleCoordinatesStatus fromString(String? value) {
    switch (value) {
      case 'CONFIRMED_VS_FEED':
        return PoleCoordinatesStatus.confirmedVsFeed;
      case 'CONFLICTING':
        return PoleCoordinatesStatus.conflicting;
      case 'REJECTED':
        return PoleCoordinatesStatus.rejected;
      default:
        return PoleCoordinatesStatus.unverified;
    }
  }
}

/// Un arrêt terminus réel du feed, rattaché à un pôle.
class PoleTerminusStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final List<String> routeIds;

  const PoleTerminusStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.routeIds,
  });

  factory PoleTerminusStop.fromJson(Map<String, dynamic> json) =>
      PoleTerminusStop(
        stopId: json['stopId'] as String,
        stopName: json['stopName'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        routeIds: List<String>.from(json['routes'] as List),
      );
}

/// Terminus (départ ou arrivée) d'une ligne à un pôle.
class RouteTerminus {
  final String poleId;
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;

  /// `depart` ou `arrivee`.
  final String role;

  /// `direction_id` réel du feed ('' si absent).
  final String directionId;

  const RouteTerminus({
    required this.poleId,
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.role,
    required this.directionId,
  });

  factory RouteTerminus.fromJson(Map<String, dynamic> json) => RouteTerminus(
        poleId: (json['pole'] ?? '') as String,
        stopId: json['stopId'] as String,
        stopName: json['stopName'] as String,
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lon'] as num).toDouble(),
        role: json['role'] as String,
        directionId: (json['directionId'] ?? '') as String,
      );
}

/// Pôle d'échange / gare routière / terminus documenté.
class TerminusPole {
  final String id;
  final String name;
  final List<String> roles;
  final bool discovered;
  final double latitude;
  final double longitude;
  final PoleCoordinatesStatus coordinatesStatus;
  final List<String> dddRoutes;
  final List<String> aftuRoutes;
  final List<String> dddTransitRoutes;
  final List<String> aftuTransitRoutes;
  final List<PoleTerminusStop> terminusStops;
  final PoleStatus status;
  final String? note;

  const TerminusPole({
    required this.id,
    required this.name,
    required this.roles,
    required this.discovered,
    required this.latitude,
    required this.longitude,
    required this.coordinatesStatus,
    required this.dddRoutes,
    required this.aftuRoutes,
    required this.dddTransitRoutes,
    required this.aftuTransitRoutes,
    required this.terminusStops,
    required this.status,
    this.note,
  });

  factory TerminusPole.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as Map<String, dynamic>;
    return TerminusPole(
      id: json['id'] as String,
      name: json['name'] as String,
      roles: List<String>.from(json['roles'] as List),
      discovered: json['discovered'] == true,
      latitude: (coords['lat'] as num).toDouble(),
      longitude: (coords['lon'] as num).toDouble(),
      coordinatesStatus:
          PoleCoordinatesStatusLabel.fromString(json['coordinatesStatus'] as String?),
      dddRoutes: List<String>.from(json['dddRoutes'] as List),
      aftuRoutes: List<String>.from(json['aftuRoutes'] as List),
      dddTransitRoutes: List<String>.from(json['dddTransitRoutes'] as List),
      aftuTransitRoutes: List<String>.from(json['aftuTransitRoutes'] as List),
      terminusStops: (json['terminalStops'] as List)
          .map((e) => PoleTerminusStop.fromJson(e as Map<String, dynamic>))
          .toList(),
      status: PoleStatusLabel.fromString(json['status'] as String?),
      note: json['note'] as String?,
    );
  }

  bool get isTerminal => roles.contains('TERMINUS');
  bool get isTransit => roles.contains('TRANSIT');

  /// Une ligne ne peut être affichée comme terminant ici que si elle figure
  /// dans [dddRoutes] / [aftuRoutes] — jamais parce qu'elle passe à proximité.
  bool terminatesHere(String routeId) =>
      dddRoutes.contains(routeId) || aftuRoutes.contains(routeId);
}

/// Référentiel pôles & terminus DDD/AFTU (chargé depuis l'asset généré).
class DddAftuTerminusReference {
  final String generatedAt;
  final List<TerminusPole> poles;
  final Map<String, dynamic> raw;

  const DddAftuTerminusReference({
    required this.generatedAt,
    required this.poles,
    required this.raw,
  });

  factory DddAftuTerminusReference.fromJson(Map<String, dynamic> json) =>
      DddAftuTerminusReference(
        generatedAt: (json['generatedAt'] ?? '') as String,
        poles: (json['poles'] as List)
            .map((e) => TerminusPole.fromJson(e as Map<String, dynamic>))
            .toList(),
        raw: json,
      );

  List<TerminusPole> get terminals =>
      poles.where((p) => p.isTerminal).toList();

  TerminusPole? poleById(String id) {
    for (final p in poles) {
      if (p.id == id) return p;
    }
    return null;
  }
}
