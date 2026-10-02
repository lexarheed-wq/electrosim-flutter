# M1B — Contrats structurels des modèles de composants

Statut : **M1B-COMPONENT-MODEL-CONTRACT-R1**

## Objectif

Décrire la structure électrique d'un modèle de composant avant le solveur, sans reprendre les `kind`, registres globaux ou branchements implicites de V1.

## Contrats ajoutés

- `ComponentFamily` : famille fonctionnelle générale ;
- `ElectricalBranchRole` : rôle structurel d'une branche interne ;
- `ComponentBranchDefinition` : paire de terminaux appartenant à un modèle ;
- `ComponentModelContract` : nombre de terminaux, modes supportés et branches ;
- `ComponentModelRegistry` : registre immutable par `modelType` ;
- `CoreComponentModelContracts` : premier noyau canonique pour interrupteurs, protections et contacteurs.

## Décision contacteur

La nouvelle architecture ne reproduit pas les ambiguïtés historiques de bornes. Un contacteur monophasé canonique comporte un pôle de puissance + A1/A2. Un contacteur triphasé canonique comporte trois pôles de puissance + A1/A2, soit 8 bornes électriques. Les rôles `lineL1/L2/L3`, `loadT1/T2/T3`, `coilA1` et `coilA2` sont maintenant disponibles.

Cette décision est structurelle uniquement : M1B ne décide pas si le contact est ouvert, fermé ou alimenté. M6 portera l'état électromécanique et les protections.

## Compatibilité

- `CircuitState.currentSchemaVersion` reste à 1 ;
- aucun ancien `modelType` V1 n'est ajouté comme alias ;
- les solveurs existants ne sont pas modifiés ;
- les contrats ne dépendent ni de Flutter, ni d'un solveur, ni de l'UI.
