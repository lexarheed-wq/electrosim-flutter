# M3B — Parité palette DC / moteur

M3B aligne les composants DC déjà exposés par l'interface avec les contrats du moteur.

## Modèles rendus canoniques et exploitables

- `push_button_no` : branche de commutation, état `controlState.closed`.
- `buzzer` : récepteur résistif explicite via `resistanceOhm`.
- `fan_dc` : récepteur résistif explicite dans M3B.
- `motor_dc` : récepteur résistif explicite dans M3B.
- `relay_coil` : branche résistive avec rôle structurel `controlCoil`, bornes A1/A2.
- `breaker_dc` et `fuse_dc` : seuls noms canoniques de protection DC acceptés.

Les modèles rotatifs restent résistifs à ce jalon ; les modèles dynamiques électromécaniques seront introduits séparément avec leurs propres contrats et tests.

## Normalisation UI

Les entrées de palette « Disjoncteur » et « Fusible » créent désormais `breaker_dc` et `fuse_dc`. Les composants reçoivent un calibre de protection initial explicite et des états `closed/tripped` cohérents.

## Hors M3B

La diode, non linéaire, n'est pas assimilée à une résistance. Elle reste à traiter dans un jalon dédié M3C plutôt que d'introduire une approximation silencieuse.
