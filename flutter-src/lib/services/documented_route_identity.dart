// CHANTIER IDENTITÉ PUBLIQUE — PR #48.
//
// RÈGLE ABSOLUE : une identité publique de ligne (opérateur + numéro public)
// n'est affichée QUE si un document l'établit. Un identifiant interne
// (`route_id`, `trip_id`, `operator`, `ddd_217`, `tata_218`) n'est JAMAIS, à
// lui seul, une preuve suffisante.
//
//   source documentée → identité validée → affichage
//   aucune preuve    → identité publique = null → repli honnête (mode réseau)
//
// Ce fichier ne contient QUE des listes d'identités publiques documentées et
// leur résolution. Il ne touche ni aux données horaires PassBi, ni aux
// parsers GTFS, ni aux calculs de minutes, ni à DakarClock, ni à DepartureInfo,
// ni aux statuts SCHEDULED / ESTIMATED / UNKNOWN, ni au moteur de routage.
//
// Distinction stricte des notions :
//   * opérateur          → « DDD », « AFTU », « Tata » ;
//   * numéro de ligne     → identifiant PUBLIC publié (« 217 ») ;
//   * type de véhicule    → « Tata » (minibus), métadonnée, pas une ligne ;
//   * numéro de véhicule  → numéro de parc (« 9003 »), jamais un numéro de ligne ;
//   * identifiant interne → `route_id` / `trip_id` GTFS, jamais affiché seul.

/// Nature de la source qui établit l'identité publique.
enum IdentitySourceType {
  /// Publication de l'opérateur national lui-même (DDD).
  operatorPublication,

  /// Site officiel de l'opérateur / de son association (AFTU).
  operatorWebsite,

  /// Source secondaire (presse), utilisée avec parcimonie pour le type de
  /// véhicule uniquement.
  secondaryPress,
}

/// Une identité publique de ligne, établie par une source documentée.
class DocumentedRouteIdentity {
  /// Opérateur normalisé : `DDD` | `AFTU` | `TATA` | `BRT` | `TER`.
  final String operator;

  /// Numéro public de ligne documenté (`null` si aucun n'est établi).
  final String? publicRouteNumber;

  /// Type de véhicule documenté (`null` si aucun n'est établi). Ce n'est PAS
  /// une ligne : un type de véhicule ne produit jamais un numéro public.
  final String? vehicleType;

  /// URL de la source documentaire.
  final String source;

  /// Nature de la source.
  final IdentitySourceType sourceType;

  /// `true` uniquement si un numéro public est réellement établi.
  final bool documented;

  const DocumentedRouteIdentity({
    required this.operator,
    required this.publicRouteNumber,
    required this.vehicleType,
    required this.source,
    required this.sourceType,
    required this.documented,
  });

  /// Identité non documentée : aucun numéro public, aucun type de véhicule.
  const DocumentedRouteIdentity.undocumented(String operator, {String? source})
      : this(
          operator: operator,
          publicRouteNumber: null,
          vehicleType: null,
          source: source ?? '',
          sourceType: IdentitySourceType.operatorPublication,
          documented: false,
        );

  @override
  String toString() => 'DocumentedRouteIdentity($operator, '
      'number=$publicRouteNumber, vehicle=$vehicleType, '
      'source=$source, documented=$documented)';
}

/// Registre des identités publiques documentées (DDD, AFTU, type de véhicule
/// Tata). Aucune identité n'y est déduite : chaque entrée est adossée à une
/// source vérifiable, citée ci-dessous.
class DocumentedRouteRegistry {
  DocumentedRouteRegistry._();

  /// Source primaire DDD — « Info voyageurs » (lignes urbaines, banlieue,
  /// dessertes des gares du TER).
  static const String demdikkSource = 'https://demdikk.sn/info-voyageurs/';

  /// Source primaire AFTU — « Infos pratiques » (lignes publiées).
  static const String aftuSource = 'https://aftu-senegal.org/infos-pratiques/';

  /// Source BRT — identité officielle SunuBRT (confirmée par le crosswalk).
  static const String brtSource = 'https://www.sunubrt.sn/';

  /// Date de consultation des deux sources ci-dessus.
  static const String sourcesCheckedAt = '2026-09-29';

  /// Identités publiques DDD documentées (`demdikk.sn/info-voyageurs/`).
  ///
  /// Lignes urbaines : 1, 4, 7, 8, 9, 10, 13, 18, 20, 23, 121.
  /// Lignes banlieue : 2, 5, 6, 11, 12, 15A, 15B, 16A, 16B, 208, 213, 217,
  ///   218, 219, 220, 221, 227, 228, 232, 233, 234.
  /// Dessertes des gares du TER : 501, 502A, 502B, 503A, 503B, 504A, 504B.
  ///
  /// Les variantes lettrées (15A/15B, 16A/16B, 502A…) sont conservées telles
  /// que publiées : un numéro « 15 » nu n'est PAS réputé documenté (impossible
  /// de savoir s'il s'agit de 15A ou 15B).
  static const Set<String> dddPublicNumbers = <String>{
    '1', '4', '7', '8', '9', '10', '13', '18', '20', '23', '121',
    '2', '5', '6', '11', '12', '15A', '15B', '16A', '16B',
    '208', '213', '217', '218', '219', '220', '221', '227', '228',
    '232', '233', '234',
    '501', '502A', '502B', '503A', '503B', '504A', '504B',
  };

  /// Identités publiques AFTU documentées (`aftu-senegal.org/infos-pratiques/`).
  ///
  /// Telles que publiées : 1–5 puis 24–89 (sans trous dans la plage publiée)
  /// et 91.
  static const Set<String> aftuPublicNumbers = <String>{
    '1', '2', '3', '4', '5',
    '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34', '35',
    '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46', '47',
    '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
    '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70', '71',
    '72', '73', '74', '75', '76', '77', '78', '79', '80', '81', '82', '83',
    '84', '85', '86', '87', '88', '89', '91',
  };

  /// Type de véhicule documenté par ligne (« AFTU 72 » et « AFTU 80 » sont des
  /// minibus Tata d'après des sources de presse). Ces associations NE sont PAS
  /// généralisées : aucune autre ligne AFTU n'est réputée Tata, et aucun Tata
  /// de l'application ne reçoit de numéro public.
  static const Map<String, String> documentedVehicleTypes = <String, String>{
    'AFTU 72': 'Tata',
    'AFTU 80': 'Tata',
  };

  /// Normalise un nom d'opérateur quelconque vers son mode court.
  static String normalizeOperator(String operator) {
    final String op = operator.toLowerCase();
    if (op.contains('dem dikk') || op == 'ddd') return 'DDD';
    if (op.contains('aftu')) return 'AFTU';
    if (op.contains('tata')) return 'TATA';
    if (op.contains('sunubrt') || op == 'brt') return 'BRT';
    if (op.contains('seter') || op == 'ter') return 'TER';
    return operator;
  }

  /// Identités publiques BRT documentées (SunuBRT, confirmées par le
  /// crosswalk `IDENTITY_OFFICIELLE`). Un identifiant `brt_b1_*` n'est jamais
  /// converti en « BRT 1 » : seule la forme « B1 »/« B2 » est publique.
  static const Set<String> brtPublicNumbers = <String>{'B1', 'B2'};

  /// Normalise un numéro public : espaces retirés, majuscules, zéros de tête
  /// retirés (« 01 » → « 1 », « 015A » → « 15A »).
  static String normalizeNumber(String raw) {
    final String s = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return s.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  }

  /// Extrait le numéro final d'un `route_id` interne (ex. « DDD_217 » → « 217 »,
  /// « AFTU_01 » → « 1 »). `null` si aucun chiffre final.
  ///
  /// Cette extraction ne FABRIQUE aucune identité : elle isole un numéro qui
  /// doit ensuite être confronté au registre documenté.
  static String? numberFromRouteId(String routeId) {
    final RegExpMatch? m = RegExp(r'(\d+)\s*$').firstMatch(routeId.trim());
    if (m == null) return null;
    final String digits = m.group(1)!;
    final int? n = int.tryParse(digits);
    return n == null ? null : '$n';
  }

  /// Numéro public DOCUMENTÉ pour `(operator, number)`, ou `null`.
  ///
  /// Aucune déduction : « operator == tata + num == 218 » ne donne JAMAIS
  /// « Tata 218 » ; « numéro de parc 9003 » ne donne JAMAIS « DDD 9003 ».
  static String? documentedPublicNumber(String operator, String? number) {
    if (number == null) return null;
    final String n = normalizeNumber(number);
    if (n.isEmpty) return null;
    switch (normalizeOperator(operator)) {
      case 'DDD':
        return dddPublicNumbers.contains(n) ? n : null;
      case 'AFTU':
        return aftuPublicNumbers.contains(n) ? n : null;
      case 'BRT':
        // Forme publique « B1 »/« B2 » uniquement (jamais « BRT 1 »).
        return brtPublicNumbers.contains(n) ? n : null;
      case 'TER':
        // Identité TER établie par le crosswalk, pas ici.
        return null;
      default:
        // TATA : AUCUNE ligne Tata n'a de numéro public publié. Un Tata ne
        // devient jamais « Tata 218 » à partir d'un identifiant interne.
        return null;
    }
  }

  /// Type de véhicule documenté pour une ligne publique, ou `null`.
  static String? documentedVehicleType(String operator, String? number) {
    final String? n = documentedPublicNumber(operator, number);
    if (n == null) return null;
    return documentedVehicleTypes['${normalizeOperator(operator)} $n'];
  }

  /// Résout l'identité publique documentée d'une ligne.
  static DocumentedRouteIdentity resolve({
    required String operator,
    String? routeNumber,
  }) {
    final String op = normalizeOperator(operator);
    final String? number = documentedPublicNumber(op, routeNumber);
    if (number == null) {
      return DocumentedRouteIdentity.undocumented(op);
    }
    final IdentitySourceType type;
    final String source;
    switch (op) {
      case 'DDD':
        type = IdentitySourceType.operatorPublication;
        source = demdikkSource;
        break;
      case 'AFTU':
        type = IdentitySourceType.operatorWebsite;
        source = aftuSource;
        break;
      case 'BRT':
        type = IdentitySourceType.operatorWebsite;
        source = brtSource;
        break;
      default:
        return DocumentedRouteIdentity.undocumented(op);
    }
    return DocumentedRouteIdentity(
      operator: op,
      publicRouteNumber: number,
      vehicleType: documentedVehicleType(op, number),
      source: source,
      sourceType: type,
      documented: true,
    );
  }

  /// Résout l'identité à partir d'un `route_id` interne de feed.
  static DocumentedRouteIdentity resolveRouteId(String operator, String routeId) {
    final String op = normalizeOperator(operator);
    // BRT : l'identité publique est « B1 »/« B2 » (et non « BRT 1 »). Un
    // route_id interne comme `brt_b1_guediawaye_petersen` ne se réduit pas au
    // numéro « 1 ».
    if (op == 'BRT') {
      final String norm = normalizeNumber(routeId);
      if (brtPublicNumbers.contains(norm)) {
        return DocumentedRouteIdentity(
          operator: 'BRT',
          publicRouteNumber: norm,
          vehicleType: null,
          source: brtSource,
          sourceType: IdentitySourceType.operatorWebsite,
          documented: true,
        );
      }
      return DocumentedRouteIdentity.undocumented(op);
    }
    return resolve(operator: operator, routeNumber: numberFromRouteId(routeId));
  }
}
