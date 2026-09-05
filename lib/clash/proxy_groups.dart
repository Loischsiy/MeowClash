import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/common.dart';

List<Group> parseProxyGroups(Map proxies) {
  if (proxies.isEmpty) return [];
  final types = GroupTypeExtension.valueList.toSet();
  final global = proxies[UsedProxy.GLOBAL.name];
  final visibleNames = <String>[
    if (global is Map) UsedProxy.GLOBAL.name,
    if (global is Map)
      for (final name in (global['all'] as List? ?? const []))
        if (name is String &&
            proxies[name] is Map &&
            proxies[name]['hidden'] != true &&
            types.contains(proxies[name]['type']))
          name,
  ];
  final visible = visibleNames.toSet();
  final names = <String>{
    ...visibleNames,
    for (final entry in proxies.entries)
      if (entry.key is String &&
          entry.value is Map &&
          types.contains(entry.value['type']))
        entry.key as String,
  };
  final parsed = <String, Proxy>{};
  return [
    for (final name in names)
      if (proxies[name] is Map)
        () {
          final raw = Map<String, dynamic>.from(proxies[name]);
          final members = <Proxy>[
            for (final child in (raw['all'] as List? ?? const []))
              if (child is String && proxies[child] is Map)
                parsed.putIfAbsent(
                    child,
                    () => Proxy.fromJson(
                        Map<String, dynamic>.from(proxies[child]))),
          ];
          // Group.fromJson only sees the header; shared members are attached
          // afterwards, avoiding repeated JSON/model conversion across groups.
          raw['all'] = <dynamic>[];
          raw['hidden'] = raw['hidden'] == true || !visible.contains(name);
          return Group.fromJson(raw).copyWith(all: members);
        }(),
  ];
}
