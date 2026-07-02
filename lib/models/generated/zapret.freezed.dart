// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../zapret.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Zapret2Strategy _$Zapret2StrategyFromJson(Map<String, dynamic> json) {
  return _Zapret2Strategy.fromJson(json);
}

/// @nodoc
mixin _$Zapret2Strategy {
  /// Stable identifier used as the cache/statistics key. Must be unique
  /// within a [Zapret2StrategyProvider] list.
  String get id => throw _privateConstructorUsedError;

  /// Human-readable label shown in the progress UI.
  String get label => throw _privateConstructorUsedError;

  /// Engine arguments realizing this strategy (e.g. --dpi-desync=fake,split2).
  List<String> get args => throw _privateConstructorUsedError;

  /// Platforms this strategy is known to run on. Empty = all platforms.
  List<SupportPlatform> get platforms => throw _privateConstructorUsedError;

  /// Serializes this Zapret2Strategy to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Zapret2Strategy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Zapret2StrategyCopyWith<Zapret2Strategy> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Zapret2StrategyCopyWith<$Res> {
  factory $Zapret2StrategyCopyWith(
          Zapret2Strategy value, $Res Function(Zapret2Strategy) then) =
      _$Zapret2StrategyCopyWithImpl<$Res, Zapret2Strategy>;
  @useResult
  $Res call(
      {String id,
      String label,
      List<String> args,
      List<SupportPlatform> platforms});
}

/// @nodoc
class _$Zapret2StrategyCopyWithImpl<$Res, $Val extends Zapret2Strategy>
    implements $Zapret2StrategyCopyWith<$Res> {
  _$Zapret2StrategyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Zapret2Strategy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? args = null,
    Object? platforms = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      args: null == args
          ? _value.args
          : args // ignore: cast_nullable_to_non_nullable
              as List<String>,
      platforms: null == platforms
          ? _value.platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<SupportPlatform>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$Zapret2StrategyImplCopyWith<$Res>
    implements $Zapret2StrategyCopyWith<$Res> {
  factory _$$Zapret2StrategyImplCopyWith(_$Zapret2StrategyImpl value,
          $Res Function(_$Zapret2StrategyImpl) then) =
      __$$Zapret2StrategyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      List<String> args,
      List<SupportPlatform> platforms});
}

/// @nodoc
class __$$Zapret2StrategyImplCopyWithImpl<$Res>
    extends _$Zapret2StrategyCopyWithImpl<$Res, _$Zapret2StrategyImpl>
    implements _$$Zapret2StrategyImplCopyWith<$Res> {
  __$$Zapret2StrategyImplCopyWithImpl(
      _$Zapret2StrategyImpl _value, $Res Function(_$Zapret2StrategyImpl) _then)
      : super(_value, _then);

  /// Create a copy of Zapret2Strategy
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? args = null,
    Object? platforms = null,
  }) {
    return _then(_$Zapret2StrategyImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      args: null == args
          ? _value._args
          : args // ignore: cast_nullable_to_non_nullable
              as List<String>,
      platforms: null == platforms
          ? _value._platforms
          : platforms // ignore: cast_nullable_to_non_nullable
              as List<SupportPlatform>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Zapret2StrategyImpl implements _Zapret2Strategy {
  const _$Zapret2StrategyImpl(
      {required this.id,
      required this.label,
      final List<String> args = const [],
      final List<SupportPlatform> platforms = const []})
      : _args = args,
        _platforms = platforms;

  factory _$Zapret2StrategyImpl.fromJson(Map<String, dynamic> json) =>
      _$$Zapret2StrategyImplFromJson(json);

  /// Stable identifier used as the cache/statistics key. Must be unique
  /// within a [Zapret2StrategyProvider] list.
  @override
  final String id;

  /// Human-readable label shown in the progress UI.
  @override
  final String label;

  /// Engine arguments realizing this strategy (e.g. --dpi-desync=fake,split2).
  final List<String> _args;

  /// Engine arguments realizing this strategy (e.g. --dpi-desync=fake,split2).
  @override
  @JsonKey()
  List<String> get args {
    if (_args is EqualUnmodifiableListView) return _args;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_args);
  }

  /// Platforms this strategy is known to run on. Empty = all platforms.
  final List<SupportPlatform> _platforms;

  /// Platforms this strategy is known to run on. Empty = all platforms.
  @override
  @JsonKey()
  List<SupportPlatform> get platforms {
    if (_platforms is EqualUnmodifiableListView) return _platforms;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_platforms);
  }

  @override
  String toString() {
    return 'Zapret2Strategy(id: $id, label: $label, args: $args, platforms: $platforms)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Zapret2StrategyImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            const DeepCollectionEquality().equals(other._args, _args) &&
            const DeepCollectionEquality()
                .equals(other._platforms, _platforms));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      label,
      const DeepCollectionEquality().hash(_args),
      const DeepCollectionEquality().hash(_platforms));

  /// Create a copy of Zapret2Strategy
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Zapret2StrategyImplCopyWith<_$Zapret2StrategyImpl> get copyWith =>
      __$$Zapret2StrategyImplCopyWithImpl<_$Zapret2StrategyImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Zapret2StrategyImplToJson(
      this,
    );
  }
}

abstract class _Zapret2Strategy implements Zapret2Strategy {
  const factory _Zapret2Strategy(
      {required final String id,
      required final String label,
      final List<String> args,
      final List<SupportPlatform> platforms}) = _$Zapret2StrategyImpl;

  factory _Zapret2Strategy.fromJson(Map<String, dynamic> json) =
      _$Zapret2StrategyImpl.fromJson;

  /// Stable identifier used as the cache/statistics key. Must be unique
  /// within a [Zapret2StrategyProvider] list.
  @override
  String get id;

  /// Human-readable label shown in the progress UI.
  @override
  String get label;

  /// Engine arguments realizing this strategy (e.g. --dpi-desync=fake,split2).
  @override
  List<String> get args;

  /// Platforms this strategy is known to run on. Empty = all platforms.
  @override
  List<SupportPlatform> get platforms;

  /// Create a copy of Zapret2Strategy
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Zapret2StrategyImplCopyWith<_$Zapret2StrategyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Zapret2Target _$Zapret2TargetFromJson(Map<String, dynamic> json) {
  return _Zapret2Target.fromJson(json);
}

/// @nodoc
mixin _$Zapret2Target {
  String get host => throw _privateConstructorUsedError;
  String? get ip => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;

  /// Serializes this Zapret2Target to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Zapret2Target
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Zapret2TargetCopyWith<Zapret2Target> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Zapret2TargetCopyWith<$Res> {
  factory $Zapret2TargetCopyWith(
          Zapret2Target value, $Res Function(Zapret2Target) then) =
      _$Zapret2TargetCopyWithImpl<$Res, Zapret2Target>;
  @useResult
  $Res call({String host, String? ip, int port});
}

/// @nodoc
class _$Zapret2TargetCopyWithImpl<$Res, $Val extends Zapret2Target>
    implements $Zapret2TargetCopyWith<$Res> {
  _$Zapret2TargetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Zapret2Target
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? ip = freezed,
    Object? port = null,
  }) {
    return _then(_value.copyWith(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      ip: freezed == ip
          ? _value.ip
          : ip // ignore: cast_nullable_to_non_nullable
              as String?,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$Zapret2TargetImplCopyWith<$Res>
    implements $Zapret2TargetCopyWith<$Res> {
  factory _$$Zapret2TargetImplCopyWith(
          _$Zapret2TargetImpl value, $Res Function(_$Zapret2TargetImpl) then) =
      __$$Zapret2TargetImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String host, String? ip, int port});
}

/// @nodoc
class __$$Zapret2TargetImplCopyWithImpl<$Res>
    extends _$Zapret2TargetCopyWithImpl<$Res, _$Zapret2TargetImpl>
    implements _$$Zapret2TargetImplCopyWith<$Res> {
  __$$Zapret2TargetImplCopyWithImpl(
      _$Zapret2TargetImpl _value, $Res Function(_$Zapret2TargetImpl) _then)
      : super(_value, _then);

  /// Create a copy of Zapret2Target
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? ip = freezed,
    Object? port = null,
  }) {
    return _then(_$Zapret2TargetImpl(
      host: null == host
          ? _value.host
          : host // ignore: cast_nullable_to_non_nullable
              as String,
      ip: freezed == ip
          ? _value.ip
          : ip // ignore: cast_nullable_to_non_nullable
              as String?,
      port: null == port
          ? _value.port
          : port // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Zapret2TargetImpl implements _Zapret2Target {
  const _$Zapret2TargetImpl({required this.host, this.ip, this.port = 443});

  factory _$Zapret2TargetImpl.fromJson(Map<String, dynamic> json) =>
      _$$Zapret2TargetImplFromJson(json);

  @override
  final String host;
  @override
  final String? ip;
  @override
  @JsonKey()
  final int port;

  @override
  String toString() {
    return 'Zapret2Target(host: $host, ip: $ip, port: $port)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Zapret2TargetImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.ip, ip) || other.ip == ip) &&
            (identical(other.port, port) || other.port == port));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, host, ip, port);

  /// Create a copy of Zapret2Target
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Zapret2TargetImplCopyWith<_$Zapret2TargetImpl> get copyWith =>
      __$$Zapret2TargetImplCopyWithImpl<_$Zapret2TargetImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Zapret2TargetImplToJson(
      this,
    );
  }
}

abstract class _Zapret2Target implements Zapret2Target {
  const factory _Zapret2Target(
      {required final String host,
      final String? ip,
      final int port}) = _$Zapret2TargetImpl;

  factory _Zapret2Target.fromJson(Map<String, dynamic> json) =
      _$Zapret2TargetImpl.fromJson;

  @override
  String get host;
  @override
  String? get ip;
  @override
  int get port;

  /// Create a copy of Zapret2Target
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Zapret2TargetImplCopyWith<_$Zapret2TargetImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Zapret2Stat _$Zapret2StatFromJson(Map<String, dynamic> json) {
  return _Zapret2Stat.fromJson(json);
}

/// @nodoc
mixin _$Zapret2Stat {
  String get strategyId => throw _privateConstructorUsedError;

  /// Number of times this strategy has been probed.
  int get trials => throw _privateConstructorUsedError;

  /// Sum of per-probe reward in [0,1] (success ratio across targets). Mean
  /// reward is [rewardSum] / [trials].
  double get rewardSum => throw _privateConstructorUsedError;

  /// Average latency in ms of the last successful probe, for tie-breaking.
  int get lastLatencyMs => throw _privateConstructorUsedError;

  /// Serializes this Zapret2Stat to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Zapret2Stat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Zapret2StatCopyWith<Zapret2Stat> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Zapret2StatCopyWith<$Res> {
  factory $Zapret2StatCopyWith(
          Zapret2Stat value, $Res Function(Zapret2Stat) then) =
      _$Zapret2StatCopyWithImpl<$Res, Zapret2Stat>;
  @useResult
  $Res call(
      {String strategyId, int trials, double rewardSum, int lastLatencyMs});
}

/// @nodoc
class _$Zapret2StatCopyWithImpl<$Res, $Val extends Zapret2Stat>
    implements $Zapret2StatCopyWith<$Res> {
  _$Zapret2StatCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Zapret2Stat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? strategyId = null,
    Object? trials = null,
    Object? rewardSum = null,
    Object? lastLatencyMs = null,
  }) {
    return _then(_value.copyWith(
      strategyId: null == strategyId
          ? _value.strategyId
          : strategyId // ignore: cast_nullable_to_non_nullable
              as String,
      trials: null == trials
          ? _value.trials
          : trials // ignore: cast_nullable_to_non_nullable
              as int,
      rewardSum: null == rewardSum
          ? _value.rewardSum
          : rewardSum // ignore: cast_nullable_to_non_nullable
              as double,
      lastLatencyMs: null == lastLatencyMs
          ? _value.lastLatencyMs
          : lastLatencyMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$Zapret2StatImplCopyWith<$Res>
    implements $Zapret2StatCopyWith<$Res> {
  factory _$$Zapret2StatImplCopyWith(
          _$Zapret2StatImpl value, $Res Function(_$Zapret2StatImpl) then) =
      __$$Zapret2StatImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String strategyId, int trials, double rewardSum, int lastLatencyMs});
}

/// @nodoc
class __$$Zapret2StatImplCopyWithImpl<$Res>
    extends _$Zapret2StatCopyWithImpl<$Res, _$Zapret2StatImpl>
    implements _$$Zapret2StatImplCopyWith<$Res> {
  __$$Zapret2StatImplCopyWithImpl(
      _$Zapret2StatImpl _value, $Res Function(_$Zapret2StatImpl) _then)
      : super(_value, _then);

  /// Create a copy of Zapret2Stat
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? strategyId = null,
    Object? trials = null,
    Object? rewardSum = null,
    Object? lastLatencyMs = null,
  }) {
    return _then(_$Zapret2StatImpl(
      strategyId: null == strategyId
          ? _value.strategyId
          : strategyId // ignore: cast_nullable_to_non_nullable
              as String,
      trials: null == trials
          ? _value.trials
          : trials // ignore: cast_nullable_to_non_nullable
              as int,
      rewardSum: null == rewardSum
          ? _value.rewardSum
          : rewardSum // ignore: cast_nullable_to_non_nullable
              as double,
      lastLatencyMs: null == lastLatencyMs
          ? _value.lastLatencyMs
          : lastLatencyMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Zapret2StatImpl implements _Zapret2Stat {
  const _$Zapret2StatImpl(
      {required this.strategyId,
      this.trials = 0,
      this.rewardSum = 0,
      this.lastLatencyMs = 0});

  factory _$Zapret2StatImpl.fromJson(Map<String, dynamic> json) =>
      _$$Zapret2StatImplFromJson(json);

  @override
  final String strategyId;

  /// Number of times this strategy has been probed.
  @override
  @JsonKey()
  final int trials;

  /// Sum of per-probe reward in [0,1] (success ratio across targets). Mean
  /// reward is [rewardSum] / [trials].
  @override
  @JsonKey()
  final double rewardSum;

  /// Average latency in ms of the last successful probe, for tie-breaking.
  @override
  @JsonKey()
  final int lastLatencyMs;

  @override
  String toString() {
    return 'Zapret2Stat(strategyId: $strategyId, trials: $trials, rewardSum: $rewardSum, lastLatencyMs: $lastLatencyMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Zapret2StatImpl &&
            (identical(other.strategyId, strategyId) ||
                other.strategyId == strategyId) &&
            (identical(other.trials, trials) || other.trials == trials) &&
            (identical(other.rewardSum, rewardSum) ||
                other.rewardSum == rewardSum) &&
            (identical(other.lastLatencyMs, lastLatencyMs) ||
                other.lastLatencyMs == lastLatencyMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, strategyId, trials, rewardSum, lastLatencyMs);

  /// Create a copy of Zapret2Stat
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Zapret2StatImplCopyWith<_$Zapret2StatImpl> get copyWith =>
      __$$Zapret2StatImplCopyWithImpl<_$Zapret2StatImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Zapret2StatImplToJson(
      this,
    );
  }
}

abstract class _Zapret2Stat implements Zapret2Stat {
  const factory _Zapret2Stat(
      {required final String strategyId,
      final int trials,
      final double rewardSum,
      final int lastLatencyMs}) = _$Zapret2StatImpl;

  factory _Zapret2Stat.fromJson(Map<String, dynamic> json) =
      _$Zapret2StatImpl.fromJson;

  @override
  String get strategyId;

  /// Number of times this strategy has been probed.
  @override
  int get trials;

  /// Sum of per-probe reward in [0,1] (success ratio across targets). Mean
  /// reward is [rewardSum] / [trials].
  @override
  double get rewardSum;

  /// Average latency in ms of the last successful probe, for tie-breaking.
  @override
  int get lastLatencyMs;

  /// Create a copy of Zapret2Stat
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Zapret2StatImplCopyWith<_$Zapret2StatImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Zapret2ProbeResult _$Zapret2ProbeResultFromJson(Map<String, dynamic> json) {
  return _Zapret2ProbeResult.fromJson(json);
}

/// @nodoc
mixin _$Zapret2ProbeResult {
  String get strategyId => throw _privateConstructorUsedError;

  /// Fraction of targets that passed, in [0,1]. Used as the UCB1 reward.
  double get successRatio => throw _privateConstructorUsedError;

  /// Median latency in ms across the successful targets (0 if none).
  int get latencyMs => throw _privateConstructorUsedError;

  /// Non-fatal diagnostic (e.g. "engine failed to start"), for the log file.
  String? get error => throw _privateConstructorUsedError;

  /// Serializes this Zapret2ProbeResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Zapret2ProbeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Zapret2ProbeResultCopyWith<Zapret2ProbeResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Zapret2ProbeResultCopyWith<$Res> {
  factory $Zapret2ProbeResultCopyWith(
          Zapret2ProbeResult value, $Res Function(Zapret2ProbeResult) then) =
      _$Zapret2ProbeResultCopyWithImpl<$Res, Zapret2ProbeResult>;
  @useResult
  $Res call(
      {String strategyId, double successRatio, int latencyMs, String? error});
}

/// @nodoc
class _$Zapret2ProbeResultCopyWithImpl<$Res, $Val extends Zapret2ProbeResult>
    implements $Zapret2ProbeResultCopyWith<$Res> {
  _$Zapret2ProbeResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Zapret2ProbeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? strategyId = null,
    Object? successRatio = null,
    Object? latencyMs = null,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      strategyId: null == strategyId
          ? _value.strategyId
          : strategyId // ignore: cast_nullable_to_non_nullable
              as String,
      successRatio: null == successRatio
          ? _value.successRatio
          : successRatio // ignore: cast_nullable_to_non_nullable
              as double,
      latencyMs: null == latencyMs
          ? _value.latencyMs
          : latencyMs // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$Zapret2ProbeResultImplCopyWith<$Res>
    implements $Zapret2ProbeResultCopyWith<$Res> {
  factory _$$Zapret2ProbeResultImplCopyWith(_$Zapret2ProbeResultImpl value,
          $Res Function(_$Zapret2ProbeResultImpl) then) =
      __$$Zapret2ProbeResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String strategyId, double successRatio, int latencyMs, String? error});
}

/// @nodoc
class __$$Zapret2ProbeResultImplCopyWithImpl<$Res>
    extends _$Zapret2ProbeResultCopyWithImpl<$Res, _$Zapret2ProbeResultImpl>
    implements _$$Zapret2ProbeResultImplCopyWith<$Res> {
  __$$Zapret2ProbeResultImplCopyWithImpl(_$Zapret2ProbeResultImpl _value,
      $Res Function(_$Zapret2ProbeResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of Zapret2ProbeResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? strategyId = null,
    Object? successRatio = null,
    Object? latencyMs = null,
    Object? error = freezed,
  }) {
    return _then(_$Zapret2ProbeResultImpl(
      strategyId: null == strategyId
          ? _value.strategyId
          : strategyId // ignore: cast_nullable_to_non_nullable
              as String,
      successRatio: null == successRatio
          ? _value.successRatio
          : successRatio // ignore: cast_nullable_to_non_nullable
              as double,
      latencyMs: null == latencyMs
          ? _value.latencyMs
          : latencyMs // ignore: cast_nullable_to_non_nullable
              as int,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Zapret2ProbeResultImpl implements _Zapret2ProbeResult {
  const _$Zapret2ProbeResultImpl(
      {required this.strategyId,
      required this.successRatio,
      this.latencyMs = 0,
      this.error});

  factory _$Zapret2ProbeResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$Zapret2ProbeResultImplFromJson(json);

  @override
  final String strategyId;

  /// Fraction of targets that passed, in [0,1]. Used as the UCB1 reward.
  @override
  final double successRatio;

  /// Median latency in ms across the successful targets (0 if none).
  @override
  @JsonKey()
  final int latencyMs;

  /// Non-fatal diagnostic (e.g. "engine failed to start"), for the log file.
  @override
  final String? error;

  @override
  String toString() {
    return 'Zapret2ProbeResult(strategyId: $strategyId, successRatio: $successRatio, latencyMs: $latencyMs, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Zapret2ProbeResultImpl &&
            (identical(other.strategyId, strategyId) ||
                other.strategyId == strategyId) &&
            (identical(other.successRatio, successRatio) ||
                other.successRatio == successRatio) &&
            (identical(other.latencyMs, latencyMs) ||
                other.latencyMs == latencyMs) &&
            (identical(other.error, error) || other.error == error));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, strategyId, successRatio, latencyMs, error);

  /// Create a copy of Zapret2ProbeResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Zapret2ProbeResultImplCopyWith<_$Zapret2ProbeResultImpl> get copyWith =>
      __$$Zapret2ProbeResultImplCopyWithImpl<_$Zapret2ProbeResultImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Zapret2ProbeResultImplToJson(
      this,
    );
  }
}

abstract class _Zapret2ProbeResult implements Zapret2ProbeResult {
  const factory _Zapret2ProbeResult(
      {required final String strategyId,
      required final double successRatio,
      final int latencyMs,
      final String? error}) = _$Zapret2ProbeResultImpl;

  factory _Zapret2ProbeResult.fromJson(Map<String, dynamic> json) =
      _$Zapret2ProbeResultImpl.fromJson;

  @override
  String get strategyId;

  /// Fraction of targets that passed, in [0,1]. Used as the UCB1 reward.
  @override
  double get successRatio;

  /// Median latency in ms across the successful targets (0 if none).
  @override
  int get latencyMs;

  /// Non-fatal diagnostic (e.g. "engine failed to start"), for the log file.
  @override
  String? get error;

  /// Create a copy of Zapret2ProbeResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Zapret2ProbeResultImplCopyWith<_$Zapret2ProbeResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Zapret2Cache _$Zapret2CacheFromJson(Map<String, dynamic> json) {
  return _Zapret2Cache.fromJson(json);
}

/// @nodoc
mixin _$Zapret2Cache {
  /// zapret2 engine version this result was produced with (single source of
  /// truth: lib/zapret_version.dart -> zapret/version.go).
  String get engineVersion => throw _privateConstructorUsedError;

  /// Platform the selection was made on. A cache is not portable across
  /// platforms because backends and strategies differ.
  SupportPlatform get platform => throw _privateConstructorUsedError;

  /// The winning strategy, or null if selection has not succeeded yet.
  Zapret2Strategy? get selectedStrategy => throw _privateConstructorUsedError;

  /// Targets the selection was validated against.
  List<Zapret2Target> get targets => throw _privateConstructorUsedError;

  /// When the selection completed.
  DateTime get testedAt => throw _privateConstructorUsedError;

  /// Per-strategy UCB1 statistics accumulated so far.
  List<Zapret2Stat> get stats => throw _privateConstructorUsedError;

  /// Serializes this Zapret2Cache to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $Zapret2CacheCopyWith<Zapret2Cache> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $Zapret2CacheCopyWith<$Res> {
  factory $Zapret2CacheCopyWith(
          Zapret2Cache value, $Res Function(Zapret2Cache) then) =
      _$Zapret2CacheCopyWithImpl<$Res, Zapret2Cache>;
  @useResult
  $Res call(
      {String engineVersion,
      SupportPlatform platform,
      Zapret2Strategy? selectedStrategy,
      List<Zapret2Target> targets,
      DateTime testedAt,
      List<Zapret2Stat> stats});

  $Zapret2StrategyCopyWith<$Res>? get selectedStrategy;
}

/// @nodoc
class _$Zapret2CacheCopyWithImpl<$Res, $Val extends Zapret2Cache>
    implements $Zapret2CacheCopyWith<$Res> {
  _$Zapret2CacheCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? engineVersion = null,
    Object? platform = null,
    Object? selectedStrategy = freezed,
    Object? targets = null,
    Object? testedAt = null,
    Object? stats = null,
  }) {
    return _then(_value.copyWith(
      engineVersion: null == engineVersion
          ? _value.engineVersion
          : engineVersion // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as SupportPlatform,
      selectedStrategy: freezed == selectedStrategy
          ? _value.selectedStrategy
          : selectedStrategy // ignore: cast_nullable_to_non_nullable
              as Zapret2Strategy?,
      targets: null == targets
          ? _value.targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<Zapret2Target>,
      testedAt: null == testedAt
          ? _value.testedAt
          : testedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      stats: null == stats
          ? _value.stats
          : stats // ignore: cast_nullable_to_non_nullable
              as List<Zapret2Stat>,
    ) as $Val);
  }

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Zapret2StrategyCopyWith<$Res>? get selectedStrategy {
    if (_value.selectedStrategy == null) {
      return null;
    }

    return $Zapret2StrategyCopyWith<$Res>(_value.selectedStrategy!, (value) {
      return _then(_value.copyWith(selectedStrategy: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$Zapret2CacheImplCopyWith<$Res>
    implements $Zapret2CacheCopyWith<$Res> {
  factory _$$Zapret2CacheImplCopyWith(
          _$Zapret2CacheImpl value, $Res Function(_$Zapret2CacheImpl) then) =
      __$$Zapret2CacheImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String engineVersion,
      SupportPlatform platform,
      Zapret2Strategy? selectedStrategy,
      List<Zapret2Target> targets,
      DateTime testedAt,
      List<Zapret2Stat> stats});

  @override
  $Zapret2StrategyCopyWith<$Res>? get selectedStrategy;
}

/// @nodoc
class __$$Zapret2CacheImplCopyWithImpl<$Res>
    extends _$Zapret2CacheCopyWithImpl<$Res, _$Zapret2CacheImpl>
    implements _$$Zapret2CacheImplCopyWith<$Res> {
  __$$Zapret2CacheImplCopyWithImpl(
      _$Zapret2CacheImpl _value, $Res Function(_$Zapret2CacheImpl) _then)
      : super(_value, _then);

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? engineVersion = null,
    Object? platform = null,
    Object? selectedStrategy = freezed,
    Object? targets = null,
    Object? testedAt = null,
    Object? stats = null,
  }) {
    return _then(_$Zapret2CacheImpl(
      engineVersion: null == engineVersion
          ? _value.engineVersion
          : engineVersion // ignore: cast_nullable_to_non_nullable
              as String,
      platform: null == platform
          ? _value.platform
          : platform // ignore: cast_nullable_to_non_nullable
              as SupportPlatform,
      selectedStrategy: freezed == selectedStrategy
          ? _value.selectedStrategy
          : selectedStrategy // ignore: cast_nullable_to_non_nullable
              as Zapret2Strategy?,
      targets: null == targets
          ? _value._targets
          : targets // ignore: cast_nullable_to_non_nullable
              as List<Zapret2Target>,
      testedAt: null == testedAt
          ? _value.testedAt
          : testedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      stats: null == stats
          ? _value._stats
          : stats // ignore: cast_nullable_to_non_nullable
              as List<Zapret2Stat>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Zapret2CacheImpl implements _Zapret2Cache {
  const _$Zapret2CacheImpl(
      {required this.engineVersion,
      required this.platform,
      this.selectedStrategy,
      final List<Zapret2Target> targets = const [],
      required this.testedAt,
      final List<Zapret2Stat> stats = const []})
      : _targets = targets,
        _stats = stats;

  factory _$Zapret2CacheImpl.fromJson(Map<String, dynamic> json) =>
      _$$Zapret2CacheImplFromJson(json);

  /// zapret2 engine version this result was produced with (single source of
  /// truth: lib/zapret_version.dart -> zapret/version.go).
  @override
  final String engineVersion;

  /// Platform the selection was made on. A cache is not portable across
  /// platforms because backends and strategies differ.
  @override
  final SupportPlatform platform;

  /// The winning strategy, or null if selection has not succeeded yet.
  @override
  final Zapret2Strategy? selectedStrategy;

  /// Targets the selection was validated against.
  final List<Zapret2Target> _targets;

  /// Targets the selection was validated against.
  @override
  @JsonKey()
  List<Zapret2Target> get targets {
    if (_targets is EqualUnmodifiableListView) return _targets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targets);
  }

  /// When the selection completed.
  @override
  final DateTime testedAt;

  /// Per-strategy UCB1 statistics accumulated so far.
  final List<Zapret2Stat> _stats;

  /// Per-strategy UCB1 statistics accumulated so far.
  @override
  @JsonKey()
  List<Zapret2Stat> get stats {
    if (_stats is EqualUnmodifiableListView) return _stats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_stats);
  }

  @override
  String toString() {
    return 'Zapret2Cache(engineVersion: $engineVersion, platform: $platform, selectedStrategy: $selectedStrategy, targets: $targets, testedAt: $testedAt, stats: $stats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Zapret2CacheImpl &&
            (identical(other.engineVersion, engineVersion) ||
                other.engineVersion == engineVersion) &&
            (identical(other.platform, platform) ||
                other.platform == platform) &&
            (identical(other.selectedStrategy, selectedStrategy) ||
                other.selectedStrategy == selectedStrategy) &&
            const DeepCollectionEquality().equals(other._targets, _targets) &&
            (identical(other.testedAt, testedAt) ||
                other.testedAt == testedAt) &&
            const DeepCollectionEquality().equals(other._stats, _stats));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      engineVersion,
      platform,
      selectedStrategy,
      const DeepCollectionEquality().hash(_targets),
      testedAt,
      const DeepCollectionEquality().hash(_stats));

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$Zapret2CacheImplCopyWith<_$Zapret2CacheImpl> get copyWith =>
      __$$Zapret2CacheImplCopyWithImpl<_$Zapret2CacheImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$Zapret2CacheImplToJson(
      this,
    );
  }
}

abstract class _Zapret2Cache implements Zapret2Cache {
  const factory _Zapret2Cache(
      {required final String engineVersion,
      required final SupportPlatform platform,
      final Zapret2Strategy? selectedStrategy,
      final List<Zapret2Target> targets,
      required final DateTime testedAt,
      final List<Zapret2Stat> stats}) = _$Zapret2CacheImpl;

  factory _Zapret2Cache.fromJson(Map<String, dynamic> json) =
      _$Zapret2CacheImpl.fromJson;

  /// zapret2 engine version this result was produced with (single source of
  /// truth: lib/zapret_version.dart -> zapret/version.go).
  @override
  String get engineVersion;

  /// Platform the selection was made on. A cache is not portable across
  /// platforms because backends and strategies differ.
  @override
  SupportPlatform get platform;

  /// The winning strategy, or null if selection has not succeeded yet.
  @override
  Zapret2Strategy? get selectedStrategy;

  /// Targets the selection was validated against.
  @override
  List<Zapret2Target> get targets;

  /// When the selection completed.
  @override
  DateTime get testedAt;

  /// Per-strategy UCB1 statistics accumulated so far.
  @override
  List<Zapret2Stat> get stats;

  /// Create a copy of Zapret2Cache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$Zapret2CacheImplCopyWith<_$Zapret2CacheImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
