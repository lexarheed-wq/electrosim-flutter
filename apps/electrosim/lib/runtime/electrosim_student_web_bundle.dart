import 'dart:io';

final class ElectroSimStudentWebBundleLocator {
  const ElectroSimStudentWebBundleLocator._();

  static Directory? resolve() {
    final String? configured =
        Platform.environment['ELECTROSIM_STUDENT_WEB_ROOT'];
    if (configured != null && configured.trim().isNotEmpty) {
      final Directory directory = Directory(configured.trim());
      if (isBundleValid(directory)) return directory;
    }

    final Directory executableDirectory = File(
      Platform.resolvedExecutable,
    ).parent;
    final List<Directory> candidates = <Directory>[
      Directory('${Directory.current.path}/build/student_web'),
      Directory(
        '${executableDirectory.parent.path}/Resources/electrosim_student_web',
      ),
      Directory('${executableDirectory.path}/electrosim_student_web'),
    ];
    for (final Directory candidate in candidates) {
      if (isBundleValid(candidate)) return candidate;
    }
    return null;
  }

  // A release must contain BOTH the entry document and its Dart JS payload.\n  // This guard is also exercised by packaging tests.\n  static bool isBundleValid(Directory directory) =>
      directory.existsSync() &&
      File('${directory.path}/index.html').existsSync() &&
      File('${directory.path}/main.dart.js').existsSync();
}
