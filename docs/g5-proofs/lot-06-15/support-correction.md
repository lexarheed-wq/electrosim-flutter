# Correction des appuis : pompes et mélangeur

Les pattes moulées des pompes portent le carter et permettent son ancrage. Le
châssis roulant du mélangeur supporte le mât et le moteur ; la tête de mélange
reste suspendue dans l'espace réservé à une cuve. Les roues ne portent donc pas
directement la tête de mélange et celle-ci ne doit pas être collée au socle.

Références déjà téléchargées et examinées : photo officielle du mélangeur
[Silverson](https://www.silverson.com/us/products/batch-mixers), pompe
[Pedrollo CP](https://www.pedrollo.com/prodotto/superficie/centrifughe-monogiranti-e-bigiranti/centrifughe-monogirante/cp/)
et famille de pompes [Lorentz](https://www.lorentz.de/products-and-technology/products/ps2-solar-pumping-systems/).
Leurs images et empreintes sont recensées dans `photo-references.json`.

Corrections de géométrie :

- Pompes AC1 et triphasée : cols moulés reliant les pattes au carter moteur et
  à la volute, avec recouvrement réel des volumes.
- Pompe solaire : oreilles d'ancrage raccordées au socle.
- Mélangeur : châssis en U avec traverse arrière, jambes longitudinales,
  embase soudée du mât et gousset ; roulettes avec platines, pivots, fourches,
  axes et pédales de frein. La tête reste libre entre les jambes du châssis.

Ces modifications concernent les maillages et leurs textures. Les dimensions
logiques, bornes, raccordements, modèles électriques et projets sauvegardés
conservent leur contrat existant.

Contrôle reproductible des contacts structurels sur les objets Blender :

```sh
blender -b --factory-startup --python-exit-code 1 \
  --python tools/g5_3d_remaining/check_support_connections.py
```

Ce contrôle mesure les recouvrements des boîtes englobantes des objets : il
détecte les appuis séparés et vérifie la chaîne de support du châssis. Les
surfaces courbes et l'apparence des soudures nécessitent aussi la revue des
rendus. Il ne constitue pas un calcul de résistance mécanique.
