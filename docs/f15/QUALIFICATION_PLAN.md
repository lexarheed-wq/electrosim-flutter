# F15 — plan de qualification

F15 ne simule pas une compatibilité multi-plateforme : chaque cible bloquante doit produire une preuve issue d'un build réel.

| Cible | Hôte autorisé | Build de référence | Blocage release |
|---|---|---|---|
| macOS | macOS | `flutter build macos --debug` | Oui |
| Windows | Windows | `flutter build windows --debug` | Oui |
| Linux | Linux | `flutter build linux --debug` | Oui |
| Android | hôte avec Android SDK | `flutter build apk --debug` | Oui |
| iOS | macOS + Xcode | `flutter build ios --debug --no-codesign` | Oui |
| Web | tout hôte Flutter compatible | `flutter build web` | Non, complémentaire |

Chaque preuve est enregistrée dans `docs/f15/evidence/<target>.json` et vérifiée par le gate.
