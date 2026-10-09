import 'dart:io';

import 'package:electrosim/runtime/electrosim_student_web_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F17 teacher must not advertise an incomplete student Web client', () {
    final root = Directory.systemTemp.createTempSync('f17-web-');
    addTearDown(() => root.deleteSync(recursive: true));

    expect(ElectroSimStudentWebBundleLocator.isBundleValid(root), isFalse);

    File('${root.path}/index.html').writeAsStringSync('<html></html>');
    expect(ElectroSimStudentWebBundleLocator.isBundleValid(root), isFalse);

    File('${root.path}/main.dart.js').writeAsStringSync('void 0;');
    expect(ElectroSimStudentWebBundleLocator.isBundleValid(root), isTrue);

    File('${root.path}/main.dart.js').deleteSync();
    expect(ElectroSimStudentWebBundleLocator.isBundleValid(root), isFalse);
  });
}
