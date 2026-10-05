import 'dart:io';

final class ElectroSimStudentWebBundleLocator {
  const ElectroSimStudentWebBundleLocator._();

  static Directory? resolve() {
    final String? configured =
        Platform.environment['ELECTROSIM_STUDENT_WEB_ROOT'];
    if (configured != null && configured.trim().isNotEmpty) {
      final Directory directory = Directory(configured.trim());
      if (_valid(directory)) return directory;
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
      if (_valid(candidate)) return candidate;
    }
    return null;
  }

  static bool _valid(Directory directory) =>
      directory.existsSync() &&
      File('${directory.path}/index.html').existsSync() &&
      File('${directory.path}/main.dart.js').existsSync();
}
