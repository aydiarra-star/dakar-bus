import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LOT §9-1 — identifiants officiels des 22 lignes Tata et DDD.
///
/// Source des verdicts : `docs/ETAPE_3A_AUDIT_IDENTIFIANTS_TATA_DDD_2026-09-25.md`
/// (§9-1 proposition P1, §12 tableau final, décision A4) et
/// `docs/REFERENTIEL_CANONIQUE_AFTU_TATA_DDD_2026-09-25.md` (révision 1.1).
///
/// Le lot ajoute QUATRE champs, en AJOUT SEUL, sur exactement 22 routes :
///   * `official_identifier_status`   — CONFIRMED | MISSING | CONFLICTING | UNKNOWN
///   * `official_identifier_note`     — motif documenté, jamais vide
///   * `official_number_observed`     — true = un numéro est réellement publié par
///                                      un opérateur vérifiable, MÊME SI ce numéro
///                                      ne correspond pas à l'identité de la route
///   * `official_number_belongs_to`   — "AFTU" | "DDD" | "TATA" | null
///
/// Verdicts figés : 15 CONFLICTING · 7 MISSING · 0 CONFIRMED · 0 UNKNOWN.
///
/// Répartition de `official_number_belongs_to` :
///   12 "DDD" (10 lignes DDD internes + `tata_218` + `tata_219`)
///    3 "AFTU" (`tata_50`, `tata_64`, `tata_78`)
///    7 null
///    0 "TATA"  — aucun Tata ne porte un numéro officiellement attribué au Tata.
///
/// Ce fichier verrouille aussi la NON-RÉGRESSION : aucune donnée préexistante
/// des 22 routes ne doit avoir été modifiée par ce lot (voir
/// `kEmpreinteDonneesExistantes`). Le lot ne touche ni aux arrêts, ni aux
/// horaires, ni aux fréquences, ni à la géométrie, ni aux autres routes.
///
/// LOT 15 (2026-09-26) — extension d'axe, sans réécriture : les MÊMES quatre
/// champs ont été ajoutés, en ajout seul, aux 80 routes AFTU (`operator_id
/// == 'aftu'`). Le périmètre des porteurs passe donc de 22 à 102 routes
/// (22 Tata/DDD + 80 AFTU). Les tuples, les notes et l'empreinte des 22
/// routes du §9-1 restent strictement inchangés : les verrous ci-dessous sont
/// conservés tels quels. Côté AFTU : 54 `CONFLICTING` (numéro officiel publié
/// mais itinéraire interne différent, référentiel rév. 1.1 §E.3) et 26
/// `MISSING` (18 numéros tombant dans le trou de publication 6–23, 8
/// identifiants techniques `new_commune_03..10`), 0 `CONFIRMED`.
/// Le contrôle automatisé correspondant est `scripts/check-line-identities.js`
/// (`npm run check:identites`).

/// Les quatre valeurs autorisées de `official_identifier_status`. Enum fermé.
const Set<String> kOfficialIdentifierStatus = <String>{
  'CONFIRMED',
  'MISSING',
  'CONFLICTING',
  'UNKNOWN',
};

/// Les quatre propriétaires autorisés de `official_number_belongs_to`.
const Set<String> kOfficialNumberOwners = <String>{'AFTU', 'DDD', 'TATA'};

/// Les quatre champs ajoutés par le lot §9-1.
const List<String> kOfficialIdentifierFields = <String>[
  'official_identifier_status',
  'official_identifier_note',
  'official_number_observed',
  'official_number_belongs_to',
];

/// Les 22 routes du lot, dans l'ordre du tableau §12 de l'audit 3A.
const List<String> kOfficialIdentifierRouteIds = <String>[
  // Tata (7)
  'tata_50',
  'tata_64',
  'tata_78',
  'tata_218',
  'tata_219',
  'new_commune_11',
  'new_commune_12',
  // DDD (15)
  'ddd_1',
  'ddd_3',
  'ddd_7',
  'ddd_8',
  'ddd_9',
  'ddd_10',
  'ddd_11',
  'ddd_12',
  'ddd_14',
  'ddd_15',
  'ddd_20',
  'ddd_23',
  'new_commune_01',
  'new_commune_02',
  'new_commune_13',
];

/// Statut attendu, route par route (audit 3A §12).
const Map<String, String> kExpectedStatus = <String, String>{
  'tata_50': 'CONFLICTING',
  'tata_64': 'CONFLICTING',
  'tata_78': 'CONFLICTING',
  'tata_218': 'CONFLICTING',
  'tata_219': 'CONFLICTING',
  'new_commune_11': 'MISSING',
  'new_commune_12': 'MISSING',
  'ddd_1': 'CONFLICTING',
  'ddd_3': 'MISSING',
  'ddd_7': 'CONFLICTING',
  'ddd_8': 'CONFLICTING',
  'ddd_9': 'CONFLICTING',
  'ddd_10': 'CONFLICTING',
  'ddd_11': 'CONFLICTING',
  'ddd_12': 'CONFLICTING',
  'ddd_14': 'MISSING',
  'ddd_15': 'CONFLICTING',
  'ddd_20': 'CONFLICTING',
  'ddd_23': 'CONFLICTING',
  'new_commune_01': 'MISSING',
  'new_commune_02': 'MISSING',
  'new_commune_13': 'MISSING',
};

/// `official_number_observed` attendu, route par route.
const Map<String, bool> kExpectedObserved = <String, bool>{
  'tata_50': true,
  'tata_64': true,
  'tata_78': true,
  'tata_218': true,
  'tata_219': true,
  'new_commune_11': false,
  'new_commune_12': false,
  'ddd_1': true,
  'ddd_3': false,
  'ddd_7': true,
  'ddd_8': true,
  'ddd_9': true,
  'ddd_10': true,
  'ddd_11': true,
  'ddd_12': true,
  'ddd_14': false,
  'ddd_15': true,
  'ddd_20': true,
  'ddd_23': true,
  'new_commune_01': false,
  'new_commune_02': false,
  'new_commune_13': false,
};

/// `official_number_belongs_to` attendu, route par route.
/// `null` est une valeur à part entière : aucun numéro n'est attribué.
const Map<String, String?> kExpectedBelongsTo = <String, String?>{
  'tata_50': 'AFTU',
  'tata_64': 'AFTU',
  'tata_78': 'AFTU',
  'tata_218': 'DDD',
  'tata_219': 'DDD',
  'new_commune_11': null,
  'new_commune_12': null,
  'ddd_1': 'DDD',
  'ddd_3': null,
  'ddd_7': 'DDD',
  'ddd_8': 'DDD',
  'ddd_9': 'DDD',
  'ddd_10': 'DDD',
  'ddd_11': 'DDD',
  'ddd_12': 'DDD',
  'ddd_14': null,
  'ddd_15': 'DDD',
  'ddd_20': 'DDD',
  'ddd_23': 'DDD',
  'new_commune_01': null,
  'new_commune_02': null,
  'new_commune_13': null,
};

/// Champs qui ne doivent JAMAIS réapparaître dans le fichier de données.
/// Ils appartiennent à la branche historique 268473, volontairement abandonnés.
const List<String> kForbiddenRouteFields = <String>[
  'official_line_number',
  'nomenclature_status',
  'canonical_status',
  'conflict_reason',
  'conflict_sources',
  'match_class',
  'possible_match_candidates',
];

/// Les identifiants techniques dont le suffixe numérique n'est PAS un numéro.
const List<String> kTechnicalIdentifierRoutes = <String>[
  'new_commune_01',
  'new_commune_02',
  'new_commune_11',
  'new_commune_12',
  'new_commune_13',
];

/// FNV-1a 32 bits de la concaténation des 22 `official_identifier_note`, dans
/// l'ordre de `kOfficialIdentifierRouteIds`.
///
/// Verrouille le libellé exact des 22 notes : toute reformulation, même
/// minime, fait échouer ce test. Valeur calculée à l'ajout du lot §9-1.
const int kEmpreinteNotes = 0x3E4A6A27;

/// FNV-1a 32 bits des champs PRÉEXISTANTS des 105 routes (les quatre champs du
/// §9-1 retirés), dans l'ordre du fichier.
///
/// C'est le verrou de NON-RÉGRESSION du lot : cette valeur est identique avant
/// et après l'ajout des quatre champs. Toute modification, ajout ou suppression
/// d'une donnée préexistante — sur n'importe laquelle des 105 routes — la fait
/// changer. Valeur vérifiée : identique sur `159627` (avant) et sur `166370`
/// (après).
const int kEmpreinteDonneesExistantes = 0x0F206256;

const String _kJsonPath = 'assets/data/dakar_network.json';

Map<String, dynamic> _raw() => jsonDecode(File(_kJsonPath).readAsStringSync())
    as Map<String, dynamic>;

List<Map<String, dynamic>> _routes() =>
    (_raw()['routes'] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _route(String id) =>
    _routes().firstWhere((Map<String, dynamic> r) => r['id'] == id);

/// Les 80 identifiants de routes AFTU (lot 15), dans l'ordre du fichier.
List<String> _aftuRouteIds() => _routes()
    .where((Map<String, dynamic> r) => r['operator_id'] == 'aftu')
    .map((Map<String, dynamic> r) => r['id'] as String)
    .toList();

/// Rend une valeur JSON sous forme de chaîne canonique, sans dépendance
/// externe (le paquet `crypto` n'est pas une dépendance du projet).
String _render(Object? v) {
  if (v == null) {
    return '~';
  }
  if (v is bool) {
    return v ? 'true' : 'false';
  }
  if (v is int) {
    return 'i$v';
  }
  if (v is num) {
    return 'f$v';
  }
  if (v is String) {
    return '@$v';
  }
  if (v is List) {
    return '[${v.map((dynamic e) => _render(e)).join('\u0003')}]';
  }
  if (v is Map) {
    final List<String> entries = <String>[];
    v.forEach((dynamic k, dynamic value) {
      entries.add('$k:${_render(value)}');
    });
    return '{${entries.join('\u0004')}}';
  }
  throw StateError('Type JSON non géré : ${v.runtimeType}');
}

/// Sérialisation canonique des 105 routes, quatre champs du §9-1 retirés.
String _canoniqueDesDonneesExistantes() {
  final List<String> blocs = <String>[];
  for (final Map<String, dynamic> r in _routes()) {
    final List<String> parts = <String>[];
    r.forEach((String key, dynamic value) {
      if (kOfficialIdentifierFields.contains(key)) {
        return;
      }
      parts.add('$key=${_render(value)}');
    });
    blocs.add(parts.join('\u0001'));
  }
  return blocs.join('\u0002');
}

/// FNV-1a 32 bits sur les unités de code UTF-16 de [s].
int _fnv1a32(String s) {
  int h = 0x811c9dc5;
  for (int i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

void main() {
  group('§9-1 — identifiants officiels Tata / DDD (22 lignes)', () {
    test('volumes globaux inchangés : 5 opérateurs, 117 arrêts, 105 routes', () {
      final Map<String, dynamic> json = _raw();
      expect((json['operators'] as List).length, 5);
      expect((json['stops'] as List).length, 117,
          reason: 'aucun arrêt ajouté, renommé ou supprimé par le lot §9-1');
      expect((json['routes'] as List).length, 105,
          reason: 'aucune route ajoutée, renommée ou supprimée par le lot §9-1');
    });

    test('exactement 102 routes portent official_identifier_status '
        '(22 Tata/DDD + 80 AFTU)', () {
      final List<Map<String, dynamic>> porteurs = _routes()
          .where((Map<String, dynamic> r) =>
              r.containsKey('official_identifier_status'))
          .toList();
      expect(porteurs.length, 102,
          reason: '22 lignes Tata/DDD (§9-1) + 80 lignes AFTU (lot 15), ni plus '
              'ni moins');
      // Comparaison ensembliste : l'ordre du tableau §12 (Tata puis DDD) n'est
      // pas l'ordre du fichier (DDD, Tata, puis new_commune_*).
      expect(
        porteurs.map((Map<String, dynamic> r) => r['id'] as String).toList(),
        unorderedEquals(<String>[
          ...kOfficialIdentifierRouteIds,
          ..._aftuRouteIds(),
        ]),
        reason: 'exactement les 22 lignes auditées (audit 3A §12) et les 80 '
            'lignes AFTU du lot 15',
      );
    });

    test('les 4 champs sont présents ensemble sur les 22 et sur les 80 AFTU, et '
        'nulle part ailleurs', () {
      for (final Map<String, dynamic> r in _routes()) {
        final String id = r['id'] as String;
        final List<String> presents =
            kOfficialIdentifierFields.where((String f) => r.containsKey(f)).toList();
        if (kOfficialIdentifierRouteIds.contains(id)) {
          expect(presents, kOfficialIdentifierFields,
              reason: '$id : les 4 champs du §9-1 attendus');
        } else if (r['operator_id'] == 'aftu') {
          expect(presents, kOfficialIdentifierFields,
              reason: '$id : les 4 champs du lot 15 attendus sur les 80 AFTU');
        } else {
          expect(presents, isEmpty,
              reason: '$id : hors périmètre des lots §9-1 et lot 15 '
                  '(TER/BRT non concernés)');
        }
      }
    });

    test('distribution official_identifier_status : 15 CONFLICTING, 7 MISSING, '
        '0 CONFIRMED, 0 UNKNOWN', () {
      final Map<String, int> compte = <String, int>{};
      for (final String id in kOfficialIdentifierRouteIds) {
        final String statut =
            _route(id)['official_identifier_status'] as String;
        expect(kOfficialIdentifierStatus, contains(statut),
            reason: '$id : valeur hors de l\'énumération fermée');
        compte[statut] = (compte[statut] ?? 0) + 1;
      }
      expect(compte['CONFLICTING'] ?? 0, 15,
          reason: '5 Tata + 10 lignes DDD internes');
      expect(compte['MISSING'] ?? 0, 7, reason: '2 Tata + 5 lignes DDD');
      expect(compte['CONFIRMED'] ?? 0, 0,
          reason: 'aucune identité officielle n\'est établie');
      expect(compte['UNKNOWN'] ?? 0, 0,
          reason: 'aucune ligne ne reste indéterminée sur l\'axe identifiant');
    });

    test('distribution official_number_observed : 15 true, 7 false', () {
      int vrais = 0;
      int faux = 0;
      for (final String id in kOfficialIdentifierRouteIds) {
        final Object? valeur = _route(id)['official_number_observed'];
        expect(valeur, isA<bool>(),
            reason: '$id : official_number_observed doit être un booléen');
        if (valeur as bool) {
          vrais++;
        } else {
          faux++;
        }
      }
      expect(vrais, 15,
          reason: 'les 15 CONFLICTING portent un numéro réellement publié');
      expect(faux, 7, reason: 'les 7 MISSING ne portent aucun numéro publié');
    });

    test('distribution official_number_belongs_to : 12 DDD, 3 AFTU, 7 null, '
        '0 TATA', () {
      int ddd = 0;
      int aftu = 0;
      int aucun = 0;
      int tata = 0;
      for (final String id in kOfficialIdentifierRouteIds) {
        final Object? valeur = _route(id)['official_number_belongs_to'];
        if (valeur == null) {
          aucun++;
          continue;
        }
        expect(valeur, isA<String>(),
            reason: '$id : propriétaire attendu sous forme de chaîne ou null');
        expect(kOfficialNumberOwners, contains(valeur),
            reason: '$id : propriétaire hors des valeurs autorisées');
        switch (valeur as String) {
          case 'DDD':
            ddd++;
            break;
          case 'AFTU':
            aftu++;
            break;
          case 'TATA':
            tata++;
            break;
          default:
            fail('$id : propriétaire inattendu « $valeur »');
        }
      }
      expect(ddd, 12, reason: '10 lignes DDD internes + tata_218 + tata_219');
      expect(aftu, 3, reason: 'tata_50, tata_64, tata_78');
      expect(aucun, 7, reason: 'les 7 lignes MISSING');
      expect(tata, 0, reason: 'aucun réseau Tata publié : jamais "TATA"');
      expect(ddd + aftu + aucun + tata, 22);
    });

    test('chaque route porte exactement les valeurs attendues (tuple figé)', () {
      expect(kExpectedStatus.length, 22);
      expect(kExpectedObserved.length, 22);
      expect(kExpectedBelongsTo.length, 22);
      for (final String id in kOfficialIdentifierRouteIds) {
        final Map<String, dynamic> r = _route(id);
        expect(r['official_identifier_status'], kExpectedStatus[id],
            reason: '$id : statut d\'identifiant');
        expect(r['official_number_observed'], kExpectedObserved[id],
            reason: '$id : numéro observé');
        expect(r['official_number_belongs_to'], kExpectedBelongsTo[id],
            reason: '$id : propriétaire du numéro');
      }
    });

    test('invariants croisés des quatre champs', () {
      for (final String id in kOfficialIdentifierRouteIds) {
        final Map<String, dynamic> r = _route(id);
        final String statut = r['official_identifier_status'] as String;
        final bool observe = r['official_number_observed'] as bool;
        final Object? proprietaire = r['official_number_belongs_to'];

        // CONFLICTING <=> numéro observé ; MISSING <=> aucun numéro observé.
        expect(statut == 'CONFLICTING', observe,
            reason: '$id : CONFLICTING et official_number_observed doivent '
                'concorder');
        expect(statut == 'MISSING', !observe,
            reason: '$id : MISSING et official_number_observed doivent '
                'concorder');

        // Un numéro observé a toujours un propriétaire identifié, et l'inverse.
        expect(observe, proprietaire != null,
            reason: '$id : numéro observé et propriétaire vont de pair');
      }
    });

    test('les notes sont non vides et libellées exactement (empreinte)', () {
      final List<String> notes = <String>[];
      for (final String id in kOfficialIdentifierRouteIds) {
        final Object? note = _route(id)['official_identifier_note'];
        expect(note, isA<String>(),
            reason: '$id : official_identifier_note doit être une chaîne');
        expect((note as String).trim(), isNotEmpty,
            reason: '$id : motif documenté obligatoire, jamais vide');
        notes.add(note);
      }
      expect(notes.toSet().length, 22, reason: '22 motifs distincts');
      expect(_fnv1a32(notes.join('\u0001')), kEmpreinteNotes,
          reason: 'le libellé des 22 notes a changé : vérifier contre l\'audit '
              '3A §2/§3 et le référentiel révision 1.1');
    });

    test('un suffixe d\'identifiant technique n\'est jamais un numéro officiel',
        () {
      for (final String id in kTechnicalIdentifierRoutes) {
        final Map<String, dynamic> r = _route(id);
        expect(r['official_identifier_status'], 'MISSING', reason: id);
        expect(r['official_number_observed'], isFalse,
            reason: '$id : le suffixe technique n\'est pas un numéro observé');
        expect(r['official_number_belongs_to'], isNull, reason: id);
        expect(r['official_line_number'], isNull,
            reason: '$id : aucun numéro officiel ne doit être renseigné');
        expect(r.containsKey('official_line_number'), isFalse,
            reason: '$id : le champ doit être ABSENT, pas null');
      }
    });

    test('tata_218 et tata_219 : le numéro appartient à DDD, pas au Tata', () {
      for (final String id in <String>['tata_218', 'tata_219']) {
        final Map<String, dynamic> r = _route(id);
        expect(r['operator_id'], 'tata', reason: id);
        expect(r['official_identifier_status'], 'CONFLICTING', reason: id);
        expect(r['official_number_observed'], isTrue, reason: id);
        expect(r['official_number_belongs_to'], 'DDD',
            reason: '$id : numéro publié par Dakar Dem Dikk, jamais par Tata');
      }
    });

    test('tata_50 / tata_64 / tata_78 : numéro publié par AFTU, non attribué '
        'au Tata', () {
      for (final String id in <String>['tata_50', 'tata_64', 'tata_78']) {
        final Map<String, dynamic> r = _route(id);
        expect(r['operator_id'], 'tata', reason: id);
        expect(r['official_identifier_status'], 'CONFLICTING', reason: id);
        expect(r['official_number_observed'], isTrue, reason: id);
        expect(r['official_number_belongs_to'], 'AFTU',
            reason: '$id : aucun remappage sur la ligne AFTU de même numéro');
      }
    });

    test('champs interdits absents de tout le fichier', () {
      for (final Map<String, dynamic> r in _routes()) {
        for (final String interdit in kForbiddenRouteFields) {
          expect(r.containsKey(interdit), isFalse,
              reason: '${r['id']} : « $interdit » ne doit pas exister '
                  '(branche historique 268473 non réintroduite)');
        }
      }
      final Map<String, dynamic> json = _raw();
      expect(json.containsKey('canonical_referentiel'), isFalse,
          reason: 'le référentiel embarqué de la branche historique n\'est pas '
              'réintroduit');
    });

    test('official_line_number absent, y compris des 22 routes du lot', () {
      for (final Map<String, dynamic> r in _routes()) {
        expect(r.containsKey('official_line_number'), isFalse,
            reason: '${r['id']} : aucun numéro officiel n\'est établi pour '
                'aucune des 22 lignes ; le champ doit rester ABSENT');
      }
    });

    test('aucune donnée préexistante modifiée (champs d\'origine des 105 routes)',
        () {
      // Empreinte calculée sur les 105 routes, quatre champs du §9-1 retirés.
      // Identique sur 159627 octets (avant) et 166370 octets (après) : le lot
      // est bien un ajout seul, sans réécriture d'aucune valeur existante.
      expect(_fnv1a32(_canoniqueDesDonneesExistantes()),
          kEmpreinteDonneesExistantes,
          reason: 'une donnée préexistante a été modifiée, ajoutée ou '
              'supprimée en dehors des quatre champs du §9-1');
    });
  });

  group('Lot 15 — identités documentaires des 80 lignes AFTU', () {
    // Plage officielle AFTU publiée (référentiel rév. 1.1, §A.1) :
    // 1–5, 24–89, 91. Trous documentés : 6–23, 90.
    final Set<int> officiels = <int>{
      1, 2, 3, 4, 5,
      for (int n = 24; n <= 89; n++) n,
      91,
    };

    test('distribution : 54 CONFLICTING, 26 MISSING, 0 CONFIRMED', () {
      final Map<String, int> compte = <String, int>{};
      for (final String id in _aftuRouteIds()) {
        final String statut = _route(id)['official_identifier_status'] as String;
        compte[statut] = (compte[statut] ?? 0) + 1;
      }
      expect(_aftuRouteIds().length, 80);
      expect(compte['CONFLICTING'] ?? 0, 54,
          reason: 'numéro officiel publié mais itinéraire interne différent '
              '(référentiel rév. 1.1 §E.3)');
      expect(compte['MISSING'] ?? 0, 26,
          reason: '18 numéros dans le trou 6–23 + 8 identifiants techniques');
      expect(compte['CONFIRMED'] ?? 0, 0,
          reason: 'aucune identité publique AFTU n’est démontrée');
      expect(compte['UNKNOWN'] ?? 0, 0,
          reason: 'aucune ligne indéterminée sur l’axe identifiant');
    });

    test('un numéro n’est « observé » que s’il appartient à la plage publiée',
        () {
      for (final String id in _aftuRouteIds()) {
        final Map<String, dynamic> r = _route(id);
        final RegExpMatch? m = RegExp(r'^aftu_(\d+)$').firstMatch(id);
        final bool observe = r['official_number_observed'] as bool;
        if (m == null) {
          expect(observe, isFalse,
              reason: '$id : identifiant technique, aucun numéro officiel');
          continue;
        }
        final bool dansPlage = officiels.contains(int.parse(m.group(1)!));
        expect(observe, dansPlage,
            reason: '$id : « observé » doit coïncider avec la plage officielle '
                'AFTU — jamais une inférence sur le numéro');
      }
    });

    test('observé ⟺ propriétaire AFTU ; sinon aucun propriétaire', () {
      for (final String id in _aftuRouteIds()) {
        final Map<String, dynamic> r = _route(id);
        final bool observe = r['official_number_observed'] as bool;
        final Object? proprietaire = r['official_number_belongs_to'];
        if (observe) {
          expect(proprietaire, 'AFTU',
              reason: '$id : numéro publié par l’AFTU');
        } else {
          expect(proprietaire, isNull,
              reason: '$id : aucun numéro publié, donc aucun propriétaire');
        }
      }
    });

    test('chaque route AFTU porte un motif documenté non vide', () {
      for (final String id in _aftuRouteIds()) {
        final Object? note = _route(id)['official_identifier_note'];
        expect(note, isA<String>(), reason: id);
        expect((note as String).trim(), isNotEmpty, reason: id);
      }
    });

    test('TER et BRT restent hors de l’axe identifiant', () {
      for (final Map<String, dynamic> r in _routes()) {
        if (r['operator_id'] != 'ter' && r['operator_id'] != 'brt') {
          continue;
        }
        for (final String f in kOfficialIdentifierFields) {
          expect(r.containsKey(f), isFalse,
              reason: '${r['id']} : réseau hors périmètre du lot 15');
        }
      }
    });

    test('aucun réseau TATA inventé, aucun numéro attribué à « TATA »', () {
      for (final Map<String, dynamic> r in _routes()) {
        expect(r['official_number_belongs_to'], isNot('TATA'),
            reason: '${r['id']} : « Tata » est une catégorie de service, pas un '
                'réseau publié');
      }
    });
  });
}
