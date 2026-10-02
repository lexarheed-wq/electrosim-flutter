# ElectroSim F18 — G4-R1 Component Visual Quality Contract

Status: **active qualification**

## Problem

The first F18 Flutter implementation reached strong shell/routing parity but
regressed the physical identity of electrical components. Eight generic
archetypes were being used as final product visuals. That is not acceptable.

## Historical quality floor

The validated V1/C31 visual line is the minimum quality floor:

- components are semi-realistic and immediately recognizable;
- palette and board use the same silhouette, only the scale changes;
- quick-access cards never fall back to emoji or generic glyphs;
- source: laboratory PSU with display and terminals;
- breaker: DIN module with lever and state indication;
- switch: physical rocker/toggle housing;
- contactor: front panel, poles, coil identity and state indication;
- lamp: recognizable bulb/lens construction;
- motor/fan: carcass, shaft/blades and mechanical identity;
- instruments: digital housing and readable display;
- fuse: physical cartridge with visible state;
- resistor: axial body and bands;
- relay/coil: coil/contact identity;
- PV/conversion/storage: differentiated equipment, not a common rectangle.

The V1/C31 renderer also treated dynamic state as public visual evidence and
kept the electrical solver independent from drawing.

## G4-R1 architecture

Production resolution order:

1. `F18ComponentVisualRegistry` dedicated model renderer;
2. historical F18 eight-family archetype renderer only for unknown models.

The registry is shared by palette previews and Canvas rendering. The same
component therefore cannot silently change silhouette after placement.

## Dedicated G4-R1 coverage

The initial quality registry covers:

- DC laboratory supply;
- breaker;
- switch;
- push button;
- lamp;
- multimeter / voltmeter / ammeter;
- resistor;
- fuse;
- buzzer;
- diode;
- DC motor;
- DC fan;
- relay coil;
- contactor;
- inverter;
- transformer;
- PV panel;
- battery;
- regulator.

## Visual qualification

A dedicated deterministic gallery is generated as
`05_flutter_component_gallery.png`.

A G4 candidate is rejected if:

- a common production model falls back to the generic archetype;
- palette and Canvas use different component identities;
- a quick-access component is represented only by a generic glyph;
- the component cannot be recognized at normal board zoom;
- the new visual is visibly poorer than the V1/C31 quality floor.

## Non-regression boundary

G4-R1 changes visual rendering only. Solver, topology, routing and TP fault
semantics remain independently validated by the F18 MagicPath workflow.
