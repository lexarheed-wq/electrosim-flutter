import 'dart:io';
import 'package:electrosim/runtime/workspace_layout_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a delayed old page cannot overwrite a more recent layout edit',
    () async {
      final dir = await Directory.systemTemp.createTemp('layout-save-order-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/layout.json');
      final old = WorkspaceLayoutPreferences.reserveSaveOrder();
      final recent = WorkspaceLayoutPreferences.reserveSaveOrder();
      await WorkspaceLayoutPreferences(
        file,
      ).save({'width': 320}, order: recent);
      await WorkspaceLayoutPreferences(file).save({'width': 280}, order: old);
      expect((await WorkspaceLayoutPreferences(file).load())!['width'], 320);
    },
  );
  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('electrosim-layout-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  test('missing file and corrupt JSON load safe defaults', () async {
    final file = File('${dir.path}/layout.json');
    final store = WorkspaceLayoutPreferences(file);
    expect(await store.load(), isNull);
    await file.writeAsString('{broken');
    expect(await store.load(), isNull);
    await file.writeAsString('[1,2]');
    expect(await store.load(), isNull);
  });
  test('roundtrip stays separate from circuit documents', () async {
    final file = File('${dir.path}/prefs/layout.json');
    final store = WorkspaceLayoutPreferences(file);
    final state = <String, Object?>{
      'version': 1,
      'paletteWidth': 280,
      'paletteVisible': false,
    };
    await store.save(state);
    expect(await store.load(), state);
    expect(await dir.list().length, 1);
  });
  test(
    'concurrent writes from separate views preserve the latest request',
    () async {
      final file = File('${dir.path}/layout.json');
      final first = WorkspaceLayoutPreferences(file);
      final second = WorkspaceLayoutPreferences(file);
      await Future.wait(
        List.generate(
          12,
          (i) => (i.isEven ? first : second).save({
            'version': 1,
            'paletteWidth': 264 + i,
          }),
        ),
      );
      expect((await first.load())!['paletteWidth'], 275);
      expect((await dir.list().toList()).whereType<File>().length, 1);
    },
  );
  test('failed write is surfaced and later valid writes still work', () async {
    final blocker = File('${dir.path}/blocked');
    await blocker.writeAsString('x');
    final store = WorkspaceLayoutPreferences(
      File('${blocker.path}/layout.json'),
    );
    await expectLater(
      store.save({'version': 1}),
      throwsA(isA<FileSystemException>()),
    );
    await blocker.delete();
    await store.save({'version': 1, 'paletteWidth': 300});
    expect((await store.load())!['paletteWidth'], 300);
  });
  test('save snapshots mutable input at request time', () async {
    final store = WorkspaceLayoutPreferences(File('${dir.path}/layout.json'));
    final data = <String, Object?>{'version': 1, 'paletteWidth': 300};
    final saved = store.save(data);
    data['paletteWidth'] = 999;
    await saved;
    expect((await store.load())!['paletteWidth'], 300);
  });
}
