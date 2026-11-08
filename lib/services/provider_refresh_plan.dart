import 'subscription_crypto.dart' show kDefaultPbkdf2Iterations;

/// Private service-isolate metadata, stripped before calling the Go core.
const providerRefreshMetadataKey = '_meowclashProviderRefresh';

/// Asks the core for a provider cache path (`proxies`/`rules`, url).
typedef ProviderCachePathResolver = Future<String> Function(
  String kind,
  String url,
);

const _planSections = {
  'proxy-providers': ('Proxy', 'proxies'),
  'rule-providers': ('Rule', 'rules'),
};

/// Key of [ProviderRefreshPlan.fromConfig]'s `cachePaths` map.
String providerCachePathKey(String kind, String url) => '$kind\u0000$url';

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
    Map<String, String> cachePaths = const {},
  }) =>
      ProviderRefreshPlan.fromConfig(
        profileId: profileId,
        userAgent: userAgent,
        config: config,
        cachePaths: cachePaths,
        password: credentials['meowclash-password'],
        iterations:
            int.tryParse(credentials['meowclash-password-iterations'] ?? '') ??
                kDefaultPbkdf2Iterations,
      );

  /// Every `http` provider with a url becomes a target. Its cache file is the
  /// explicit `path` when the config has one, otherwise the path the core
  /// reported for `(kind, url)` in [cachePaths] (see [resolveCachePaths]);
  /// providers whose path is unknown are skipped.
  factory ProviderRefreshPlan.fromConfig({
    required String profileId,
    required String userAgent,
    required Map<String, dynamic> config,
    String? password,
    int iterations = kDefaultPbkdf2Iterations,
    Map<String, String> cachePaths = const {},
  }) {
    final targets = <ProviderRefreshTarget>[];
    for (final section in _planSections.entries) {
      final providers = config[section.key];
      if (providers is! Map) continue;
      final (type, kind) = section.value;
      for (final entry in providers.entries) {
        final provider = entry.value;
        if (provider is! Map || provider['type'] != 'http') continue;
        final url = provider['url'];
        if (url is! String || url.isEmpty) continue;
        final explicit = provider['path'];
        final path = explicit is String && explicit.isNotEmpty
            ? explicit
            : cachePaths[providerCachePathKey(kind, url)];
        if (path == null || path.isEmpty) continue;
        targets.add(ProviderRefreshTarget(
          name: entry.key.toString(),
          type: type,
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

  /// The app owns every http provider download (the core only rereads cache
  /// files), so any profile with such a provider is managed. The password is
  /// optional: plaintext providers pass through, and the response headers may
  /// carry the credentials.
  bool get managed => targets.isNotEmpty;
  bool get hasAutomaticUpdates =>
      targets.any((target) => target.interval > Duration.zero);

  /// Asks the core (never computes in Dart) for the cache file of every http
  /// provider that has no explicit `path`.
  static Future<Map<String, String>> resolveCachePaths(
    Map<String, dynamic> config,
    ProviderCachePathResolver resolve,
  ) async {
    final paths = <String, String>{};
    for (final section in _planSections.entries) {
      final providers = config[section.key];
      if (providers is! Map) continue;
      final kind = section.value.$2;
      for (final provider in providers.values) {
        if (provider is! Map || provider['type'] != 'http') continue;
        final url = provider['url'];
        if (url is! String || url.isEmpty) continue;
        final explicit = provider['path'];
        if (explicit is String && explicit.isNotEmpty) continue;
        final key = providerCachePathKey(kind, url);
        if (paths.containsKey(key)) continue;
        try {
          final path = await resolve(kind, url);
          if (path.isNotEmpty) paths[key] = path;
        } catch (_) {
          // Unknown path: the provider is simply not refreshed in the background.
        }
      }
    }
    return paths;
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'userAgent': userAgent,
        'password': password,
        'iterations': iterations,
        'targets': targets.map((target) => target.toJson()).toList(),
      };
}
