enum ElectroSimWindowClass { compact, medium, expanded }

abstract final class ElectroSimBreakpoints {
  static const double compactUpperBound = 600;
  static const double mediumUpperBound = 1000;

  static ElectroSimWindowClass classify(double width) {
    if (width < compactUpperBound) {
      return ElectroSimWindowClass.compact;
    }
    if (width <= mediumUpperBound) {
      return ElectroSimWindowClass.medium;
    }
    return ElectroSimWindowClass.expanded;
  }
}
