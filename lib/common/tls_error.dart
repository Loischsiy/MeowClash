import 'dart:io';

import 'package:dio/dio.dart';
import 'package:meowclash/common/print.dart';
import 'package:meowclash/l10n/l10n.dart';

/// Why a TLS handshake was rejected.
///
/// Dart's TLS stack (BoringSSL) never downloads a missing issuer over AIA the
/// way browsers do - on any platform, Windows included. A chain the server
/// sent incompletely and a root that is missing from the local store both end
/// up as `CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate`,
/// so both are reported as [TlsFailureKind.untrustedChain]. The log written by
/// [TlsFailure] is what makes the two distinguishable after the fact.
enum TlsFailureKind {
  /// The presented chain could not be linked to a trusted root.
  untrustedChain,

  /// The certificate is expired or not valid yet (often a wrong device clock).
  expired,

  /// The certificate was issued for another domain.
  hostMismatch,

  /// The peer presented a self-signed certificate, i.e. interception.
  selfSigned,

  /// A TLS error that could not be attributed to any case above.
  unknown,
}

/// A TLS handshake failure, described well enough to be shown to a user and
/// diagnosed from a log afterwards.
class TlsFailure implements Exception {
  const TlsFailure({
    required this.kind,
    required this.host,
    required this.port,
    required this.details,
  });

  final TlsFailureKind kind;
  final String host;
  final int port;

  /// Verbatim exception text, including the BoringSSL / OS error string.
  final String details;

  String get _hint => switch (kind) {
        TlsFailureKind.untrustedChain =>
          AppLocalizations.current.tlsUntrustedChainHint,
        TlsFailureKind.expired =>
          AppLocalizations.current.tlsCertificateExpiredHint,
        TlsFailureKind.hostMismatch =>
          AppLocalizations.current.tlsHostMismatchHint,
        TlsFailureKind.selfSigned => AppLocalizations.current.tlsSelfSignedHint,
        TlsFailureKind.unknown => AppLocalizations.current.tlsGenericHint,
      };

  /// Shown in place of the generic "could not update" text.
  String get message {
    final localizations = AppLocalizations.current;
    final target = host.isEmpty ? "" : "\n$host";
    return "${localizations.tlsHandshakeFailed}$target\n\n$_hint"
        "\n\n${localizations.tlsErrorDetails}: $details";
  }

  @override
  String toString() => message;

  /// Builds a [TlsFailure] out of [error] when - and only when - it was caused
  /// by TLS, logging everything needed to tell the possible causes apart.
  /// Returns null for any other error so callers can rethrow it untouched.
  static Future<TlsFailure?> fromError(
    Object error, {
    required String url,
    required String action,
  }) async {
    final exception = _findTlsException(error);
    if (exception == null) {
      return null;
    }
    final uri = _resolveUri(error, url);
    final failure = TlsFailure(
      kind: _classify(exception.toString()),
      host: uri?.host ?? "",
      port: uri == null || uri.port == 0 ? 443 : uri.port,
      details: exception.toString(),
    );
    await failure._log(action);
    return failure;
  }

  /// The URL itself is deliberately never logged: subscription links carry
  /// tokens. Host, port, platform and the OS error string are enough to act on.
  Future<void> _log(String action) async {
    commonPrint.log(
      "[TLS] $action failed | host=$host:$port | kind=${kind.name}"
      " | platform=${Platform.operatingSystem}"
      " ${Platform.operatingSystemVersion} | error=$details",
    );
    final certificate = await _probePeerCertificate(host, port);
    if (certificate == null) {
      return;
    }
    commonPrint.log(
      "[TLS] $host:$port presented subject=${_oneLine(certificate.subject)}"
      " issuer=${_oneLine(certificate.issuer)}"
      " valid=${certificate.startValidity.toIso8601String()}"
      "..${certificate.endValidity.toIso8601String()}",
    );
  }
}

/// Runs [send] and replaces a TLS handshake failure with a [TlsFailure] whose
/// `toString()` explains the problem, so every existing call site that renders
/// `"$error"` shows the reason instead of a generic failure. Any other error
/// keeps its original type and stack trace.
Future<T> guardTlsErrors<T>(
  String url,
  Future<T> Function() send, {
  required String action,
}) async {
  try {
    return await send();
  } catch (error, stackTrace) {
    final failure = await TlsFailure.fromError(error, url: url, action: action);
    if (failure == null) {
      rethrow;
    }
    Error.throwWithStackTrace(failure, stackTrace);
  }
}

/// Unwraps the [TlsException] dio hides inside [DioException.error].
TlsException? _findTlsException(Object error) {
  var current = error;
  for (var depth = 0; depth < 4; depth++) {
    if (current is TlsException) {
      return current;
    }
    if (current is! DioException) {
      return null;
    }
    final inner = current.error;
    if (inner == null) {
      return null;
    }
    current = inner;
  }
  return null;
}

/// Prefers the URI dio actually requested, so a failure after a redirect is
/// attributed to the host that really failed.
Uri? _resolveUri(Object error, String fallbackUrl) {
  if (error is DioException) {
    try {
      return error.requestOptions.uri;
    } catch (_) {
      // Malformed options: fall back to the URL the caller passed in.
    }
  }
  return Uri.tryParse(fallbackUrl);
}

TlsFailureKind _classify(String raw) {
  final text = raw.toLowerCase();
  if (text.contains("certificate has expired") ||
      text.contains("certificate_expired") ||
      text.contains("certificate is not yet valid")) {
    return TlsFailureKind.expired;
  }
  if (text.contains("hostname mismatch") ||
      text.contains("host name mismatch") ||
      text.contains("common name invalid")) {
    return TlsFailureKind.hostMismatch;
  }
  if (text.contains("self signed") || text.contains("self-signed")) {
    return TlsFailureKind.selfSigned;
  }
  if (text.contains("unable to get local issuer certificate") ||
      text.contains("unable to get issuer certificate") ||
      text.contains("unable to verify the first certificate") ||
      text.contains("certificate_verify_failed")) {
    return TlsFailureKind.untrustedChain;
  }
  return TlsFailureKind.unknown;
}

/// Hosts already probed in this run: a failing auto-update repeats every
/// 20 minutes, while the certificate only needs to be recorded once.
final Set<String> _probedHosts = <String>{};

/// Reconnects once, directly, only to record which certificate the server
/// actually sends - subject, issuer and validity are what a maintainer needs
/// in order to check whether the served chain is complete. The certificate is
/// always rejected (`onBadCertificate` returns false), so this never weakens
/// verification, and it runs only after a handshake already failed.
Future<X509Certificate?> _probePeerCertificate(String host, int port) async {
  if (host.isEmpty || !_probedHosts.add("$host:$port")) {
    return null;
  }
  X509Certificate? presented;
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
      onBadCertificate: (certificate) {
        presented = certificate;
        return false;
      },
    );
    presented ??= socket.peerCertificate;
    socket.destroy();
  } catch (error) {
    if (presented == null) {
      commonPrint.log("[TLS] certificate probe for $host:$port failed: $error");
    }
  }
  return presented;
}

String _oneLine(String value) =>
    value.replaceAll(RegExp(r"\s*\r?\n\s*"), "; ").trim();
