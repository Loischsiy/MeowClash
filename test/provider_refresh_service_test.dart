// Explicit lifecycle steps make ordering assertions readable.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/services/provider_refresh_plan.dart';
import 'package:meowclash/services/provider_refresh_service.dart';

final epoch = DateTime.utc(2026);

ProviderRefreshPlan plan(
        {String id = 'A',
        String? password = 'fixture-only',
        int interval = 1200,
        bool both = true}) =>
    ProviderRefreshPlan.fromConfig(
      profileId: id,
      userAgent: 'MeowClash-test',
      password: password,
      config: {
        'proxy-providers': {
          'shared': {
            'type': 'http',
            'url': 'https://example.invalid/proxies',
            'path': '/$id/proxies',
            'interval': interval
          }
        },
        if (both)
          'rule-providers': {
            'shared': {
              'type': 'http',
              'url': 'https://example.invalid/rules',
              'path': '/$id/rules',
              'interval': interval
            }
          },
      },
    );

class Harness {
  Harness(this.clock) {
    service = ProviderRefreshService(
      invokeCore: (text) async {
        final action = json.decode(text) as Map<String, dynamic>;
        actions.add(action);
        final responder = coreResponder;
        if (responder != null) return responder(action);
        return json.encode({
          'id': action['id'],
          'method': action['method'],
          'code': 0,
          'data': action['method'] == 'startListener' ||
                  action['method'] == 'stopListener'
              ? true
              : (action['method'] == 'sideLoadExternalProvider'
                  ? coreError
                  : ''),
        });
      },
      isRunning: () => running,
      fetch: (p, target, cancellation) {
        downloads.add(target.key);
        cancellations.add(cancellation);
        return fetcher?.call(p, target, cancellation) ??
            Future.value(Uint8List.fromList([77, 82, 83, 0, 255, 128]));
      },
      modifiedAt: (path) async => writes[path] ?? epoch,
      persist: (path, bytes) async {
        persisted.add(path);
        writes[path] = epoch.add(clock.elapsed);
      },
      log: logs.add,
      now: () => epoch.add(clock.elapsed),
    );
  }
  final FakeAsync clock;
  late final ProviderRefreshService service;
  bool running = true;
  String coreError = '';
  ProviderPayloadFetcher? fetcher;
  Future<String> Function(Map<String, dynamic> action)? coreResponder;
  final downloads = <String>[];
  final cancellations = <CancelToken>[];
  final persisted = <String>[];
  final writes = <String, DateTime>{};
  final actions = <Map<String, dynamic>>[];
  final logs = <String>[];

  void configure(ProviderRefreshPlan p) {
    unawaited(service.configure<String>(p, () async => '',
        succeeded: (result) => result.isEmpty));
    clock.flushMicrotasks();
  }

  Iterable<Map<String, dynamic>> get applied =>
      actions.where((action) => action['method'] == 'sideLoadExternalProvider');
}

void main() {
  test('providers sharing a cache retain independent refresh deadlines', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(ProviderRefreshPlan(
        profileId: 'A',
        userAgent: 'test',
        password: 'fixture-only',
        targets: const [
          ProviderRefreshTarget(
              name: 'fast',
              type: 'Proxy',
              url: 'https://example.invalid/shared',
              path: '/A/shared',
              interval: Duration(minutes: 20)),
          ProviderRefreshTarget(
              name: 'slow',
              type: 'Proxy',
              url: 'https://example.invalid/shared',
              path: '/A/shared',
              interval: Duration(minutes: 60)),
        ],
      ));
      clock.elapse(const Duration(minutes: 60));
      expect(
          h.downloads.where((key) => key == 'Proxy\u0000fast'), hasLength(3));
      expect(
          h.downloads.where((key) => key == 'Proxy\u0000slow'), hasLength(1));
      h.service.dispose();
    });
  });

  test('stop during setup retains the plan for a later explicit start', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final setup = Completer<String>();
      unawaited(h.service.configure<String>(
          plan(both: false), () => setup.future,
          succeeded: (value) => value.isEmpty));
      clock.flushMicrotasks();
      h.service.suspend();
      setup.complete('');
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 0);
      h.service.resume();
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 20));
      expect(h.downloads, hasLength(1));
      h.service.dispose();
    });
  });

  test('shutdown during setup invalidates its plan even after a late reply',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final setup = Completer<String>();
      unawaited(h.service.configure<String>(
          plan(both: false), () => setup.future,
          succeeded: (value) => value.isEmpty));
      clock.flushMicrotasks();
      unawaited(h.service.handleAction(json.encode({
        'id': 'shutdown',
        'method': 'shutdown',
        'data': null,
      })));
      setup.complete('');
      clock.flushMicrotasks();
      h.service.resume();
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(h.downloads, isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
      h.service.dispose();
    });
  });

  test('stop while native refresh is pending prevents a late cache commit', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan(both: false));
      final nativeReply = Completer<String>();
      h.coreResponder = (_) => nativeReply.future;
      clock.elapse(const Duration(minutes: 20));
      expect(h.applied, hasLength(1));
      h.service.suspend();
      nativeReply.complete(json.encode({'code': 0, 'data': ''}));
      clock.flushMicrotasks();
      expect(h.persisted, isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
      h.service.dispose();
    });
  });

  test('a late start reply cannot restart polling after a stop request', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan(both: false));
      h.service.suspend();
      final startReply = Completer<String>();
      h.coreResponder = (action) async {
        if (action['method'] == 'startListener') return startReply.future;
        return json.encode({
          'id': action['id'],
          'method': action['method'],
          'code': 0,
          'data': true,
        });
      };
      unawaited(h.service.handleAction(json.encode({
        'id': 'start',
        'method': 'startListener',
        'data': null,
      })));
      clock.flushMicrotasks();
      unawaited(h.service.handleAction(json.encode({
        'id': 'stop',
        'method': 'stopListener',
        'data': null,
      })));
      h.running = false;
      clock.flushMicrotasks();
      startReply.complete(json.encode({
        'id': 'start',
        'method': 'startListener',
        'code': 0,
        'data': true,
      }));
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 0);
      clock.elapse(const Duration(hours: 2));
      expect(h.downloads, isEmpty);
      h.service.dispose();
    });
  });

  test(
      'headless service refreshes both namespaces at 1200 seconds, not earlier',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan());
      clock.elapse(const Duration(minutes: 19));
      expect(h.downloads, isEmpty);
      clock.elapse(const Duration(minutes: 1));
      expect(h.downloads, ['Proxy\u0000shared', 'Rule\u0000shared']);
      expect(h.persisted, ['/A/proxies', '/A/rules']);
      final payloads = h.applied
          .map((action) => json.decode(action['data'] as String) as Map)
          .toList();
      expect(payloads.map((payload) => payload['providerType']),
          ['Proxy', 'Rule']);
      expect(base64.decode(payloads.first['dataBase64'] as String),
          [77, 82, 83, 0, 255, 128]);
      clock.elapse(const Duration(minutes: 19));
      expect(h.downloads, hasLength(2));
      clock.elapse(const Duration(minutes: 1));
      expect(h.downloads, hasLength(4));
      h.service.dispose();
    });
  });

  test('manual refresh and due automatic tick share the same request', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final p = plan(both: false);
      final blocked = Completer<Uint8List>();
      h.fetcher = (_, __, ___) => blocked.future;
      h.configure(p);
      clock.elapse(const Duration(minutes: 20));
      final first = h.service.refresh(p.targets.single);
      final second = h.service.refresh(p.targets.single);
      expect(identical(first, second), isTrue);
      clock.elapse(const Duration(minutes: 40));
      expect(h.downloads, hasLength(1));
      blocked.complete(Uint8List.fromList([1, 2, 3]));
      clock.flushMicrotasks();
      expect(h.persisted, hasLength(1));
      h.service.dispose();
    });
  });

  test('switching profile cancels downloads and cannot publish stale bytes',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final blocked = Completer<Uint8List>();
      h.fetcher = (_, __, ___) => blocked.future;
      h.configure(plan(both: false));
      clock.elapse(const Duration(minutes: 20));
      expect(h.downloads, hasLength(1));
      h.writes['/B/proxies'] = epoch.add(clock.elapsed);
      h.configure(plan(id: 'B', both: false));
      expect(h.cancellations.first.isCancelled, isTrue);
      blocked.complete(Uint8List.fromList([9]));
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      expect(h.persisted, isEmpty);
      expect(h.applied, isEmpty);
      h.service.dispose();
    });
  });

  test('stop during download leaves no timer or late update; resume catches up',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final blocked = Completer<Uint8List>();
      h.fetcher = (_, __, ___) => blocked.future;
      h.configure(plan(both: false));
      clock.elapse(const Duration(minutes: 20));
      h.service.suspend();
      blocked.complete(Uint8List.fromList([9]));
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(h.persisted, isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
      h.fetcher = null;
      h.service.resume();
      clock.flushMicrotasks();
      expect(h.persisted, ['/A/proxies']);
      h.service.dispose();
    });
  });

  test('offline/decryption failure retries and does not block other providers',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.fetcher = (_, target, __) async {
        if (target.type == 'Proxy') {
          throw const FormatException('fixture failure');
        }
        return Uint8List.fromList([1]);
      };
      h.configure(plan());
      clock.elapse(const Duration(minutes: 20));
      expect(h.persisted, ['/A/rules']);
      h.fetcher = null;
      clock.elapse(const Duration(minutes: 1));
      expect(h.persisted, ['/A/rules', '/A/proxies']);
      expect(h.downloads.where((key) => key.startsWith('Rule')), hasLength(1));
      expect(h.logs.join(), isNot(contains('fixture-only')));
      h.service.dispose();
    });
  });

  test('nonempty core error is failure and never commits cache', () {
    fakeAsync((clock) {
      final h = Harness(clock)..coreError = 'invalid rule data';
      h.configure(plan(both: false));
      clock.elapse(const Duration(minutes: 20));
      expect(h.persisted, isEmpty);
      h.coreError = '';
      clock.elapse(const Duration(minutes: 1));
      expect(h.persisted, hasLength(1));
      h.service.dispose();
    });
  });

  test('disabled interval and stopped VPN do not cause background downloads',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan(interval: 0));
      clock.elapse(const Duration(hours: 2));
      expect(h.downloads, isEmpty);
      h.running = false;
      h.configure(plan());
      clock.elapse(const Duration(hours: 2));
      expect(h.downloads, isEmpty);
      h.service.dispose();
    });
  });

  test('unencrypted providers retain native scheduling without Dart duplicates',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan(password: null));
      clock.elapse(const Duration(hours: 2));
      expect(h.downloads, isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
      h.service.dispose();
    });
  });

  test(
      'setup IPC strips credentials and preserves the original interval snapshot',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      final config = <String, dynamic>{
        'proxy-providers': {
          'nodes': {
            'type': 'http',
            'url': 'https://example.invalid/nodes',
            'path': '/A/nodes',
            'interval': 1200,
            'health-check': {'enable': true, 'interval': 300},
          }
        }
      };
      final p = ProviderRefreshPlan.fromConfig(
          profileId: 'A',
          userAgent: 'test',
          config: config,
          password: 'private-fixture');
      unawaited(h.service.handleAction(json.encode({
        'id': 'setup',
        'method': 'setupConfig',
        'data': json.encode({
          'config': config,
          'selected-map': {},
          'test-url': '',
          providerRefreshMetadataKey: p.toJson(),
        })
      })));
      clock.flushMicrotasks();
      final forwarded = h.actions.single;
      expect(json.encode(forwarded), isNot(contains('private-fixture')));
      expect(
          json.encode(forwarded), isNot(contains(providerRefreshMetadataKey)));
      final applied = json.decode(forwarded['data'] as String) as Map;
      expect(applied['config']['proxy-providers']['nodes']['interval'], 0);
      expect(
          applied['config']['proxy-providers']['nodes']['health-check']
              ['interval'],
          300);
      expect((config['proxy-providers'] as Map)['nodes']['interval'], 1200);
      clock.elapse(const Duration(minutes: 20));
      expect(h.persisted, ['/A/nodes']);
      h.service.dispose();
    });
  });

  test('failed setup and disposed services never arm background timers', () {
    fakeAsync((clock) {
      final h = Harness(clock);
      unawaited(h.service.configure<String>(plan(), () async => 'bad config',
          succeeded: (result) => result.isEmpty));
      clock.flushMicrotasks();
      clock.elapse(const Duration(hours: 1));
      expect(h.downloads, isEmpty);
      h.service.dispose();
      h.configure(plan());
      clock.elapse(const Duration(hours: 1));
      expect(h.downloads, isEmpty);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('manual IPC uses the service decrypting path and preserves reply id',
      () {
    fakeAsync((clock) {
      final h = Harness(clock);
      h.configure(plan(both: false));
      Map? reply;
      unawaited(h.service
          .handleAction(json.encode({
        'id': 'manual',
        'method': 'updateExternalProvider',
        'data': 'shared'
      }))
          .then((value) {
        reply = json.decode(value) as Map;
      }));
      clock.flushMicrotasks();
      expect(reply?['id'], 'manual');
      expect(reply?['data'], '');
      expect(h.persisted, ['/A/proxies']);
      expect(
          h.actions
              .any((action) => action['method'] == 'updateExternalProvider'),
          isFalse);
      h.service.dispose();
    });
  });
}
