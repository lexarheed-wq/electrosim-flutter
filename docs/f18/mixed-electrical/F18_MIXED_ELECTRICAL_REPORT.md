# F18 — Circuits mixtes AC3 et commande 24 V CC

Date : 2026-10-16 (Africa/Ouagadougou)  
État : **candidat source non qualifié**  
Base : `5da025d5`  
Commits d’implémentation : `72ff2113`, `839e899d`, `c1ecf46e`, `e46c2ecb`, `8a4f0dde`

## Livré dans le candidat source

- Un projet peut contenir un réseau de commande CC séparé d’un réseau de puissance AC3, chacun résolu par son solveur homogène.
- Le réseau CC inclut un API `plc_dc` avec entrées isolées, quatre sorties et un sous-ensemble Ladder (contacts NO/NC, TON, bobines et mémoires SET/RESET).
- Une sortie API commande une vraie bobine de relais CC dans le solveur. Son contact sec peut être lié explicitement à un contact auxiliaire AC3.
- Les retours auxiliaires AC3 sont transmis à une entrée API avec un cycle de retard. La perte d’alimentation API désactive ses sorties.
- L’interface fournit un espace projet à deux réseaux, une horloge commune, la gestion des liaisons et une enveloppe de sauvegarde versionnée qui conserve les anciennes sauvegardes monoréseau.

Une alimentation CC 24 V doit encore être dessinée dans le réseau de commande. La génération 24 V CC depuis une source 230 V CA par transformateur/redresseur n’est pas comprise dans cette phase. Le candidat ne constitue pas une certification électrique ou de sécurité machine.

## Vérifications effectuées

| Commande | Résultat |
|---|---|
| `git diff --check` | PASS |
| `python3 tools/f18_g11_audit.py` | PASS — 50 contrôles, inventaire de 291 fichiers de test |
| `dart test test/electrical_project_runtime_test.dart` depuis `apps/electrosim` avec Dart 3.10.9 embarqué | BLOQUÉ — le VM termine par `cpuinfo_macos.cc: 42: error: unreachable code` (code 134), avant l’exécution du test |
| `flutter --version` avec Flutter 3.38.10 depuis le candidat FIX10 sous `~/Downloads` | BLOQUÉ — écriture de `bin/cache/engine.stamp` refusée (`Operation not permitted`) |

L’analyse Dart/Flutter, les tests Flutter ciblés et complets, la compilation macOS Intel, le lancement de l’application, ainsi que la recette physique n’ont donc pas été qualifiés. Le contrôle statique G11 concerne les contrats F18 existants et ne remplace pas les tests d’exécution de cette fonctionnalité.

## Candidat de livraison

Les cinq commits ci-dessus sont le candidat source révisable. Aucun `.app`, archive Mac Intel ni empreinte de binaire n’est fourni : la procédure de compilation macOS active repérée dans le dépôt vise une autre branche de fonctionnalité et ne peut pas certifier ces commits. Il faut relancer analyse, tests, build et lancement sur un runner Mac Intel propre, puis effectuer une recette sur le Mac cible.
