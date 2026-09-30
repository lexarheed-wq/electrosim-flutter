# Validation physique macOS — ElectroSim F17

Base qualifiée : `ELECTROSIM2-F17-R12-QUALIFIED`

Cette validation ne sert pas à redévelopper F17. Elle confirme seulement le comportement réel sur le Mac cible après la qualification automatisée Linux/Windows/Android/macOS/iOS.

## Lancement

1. Décompresser le ZIP ElectroSim dans un dossier local.
2. Si Flutter 3.38.10 / Dart 3.10.9 n'est pas déjà disponible, télécharger tous les morceaux `flutter_macos_3.38.10-stable.zip.part-*` dans un même dossier.
3. Depuis le dossier ElectroSim, reconstruire et vérifier automatiquement l'archive officielle :

```bash
chmod +x tools/install_macos_intel_toolchain_parts.sh
./tools/install_macos_intel_toolchain_parts.sh /chemin/vers/le/dossier/des/morceaux
```

4. Ouvrir Terminal dans le dossier ElectroSim.
5. Exécuter :

```bash
chmod +x tools/run_macos_test.sh
./tools/run_macos_test.sh
```

Le lanceur :
- vérifie la toolchain verrouillée ;
- régénère le runner macOS dans un dossier temporaire ;
- applique et vérifie les permissions LAN F17-R12 ;
- exécute l'analyse Flutter et les tests rapides critiques ;
- lance ElectroSim sur macOS.

## Contrôle physique court

Valider uniquement ces points :

- Accueil : les trois accès principaux ouvrent les interfaces attendues et aucun bouton ne renvoie arbitrairement vers le moteur.
- Navigation session : Accueil, Tableau de bord et Gérer la session restent fonctionnels.
- Canvas : déplacement, sélection, câblage et suppression restent utilisables.
- Trackpad : pan à deux doigts et zoom/pinch sont fluides, sans saut ni blocage.
- Rendu : aucun débordement, clipping anormal ou panneau inaccessible.
- Persistance : Sauvegarder localement puis Reprendre la dernière sauvegarde restaure le circuit et l'état TP.
- LAN : si deux machines/appareils sont disponibles, le professeur active le partage, l'élève rejoint avec l'adresse et le code, puis une modification élève remonte et la reconnexion récupère l'état professeur.

## Résultat attendu

Si les points ci-dessus sont conformes, noter simplement :

```
F17_PHYSICAL_MAC_PASS
```

En cas d'anomalie, fournir une capture ou un enregistrement et décrire uniquement l'action qui déclenche le problème.
