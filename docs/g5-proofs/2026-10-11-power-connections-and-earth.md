# Raccordements des appareils externes et terre du châssis

Branche : `feat/g5-3d-sequential-26-components`. Travail séparé des qualifications 3D des 26 composants : seuls les composants 01–04 restent qualifiés à ce stade. Aucune fusion G5/main et aucune qualification globale de release.

## Utilisation

1. Pour un appareil mobile, choisir **Raccordement → Cordon avec fiche** dans les propriétés. Les nouveaux réfrigérateurs, congélateurs, fers, ordinateurs et téléviseurs utilisent ce mode par défaut.
2. Ajouter **Prise alimentation L/N/PE**, catégorie **Raccordements**, puis câbler ses entrées L, N et PE au circuit réel.
3. Choisir cette prise dans les propriétés de l'appareil. Le câble souple représente deux conducteurs pour un appareil sans PE et trois pour un appareil de classe I.
4. Choisir **Fiche débranchée** pour supprimer les liaisons du cordon. Les fils d'alimentation de la prise sont conservés.
5. Pour une installation fixe, conserver **Boîtier / raccordement fixe** et raccorder ses bornes. Les machines triphasées restent en raccordement fixe, avec leurs six bornes de bobinage et une borne PE supplémentaire. Les moteurs seuls sont inchangés.
6. Les appareils DC utilisent **Connecteur courant continu** et **Connecteur alimentation CC**, sans fiche secteur AC. La pompe solaire DC est reconnue par son modèle moteur DC.

Les projets existants conservent leur raccordement fixe jusqu'à une modification explicite : aucun ancien câble n'est remplacé automatiquement. Une conversion en fiche est refusée tant que des fils directs subsistent, pour éviter un contournement du débranchement. Une prise occupée ne reçoit pas un second appareil.

## Contrat électrique

- `power_socket_ac` : six bornes, trois traversées indépendantes L→L, N→N et PE→PE. Aucune liaison interne N–PE et aucune source implicite.
- `power_socket_dc` : quatre bornes, deux traversées indépendantes +→+ et −→−.
- Le cordon est constitué de vraies connexions du domaine, identifiées par la métadonnée `appliancePowerCable`. Leur représentation physique est un câble souple avec une fiche ; la vue schéma conserve les conducteurs.
- Les appareils AC de classe I sont représentés par `earthed_resistor` ou `earthed_impedance`. Leurs anciens identifiants L/N, paramètres, état et positions de connexion restent identiques ; PE est ajouté au châssis.
- Les machines industrielles triphasées utilisent `earthed_machine_3p_7t`. Leurs trois bobinages à six bornes, couplages étoile/triangle et animation restent inchangés ; PE est séparé des bobinages.
- L'ajout du PE est idempotent et évite les collisions avec les identifiants des anciens projets.
- Les classifications II/III explicites n'acquièrent pas de PE fictif. Le téléviseur générique est traité par défaut sans PE ; un modèle concret déclaré classe I peut être différent. La classification doit être vérifiée sur la référence fabricant retenue.
- Les séances TP actives ne subissent pas de migration automatique de leurs composants, pour préserver leurs contrats d'évaluation.

## Défaut d'isolement

Le commutateur **Défaut d'isolement phase / châssis** ajoute, uniquement dans le circuit calculé, une résistance entre la première phase et PE. Valeur par défaut : 1 kΩ. Le paramètre `insulationFaultResistanceOhm` permet une autre valeur finie strictement positive.

Le défaut ne crée aucune terre idéale. Le courant dépend du circuit réellement raccordé, notamment de l'impédance du retour de terre. Une rupture du PE ne déclenche pas artificiellement le différentiel. Les composants de défaut restent internes au calcul et ne polluent pas la platine ni les sauvegardes.

Dans le cas TN utilisé par le test, le raccordement terre/neutre est placé à l'amont du différentiel. Sous 230 V, le défaut de 1 kΩ produit 230 mA : le différentiel de 30 mA déclenche après son délai modélisé. Avec PE coupé, le courant de défaut est nul et le châssis atteint 230 V par rapport au neutre. Ce dernier cas ne constitue pas une situation protégée.

L'inspecteur affiche la tension **châssis / neutre**, issue des tensions complexes du solveur, et signale une valeur supérieure à 50 V en rouge. Il affiche **indéterminée** lorsque ces points n'appartiennent pas au même réseau de branches actives, au lieu de présenter un zéro arbitraire d'îlot flottant.

Il s'agit d'un modèle de défaut résistif en régime permanent. Capacité parasite, courant à travers une personne, défaut d'arc, transitoires de contacts et qualification détaillée des schémas TT/IT ne sont pas modélisés par ce changement. La prise CEE d'une machine complète avec démarreur interne n'est pas assimilée à ses six bornes de bobinage.

## Vérification et preuves

Tests ciblés : raccordement/débranchement, incompatibilité AC/DC, collision d'identifiants, absence de PE sur classe II, conservation des bornes L/N, défaut avec/sans PE, déclenchement différentiel, couplages étoile/triangle et courant triphasé, commandes de l'interface réelle, instruments précédemment qualifiés et silhouettes existantes.

Les captures sont produites par `tool/capture_g5_power_connections_test.dart` dans le véritable `F18WorkspacePage`, avec branchement, débranchement et commande de défaut exercés par Flutter. Elles ne prétendent pas qualifier le nouveau rendu 3D du réfrigérateur, encore à réaliser.

- [Appareil branché et PE raccordé](power-connections/connected-pe.png)
- [Fiche débranchée et châssis isolé](power-connections/unplugged.png)

Les deux nouveaux connecteurs possèdent actuellement un rendu vectoriel avec relief. Ils n'ont pas encore de qualification photographique fabricant ni de texture Cycles dédiée.

Résultat de la campagne ciblée : **51 tests passés**. La capture a également été régénérée et vérifiée après amélioration des broches visibles de la fiche débranchée. Analyse statique des fichiers Dart applicatifs modifiés : aucune anomalie. Les builds de distribution et la qualification globale G5 restent à réaliser.
