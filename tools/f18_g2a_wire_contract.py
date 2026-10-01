#!/usr/bin/env python3
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTRACT = ROOT / "docs/f18/g2a/F18_G2A_WIRE_ROUTING_CONTRACT.json"

def load_contract(root=ROOT):
    return json.loads((root / "docs/f18/g2a/F18_G2A_WIRE_ROUTING_CONTRACT.json").read_text())

def validate_contract(data):
    errors=[]
    g=data.get("geometry",{})
    r=data.get("routing",{})
    p=data.get("placement",{})
    d=data.get("domains",{})
    if data.get("schemaVersion") != 1: errors.append("schemaVersion")
    if data.get("gate") != "F18-G2A": errors.append("gate")
    if g.get("allowedOrientations") != ["horizontal","vertical"]: errors.append("orthogonal-only")
    if g.get("canvasGrid") != 24 or g.get("routingTrackPitch") != 24: errors.append("grid")
    if g.get("bendKeepOut",0) < 48: errors.append("bendKeepOut")
    if g.get("minimumTerminalStub",0) < 24: errors.append("terminalStub")
    if g.get("terminalHitTarget",0) < 48: errors.append("terminalHitTarget")
    if r.get("automaticDifferentNetCrossingsAllowed") is not False: errors.append("crossings")
    if r.get("automaticNonJunctionCrossingsAllowed") is not False: errors.append("autoNonJunctionCrossing")
    if r.get("unresolvedInsteadOfCrossing") is not True: errors.append("unresolvedPolicy")
    if r.get("candidateOrder") != ["straight","one-bend","two-bend","manhattan-a-star","unresolved"]: errors.append("candidateOrder")
    if p.get("autoPlacementAtBendAllowed") is not False: errors.append("bendPlacement")
    if p.get("autoPlacementRequiresStraightHost") is not True: errors.append("straightHost")
    if d.get("dc",{}).get("defaultLayout") != "rectangular-loop": errors.append("dcLayout")
    if d.get("ac1",{}).get("laneOrder") != ["L","N","PE"]: errors.append("ac1LaneOrder")
    if d.get("ac3",{}).get("laneOrder") != ["L1","L2","L3","N","PE"]: errors.append("ac3LaneOrder")
    if d.get("pv",{}).get("dcPairOrder") != ["+","-"]: errors.append("pvPairOrder")
    if len(data.get("referenceScenarios",[])) < 10: errors.append("referenceScenarios")
    required={
      "axis-aligned-auto-segments","zero-auto-different-net-crossings",
      "zero-auto-components-in-bend-keepout","dc-centered-symmetric-inline-placement",
      "topology-preserved-by-reroute","deterministic-routing","idempotent-reroute"
    }
    if not required.issubset(set(data.get("invariants",[]))): errors.append("invariants")
    return errors

def main():
    errors=validate_contract(load_contract())
    if errors:
        print("F18_G2A_WIRE_ARCHITECTURE_SPEC_FAIL")
        for e in errors: print(e)
        return 1
    print("F18_G2A_WIRE_ARCHITECTURE_SPEC_PASS")
    print("grid=24 bend_keepout=48 auto_crossings=0 dc=rectangular ac1=L,N,PE ac3=L1,L2,L3,N,PE")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
