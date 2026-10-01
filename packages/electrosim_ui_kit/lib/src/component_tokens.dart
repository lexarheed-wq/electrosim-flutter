import 'package:flutter/material.dart';

abstract final class ElectroSimComponentTokens {
  static const double controlHeight = 40;
  static const double compactControlHeight = 32;
  static const double iconSmall = 16;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const int quickPaletteItemCount = 5;
  static const String paletteExpansionLabel = 'Voir tous';

  static const List<BoxShadow> cardElevation = <BoxShadow>[
    BoxShadow(color: Color(0x0F203753), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> floatingElevation = <BoxShadow>[
    BoxShadow(color: Color(0x1A203753), blurRadius: 36, offset: Offset(0, 16)),
  ];
  static const List<BoxShadow> dialogElevation = <BoxShadow>[
    BoxShadow(color: Color(0x29203553), blurRadius: 55, offset: Offset(0, 20)),
  ];
}
