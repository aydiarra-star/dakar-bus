/// Chantier « Recherche + GPS + Routage » — le GPS comme entrée directe du
/// routage.
///
/// Objet : à partir d'une position GPS, trouver **un ensemble** de points
/// d'accès réels du réseau (arrêts DDD, AFTU, BRT, gares TER, terminus
/// documentés), sans jamais se limiter à un seul arrêt ni à une correspondance
/// textuelle de nom.
///
/// Règles (aucune donnée inventée) :
///  * les points d'accès sont des arrêts RÉELLEMENT desservis par le feed
///    ([PassBiSource.nativeStops] : dérivés des `stop_times`), avec leurs
///    coordonnées exactes ;
///  * plusieurs candidats sont retenus par réseau, de sorte qu'aucune mobilité
///    n'est exclue parce qu'une autre possède plus de données (§11) ;
///  * la proximité géographique sert UNIQUEMENT à choisir les points d'entrée
///    et de sortie. Elle ne crée jamais une correspondance : le moteur de
///    routage continue d'exiger un `stop_sequence` réel ou un lien de
///    transfert DOCUMENTÉ (`TransferLink.isDocumented`).
library;

import 'dart:math' as math;

import 'passbi_source.dart';

/// Un point d'accès au réseau : un arrêt réel du feed et sa distance à
/// l'usager.
class NetworkAccessPoint {
  final String network; // TER | BRT | DDD | AFTU
  final String stopId; // identifiant feed exact
  final String name; // nom d'arrêt exact du feed
  final double lat;
  final double lon;
  final double distanceMeters; // distance à la position de l'usager
  final int routeCount; // lignes qui desservent réellement cet arrêt

  const NetworkAccessPoint({
    required this.network,
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    required this.routeCount,
  });

  /// Clé composite du moteur (`NET:id`), identique au crosswalk.
  String get compositeKey => '$network:$stopId';

  /// Temps de marche depuis l'usager (secondes) — 80 m/min, minimum 1 minute.
  int get walkSeconds => NetworkAccess.walkSecondsFor(distanceMeters);
}

/// Politique d'accès (bornes documentées, déterministes).
class NetworkAccess {
  NetworkAccess._();

  /// Vitesse de marche retenue pour convertir une distance en temps — même
  /// valeur que le moteur de routage (80 m/min).
  static const double walkMetersPerMinute = 80.0;

  /// Rayon de recherche des points d'accès autour de l'usager (mètres).
  /// Volontairement plus large que la proximité d'affichage de l'Explorer :
  /// un arrêt à 2 km peut mener à un trajet bien plus court qu'un arrêt à
  /// 200 m (règle « proximité ≠ meilleur trajet »).
  static const double defaultRadiusMeters = 2500.0;

  /// Nombre maximal de points d'accès retenus par réseau. Empêche un réseau
  /// dense (DDD/AFTU) d'évincer à lui seul les autres mobilités.
  static const int maxPerNetwork = 5;

  /// Nombre maximal de points d'accès retenus au total.
  static const int maxPoints = 15;

  /// Temps de marche (secondes) pour une distance en mètres.
  static int walkSecondsFor(double meters) {
    final int minutes = (meters / walkMetersPerMinute).floor();
    return (minutes < 1 ? 1 : minutes) * 60;
  }

  /// Distance orthodromique (mètres), même rayon terrestre que
  /// `DistanceHelper.haversineMeters` (6 371 008,8 m).
  static double haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371008.8;
    final double p1 = lat1 * math.pi / 180.0;
    final double p2 = lat2 * math.pi / 180.0;
    final double dp = (lat2 - lat1) * math.pi / 180.0;
    final double dl = (lon2 - lon1) * math.pi / 180.0;
    final double a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.sqrt(a > 1 ? 1 : a));
  }
}

/// Index d'accès au réseau : recherche, pour une position donnée, l'ensemble
/// des arrêts réels accessibles à pied, réseau par réseau.
///
/// La recherche utilise les COORDONNÉES réelles des arrêts (aucune
/// correspondance textuelle) et retourne TOUS les candidats pertinents, jamais
/// un seul arrêt « le plus proche ».
class NetworkAccessIndex {
  final PassBiSource source;

  /// Rayon et bornes de sélection (paramétrables pour les tests).
  final double radiusMeters;
  final int maxPerNetwork;
  final int maxPoints;

  NetworkAccessIndex(
    this.source, {
    this.radiusMeters = NetworkAccess.defaultRadiusMeters,
    this.maxPerNetwork = NetworkAccess.maxPerNetwork,
    this.maxPoints = NetworkAccess.maxPoints,
  });

  /// Points d'accès autour de [lat]/[lon] : arrêts réels des quatre feeds,
  /// filtrés par le rayon, plafonnés par réseau puis globalement, triés par
  /// distance croissante.
  ///
  /// Aucun arrêt n'est fabriqué : la liste provient de
  /// [PassBiSource.nativeStops], elle-même dérivée des `stop_times`.
  List<NetworkAccessPoint> accessPointsNear({
    required double lat,
    required double lon,
  }) {
    if (!source.isActive) return const <NetworkAccessPoint>[];
    final List<NetworkAccessPoint> selected = <NetworkAccessPoint>[];
    for (final networkKey in PassBiSource.assetFiles.keys) {
      final List<NetworkAccessPoint> perNetwork = <NetworkAccessPoint>[];
      for (final ref in source.nativeStops(networkKey)) {
        final double d =
            NetworkAccess.haversineMeters(lat, lon, ref.lat, ref.lon);
        if (d > radiusMeters) continue;
        perNetwork.add(NetworkAccessPoint(
          network: ref.network,
          stopId: ref.stopId,
          name: ref.name,
          lat: ref.lat,
          lon: ref.lon,
          distanceMeters: d,
          routeCount: ref.routeCount,
        ));
      }
      perNetwork
          .sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
      selected.addAll(perNetwork.take(maxPerNetwork));
    }
    selected.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return List<NetworkAccessPoint>.unmodifiable(
        selected.take(maxPoints).toList());
  }

  /// Clés composites des points d'accès autour d'une position — entrée directe
  /// du moteur de routage (`planJourneys(fromKeys: …)`).
  Set<String> accessKeysNear({required double lat, required double lon}) =>
      accessPointsNear(lat: lat, lon: lon)
          .map((p) => p.compositeKey)
          .toSet();

  /// Réseaux réellement accessibles autour d'une position (au moins un arrêt
  /// dans le rayon). Sert à répondre « quelles mobilités puis-je prendre ? ».
  Set<String> networksNear({required double lat, required double lon}) =>
      accessPointsNear(lat: lat, lon: lon).map((p) => p.network).toSet();
}
