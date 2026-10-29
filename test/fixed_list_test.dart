import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/fixed.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';

import 'connections_logs_test_support.dart';
import 'performance_test_support.dart';

FixedList<int> _filled(int maxLength, Iterable<int> items) {
  final list = FixedList<int>(maxLength);
  items.forEach(list.add);
  return list;
}

List<int> _indexed(FixedList<int> list) =>
    [for (var i = 0; i < list.length; i++) list[i]];

void main() {
  group('behavior kept', () {
    test('keeps the newest maxLength items, oldest first', () {
      final list = _filled(5, [1, 2, 3]);
      expect(list.list, [1, 2, 3]);
      expect(list.length, 3);
      expect(list.maxLength, 5);

      for (var i = 4; i <= 12; i++) {
        list.add(i);
      }
      expect(list.list, [8, 9, 10, 11, 12]);
      expect(_indexed(list), [8, 9, 10, 11, 12]);
      expect(list.length, 5);
    });

    test('maxLength 1 keeps only the last item', () {
      final list = _filled(1, [1, 2, 3]);
      expect(list.list, [3]);
      expect(list[0], 3);
      expect(list.length, 1);
    });

    test('clear empties the buffer and adding starts over', () {
      final list = _filled(3, [1, 2, 3, 4])..clear();
      expect(list.list, isEmpty);
      expect(list.length, 0);
      list
        ..add(5)
        ..add(6);
      expect(list.list, [5, 6]);
      expect(_indexed(list), [5, 6]);
    });

    test('an initial list keeps its newest maxLength items', () {
      expect(FixedList<int>(3, list: [1, 2, 3, 4, 5]).list, [3, 4, 5]);
      expect(FixedList<int>(3, list: [1, 2]).list, [1, 2]);
      final list = FixedList<int>(3, list: [1, 2, 3])..add(4);
      expect(list.list, [2, 3, 4]);
    });

    test('list is an unmodifiable snapshot', () {
      final list = _filled(3, [1, 2]);
      final snapshot = list.list;
      expect(() => snapshot.add(9), throwsUnsupportedError);
      expect(() => snapshot[0] = 9, throwsUnsupportedError);
      list
        ..add(3)
        ..add(4);
      expect(snapshot, [1, 2]);
      expect(list.list, [2, 3, 4]);
    });

    test('an index out of range throws', () {
      final list = _filled(3, [1, 2, 3, 4]);
      expect(() => list[3], throwsRangeError);
      expect(() => list[-1], throwsRangeError);
    });

    test('copyWith is a new wrapper over the same items', () {
      final first = _filled(3, [1]);
      final second = first.copyWith()..add(2);
      expect(identical(first, second), isFalse);
      expect(second.maxLength, 3);
      expect(first.list, [1, 2]);
      expect(second.list, [1, 2]);
    });

    test('in-place add is seen by every wrapper', () {
      final first = _filled(2, [1]);
      final second = first.copyWith();
      first.add(2);
      second.add(3);
      expect(first.list, [2, 3]);
      expect(second.list, [2, 3]);
      second.clear();
      expect(first.length, 0);
    });

    test('matches a plain list on random operations', () {
      final random = Random(7);
      for (final maxLength in [1, 2, 5, 150]) {
        var list = FixedList<int>(maxLength);
        final reference = <int>[];
        for (var i = 0; i < 3000; i++) {
          final op = random.nextInt(100);
          if (op == 0) {
            list.clear();
            reference.clear();
          } else if (op < 5) {
            list = list.copyWith();
          } else {
            list.add(i);
            reference.add(i);
            if (reference.length > maxLength) reference.removeAt(0);
          }
          if (i % 37 == 0) {
            expect(list.list, reference, reason: 'maxLength $maxLength, op $i');
            expect(_indexed(list), reference);
          }
          expect(list.length, reference.length);
        }
      }
    });
  });

  group('version', () {
    test('add and clear bump it, reads do not', () {
      final list = FixedList<int>(2);
      final versions = <int>[list.version];
      for (var i = 0; i < 5; i++) {
        list.add(i);
        versions.add(list.version);
      }
      list.clear();
      versions.add(list.version);
      list.clear();
      versions.add(list.version);
      for (var i = 1; i < versions.length; i++) {
        expect(versions[i], greaterThan(versions[i - 1]));
      }

      list.add(1);
      final version = list.version;
      expect(list.list, [1]);
      expect(list[0], 1);
      expect(list.length, 1);
      expect(list.copyWith().version, version);
      expect(list.version, version);
    });

    test('maxLength 1 bumps it on every add', () {
      final list = FixedList<int>(1);
      var version = list.version;
      for (var i = 0; i < 4; i++) {
        list.add(i);
        expect(list.version, greaterThan(version));
        version = list.version;
      }
      expect(list.list, [3]);
    });

    test('wrappers share it, in-place add included', () {
      final first = _filled(3, [1]);
      final second = first.copyWith();
      expect(second.version, first.version);
      first.add(2);
      expect(second.version, first.version);
      second.clear();
      expect(first.version, second.version);
    });

    test('a new buffer never reuses a version', () {
      // A profile switch replaces the buffer; the same number of adds on
      // the new one must still give a version the page has not seen.
      final old = _filled(150, List.generate(40, (i) => i));
      final seen = old.version;
      final fresh = FixedList<int>(150);
      expect(fresh.version, isNot(seen));
      for (var i = 0; i < 40; i++) {
        fresh.add(i);
        expect(fresh.version, isNot(seen));
      }
      expect(FixedList<int>(3).version, isNot(FixedList<int>(3).version));
    });
  });

  group('snapshot', () {
    test('is cached until the next add or clear', () {
      final list = _filled(3, [1, 2, 3, 4]);
      final first = list.list;
      expect(identical(list.list, first), isTrue);
      expect(identical(list.copyWith().list, first), isTrue);

      list.add(5);
      final second = list.list;
      expect(identical(second, first), isFalse);
      expect(first, [2, 3, 4]);
      expect(second, [3, 4, 5]);

      list.clear();
      expect(list.list, isEmpty);
      expect(second, [3, 4, 5]);
      expect(() => list.list.add(1), throwsUnsupportedError);
    });

    test('the initial list is copied, not kept', () {
      final source = [1, 2, 3, 4, 5];
      final list = FixedList<int>(3, list: source);
      source
        ..[4] = 9
        ..add(6);
      expect(source, [1, 2, 3, 4, 9, 6]);
      expect(list.list, [3, 4, 5]);
    });
  });

  group('with Riverpod', () {
    late ProviderContainer container;

    setUp(() {
      initializePerformanceState();
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('a version select fires once per addLog, not on in-place add', () {
      final versions = <int>[];
      final sub = container.listen(
        logsProvider.select((state) => state.version),
        (_, next) => versions.add(next),
      );
      final notifier = container.read(logsProvider.notifier)
        ..addLog(sampleLog(1));
      expect(versions, hasLength(1));

      // AppController.addLog: in place, no notification.
      container.read(logsProvider).add(sampleLog(2));
      expect(versions, hasLength(1));

      notifier.addLog(sampleLog(3));
      expect(versions, hasLength(2));
      expect(versions.last, container.read(logsProvider).version);
      expect(container.read(logsProvider).list,
          [sampleLog(1), sampleLog(2), sampleLog(3)]);
      expect(globalState.appState.logs.version, versions.last);
      sub.close();
    });

    test('replacing the buffer fires even with the same number of adds', () {
      final notifier = container.read(logsProvider.notifier);
      for (var i = 0; i < 4; i++) {
        notifier.addLog(sampleLog(i));
      }
      final versions = <int>[];
      final sub = container.listen(
        logsProvider.select((state) => state.version),
        (_, next) => versions.add(next),
      );
      final seen = container.read(logsProvider).version;

      notifier.value = createEventBuffer();
      for (var i = 10; i < 14; i++) {
        notifier.addLog(sampleLog(i));
      }
      expect(versions, hasLength(5));
      expect(versions, everyElement(isNot(seen)));
      expect(container.read(logsProvider).list,
          [for (var i = 10; i < 14; i++) sampleLog(i)]);
      sub.close();
    });

    test('traffics clear keeps notifying', () {
      final versions = <int>[];
      final sub = container.listen(
        trafficsProvider.select((state) => state.version),
        (_, next) => versions.add(next),
      );
      final notifier = container.read(trafficsProvider.notifier)
        ..addTraffic(Traffic())
        ..clear();
      expect(versions, hasLength(2));
      expect(container.read(trafficsProvider).length, 0);
      notifier.addTraffic(Traffic());
      expect(container.read(trafficsProvider).length, 1);
      sub.close();
    });
  });
}
