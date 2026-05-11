import 'package:flutter_test/flutter_test.dart';
import 'package:meow_clash/services/config_merge_service.dart';

void main() {
  group('ConfigMergeService', () {
    group('when externalPriority is false (default)', () {
      const service = ConfigMergeService(externalPriority: false);

      test('apply always overwrites existing value', () {
        final config = <String, dynamic>{'mode': 'Global'};
        service.apply(config, 'mode', 'Rule');
        expect(config['mode'], 'Rule');
      });

      test('apply sets value when key is absent', () {
        final config = <String, dynamic>{};
        service.apply(config, 'mode', 'Rule');
        expect(config['mode'], 'Rule');
      });

      test('applySection overwrites existing section', () {
        final config = <String, dynamic>{
          'dns': {'enable': true, 'nameserver': ['8.8.8.8']},
        };
        service.applySection(config, 'dns', {'enable': false});
        expect(config['dns'], {'enable': false});
      });

      test('shouldOverrideSection always returns true', () {
        final config = <String, dynamic>{
          'dns': {'enable': true},
        };
        expect(service.shouldOverrideSection(config, 'dns'), isTrue);
      });
    });

    group('when externalPriority is true', () {
      const service = ConfigMergeService(externalPriority: true);

      test('apply preserves existing value', () {
        final config = <String, dynamic>{'mode': 'Global'};
        service.apply(config, 'mode', 'Rule');
        expect(config['mode'], 'Global');
      });

      test('apply sets value when key is absent', () {
        final config = <String, dynamic>{};
        service.apply(config, 'mode', 'Rule');
        expect(config['mode'], 'Rule');
      });

      test('apply sets value when existing value is null', () {
        final config = <String, dynamic>{'mode': null};
        service.apply(config, 'mode', 'Rule');
        expect(config['mode'], 'Rule');
      });

      test('applySection preserves existing non-empty section', () {
        final config = <String, dynamic>{
          'dns': {'enable': true, 'nameserver': ['8.8.8.8']},
        };
        service.applySection(config, 'dns', {'enable': false});
        expect(config['dns'], {'enable': true, 'nameserver': ['8.8.8.8']});
      });

      test('applySection sets section when it is absent', () {
        final config = <String, dynamic>{};
        service.applySection(config, 'dns', {'enable': false});
        expect(config['dns'], {'enable': false});
      });

      test('applySection sets section when it is empty map', () {
        final config = <String, dynamic>{'dns': <String, dynamic>{}};
        service.applySection(config, 'dns', {'enable': false});
        expect(config['dns'], {'enable': false});
      });

      test('shouldOverrideSection returns false for existing non-empty section', () {
        final config = <String, dynamic>{
          'dns': {'enable': true},
        };
        expect(service.shouldOverrideSection(config, 'dns'), isFalse);
      });

      test('shouldOverrideSection returns true for absent section', () {
        final config = <String, dynamic>{};
        expect(service.shouldOverrideSection(config, 'dns'), isTrue);
      });

      test('shouldOverrideSection returns true for empty list section', () {
        final config = <String, dynamic>{'tunnels': <dynamic>[]}; 
        expect(service.shouldOverrideSection(config, 'tunnels'), isTrue);
      });
    });
  });
}
