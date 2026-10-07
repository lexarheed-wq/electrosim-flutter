#!/usr/bin/env python3
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

def load_contract(root=ROOT):
    return json.loads((root / "docs/f18/g2a/F18_G2A_WIRE_ROUTING_CONTRACT.json").read_text())

def validate_contract(data):
    errors=[]
    g=data.get("geometry",{})
    r=data.get("routing",{})
    p=data.get("placement",{})
    d=data.get("domains",{})
    if data.get("schemaVersion") != 2: errors.append("schemaVersion")
    if data.get("gate") != "F18-G2A": errors.append("gate")
    if g.get("allowedOrientations") != ["horizontal","vertical"]: errors.append("orthogonal-only")
    if g.get("canvasGrid") != 24 or g.get("routingTrackPitch") != 24: errors.append("grid")
    if g.get("bendKeepOut",0) < 48: errors.append("bendKeepOut")
    if g.get("minimumTerminalStub",0) < 24: errors.append("terminalStub")
    if g.get("terminalHitTarget",0) < 48: errors.append("terminalHitTarget")
    if r.get("netAware") is not True: errors.append("netAware")
    if r.get("crossingPolicy") != "avoid-then-bridge": errors.append("crossingPolicy")
    if r.get("automaticNonJunctionCrossingsAllowed") is not True: errors.append("bridgeFallback")
    if r.get("electricalConnectionMayBeRejectedForRouting") is not False: errors.append("routingMustNotRejectElectrical")
    if r.get("componentPenetrationAllowed") is not False: errors.append("componentPenetration")
    if r.get("candidateOrder") != ["straight","one-bend","two-bend","manhattan-a-star","bridge-fallback","unresolved"]: errors.append("candidateOrder")
    if p.get("autoPlacementAtBendAllowed") is not False: errors.append("bendPlacement")
    if p.get("autoPlacementRequiresStraightHost") is not True: errors.append("straightHost")
    if d.get("dc",{}).get("defaultLayout") != "rectangular-loop": errors.append("dcLayout")
    if d.get("ac1",{}).get("laneOrder") != ["L","N","PE"]: errors.append("ac1LaneOrder")
    if d.get("ac3",{}).get("laneOrder") != ["L1","L2","L3","N","PE"]: errors.append("ac3LaneOrder")
    if d.get("pv",{}).get("dcPairOrder") != ["+","-"]: errors.append("pvPairOrder")
    required={
      "axis-aligned-auto-segments",
      "different-net-crossings-avoided-before-bridge-fallback",
      "valid-electrical-connection-never-refused-by-routing",
      "different-net-crossing-is-non-junction",
      "same-net-intersection-may-junction",
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
    print("grid=24 net-aware=1 crossing=avoid-then-bridge routing-never-rejects-electrical=1")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
