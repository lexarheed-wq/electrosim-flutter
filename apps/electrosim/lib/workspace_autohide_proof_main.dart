import 'package:flutter/material.dart';

import 'main.dart' show F9WorkspaceDemoPage;

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: F9WorkspaceDemoPage(initialSelectedElementId: 'switch-1'),
    ),
  );
}
