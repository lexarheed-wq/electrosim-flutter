import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Web student frontend must not depend on the desktop main entrypoint',
    () {
      final web = File('lib/student_web_main.dart').readAsStringSync();
      final workspace = File('lib/f18_workspace_page.dart').readAsStringSync();
      final desktop = File('lib/main.dart').readAsStringSync();

      expect(web, contains("import 'f18_workspace_page.dart';"));
      expect(web, isNot(contains("import 'main.dart'")));
      expect(web, isNot(contains('product.F18WorkspacePage')));
      expect(web, contains('F18WorkspacePage('));
      expect(
        workspace,
        contains('class F18WorkspacePage extends StatefulWidget'),
      );
      expect(workspace, isNot(contains("import 'main.dart'")));
      expect(workspace, isNot(contains("import 'f18_home.dart'")));
      expect(
        workspace,
        isNot(contains("import 'f18_session_coordinator.dart'")),
      );
      expect(desktop, contains("import 'f18_workspace_page.dart';"));
      expect(
        desktop,
        contains("export 'f18_workspace_page.dart' show F18WorkspacePage;"),
      );
      expect(
        desktop,
        isNot(contains('class F18WorkspacePage extends StatefulWidget')),
      );
    },
  );

  test(
    'Web sync uses the host reconnect token and never marks a drop as ended',
    () {
      final bridge = File(
        'lib/runtime/electrosim_student_web_sync.dart',
      ).readAsStringSync();
      expect(bridge, contains("payloadRaw['reconnectToken']"));
      expect(bridge, contains("'reconnectToken': _reconnectToken!"));
      expect(bridge, contains('maxAutomaticReconnects'));
      expect(bridge, contains('Future<void> retry()'));
      expect(bridge, contains('_teacherEnded'));
      expect(bridge, contains('controller.toStudentPersistenceJson()'));
    },
  );
}
