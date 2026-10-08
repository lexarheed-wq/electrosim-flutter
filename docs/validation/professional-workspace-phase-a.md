# Atelier professionnel ElectroSim — validation du lot A

Base : `09f0459dd584c6231870387e7d5f8d8dd77b647d`. Branche : `feat/professional-workspace`.

## Résultat livré

- Bandeau bleu nuit et commandes Lancer/Pause permanentes, avec état réellement connecté à la simulation.
- Catalogue et inspecteur ancrés, masquables et redimensionnables sur grand écran ; aucun onglet derrière la barre.
- Un seul panneau modal à la fois en disposition étroite ; fermeture au clavier/retour système, focus rendu au déclencheur.
- Transitions de panneau de 200 ms avec décélération, désactivées lorsque la réduction des animations est demandée.
- Préférences de disposition stockées à part des circuits : lecture tolérante, valeurs bornées, écritures sérialisées et remplacement par renommage.
- Centre du monde conservé lors du redimensionnement ; gestes en cours annulés proprement avant changement de viewport.
- Recentrage compact utilisant la limite de zoom existante de 0,35 au lieu du plancher artificiel 0,75.
- Palette plus compacte, champs adaptatifs et onglets lisibles, y compris avec texte agrandi.

Les composants et modèles électriques existants sont conservés. Ce lot ne constitue pas une copie photographique de la maquette. Les animations mécaniques détaillées, favoris, annuler/rétablir, nouvelle vue Schéma et volet inférieur de résultats détaillés restent les lots B/C.

## Vérification

Flutter 3.38.10 / Dart 3.10.9. Vérification locale dans l’environnement Linux de développement :

| Périmètre | Commande depuis le package | Résultat |
|---|---|---|
| Application | `flutter test` dans `apps/electrosim` | 278 tests réussis |
| Canvas | `flutter test` dans `packages/electrosim_canvas` | 81 tests réussis |
| UI kit | `flutter test` dans `packages/electrosim_ui_kit` | 23 tests réussis avant revue (24 après correction accessibilité) |
| Analyse des trois packages | `flutter analyze` | Aucun problème |
| Captures réelles de widgets | `flutter test tool/capture_professional_workspace_test.dart` | 6 scénarios réussis |
| Contrat Python de design system | `python3 -m unittest tools/test_f18_g1_design_system.py` | 4 tests réussis |
| Audit statique F18-G11 | `python3 tools/f18_g11_audit.py` | Liste d’erreurs vide |

Les nouveaux tests ont d’abord reproduit les API absentes et défauts visés : centre du circuit déplacé, connexion parasite après resize, commande sans libellé, débordements à texte 200 %, et cadrage compact trop zoomé. Les quantités électriques des tests existants sont conservées ; le test de propriétés fait désormais défiler son vrai panneau pour atteindre les champs.

Les anciennes images golden ont changé intentionnellement avec la refonte. Leurs profils ont été adaptés aux panneaux ancrés et aux commandes permanentes, après contrôle visuel des captures. Les goldens restent des références de tests, pas des captures d’un appareil physique.

## Captures et reproduction

Le script `apps/electrosim/tool/capture_professional_workspace_test.dart` produit desktop, mesures, panneaux masqués, téléphone, inspecteur téléphone et texte 200 %.

Depuis `apps/electrosim`, définir `ELECTROSIM_UI_CAPTURE_DIR` pour le dossier de sortie et `ELECTROSIM_FONT_DIR` pour le dossier `bin/cache/artifacts/material_fonts` du SDK Flutter, puis exécuter le script avec `flutter test`.

Les rapports JSON de capture contiennent les contrôles des cibles tactiles, des libellés et du clic sur Mesures. Les rendus emploient les widgets réels. Le lot de rendu industriel complémentaire utilise une police explicite sur les peintres concernés et les captures chargent Roboto/MaterialIcons, sans retouche des images. Les goldens restent des images du moteur de test.

## Essai utilisateur conseillé

1. Créer un circuit et vérifier recherche, ajout rapide et glisser-déposer.
2. Sélectionner un composant ; ouvrir Mesures ; fermer puis rouvrir les panneaux.
3. Redimensionner les panneaux : positions et fils restent inchangés.
4. Faire une connexion, une rotation, une sélection multiple et une suppression.
5. Lancer, mettre en pause et réinitialiser ; vérifier les mesures et le statut.
6. Fermer/réouvrir l’atelier : retrouver la disposition préférée.
7. Réduire la fenêtre et activer un texte agrandi ; vérifier l’accès aux mêmes actions.

## Limites vérifiées et qualification restante

Aucun essai manuel Mac/Windows/téléphone physique dans cette session. Les outils GTK de build Linux ne sont pas disponibles ; le build natif doit être qualifié par la CI ou la machine cible. Les widget tests ne prouvent pas 60 Hz sur une platine de 400 composants.

Protocole profile/release pour l’objectif 400 : même machine et mêmes circuits de référence que l’audit moteur ; tester ouverture/fermeture de panneau, déplacement, zoom et clic de connexion ; consigner hardware, topologie, nombre de fils, latences p50/p95 et frames >16,7 ms. Objectifs de validation, pas garanties actuelles : interaction ordinaire <100 ms et budget 16,7 ms à 60 Hz. Les optimisations de routage de la PR #35 restent présentes.

Les défauts de sauvegarde des circuits identifiés avant cette refonte ne sont pas corrigés par le nouveau stockage des préférences de disposition. Aucun label Enregistré n’est ajouté pour masquer cette limite.

## Décisions prises pendant l’implémentation

- Réutilisation du worktree lié existant sur une nouvelle branche : isolation Git suffisante, sans copier de nouveau l’ensemble du dépôt. Risque : tooling partagé avec la branche précédente.
- Ledger équivalent aux scripts du skill, absents de l’environnement cloud : progression et preuves RED/GREEN conservées. Risque : suivi moins automatisé.
- Breakpoints spécifiques à l’atelier (720/1200), sans changer ceux de l’accueil : préserve la navigation existante. Risque : deux contrats responsive à maintenir.
- Annulation explicite d’un geste lors d’un changement de disposition : évite une valeur de verrouillage périmée dans les callbacks existants. Risque : une manipulation commencée doit être reprise après resize, avec statut explicatif.
- Mise à jour des goldens après lecture des captures et vérification des comportements : reflète la refonte approuvée. Risque : les images de référence ne suffisent pas seules à détecter un défaut fonctionnel ; tests de clic/focus/géométrie maintenus.

La revue indépendante du lot A et des rendus n’a identifié aucun blocage Critical/Important. Deux défauts Minor ont été corrigés : sens de l’action accessibilité Augmenter sur l’inspecteur et sauvegarde après fermeture avant résolution du stockage natif. Tests dédiés RED/GREEN, incluant protection contre une écriture ancienne arrivant après une édition récente. Les résultats complémentaires sont consignés dans [le rapport de rendu industriel](professional-industrial-rendering.md).
