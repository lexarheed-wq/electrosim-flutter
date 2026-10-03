# Figma asset pipeline — ElectroSim

Source Figma identifiée : `ElectroSim F18 - Design System G1`
File key : `TyYIfxMB0jPVIEcJPGsOwI`.

## But

Remplacer le rendu final dessiné à la main par des assets SVG exportés depuis Figma, sans modifier le moteur électrique.

## Contrat

Chaque modèle électrique possède :

- un `modelType` stable côté moteur ;
- un asset SVG par état visuel : `normal`, `active`, `selected`, `fault` ;
- une taille native issue de l'artboard Figma ;
- des ancres de bornes normalisées dans les coordonnées de l'artwork ;
- un vrai `figmaNodeId` uniquement après lecture réussie du fichier Figma.

Les node IDs ne doivent jamais être inventés.

## Architecture

`CircuitState` reste la source électrique.

`FigmaComponentAssetSpec` ne contient aucune logique électrique : il décrit seulement le visuel, son aspect ratio et l'emplacement des bornes.

Le renderer Flutter utilisera les SVG Figma à leur ratio natif, sans fond carré ni carte décorative. La hitbox rectangulaire peut exister pour le drag/sélection, mais doit rester invisible.

## État actuel

Le quota Figma MCP Starter et le quota MagicPath sont épuisés au moment de cette préparation. La structure est donc prête, mais aucun node ID ni asset exporté n'est renseigné tant que l'accès Figma n'est pas rétabli.
