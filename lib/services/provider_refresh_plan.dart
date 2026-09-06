import 'subscription_crypto.dart' show kDefaultPbkdf2Iterations;

/// Private service-isolate metadata, stripped before calling the Go core.
const providerRefreshMetadataKey = '_meowclashProviderRefresh';

class ProviderRefreshTarget {
  const ProviderRefreshTarget({
    required this.name,
    required this.type,
    required this.url,
    required this.path,
    required this.interval,
    this.headers = const {},
  });

  factory ProviderRefreshTarget.fromJson(Map<String, dynamic> json) =>
      ProviderRefreshTarget(
        name: json['name'] as String,
        type: json['type'] as String,
        url: json['url'] as String,
        path: json['path'] as String,
        interval: Duration(seconds: json['interval'] as int),
        headers: Map<String, dynamic>.unmodifiable(json['headers'] as Map),
      );

  final String name;
  final String type;
  final String url;
  final String path;
  final Duration interval;
  final Map<String, dynamic> headers;
  String get key => '$type\u0000$name';

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'url': url,
        'path': path,
        'interval': interval.inSeconds,
        'headers': headers,
      };
}

/// An immutable snapshot of the *applied* profile, including JS overrides.
/// Credentials never enter mihomo's config or its external-controller API.
class ProviderRefreshPlan {
  ProviderRefreshPlan({
    required this.profileId,
    required this.userAgent,
    required Iterable<ProviderRefreshTarget> targets,
    this.password,
    this.iterations = kDefaultPbkdf2Iterations,
  }) : targets = List.unmodifiable(targets);

  factory ProviderRefreshPlan.forProfile({
    required String profileId,
    required String userAgent,
    required Map<String, dynamic> config,
    required Map<String, String> credentials,
  }) =>
      ProviderRefreshPlan.fromConfig(
        profileId: profileId,
        userAgent: userAgent,
        config: config,
        password: credentials['meowclash-password'],
        iterations:
            int.tryParse(credentials['meowclash-password-iterations'] ?? '') ??
                kDefaultPbkdf2Iterations,
      );

  factory ProviderRefreshPlan.fromConfig({
    required String profileId,
    required String userAgent,
    required Map<String, dynamic> config,
    String? password,
    int iterations = kDefaultPbkdf2Iterations,
  }) {
    final targets = <ProviderRefreshTarget>[];
    for (final section
        in {'proxy-providers': 'Proxy', 'rule-providers': 'Rule'}.entries) {
      final providers = config[section.key];
      if (providers is! Map) continue;
      for (final entry in providers.entries) {
        final provider = entry.value;
        if (provider is! Map || provider['type'] != 'http') continue;
        final url = provider['url'];
        final path = provider['path'];
        if (url is! String || url.isEmpty || path is! String || path.isEmpty) {
          continue;
        }
        targets.add(ProviderRefreshTarget(
          name: entry.key.toString(),
          type: section.value,
          url: url,
          path: path,
          interval:
              Duration(seconds: int.tryParse('${provider['interval']}') ?? 0),
          headers: Map<String, dynamic>.unmodifiable(
            provider['header'] is Map ? provider['header'] as Map : const {},
          ),
        ));
      }
    }
    return ProviderRefreshPlan(
      profileId: profileId,
      userAgent: userAgent,
      targets: targets,
      password: password,
      iterations: iterations,
    );
  }

  factory ProviderRefreshPlan.fromJson(Map<String, dynamic> json) =>
      ProviderRefreshPlan(
        profileId: json['profileId'] as String,
        userAgent: json['userAgent'] as String,
        password: json['password'] as String?,
        iterations: json['iterations'] as int,
        targets: (json['targets'] as List).map((target) =>
            ProviderRefreshTarget.fromJson(
                Map<String, dynamic>.from(target as Map))),
      );

  final String profileId;
  final String userAgent;
  final String? password;
  final int iterations;
  final List<ProviderRefreshTarget> targets;
  bool get managed => password?.isNotEmpty == true;
  bool get hasAutomaticUpdates =>
      managed && targets.any((target) => target.interval > Duration.zero);

  /// Only encrypted-profile HTTP downloads move to Dart. Ordinary HTTP,
  /// file/inline providers and health checks retain their native behavior.
  Map<String, dynamic> prepareCoreConfig(Map<String, dynamic> config) {
    if (!managed) return config;
    final result = Map<String, dynamic>.from(config);
    for (final section
        in {'proxy-providers': 'Proxy', 'rule-providers': 'Rule'}.entries) {
      final providers = config[section.key];
      if (providers is! Map) continue;
      final copy = Map<String, dynamic>.from(providers);
      for (final target
          in targets.where((target) => target.type == section.value)) {
        final provider = copy[target.name];
        if (provider is Map) {
          copy[target.name] = {...provider, 'interval': 0};
        }
      }
      result[section.key] = copy;
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'userAgent': userAgent,
        'password': password,
        'iterations': iterations,
        'targets': targets.map((target) => target.toJson()).toList(),
      };
}
