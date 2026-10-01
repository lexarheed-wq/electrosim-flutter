# ElectroSim F18 — Validation physique Mac après G3

Candidat source qualifié : `6bcfacbf2b39c0667ac695a80b39d4f3e215615b`

## Avant le test

1. Décompresser l’archive du candidat.
2. Ouvrir `ElectroSim.app`.
3. Si macOS indique que le développeur ne peut pas être vérifié, utiliser **Ctrl-clic > Ouvrir > Ouvrir**. Ne pas désactiver Gatekeeper.
4. Aucun Flutter ni Xcode n’est nécessaire pour exécuter ce candidat.

## Test physique minimal

### A — Accueil
- Vérifier les 3 cartes principales : Créer une nouvelle session / Centre de maintenance / Centre de conception.
- Vérifier que Rejoindre une session reste une action secondaire.
- Vérifier absence de zone coupée ou hors écran.

### B — Session professeur
- Créer une nouvelle session.
- Vérifier que le Tableau de bord apparaît avant le simulateur.
- Vérifier Câblage / Recherche de dérangement / Supervision.
- Ouvrir Gérer la session, créer un TP, fermer puis rouvrir : le même TP doit toujours être présent.

### C — Supervision
- Ouvrir Supervision.
- Vérifier qu’elle s’ouvre hors du simulateur.
- Vérifier que le TP créé apparaît avec le même état.

### D — Partage réseau local
- Ouvrir Gérer la session puis Activer le partage professeur.
- Vérifier qu’une adresse réseau et un code à 6 caractères apparaissent.

### E — Câblage
- Depuis le Tableau de bord, ouvrir Câblage.
- Vérifier que le simulateur s’ouvre seulement à ce moment.
- Vérifier Accueil / Tableau de bord / Gérer la session.
- Revenir au Tableau de bord puis rouvrir Câblage.

### F — Recherche de dérangement
- Depuis le Tableau de bord, ouvrir Recherche de dérangement.
- Vérifier que le simulateur s’ouvre dans ce mode puis revenir au Tableau de bord.

### G — Canvas / trackpad
- Tester déplacement du Canvas au trackpad et zoom avant/arrière.
- Déplacer quelques composants.
- Créer quelques liaisons et vérifier que le routage automatique privilégie les segments orthogonaux et évite les croisements automatiques inutiles.

## À signaler

Pour chaque anomalie : écran concerné, action juste avant, résultat attendu, résultat obtenu, capture ou courte vidéo si possible.

Ce test physique G3 valide le parcours réel Mac jusqu’à G3 ; il ne constitue pas encore le marker physique final de F18.