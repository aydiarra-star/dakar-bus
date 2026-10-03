import 'package:flutter/material.dart';

/// DAKAR BUS — DESIGN SYSTEM 2026 (présentation seule).
///
/// Ce fichier centralise les tokens de MISE EN FORME (espacements, rayons,
/// profondeur, mouvement, typographie) afin qu'aucune retouche visuelle future
/// n'ait à rechercher des valeurs magiques dans toute l'application.
///
/// RÈGLE ABSOLUE : ces constantes ne portent AUCUNE donnée métier. Elles ne
/// modifient ni les horaires, ni le routage, ni les statuts, ni les couleurs
/// d'identité verrouillées par les tests. Les palettes de marque et de réseau
/// restent dans `AppColors` (main.dart).

/// Rythme d'espacement (grille de 4 px).
///
/// Progression : 4 → 8 → 12 → 16 → 24 → 32. Utiliser ces pas plutôt que des
/// valeurs arbitraires pour homogénéiser padding, marges et gaps.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const EdgeInsets page = EdgeInsets.all(md);
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets cardDense = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );
}

/// Rayons harmonisés.
///
/// 12 (petits éléments) → 16 (cartes) → 20 (grands composants) → 24 (surfaces
/// principales : carte, panneaux) → 999 (pastilles pleines).
abstract final class AppRadius {
  static const double sm = 12;
  static const double card = 16;
  static const double lg = 20;
  static const double sheet = 24;
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get cardAll => BorderRadius.circular(card);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get sheetAll => BorderRadius.circular(sheet);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Profondeur (ombres très douces, jamais lourdes).
///
/// La hiérarchie de surfaces — background → surface → elevated → floating — est
/// rendue par un contraste de surface et une ombre légère, pas par des bordures
/// partout.
abstract final class AppElevation {
  /// Surface posée (cartes de contenu).
  static List<BoxShadow> surface(bool dark) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.28 : 0.05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  /// Surface secondaire (champs, pastilles, badges flottants).
  static List<BoxShadow> soft(bool dark) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.20 : 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  /// Surface flottante (contrôles au-dessus de la carte, bottom sheets).
  static List<BoxShadow> floating(bool dark) => <BoxShadow>[
        BoxShadow(
          color: Colors.black.withOpacity(dark ? 0.34 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}

/// Langage de mouvement cohérent (durées courtes, organiques, utiles).
///
/// Respecter `MediaQuery.disableAnimations` : les composants interrogent
/// [resolve] pour retomber instantanément sur l'état final quand l'utilisateur
/// a désactivé les animations.
abstract final class AppMotion {
  /// Micro-interaction (appui, sélection, changement d'état).
  static const Duration micro = Duration(milliseconds: 150);

  /// Transition (apparition de résultat, changement d'onglet).
  static const Duration short = Duration(milliseconds: 220);

  /// Panneau / surface étendue (bottom sheet, déploiement).
  static const Duration medium = Duration(milliseconds: 300);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;

  /// Durée effective : nulle si les animations sont désactivées.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : duration;
}

/// Échelle typographique (graisses et tailles).
///
/// Hiérarchie de lecture : information utile (horaires) > destination > mode >
/// secondaire. Les minutes restent dominantes, jamais noyées dans un texte long.
abstract final class AppType {
  static const double display = 26;
  static const double title = 18;
  static const double heading = 16;
  static const double body = 14;
  static const double label = 13;
  static const double caption = 11;
  static const double micro = 10;

  /// Taille des minutes de prochain passage (élément visuel dominant).
  static const double minutes = 22;
  static const double minutesCompact = 17;

  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
}

/// Teintes de surface NEUTRES (off-white / blanc / graphite).
///
/// Ces valeurs ne remplacent aucune couleur verrouillée : elles complètent la
/// hiérarchie de surfaces claire demandée (fond, surface, surface secondaire).
/// Les couleurs de marque et de réseau restent définies par `AppColors`.
abstract final class AppSurface {
  static const Color backgroundLight = Color(0xFFF7FAF8);
  static const Color backgroundDark = Color(0xFF101513);
  static const Color raisedLight = Color(0xFFF1F5F3);
  static const Color raisedDark = Color(0xFF1B211E);
  static const Color mutedTextLight = Color(0xFF8A9690);
  static const Color mutedTextDark = Color(0xFF9AA6A0);
  static const Color borderLight = Color(0xFFDDE5E0);
  static const Color borderDark = Color(0xFF2C3430);

  static Color background(bool dark) => dark ? backgroundDark : backgroundLight;
  static Color raised(bool dark) => dark ? raisedDark : raisedLight;
  static Color mutedText(bool dark) => dark ? mutedTextDark : mutedTextLight;
  static Color border(bool dark) => dark ? borderDark : borderLight;
}
