# F9 — Langage visuel des composants électriques

## Principe

Un même composant possède une identité visuelle unique. La palette peut utiliser une variante compacte de cette identité, mais ne doit pas montrer une forme sans rapport avec la forme déposée sur la platine.

## Niveaux de représentation

1. **Palette** : silhouette immédiatement reconnaissable, nom court, famille, bornes principales lisibles si utile.
2. **Canvas nominal** : représentation technique claire avec bornes explicites et états graphiques contrôlés.
3. **Sélection** : contour/halo UI, sans modifier l'état électrique.
4. **Fonctionnement** : animation uniquement issue d'un `SimulationResult`/état physique validé.
5. **Défaut** : ne jamais afficher un défaut uniquement parce qu'une activité l'a demandé ; le visuel doit refléter un état réel ou un diagnostic prouvé.

## Familles à normaliser

- sources CC ;
- alimentation AC1 ;
- alimentation AC3 ;
- PV / onduleur ;
- protection ;
- commande/contacteurs ;
- récepteurs : lampe, moteur, ventilateur, chauffage ;
- résistances/RLC ;
- prises/appareils ;
- instruments de mesure.

## Bornes

- position et rôle stables par modèle ;
- hit target écran stable au zoom ;
- état disponible / en cours de câblage / compatible / incompatible visuellement distinct ;
- phase/polarité clairement lisible sans dépendre uniquement de la couleur.

## Niveau de détail

Le rendu doit rester lisible aux trois profils. Les détails décoratifs qui gênent les bornes, le câblage ou la lecture pédagogique sont exclus. Le réalisme recherché est fonctionnel, pas photoréaliste.
