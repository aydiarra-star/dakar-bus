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
//   * type de véhicule    → « TATA » (minibus), métadonnée, pas une ligne ;
//   * numéro de véhicule  → numéro de parc (« 9003 »), jamais un numéro de ligne ;
//   * identifiant interne → `route_id` / `trip_id` GTFS, jamais affiché seul.
//
// ---------------------------------------------------------------------------
// CHANTIER TATA (PR #48, lot 2) — HIÉRARCHIE DES SOURCES
// ---------------------------------------------------------------------------
// Niveau 1 — source officielle : CETUD / AFTU / données officielles de mobilité.
//   `cetud.sn/reseaux-de-transport/*`, `aftu-senegal.org/infos-pratiques/`.
// Niveau 2 — applications de mobilité : PassBi / Bus Bii.
//   Une association TATA n'est enregistrée comme preuve que si ces applications
//   exposent EXPLICITEMENT une ligne TATA (numéro et/ou arrêts).
// Niveau 3 — sources secondaires (covoiturage.sn, Scribd) : CANDIDATURE
//   uniquement, jamais transformée en vérité officielle.
//
// CONSTAT PROUVÉ (cet audit, 2026-09-29) : aucune source admissible ne documente
// un NUMÉRO de ligne TATA.
//   * AFTU/CETUD publient des numéros de ligne AFTU ; ils ne nomment aucun
//     véhicule TATA (le référentiel interne le note : « minibus des GIE AFTU »).
//   * Le feed PassBi AFTU expose 73 routes (`id`, `short`, `long`, `type`) sans
//     champ `vehicle_type`/`network`/`agency` ; aucune route ne porte « tata ».
//     `PassBiSource.tataMentions()` est vide sur tous les feeds chargés.
//   * Bus Bii (busbii.com) déclare des itinéraires « TATA » mais n'expose
//     aucune API/route numérotée publiquement consultable.
// ⇒ TATA reste un TYPE DE VÉHICULE. Aucune ligne TATA n'est CONFIRMED : le
//   registre ci-dessous conserve des CANDIDATS (niveau 3) à des fins de
//   cross-check, sans jamais les afficher comme « Tata XX ».

/// Nature de la source qui établit l'identité publique.
enum IdentitySourceType {
  /// Publication de l'opérateur national lui-même (DDD).
  operatorPublication,

  /// Site officiel de l'opérateur / de son association (AFTU).
  operatorWebsite,

  /// Publication officielle de l'autorité organisatrice (CETUD).
  officialAuthority,

  /// Application de mobilité (PassBi, Bus Bii) exposant explicitement la ligne.
  officialMobilityApp,

  /// Source secondaire (covoiturage.sn, Scribd) — cross-check, jamais preuve.
  secondaryCrossCheck,

  /// Source secondaire (presse), utilisée avec parcimonie pour le type de
  /// véhicule uniquement.
  secondaryPress,
}

/// Statut de documentation d'une identité publique.
///
/// Nommé `PublicIdentityStatus` (et non `IdentityStatus`) pour ne pas entrer en
/// collision avec l'énumération homonyme de `departure_info.dart`, qui qualifie
/// le STATUT D'UNE LIGNE dans le crosswalk, notion différente.
enum PublicIdentityStatus {
  /// Identité corroborée par une source admissible (niveau 1 ou 2).
  documented,

  /// Correspondance établie par une source secondaire (niveau 3) uniquement.
  /// Conserve la donnée pour validation, ne s'affiche JAMAIS comme identité.
  candidate,

  /// Aucune source, ou sources non concordantes.
  unconfirmed,
}

/// Nature de l'élément qui adosse une identité.
enum IdentityEvidence {
  /// Publication officielle (CETUD / AFTU / opérateur).
  officialPublication,

  /// Application de mobilité exposant explicitement la ligne.
  mobilityApp,

  /// Concordance de terminus (source secondaire) — candidature.
  terminusCrossCheck,

  /// Observation terrain non vérifiée.
  fieldObservation,

  /// Aucun élément.
  none,
}

/// Candidature TATA issue de la liste secondaire (niveau 3).
///
/// Une candidature n'est PAS une identité : elle sert au cross-check avec les
/// sources admissibles (CETUD/AFTU/PassBi/Bus Bii). Elle n'est jamais affichée
/// comme « Tata XX ».
class TataLineCandidate {
  /// Numéro de ligne AFTU correspondant (1–5, 24–89, 91).
  final String routeNumber;

  /// Opérateur déduit de la source primaire — TOUJOURS « AFTU » ici : TATA
  /// n'est jamais un opérateur.
  final String operator;

  /// Terminus A de la liste secondaire (cross-check, non officiel).
  final String secondaryTerminusA;

  /// Terminus B de la liste secondaire (cross-check, non officiel).
  final String secondaryTerminusB;

  /// Terminus A tel que publié par la source AFTU (feed PassBi AFTU).
  final String feedTerminusA;

  /// Terminus B tel que publié par la source AFTU (feed PassBi AFTU).
  final String feedTerminusB;

  /// Élément d'adossement (jamais `officialPublication` : aucune source
  /// officielle ne nomme un véhicule TATA).
  final IdentityEvidence evidence;

  const TataLineCandidate({
    required this.routeNumber,
    required this.operator,
    required this.secondaryTerminusA,
    required this.secondaryTerminusB,
    required this.feedTerminusA,
    required this.feedTerminusB,
    required this.evidence,
  });
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

  /// Statut de documentation de l'identité.
  final PublicIdentityStatus status;

  /// Date de vérification (`YYYY-MM-DD`), vide si non applicable.
  final String verifiedAt;

  /// Niveau de confiance : `HIGH` | `MEDIUM` | `LOW` | `''`.
  final String confidence;

  const DocumentedRouteIdentity({
    required this.operator,
    required this.publicRouteNumber,
    required this.vehicleType,
    required this.source,
    required this.sourceType,
    this.status = PublicIdentityStatus.documented,
    this.verifiedAt = '',
    this.confidence = '',
  });

  /// `true` uniquement si un numéro public est réellement établi.
  bool get documented => status == PublicIdentityStatus.documented;

  /// Identité non documentée : aucun numéro public, aucun type de véhicule.
  const DocumentedRouteIdentity.undocumented(String operator, {String? source})
      : this(
          operator: operator,
          publicRouteNumber: null,
          vehicleType: null,
          source: source ?? '',
          sourceType: IdentitySourceType.operatorPublication,
          status: PublicIdentityStatus.unconfirmed,
        );

  /// Identité CANDIDATE : correspondance secondaire, jamais affichée.
  const DocumentedRouteIdentity.candidate({
    required String operator,
    required String source,
  }) : this(
          operator: operator,
          publicRouteNumber: null,
          vehicleType: null,
          source: source,
          sourceType: IdentitySourceType.secondaryCrossCheck,
          status: PublicIdentityStatus.candidate,
        );

  @override
  String toString() => 'DocumentedRouteIdentity($operator, '
      'number=$publicRouteNumber, vehicle=$vehicleType, '
      'source=$source, status=$status)';
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

  /// Source officielle CETUD — autorité organisatrice (référence réseau).
  static const String cetudSource = 'https://cetud.sn/reseaux-de-transport/';

  /// Source niveau 3 — liste secondaire de correspondances TATA (covoiturage.sn,
  /// Scribd). Cross-check uniquement : ne constitue JAMAIS une preuve.
  static const String tataSecondaryListSource =
      'https://covoiturage.sn/ (liste TATA, recoupée Scribd) — NON OFFICIEL';

  /// Source niveau 2 — application de mobilité Bus Bii : déclare des itinéraires
  /// « TATA » mais n'expose aucun numéro de ligne publiquement consultable.
  static const String busBiiSource = 'https://www.busbii.com/';

  /// Date de consultation des sources ci-dessus.
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

  /// Type de véhicule documenté par ligne. **Aucune entrée active** : voir le
  /// constat ci-dessous.
  ///
  /// Constat d'audit (2026-09-29) : aucune source admissible (CETUD/AFTU,
  /// PassBi, Bus Bii) n'établit qu'une ligne AFTU précise est exploitée en
  /// minibus TATA.
  ///   * L'ITF/ILO (2020) atteste que « Tata » = marque/catégorie de
  ///     l'écosystème AFTU, sans nommer de numéro de ligne.
  ///   * Le feed PassBi AFTU ne comporte aucun champ `vehicle_type`.
  ///   * Le référentiel interne et l'audit 3A concluent : « aucune
  ///     correspondance officielle confirmée » (0 `CONFIRMED`).
  /// La carte reste donc VIDE : TATA demeure un type de véhicule, jamais
  /// attaché à un numéro faute de preuve. Les correspondances candidates sont
  /// conservées à part dans [tataCandidates] (niveau 3, cross-check).
  static const Map<String, String> documentedVehicleTypes = <String, String>{};

  /// Correspondances candidates TATA ↔ lignes AFTU (niveau 3, cross-check).
  ///
  /// Chaque entrée croise la liste secondaire (terminus « Tata N ») avec les
  /// terminus PUBLIÉS par AFTU (feed PassBi AFTU, champ `long`). Deux terminus
  /// concordants → [IdentityEvidence.terminusCrossCheck] ; sinon
  /// [IdentityEvidence.none].
  ///
  /// Ces entrées NE SONT PAS des identités : `operator` vaut toujours `AFTU`
  /// (TATA n'est jamais un opérateur), et aucune n'est CONFIRMED faute de
  /// source admissible nommant un véhicule TATA. Elles servent uniquement au
  /// cross-check CETUD/AFTU/PassBi/Bus Bii et ne s'affichent jamais « Tata XX ».
  static const Map<String, TataLineCandidate> tataCandidates =
      <String, TataLineCandidate>{
    '1': TataLineCandidate(
        routeNumber: '1',
        operator: 'AFTU',
        secondaryTerminusA: 'HLM Grand Yoff',
        secondaryTerminusB: 'Lat Dior',
        feedTerminusA: 'HLM-GR-YOFF',
        feedTerminusB: 'LAT-DIOR',
        evidence: IdentityEvidence.terminusCrossCheck),
    '2': TataLineCandidate(
        routeNumber: '2',
        operator: 'AFTU',
        secondaryTerminusA: 'Parcelles Assainies',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Parcelles-Assainies',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '3': TataLineCandidate(
        routeNumber: '3',
        operator: 'AFTU',
        secondaryTerminusA: 'Yoff Village',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Petersen',
        feedTerminusB: 'Yoff',
        evidence: IdentityEvidence.terminusCrossCheck),
    '4': TataLineCandidate(
        routeNumber: '4',
        operator: 'AFTU',
        secondaryTerminusA: 'Yoff Village',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Petersen',
        feedTerminusB: 'Yoff',
        evidence: IdentityEvidence.terminusCrossCheck),
    '5': TataLineCandidate(
        routeNumber: '5',
        operator: 'AFTU',
        secondaryTerminusA: 'Parcelles Assainies',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Parcelles-Assainies',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '24': TataLineCandidate(
        routeNumber: '24',
        operator: 'AFTU',
        secondaryTerminusA: 'Guediawaye',
        secondaryTerminusB: 'UCAD',
        feedTerminusA: 'Notaire',
        feedTerminusB: 'UCAD',
        evidence: IdentityEvidence.terminusCrossCheck),
    '25': TataLineCandidate(
        routeNumber: '25',
        operator: 'AFTU',
        secondaryTerminusA: 'Parcelles Assainies',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Parcelle-Assainies',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '26': TataLineCandidate(
        routeNumber: '26',
        operator: 'AFTU',
        secondaryTerminusA: 'Parcelles Assainies',
        secondaryTerminusB: 'Poste Thiaroye',
        feedTerminusA: 'Parcelle-Assainies',
        feedTerminusB: 'Poste-Thiaroye',
        evidence: IdentityEvidence.terminusCrossCheck),
    '27': TataLineCandidate(
        routeNumber: '27',
        operator: 'AFTU',
        secondaryTerminusA: 'Marche Boubess',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Guediawaye MB',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '28': TataLineCandidate(
        routeNumber: '28',
        operator: 'AFTU',
        secondaryTerminusA: 'Hamo VI',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Hamo VI',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '29': TataLineCandidate(
        routeNumber: '29',
        operator: 'AFTU',
        secondaryTerminusA: 'Cite Naons Unis',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Malibu',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '30': TataLineCandidate(
        routeNumber: '30',
        operator: 'AFTU',
        secondaryTerminusA: 'Gadaye',
        secondaryTerminusB: 'Colobane',
        feedTerminusA: 'Colobane',
        feedTerminusB: 'Gadaye',
        evidence: IdentityEvidence.terminusCrossCheck),
    '31': TataLineCandidate(
        routeNumber: '31',
        operator: 'AFTU',
        secondaryTerminusA: 'Terminus Texaco',
        secondaryTerminusB: 'Terminus Sham',
        feedTerminusA: 'Sham',
        feedTerminusB: 'Thiaroye-kao',
        evidence: IdentityEvidence.terminusCrossCheck),
    '32': TataLineCandidate(
        routeNumber: '32',
        operator: 'AFTU',
        secondaryTerminusA: 'Guediawaye',
        secondaryTerminusB: 'Terminus Sham',
        feedTerminusA: 'Daroukhane',
        feedTerminusB: 'Sham',
        evidence: IdentityEvidence.terminusCrossCheck),
    '33': TataLineCandidate(
        routeNumber: '33',
        operator: 'AFTU',
        secondaryTerminusA: 'Daroukhane',
        secondaryTerminusB: 'Colobane',
        feedTerminusA: 'Colobane',
        feedTerminusB: 'Daroukane',
        evidence: IdentityEvidence.terminusCrossCheck),
    '34': TataLineCandidate(
        routeNumber: '34',
        operator: 'AFTU',
        secondaryTerminusA: 'Nord Foire',
        secondaryTerminusB: 'Lat Dior',
        feedTerminusA: 'LAT-DIOR',
        feedTerminusB: 'Nord-Foire',
        evidence: IdentityEvidence.terminusCrossCheck),
    '36': TataLineCandidate(
        routeNumber: '36',
        operator: 'AFTU',
        secondaryTerminusA: 'Daroukhane',
        secondaryTerminusB: 'Ngor Village',
        feedTerminusA: 'Daroukhane',
        feedTerminusB: 'Ngor',
        evidence: IdentityEvidence.terminusCrossCheck),
    '37': TataLineCandidate(
        routeNumber: '37',
        operator: 'AFTU',
        secondaryTerminusA: 'Petersen',
        secondaryTerminusB: 'Guediawaye',
        feedTerminusA: 'APIX',
        feedTerminusB: 'UCAD',
        evidence: IdentityEvidence.none),
    '38': TataLineCandidate(
        routeNumber: '38',
        operator: 'AFTU',
        secondaryTerminusA: 'Cite des Enseignants',
        secondaryTerminusB: 'Sham',
        feedTerminusA: 'Guediawaye',
        feedTerminusB: 'Sahm',
        evidence: IdentityEvidence.terminusCrossCheck),
    '39': TataLineCandidate(
        routeNumber: '39',
        operator: 'AFTU',
        secondaryTerminusA: 'Terminus Diamalaye',
        secondaryTerminusB: 'Gare Lat Dior',
        feedTerminusA: 'Diamalaye',
        feedTerminusB: 'Lat Dior',
        evidence: IdentityEvidence.terminusCrossCheck),
    '40': TataLineCandidate(
        routeNumber: '40',
        operator: 'AFTU',
        secondaryTerminusA: 'Grand Mbao',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Mbao',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '41': TataLineCandidate(
        routeNumber: '41',
        operator: 'AFTU',
        secondaryTerminusA: 'Guediawaye Madial',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Guediawaye',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '42': TataLineCandidate(
        routeNumber: '42',
        operator: 'AFTU',
        secondaryTerminusA: 'Corniche Guediawaye',
        secondaryTerminusB: 'Ouakam',
        feedTerminusA: 'Gadaye',
        feedTerminusB: 'Ouakam',
        evidence: IdentityEvidence.terminusCrossCheck),
    '43': TataLineCandidate(
        routeNumber: '43',
        operator: 'AFTU',
        secondaryTerminusA: 'Yeumbeul Sud',
        secondaryTerminusB: 'Ouakam Cite Avion',
        feedTerminusA: 'Comico',
        feedTerminusB: 'Ouakam',
        evidence: IdentityEvidence.terminusCrossCheck),
    '44': TataLineCandidate(
        routeNumber: '44',
        operator: 'AFTU',
        secondaryTerminusA: 'Ouakam Baye',
        secondaryTerminusB: 'Grand Mbao Extension',
        feedTerminusA: 'Mbao',
        feedTerminusB: 'Ouakam',
        evidence: IdentityEvidence.terminusCrossCheck),
    '46': TataLineCandidate(
        routeNumber: '46',
        operator: 'AFTU',
        secondaryTerminusA: 'Guediawaye Notaire',
        secondaryTerminusB: 'Lat Dior',
        feedTerminusA: 'Guediawaye',
        feedTerminusB: 'Lat Dior',
        evidence: IdentityEvidence.terminusCrossCheck),
    '47': TataLineCandidate(
        routeNumber: '47',
        operator: 'AFTU',
        secondaryTerminusA: 'Almadies',
        secondaryTerminusB: 'Lat Dior',
        feedTerminusA: 'Lat Dior',
        feedTerminusB: 'Almadies',
        evidence: IdentityEvidence.terminusCrossCheck),
    '48': TataLineCandidate(
        routeNumber: '48',
        operator: 'AFTU',
        secondaryTerminusA: 'Cite Serigne Mansour',
        secondaryTerminusB: 'Lat Dior',
        feedTerminusA: 'Lat Dior',
        feedTerminusB: 'Rufisque',
        evidence: IdentityEvidence.terminusCrossCheck),
    '49': TataLineCandidate(
        routeNumber: '49',
        operator: 'AFTU',
        secondaryTerminusA: 'Gadaye',
        secondaryTerminusB: 'Ngor Village',
        feedTerminusA: 'Gadaye',
        feedTerminusB: 'Ngor',
        evidence: IdentityEvidence.terminusCrossCheck),
    '50': TataLineCandidate(
        routeNumber: '50',
        operator: 'AFTU',
        secondaryTerminusA: 'Malika',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Malicka',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '51': TataLineCandidate(
        routeNumber: '51',
        operator: 'AFTU',
        secondaryTerminusA: 'Plan Jaxaay 1',
        secondaryTerminusB: 'Gare des Baux Maraichers',
        feedTerminusA: 'Baux Maraichers',
        feedTerminusB: 'Jaxaay',
        evidence: IdentityEvidence.terminusCrossCheck),
    '52': TataLineCandidate(
        routeNumber: '52',
        operator: 'AFTU',
        secondaryTerminusA: 'Bountou Pikine',
        secondaryTerminusB: 'Keur Massar',
        feedTerminusA: 'Baux Maraichers',
        feedTerminusB: 'Jaxaay',
        evidence: IdentityEvidence.none),
    '53': TataLineCandidate(
        routeNumber: '53',
        operator: 'AFTU',
        secondaryTerminusA: 'Keur Massar',
        secondaryTerminusB: 'Sebikhotane',
        feedTerminusA: 'KEUR MASSAR',
        feedTerminusB: 'Sebikotane',
        evidence: IdentityEvidence.terminusCrossCheck),
    '54': TataLineCandidate(
        routeNumber: '54',
        operator: 'AFTU',
        secondaryTerminusA: 'Keur Massar',
        secondaryTerminusB: 'UCAD',
        feedTerminusA: 'M T O A',
        feedTerminusB: 'UCAD',
        evidence: IdentityEvidence.terminusCrossCheck),
    '55': TataLineCandidate(
        routeNumber: '55',
        operator: 'AFTU',
        secondaryTerminusA: 'Rufisque SONADIS',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Petersen',
        feedTerminusB: 'Rufisque',
        evidence: IdentityEvidence.terminusCrossCheck),
    '56': TataLineCandidate(
        routeNumber: '56',
        operator: 'AFTU',
        secondaryTerminusA: 'Jaxaay 2',
        secondaryTerminusB: 'Petersen',
        feedTerminusA: 'Jaxaaye',
        feedTerminusB: 'Petersen',
        evidence: IdentityEvidence.terminusCrossCheck),
    '57': TataLineCandidate(
        routeNumber: '57',
        operator: 'AFTU',
        secondaryTerminusA: 'Rufisque Gouye Mouride',
        secondaryTerminusB: 'Giratoire Liberte 6',
        feedTerminusA: 'LIBERTE 5',
        feedTerminusB: 'Rufisque Gouye Mouride',
        evidence: IdentityEvidence.terminusCrossCheck),
    '58': TataLineCandidate(
        routeNumber: '58',
        operator: 'AFTU',
        secondaryTerminusA: 'Fass Mbao',
        secondaryTerminusB: 'Sham',
        feedTerminusA: 'Comico',
        feedTerminusB: 'Sahm',
        evidence: IdentityEvidence.terminusCrossCheck),
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
      status: PublicIdentityStatus.documented,
      verifiedAt: sourcesCheckedAt,
      confidence: 'HIGH',
    );
  }

  /// Statut de documentation de l'identité TATA d'une ligne.
  ///
  /// Aucune ligne TATA n'est [PublicIdentityStatus.documented] : aucune source
  /// admissible ne documente un numéro de ligne TATA. Une ligne AFTU figurant
  /// dans [tataCandidates] est [PublicIdentityStatus.candidate] ; les autres
  /// sont [PublicIdentityStatus.unconfirmed].
  static PublicIdentityStatus tataIdentityStatus(String operator, String? number) {
    final String op = normalizeOperator(operator);
    if (op != 'AFTU') return PublicIdentityStatus.unconfirmed;
    if (number == null) return PublicIdentityStatus.unconfirmed;
    final String n = normalizeNumber(number);
    if (tataCandidates.containsKey(n)) return PublicIdentityStatus.candidate;
    return PublicIdentityStatus.unconfirmed;
  }

  /// Correspondance candidate TATA pour une ligne, ou `null`.
  static TataLineCandidate? tataCandidateFor(String operator, String? number) {
    final String op = normalizeOperator(operator);
    if (op != 'AFTU' || number == null) return null;
    return tataCandidates[normalizeNumber(number)];
  }

  /// Identité TATA d'une ligne : CANDIDATE si la correspondance secondaire
  /// existe, sinon non documentée. Ne retourne JAMAIS un numéro public : TATA
  /// n'est pas une ligne.
  static DocumentedRouteIdentity resolveTata(String operator, String? number) {
    final String op = normalizeOperator(operator);
    final PublicIdentityStatus status = tataIdentityStatus(op, number);
    if (status == PublicIdentityStatus.candidate) {
      return DocumentedRouteIdentity.candidate(
          operator: op, source: tataSecondaryListSource);
    }
    return DocumentedRouteIdentity.undocumented(op);
  }

  /// Libellé « Tata N » pour un STATUT donné, ou `null` si l'identité TATA
  /// n'est pas CONFIRMÉE.
  ///
  /// Règle pure et testable : seule une identité [PublicIdentityStatus
  /// .documented] produit « Tata N ». Une candidature ([candidate]) ou une
  /// absence ([unconfirmed]) ne produit JAMAIS de libellé « Tata N » — c'est ce
  /// qui garantit qu'une correspondance secondaire ne devient pas une ligne.
  static String? tataLabelForStatus(PublicIdentityStatus status, String number) {
    if (status != PublicIdentityStatus.documented) return null;
    final String n = normalizeNumber(number);
    return n.isEmpty ? null : 'Tata $n';
  }

  /// Libellé d'affichage « Tata N », ou `null` si l'identité TATA n'est PAS
  /// confirmée. Aucune source admissible ne confirmant aujourd'hui de ligne
  /// TATA, cette méthode retourne `null` en l'état : l'appelant retombe alors
  /// sur l'identité AFTU documentée ou, à défaut, sur le type de véhicule seul.
  static String? confirmedTataLabel(String operator, String? number) {
    if (number == null) return null;
    final PublicIdentityStatus status = tataIdentityStatus(operator, number);
    if (status != PublicIdentityStatus.documented) return null;
    final TataLineCandidate? c = tataCandidateFor(operator, number);
    return tataLabelForStatus(status, c?.routeNumber ?? number);
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
          status: PublicIdentityStatus.documented,
          verifiedAt: sourcesCheckedAt,
          confidence: 'HIGH',
        );
      }
      return DocumentedRouteIdentity.undocumented(op);
    }
    return resolve(operator: operator, routeNumber: numberFromRouteId(routeId));
  }
}
