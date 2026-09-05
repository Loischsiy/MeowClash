import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meowclash/common/ip_country_names.dart';
import 'package:meowclash/l10n/l10n.dart';
import 'package:meowclash/models/common.dart';
import 'package:meowclash/models/ip_details.dart';
import 'package:meowclash/services/ip_details_service.dart';
import 'package:meowclash/views/dashboard/widgets/ip_details_dialog.dart';

const ip = IpInfo(ip: '8.8.8.8', countryCode: 'RU');

Future<IpDetails?> success(
        {required String ip,
        required String languageCode,
        CancelToken? cancelToken}) async =>
    IpDetails(
      ip: ip,
      countryCode: 'RU',
      region: 'Moscow',
      city: 'Moscow',
      domain: 'example.net',
      geographyLanguage: IpDetailsService.geographyLanguage(languageCode),
    );

Widget host({
  IpInfo? info = ip,
  Locale locale = const Locale('ru'),
  IpDetailsLoader loader = success,
  bool loading = false,
  double textScale = 1,
  VoidCallback? refresh,
  Future<bool> Function(Uri)? openLink,
}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
          body: Builder(
              builder: (context) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(textScale)),
                    child: IpDetailsDialog(
                        ipInfo: info,
                        loadDetails: loader,
                        onRefresh: refresh ?? () {},
                        isIpLoading: loading,
                        openLink: openLink),
                  ))),
    );

void main() {
  for (final locale in AppLocalizations.delegate.supportedLocales) {
    testWidgets('labels and countries follow app locale $locale',
        (tester) async {
      await tester.pumpWidget(host(locale: locale));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.current;
      expect(find.text(l10n.ipDetailsTitle), findsOneWidget);
      expect(find.text(l10n.ipDetailsCountry), findsOneWidget);
      expect(find.text(localizedIpCountryName('RU', locale.languageCode)!),
          findsOneWidget);
      expect(find.text('example.net'), findsOneWidget);
      expect(find.byType(SelectableText), findsNWidgets(4));
      if (locale.languageCode != 'zh') expect(find.text('俄罗斯'), findsNothing);
      final fallback = ['fi', 'uk'].contains(locale.languageCode);
      expect(find.text(l10n.ipDetailsEnglishFallback),
          fallback ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'shows IP/country immediately; loading, failure and retry stay usable',
      (tester) async {
    final pending = Completer<IpDetails?>();
    var calls = 0;
    Future<IpDetails?> load(
        {required String ip,
        required String languageCode,
        CancelToken? cancelToken}) {
      calls++;
      return calls == 1
          ? pending.future
          : success(ip: ip, languageCode: languageCode);
    }

    await tester.pumpWidget(host(loader: load));
    await tester.pump();
    expect(find.text(ip.ip), findsOneWidget);
    expect(find.text('Россия'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.current;
    expect(find.text(l10n.ipDetailsLoadFailed), findsOneWidget);
    expect(find.text(ip.ip), findsOneWidget);
    await tester.ensureVisible(find.text(l10n.ipDetailsRetry));
    await tester.tap(find.text(l10n.ipDetailsRetry));
    await tester.pumpAndSettle();
    expect(find.text('example.net'), findsOneWidget);
    expect(find.text(l10n.ipDetailsLoadFailed), findsNothing);
    expect(calls, 2);
  });

  testWidgets(
      'changing IP or locale cancels old requests and ignores late replies',
      (tester) async {
    final requests = <({
      String ip,
      String lang,
      CancelToken cancel,
      Completer<IpDetails?> result
    })>[];
    Future<IpDetails?> load(
        {required String ip,
        required String languageCode,
        CancelToken? cancelToken}) {
      final result = Completer<IpDetails?>();
      requests.add(
          (ip: ip, lang: languageCode, cancel: cancelToken!, result: result));
      return result.future;
    }

    await tester.pumpWidget(host(loader: load));
    await tester.pump();
    await tester.pumpWidget(host(
        loader: load, info: const IpInfo(ip: '1.1.1.1', countryCode: 'FI')));
    await tester.pump();
    expect(requests.first.cancel.isCancelled, isTrue);
    requests.first.result.complete(
        const IpDetails(ip: '8.8.8.8', countryCode: 'RU', domain: 'stale.net'));
    await tester.pump();
    expect(find.text('stale.net'), findsNothing);
    expect(find.text('1.1.1.1'), findsOneWidget);
    await tester.pumpWidget(host(
        loader: load,
        info: const IpInfo(ip: '1.1.1.1', countryCode: 'FI'),
        locale: const Locale('ja')));
    await tester.pump();
    expect(requests[1].cancel.isCancelled, isTrue);
    expect(requests.last.lang, 'ja');
    requests.last.result.complete(const IpDetails(
        ip: '1.1.1.1',
        countryCode: 'FI',
        domain: 'current.net',
        geographyLanguage: 'ja'));
    await tester.pumpAndSettle();
    expect(find.text('current.net'), findsOneWidget);
    expect(find.text('フィンランド'), findsOneWidget);
    requests[1].result.complete(const IpDetails(
        ip: '1.1.1.1', countryCode: 'FI', domain: 'wrong-language.net'));
    await tester.pump();
    expect(find.text('wrong-language.net'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal cancels work without setState after dispose',
      (tester) async {
    final pending = Completer<IpDetails?>();
    CancelToken? token;
    Future<IpDetails?> load(
        {required String ip,
        required String languageCode,
        CancelToken? cancelToken}) {
      token = cancelToken;
      return pending.future;
    }

    await tester.pumpWidget(host(loader: load));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(token!.isCancelled, isTrue);
    pending.complete(const IpDetails(ip: '8.8.8.8', countryCode: 'RU'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('no IP never starts a detail request; refresh is explicit',
      (tester) async {
    var calls = 0;
    var refreshes = 0;
    Future<IpDetails?> load(
        {required String ip,
        required String languageCode,
        CancelToken? cancelToken}) async {
      calls++;
      return null;
    }

    await tester
        .pumpWidget(host(info: null, loader: load, refresh: () => refreshes++));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    await tester.tap(find.text(AppLocalizations.current.ipDetailsRefresh));
    expect(refreshes, 1);
    await tester.pumpWidget(host(info: null, loader: load, loading: true));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('external link targets exactly the displayed IPv6 address',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(host(
        info: const IpInfo(ip: '2001:4860:4860::8888', countryCode: 'US'),
        openLink: (uri) async {
          opened = uri;
          return true;
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pumpAndSettle();
    expect(opened!.scheme, 'https');
    expect(opened!.host, 'ipinfo.io');
    expect(opened!.path, '/2001:4860:4860::8888');
  });

  testWidgets('small screen, long IPv6 and large fonts do not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(
      info: const IpInfo(
          ip: '2001:4860:4860:1234:5678:90ab:cdef:8888', countryCode: 'GB'),
      textScale: 2,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(AppLocalizations.current.confirm), findsOneWidget);
    await tester.ensureVisible(find.text('example.net'));
    expect(tester.takeException(), isNull);
  });
}
