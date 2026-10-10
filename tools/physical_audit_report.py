#!/usr/bin/env python3
"""Summarize instrumented physical simulations into reproducible evidence."""
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

source = Path(sys.argv[1])
dest = Path(sys.argv[2])
commit = sys.argv[3] if len(sys.argv) > 3 else "unknown"
dest.mkdir(parents=True, exist_ok=True)
rows = []
for line in source.read_text(encoding="utf-8", errors="replace").splitlines():
    if "PHYSICS_AUDIT_JSON:" not in line:
        continue
    payload = line.split("PHYSICS_AUDIT_JSON:", 1)[1]
    payload = re.sub(r"\x1b\[[0-9;]*m", "", payload).strip()
    try:
        item = json.loads(payload)
    except json.JSONDecodeError:
        print("Malformed audit observation", file=sys.stderr)
        continue
    if isinstance(item, dict):
        rows.append(item)

(dest / "physical_audit_results.json").write_text(
    json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
)
fields = ["family","case","verdict","mode","model","kind","solved","error"]
with (dest / "physical_audit_results.csv").open("w", newline="", encoding="utf-8") as out:
    writer = csv.writer(out)
    writer.writerow(fields)
    for item in rows:
        writer.writerow([item.get(field, "") for field in fields])
counts = Counter(str(item.get("verdict")) for item in rows)
by_family = defaultdict(list)
for item in rows:
    by_family[str(item.get("family", "unknown"))].append(item)
inventory = next((r for r in rows if r.get("family") == "inventory-summary"), {})
report = [
    "# ElectroSim — Rapport détaillé de qualification physique",
    "",
    "Exécution instrumentée du moteur ElectroSimRuntimeEngine (simulation numérique, non banc physique).",
    "",
    "**SHA testé :** " + commit,
    "**Observations :** " + str(len(rows)),
    "**Répartition :** " + "; ".join(f"{k}: {v}" for k,v in sorted(counts.items())),
    "",
    "## Portée et règles d'interprétation",
    "",
    "Le balayage parcourt chaque entrée de palette et chaque mode annoncé, sans câblage. "
    "Ne pas résoudre un circuit déconnecté n'est pas une régression. "
    "Les cas de lois physiques, eux, sont alimentés et comparés à des résultats calculés indépendamment. "
    "Les instruments physiques sans bornes sont des overlays ; pas des branches électriques.",
    "",
    "## Inventaire systématique",
    "",
    "- Entrées dans la palette : " + str(inventory.get("entries", "NON MESURÉ")),
    "- Modèles distincts : " + str(inventory.get("distinctModels", "NON MESURÉ")),
    "- Couples palette/mode explorés : " + str(inventory.get("modelModeAttempts", "NON MESURÉ")),
    "- Exceptions et résidus non finis : " + str(inventory.get("exceptionsAndNonfinite", "NON MESURÉ")),
    "",
    "## Résultats instrumentés",
    "",
]
for family, family_rows in sorted(by_family.items()):
    report.extend(["### " + family, "", "| Cas | Verdict | Mesures / diagnostics |", "|---|---|---|"])
    for row in family_rows:
        details = ", ".join(
            key + "=" + json.dumps(value, ensure_ascii=False)
            for key, value in row.items()
            if key not in ("case", "family", "verdict", "note")
        )
        details = details.replace("|", "/")
        if len(details) > 420:
            details = details[:420] + "…"
        report.append("| " + str(row.get("case", "")).replace("|", "/") +
                      " | " + str(row.get("verdict")) + " | " + details + " |")
    report.append("")
report.extend([
    "## Critères de qualification",
    "",
    "Une résistance alimentée doit respecter U=RI, P=UI ; les résistances en série et en "
    "parallèle doivent respecter Kirchhoff. Les sources ne doivent pas tomber à 0 V "
    "lorsqu'une charge valide est connectée. Les résultats AC1 doivent respecter "
    "les valeurs RMS et la puissance active ; AC3 doit produire des courants de "
    "phase symétriques et un courant de neutre quasi nul pour une étoile équilibrée.",
    "",
    "## Limites explicites",
    "",
    "Les topologies possibles sont combinatoires : aucune campagne finie ne peut "
    "couvrir absolument tous les câblages, charges et paramètres. Ce rapport couvre "
    "uniquement les observations listées. Les tests à vide ne vérifient pas "
    "le comportement sous charge. Les transitoires, tolérances, échauffements, "
    "protections chronométrées, conditions extrêmes PV et instruments doivent aussi "
    "être qualifiés par des essais spécialisés. Aucun essai de matériel physique "
    "ni de téléphones Mac/LAN n'est revendiqué ici.",
    "",
])
(dest / "RAPPORT_QUALIFICATION_PHYSIQUE.md").write_text("\n".join(report), encoding="utf-8")
print(f"AUDIT_REPORT_COLLECTED={len(rows)}", flush=True)
if not rows:
    sys.exit(2)
