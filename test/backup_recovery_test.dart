import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/archive.dart';
import 'package:path/path.dart' as p;

void main() {
  group('backup recovery path checks', () {
    final home = p.join('tmp', 'meowclash');
    final profiles = p.join(home, 'profiles');

    test('allows files restored under profiles', () {
      expect(
        isSafeBackupProfileEntry(
          homeDirPath: home,
          profilesPath: profiles,
          entryName: p.join('profiles', 'profile.yaml'),
        ),
        isTrue,
      );
    });

    test('rejects traversal and non-profile writes', () {
      for (final entryName in [
        p.join('profiles', '..', 'evil.yaml'),
        p.join('..', 'evil.yaml'),
        p.join('cores', 'MeowClashCore'),
      ]) {
        expect(
          isSafeBackupProfileEntry(
            homeDirPath: home,
            profilesPath: profiles,
            entryName: entryName,
          ),
          isFalse,
        );
      }
    });

    test('rejects absolute paths', () {
      expect(
        isSafeBackupProfileEntry(
          homeDirPath: home,
          profilesPath: profiles,
          entryName: p.absolute('evil.yaml'),
        ),
        isFalse,
      );
    });
  });
}
