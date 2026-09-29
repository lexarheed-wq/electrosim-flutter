# ElectroSim F15-R6

Correction de qualification iOS : un composant/runtime iOS absent dans Xcode est classé `F15_TARGET_UNAVAILABLE` au lieu de faire échouer toute la qualification de l'hôte. Aucun fichier de preuve PASS iOS n'est créé dans ce cas. Les autres échecs de build restent bloquants.
