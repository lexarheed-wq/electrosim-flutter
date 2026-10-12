# Revue Mac Intel — audit G5

Source capturée : merge GitHub `2e797e6b84748578a1774605e3d616495932646d`, tête PR140 `ede291a74c1c1e09bcb88fdaa5adf5466ab7e6eb`, run38246532244, artefact11746262209.

Les15 paires Linux/Mac ont été inspectées sur planches comparatives ; trois cas ont aussi été examinés en pleine résolution par un second agent. Aucun nouveau déplacement visible de géométrie, port ou conducteur ni débordement de disposition. Différences observées : glyphes, blocs Ahem et icônes. OFF/ON/TRIP conserve les positions et couleurs vert/rouge/ambre.

Limite : les fixtures F9 utilisent Ahem et ne prouvent pas la typographie réelle du produit. Le débordement des blocs Ahem sur le fixture premium existe dans les deux captures ; il ne doit pas être interprété comme une validation de la lisibilité réelle. Les preuves de composants avec Roboto sont dans le lot16–26.

L’ancien manifeste est conservé dans `previous-approved-pixels.json`. Le nouveau manifeste exige les SHA256 exacts des15 images et des masters Linux,9 seuls échecs widget de rasterisation attendus, sans tolérance ni dispense d’échec fonctionnel.
