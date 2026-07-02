// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../zapret.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$zapret2ServiceHash() => r'6bfca9704efe503021e47cbaa35e60a6b35abb62';

/// Owns the single [Zapret2Service] instance for the app. Kept alive (not
/// auto-disposed) because the engine session outlives any one widget subtree.
///
/// Copied from [zapret2Service].
@ProviderFor(zapret2Service)
final zapret2ServiceProvider = Provider<Zapret2Service>.internal(
  zapret2Service,
  name: r'zapret2ServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$zapret2ServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef Zapret2ServiceRef = ProviderRef<Zapret2Service>;
String _$zapret2RuntimeHash() => r'0d5a7f0e723389180ddef7f6efdc7101b10d99be';

/// Reactive mirror of the service's [Zapret2Status] for the UI. Seeds from the
/// current status and then follows the service's broadcast stream, so progress
/// during a (possibly long) auto-selection is shown live.
///
/// Copied from [Zapret2Runtime].
@ProviderFor(Zapret2Runtime)
final zapret2RuntimeProvider =
    AutoDisposeNotifierProvider<Zapret2Runtime, Zapret2Status>.internal(
  Zapret2Runtime.new,
  name: r'zapret2RuntimeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$zapret2RuntimeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Zapret2Runtime = AutoDisposeNotifier<Zapret2Status>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
