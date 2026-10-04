# Phase 20 — UX Premium 2026 — Implementation

## Scope

Cette première implémentation Phase 20 reste strictement UI/UX. Aucun flux transport, horaire, calcul d'ETA, routage, GPS, correspondance ou règle de provenance n'a été modifié.

## Modifications appliquées

### Navigation basse
- hauteur harmonisée à 72 px pour une meilleure lisibilité mobile ;
- labels toujours visibles ;
- état actif plus lisible ;
- icône active légèrement renforcée ;
- séparation visuelle conservée sans ombre lourde ;
- surface de navigation sans teinte Material automatique.

### Surfaces premium
- cartes Material 3 normalisées sur le rayon Dakar Bus existant de 20 px ;
- suppression des ombres Material implicites afin de conserver la profondeur contrôlée par l'UI existante ;
- surface et surface-tint explicites pour éviter les dérives de couleur ;
- puces harmonisées avec le rayon pill existant et la hiérarchie verte Dakar.

### Identité
- #00B140 reste l'accent principal ;
- aucune nouvelle teinte verte créée ;
- couleurs TER/BRT/DDD/AFTU/Tata conservées.

## Garde-fous

Cette étape ne fabrique aucune donnée et ne change aucun statut REAL_TIME/ESTIMATED/SCHEDULED/UNKNOWN.

Les informations de transport restent celles des sources déjà chargées par l'application.

## Validation

La validation automatisée doit être effectuée par la CI sur ce commit/PR. Cette documentation ne déclare pas un build local réussi : seul le résultat CI fera foi.
