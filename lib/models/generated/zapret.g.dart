// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../zapret.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$Zapret2StrategyImpl _$$Zapret2StrategyImplFromJson(
        Map<String, dynamic> json) =>
    _$Zapret2StrategyImpl(
      id: json['id'] as String,
      label: json['label'] as String,
      args:
          (json['args'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      platforms: (json['platforms'] as List<dynamic>?)
              ?.map((e) => $enumDecode(_$SupportPlatformEnumMap, e))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$Zapret2StrategyImplToJson(
        _$Zapret2StrategyImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'args': instance.args,
      'platforms':
          instance.platforms.map((e) => _$SupportPlatformEnumMap[e]!).toList(),
    };

const _$SupportPlatformEnumMap = {
  SupportPlatform.Windows: 'Windows',
  SupportPlatform.MacOS: 'MacOS',
  SupportPlatform.Linux: 'Linux',
  SupportPlatform.Android: 'Android',
};

_$Zapret2TargetImpl _$$Zapret2TargetImplFromJson(Map<String, dynamic> json) =>
    _$Zapret2TargetImpl(
      host: json['host'] as String,
      ip: json['ip'] as String?,
      port: (json['port'] as num?)?.toInt() ?? 443,
    );

Map<String, dynamic> _$$Zapret2TargetImplToJson(_$Zapret2TargetImpl instance) =>
    <String, dynamic>{
      'host': instance.host,
      'ip': instance.ip,
      'port': instance.port,
    };

_$Zapret2StatImpl _$$Zapret2StatImplFromJson(Map<String, dynamic> json) =>
    _$Zapret2StatImpl(
      strategyId: json['strategyId'] as String,
      trials: (json['trials'] as num?)?.toInt() ?? 0,
      rewardSum: (json['rewardSum'] as num?)?.toDouble() ?? 0,
      lastLatencyMs: (json['lastLatencyMs'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$Zapret2StatImplToJson(_$Zapret2StatImpl instance) =>
    <String, dynamic>{
      'strategyId': instance.strategyId,
      'trials': instance.trials,
      'rewardSum': instance.rewardSum,
      'lastLatencyMs': instance.lastLatencyMs,
    };

_$Zapret2ProbeResultImpl _$$Zapret2ProbeResultImplFromJson(
        Map<String, dynamic> json) =>
    _$Zapret2ProbeResultImpl(
      strategyId: json['strategyId'] as String,
      successRatio: (json['successRatio'] as num).toDouble(),
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$$Zapret2ProbeResultImplToJson(
        _$Zapret2ProbeResultImpl instance) =>
    <String, dynamic>{
      'strategyId': instance.strategyId,
      'successRatio': instance.successRatio,
      'latencyMs': instance.latencyMs,
      'error': instance.error,
    };

_$Zapret2CacheImpl _$$Zapret2CacheImplFromJson(Map<String, dynamic> json) =>
    _$Zapret2CacheImpl(
      engineVersion: json['engineVersion'] as String,
      platform: $enumDecode(_$SupportPlatformEnumMap, json['platform']),
      selectedStrategy: json['selectedStrategy'] == null
          ? null
          : Zapret2Strategy.fromJson(
              json['selectedStrategy'] as Map<String, dynamic>),
      targets: (json['targets'] as List<dynamic>?)
              ?.map((e) => Zapret2Target.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      testedAt: DateTime.parse(json['testedAt'] as String),
      stats: (json['stats'] as List<dynamic>?)
              ?.map((e) => Zapret2Stat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$Zapret2CacheImplToJson(_$Zapret2CacheImpl instance) =>
    <String, dynamic>{
      'engineVersion': instance.engineVersion,
      'platform': _$SupportPlatformEnumMap[instance.platform]!,
      'selectedStrategy': instance.selectedStrategy,
      'targets': instance.targets,
      'testedAt': instance.testedAt.toIso8601String(),
      'stats': instance.stats,
    };
