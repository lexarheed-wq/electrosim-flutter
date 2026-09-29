# F9 — Architecture de l'information et parcours

**Préparation uniquement — aucun écran F9 n'est encore implémenté.**

## 1. Arbre de navigation cible

```text
Accueil ElectroSim
├── Créer une nouvelle session
│   ├── Préparation / connexion élèves
│   └── Session active
│       ├── Tableau de bord
│       │   ├── Câblage
│       │   ├── Recherche de dérangement
│       │   └── Supervision
│       └── Gérer la session
├── Centre de maintenance
│   ├── Scénarios de panne
│   └── Recherche de dérangement
└── Centre de conception
    ├── Câblage libre
    └── Bibliothèque de schémas sains
```

## 2. Shell simulateur

Le shell ne change pas de logique métier avec le breakpoint ; seule sa composition visuelle change.

### Expanded

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Navigation session / mode / état                                    │
├──────────────┬───────────────────────────────────┬───────────────────┤
│ Palette      │                                   │ Propriétés / EIE │
│              │             CANVAS                │ / Diagnostic*    │
│              │                                   │                   │
├──────────────┴───────────────────────────────────┴───────────────────┤
│ Barre d'état / mesures / simulation                                 │
└──────────────────────────────────────────────────────────────────────┘
```

### Medium

```text
┌────────────────────────────────────────────────────────────┐
│ Navigation compacte                                        │
├──────────────────────────────────────────┬─────────────────┤
│                  CANVAS                  │ Panneau unique  │
│                                          │ escamotable     │
├──────────────────────────────────────────┴─────────────────┤
│ Actions / statut                                           │
└────────────────────────────────────────────────────────────┘
```

### Compact

```text
┌──────────────────────────────┐
│ App bar / retour / contexte  │
├──────────────────────────────┤
│                              │
│            CANVAS            │
│                              │
├──────────────────────────────┤
│ Actions principales          │
└──────────────────────────────┘

Palette / propriétés / diagnostic / EIE = sheets superposées,
jamais colonnes permanentes.
```

`*` Diagnostic uniquement élève + Recherche de dérangement.

## 3. Priorité d'information

Ordre de priorité dans le workspace :

1. circuit et interaction Canvas ;
2. état de simulation et sécurité ;
3. action courante (câbler, mesurer, diagnostiquer) ;
4. propriétés / mesures ;
5. aide/EIE ;
6. navigation secondaire.

Cette hiérarchie évite que la chrome UI prenne plus de place que la tâche électrique.

## 4. Transitions de contexte

- passer compact ↔ medium ↔ expanded ne modifie ni `CircuitState`, ni sélection métier, ni révision de circuit ;
- fermer un panneau ne perd pas son contenu ;
- terminer un TP bascule vers lecture seule sans revenir à un ancien écran éditable ;
- entrer en Recherche de dérangement peut afficher la fiche diagnostic ; sortir de ce contexte la retire de l'interface.
