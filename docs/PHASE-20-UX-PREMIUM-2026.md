# Phase 20 — Audit UX & Premiumisation 2026

## Objectif
Transformer Dakar Bus en expérience de mobilité premium 2026 sans modifier les données, les horaires, le routage ou les règles métier validées.

## Périmètre
- Explorer : hiérarchie, lisibilité, prochains passages, densité.
- Carte : conteneur premium, lisibilité, GPS, cohérence carte/liste.
- Recherche : résultats unifiés et états vides.
- Fiche arrêt : station → direction → prochains passages.
- Alertes : hiérarchie et honnêteté des états.
- États : chargement, indisponibilité, GPS refusé, absence de résultat.
- Mobile-first : zones tactiles, navigation une main, responsive.
- Accessibilité : contraste, taille des textes, semantics.
- Performance : éviter les rebuilds et effets décoratifs coûteux.

## Garde-fous absolus
- Aucune donnée inventée.
- Aucun horaire, fréquence, ETA ou statut temps réel ajouté sans source.
- Ne pas modifier les feeds TER/BRT/DDD/AFTU.
- Ne pas modifier le routage métier.
- Ne pas exposer le nom technique PassBi.
- Conserver l'identité Dakar Green #00B140 validée en Phase 19.
- Conserver les couleurs propres aux réseaux lorsqu'elles sont documentées.
- Tout changement doit être couvert par tests ou validation adaptée.

## Méthode
1. Audit intégral de l'UI existante avant écriture.
2. Identifier les incohérences UX réelles.
3. Corriger uniquement les problèmes démontrés.
4. Ajouter/mettre à jour les tests UI concernés.
5. flutter analyze.
6. flutter test.
7. flutter build web --release --base-href /dakar-bus/.
8. npm test.
9. npm run validate:data.
10. npm run validate:public-lines.
11. Vérification finale des changements et absence de régression.

## Critère de sortie
Phase 20 n'est considérée comme terminée que si les validations passent et que l'interface est plus claire, plus rapide à comprendre et visuellement premium sans changement de vérité des données.
