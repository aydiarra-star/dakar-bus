/// Chantier « Recherche + GPS + Routage » — référentiel de recherche unique.
///
/// La barre de recherche et le GPS doivent interroger le MÊME catalogue réseau.
/// Ce catalogue est construit à partir des données réellement disponibles :
///  * mobilités (TER, BRT, DDD, AFTU) — les feeds effectivement chargés ;
///  * lignes (route_id + libellés réels du feed) ;
///  * arrêts (nom + coordonnées exactes des arrêts réellement desservis) ;
///  * gares / terminus / pôles documentés (référentiel généré DDD/AFTU).
///
/// Aucun élément n'est fabriqué : une entrée absente des données est absente du
/// catalogue, et l'autocomplétion ne propose donc rien pour elle.
library;

import '../models/public_bus_line.dart';
import '../models/terminus_pole.dart';
import 'gtfs/passbi_source.dart';

/// Nature d'une entrée du catalogue de recherche.
enum NetworkSearchKind {
  mobility, // DDD, AFTU, BRT, TER
  line, // une ligne réelle du feed
  stop, // un arrêt réellement desservi
  station, // gare TER / station BRT du référentiel
  terminus, // terminus documenté
  pole, // pôle d'échange / gare routière documenté
  destination, // destination documentée (terminus nommé)
}

extension NetworkSearchKindLabel on NetworkSearchKind {
  String get code => switch (this) {
        NetworkSearchKind.mobility => 'MOBILITE',
        NetworkSearchKind.line => 'LIGNE',
        NetworkSearchKind.stop => 'ARRET',
        NetworkSearchKind.station => 'GARE_STATION',
        NetworkSearchKind.terminus => 'TERMINUS',
        NetworkSearchKind.pole => 'POLE',
        NetworkSearchKind.destination => 'DESTINATION',
      };
}

/// Une entrée recherchable : libellé affiché, identité source et provenance.
class NetworkSearchEntry {
  final NetworkSearchKind kind;
  final String label; // libellé affiché (donnée source, jamais inventé)
  final String network; // TER | BRT | DDD | AFTU | '' (pôles documentés)
  final String? stopId; // identifiant feed (arrêts)
  final String? routeId; // identifiant de ligne (lignes)
  final String? poleId; // identifiant de pôle (pôles/terminus)
  final double? lat;
  final double? lon;
  final String source; // provenance (feed / référentiel généré)

  const NetworkSearchEntry({
    required this.kind,
    required this.label,
    required this.network,
    required this.source,
    this.stopId,
    this.routeId,
    this.poleId,
    this.lat,
    this.lon,
  });

  /// Clé composite PassBi de l'arrêt (entrée directe du moteur de routage).
  String? get compositeKey =>
      (stopId != null && network.isNotEmpty) ? '$network:$stopId' : null;

  /// Texte de recherche normalisé (accents/casse/ponctuation repliés).
  String get normalizedLabel => PassBiSource.normalizeName(label);
}

/// Catalogue de recherche : entrées + recherche classée.
///
/// La recherche est PURE (aucun accès disque) : elle opère sur les entrées
/// déjà construites depuis les données chargées.
class NetworkSearchCatalog {
  final List<NetworkSearchEntry> entries;

  const NetworkSearchCatalog(this.entries);

  /// Nombre d'entrées d'une nature donnée (rapport et tests).
  int countOf(NetworkSearchKind kind) =>
      entries.where((e) => e.kind == kind).length;

  int get total => entries.length;

  /// Entrées d'arrêts (toutes natures confondues : arrêts, gares, stations).
  int get stopLikeCount =>
      countOf(NetworkSearchKind.stop) +
      countOf(NetworkSearchKind.station);

  /// Recherche exhaustive : toute entrée dont le libellé normalisé CONTIENT la
  /// requête normalisée. Le classement privilégie, à égalité de correspondance,
  /// les libellés qui COMMENCENT par la requête, puis les natures les plus
  /// « actionnables » (arrêts/lignes avant mobilités).
  ///
  /// Aucune correspondance approchée, aucune entrée inventée : une requête qui
  /// ne correspond à rien rend une liste vide.
  List<NetworkSearchEntry> search(String query, {int limit = 12}) {
    final String q = PassBiSource.normalizeName(query);
    if (q.length < 2) return const <NetworkSearchEntry>[];
    final List<NetworkSearchEntry> hits = <NetworkSearchEntry>[];
    for (final e in entries) {
      final String n = e.normalizedLabel;
      if (n.isEmpty || !n.contains(q)) continue;
      hits.add(e);
    }
    hits.sort((a, b) {
      final int pa = _rank(a, q);
      final int pb = _rank(b, q);
      if (pa != pb) return pa.compareTo(pb);
      final int la = a.label.length;
      final int lb = b.label.length;
      if (la != lb) return la.compareTo(lb);
      return a.label.compareTo(b.label);
    });
    return hits.take(limit).toList(growable: false);
  }

  static int _rank(NetworkSearchEntry e, String q) {
    // 0 : libellé EXACTEMENT égal à la requête (mobilité « DDD », arrêt
    //     « Petersen ») ; 1 : commence par la requête ou contient un mot égal ;
    //     2 : simple inclusion.
    final String n = e.normalizedLabel;
    final int position;
    if (n == q) {
      position = 0;
    } else if (n.startsWith(q) || n.split(' ').contains(q)) {
      position = 1;
    } else {
      position = 2;
    }
    // Nature : arrêt/ligne prioritaires pour l'action, mobilité ensuite.
    final int kindRank = switch (e.kind) {
      NetworkSearchKind.stop => 0,
      NetworkSearchKind.station => 0,
      NetworkSearchKind.line => 1,
      NetworkSearchKind.terminus => 2,
      NetworkSearchKind.pole => 2,
      NetworkSearchKind.destination => 3,
      NetworkSearchKind.mobility => 4,
    };
    return position * 10 + kindRank;
  }
}

/// Construction du catalogue depuis les données réellement chargées.
class NetworkSearchCatalogBuilder {
  NetworkSearchCatalogBuilder._();

  /// Mobilités + lignes + arrêts depuis les feeds PassBi chargés.
  ///
  /// Les arrêts proviennent de [PassBiSource.nativeStops] : uniquement des
  /// arrêts RÉELLEMENT desservis (dérivés des `stop_times`). Les lignes
  /// proviennent des `route_id` / `short_name` / `long_name` du feed.
  static List<NetworkSearchEntry> fromPassBi(PassBiSource source) {
    if (!source.isActive) return const <NetworkSearchEntry>[];
    final List<NetworkSearchEntry> out = <NetworkSearchEntry>[];
    for (final key in PassBiSource.assetFiles.keys) {
      final net = source.network(key);
      if (net == null) continue;
      // Mobilité : une entrée par réseau réellement présent dans les feeds.
      out.add(NetworkSearchEntry(
        kind: NetworkSearchKind.mobility,
        label: key,
        network: key,
        source: PassBiSource.sourceName,
      ));
      // Lignes : libellés réels du feed (aucun numéro deviné).
      for (final r in net.routes) {
        out.add(NetworkSearchEntry(
          kind: NetworkSearchKind.line,
          label: r.short.isNotEmpty ? r.short : r.id,
          network: key,
          routeId: r.id,
          source: PassBiSource.sourceName,
        ));
        if (r.long.isNotEmpty && r.long != r.short) {
          out.add(NetworkSearchEntry(
            kind: NetworkSearchKind.line,
            label: r.long,
            network: key,
            routeId: r.id,
            source: PassBiSource.sourceName,
          ));
        }
      }
      // Arrêts : nom et coordonnées exacts du feed, réellement desservis.
      for (final s in source.nativeStops(key)) {
        out.add(NetworkSearchEntry(
          kind: key == 'TER' || key == 'BRT'
              ? NetworkSearchKind.station
              : NetworkSearchKind.stop,
          label: s.name,
          network: key,
          stopId: s.stopId,
          lat: s.lat,
          lon: s.lon,
          source: PassBiSource.sourceName,
        ));
      }
    }
    return out;
  }

  /// Pôles / gares / terminus documentés (référentiel généré DDD/AFTU).
  ///
  /// Un pôle est exposé comme [NetworkSearchKind.pole] ; son rôle TERMINUS ou
  /// GARE_ROUTIERE est distingué, et le nom du pôle alimente aussi les
  /// destinations documentées (il désigne un lieu atteignable).
  static List<NetworkSearchEntry> fromPoles(List<TerminusPole> poles) {
    final List<NetworkSearchEntry> out = <NetworkSearchEntry>[];
    for (final p in poles) {
      final NetworkSearchKind kind = p.isTerminal
          ? NetworkSearchKind.terminus
          : NetworkSearchKind.pole;
      out.add(NetworkSearchEntry(
        kind: kind,
        label: p.name,
        network: '',
        poleId: p.id,
        lat: p.latitude,
        lon: p.longitude,
        source: 'Référentiel pôles & terminus (généré depuis les feeds)',
      ));
      out.add(NetworkSearchEntry(
        kind: NetworkSearchKind.destination,
        label: p.name,
        network: '',
        poleId: p.id,
        lat: p.latitude,
        lon: p.longitude,
        source: 'Référentiel pôles & terminus (généré depuis les feeds)',
      ));
    }
    return out;
  }

  /// Lignes PUBLIQUES AFTU / DDD (référentiel public, numéros officiels).
  ///
  /// Le libellé recherchable est « AFTU 26 » / « DDD 221 » — un NUMÉRO PUBLIC
  /// établi par une source, jamais un identifiant de feed. Le nom officiel et
  /// les terminus publiés complètent la recherche (mobilité, ligne, arrêt).
  /// Aucune identité Tata n'est exposée : TATA est un type de véhicule.
  static List<NetworkSearchEntry> fromPublicLines(List<PublicBusLine> lines) {
    final List<NetworkSearchEntry> out = <NetworkSearchEntry>[];
    for (final l in lines) {
      if (!l.isPublic) continue; // un numéro public est obligatoire
      final String net = l.operator.toUpperCase();
      out.add(NetworkSearchEntry(
        kind: NetworkSearchKind.line,
        label: l.publicLabel,
        network: net,
        routeId: l.feedRouteIds.isNotEmpty ? l.feedRouteIds.first : null,
        source: l.source,
      ));
      // Mobilité : la ligne publique prouve que l'opérateur est réellement
      // présent (l'entrée de mobilité du feed reste par ailleurs conservée).
      out.add(NetworkSearchEntry(
        kind: NetworkSearchKind.mobility,
        label: net,
        network: net,
        source: l.source,
      ));
      // Terminus publiés (origine / destination) = lieux atteignables.
      if (l.hasPublishedTerminus) {
        for (final String t in <String>{l.origin, l.destination}) {
          out.add(NetworkSearchEntry(
            kind: NetworkSearchKind.destination,
            label: t,
            network: net,
            source: l.source,
          ));
        }
      }
    }
    return out;
  }

  /// Assemble le catalogue complet, en dédupliquant les libellés identiques
  /// d'une même nature (les feeds DDD/AFTU partagent des noms d'arrêts).
  static NetworkSearchCatalog build({
    required List<NetworkSearchEntry> passBi,
    required List<NetworkSearchEntry> poles,
    List<NetworkSearchEntry> extra = const <NetworkSearchEntry>[],
  }) {
    final Set<String> seen = <String>{};
    final List<NetworkSearchEntry> merged = <NetworkSearchEntry>[];
    for (final e in <NetworkSearchEntry>[...passBi, ...extra, ...poles]) {
      final String key = '${e.kind.name}|${e.normalizedLabel}|${e.network}'
          '|${e.stopId ?? ''}|${e.routeId ?? ''}|${e.poleId ?? ''}';
      if (!seen.add(key)) continue;
      merged.add(e);
    }
    return NetworkSearchCatalog(List<NetworkSearchEntry>.unmodifiable(merged));
  }
}
