import 'package:meowclash/enum/enum.dart';
import 'package:meowclash/models/models.dart';

/// Supplies the candidate DPI-bypass strategies the auto-selector explores.
///
/// The list is deliberately ordered from cheapest/most-common to more exotic so
/// that, absent any prior statistics, the UCB1 selector's first exploratory
/// picks are the ones most likely to work on typical Russian ISPs. Each
/// strategy's [Zapret2Strategy.args] are raw engine flags interpreted by the
/// platform [Zapret2Backend]; only strategies whose [Zapret2Strategy.platforms]
/// include the current platform are offered (empty = all platforms).
abstract class Zapret2StrategyProvider {
  const Zapret2StrategyProvider();

  List<Zapret2Strategy> all();

  /// Strategies applicable to [platform], in provider order.
  List<Zapret2Strategy> forPlatform(SupportPlatform platform) =>
      all().where((s) => s.supports(platform)).toList();
}

/// Default built-in strategy catalogue based on the common zapret2 desync
/// presets. These mirror the flag shapes documented by upstream (bol-van); the
/// per-platform backend translates them to winws/nfqws arguments.
class DefaultZapret2StrategyProvider extends Zapret2StrategyProvider {
  const DefaultZapret2StrategyProvider();

  @override
  List<Zapret2Strategy> all() => const [
        Zapret2Strategy(
          id: "lua_disorder_fake_http",
          label: "Lua disorder fake HTTP",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=disorder_fake_http",
          ],
        ),
        Zapret2Strategy(
          id: "lua_tlsrec",
          label: "Lua TLS record split",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=tlsrec",
          ],
        ),
        Zapret2Strategy(
          id: "lua_fake_tls",
          label: "Lua fake TLS",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=fake_tls",
          ],
        ),
        Zapret2Strategy(
          id: "lua_fake_unknown_udp",
          label: "Lua fake unknown UDP",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=fake_unknown_udp",
          ],
        ),
        Zapret2Strategy(
          id: "lua_syndata",
          label: "Lua syndata",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=syndata",
          ],
        ),
        Zapret2Strategy(
          id: "lua_multisplit",
          label: "Lua multisplit",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=multisplit",
          ],
        ),
        Zapret2Strategy(
          id: "lua_fakedsplit",
          label: "Lua fake split",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=fakedsplit",
          ],
        ),
        Zapret2Strategy(
          id: "lua_split2",
          label: "Lua split2",
          args: [
            "--lua-init=@zapret-lib.lua",
            "--lua-init=@zapret-antidpi.lua",
            "--lua-desync=split2",
          ],
        ),
        Zapret2Strategy(
          id: "fake_split2",
          label: "Fake + split2 (TLS)",
          args: [
            "--dpi-desync=fake,split2",
            "--dpi-desync-ttl=6",
          ],
        ),
        Zapret2Strategy(
          id: "fakeddisorder",
          label: "Fake + disorder2",
          args: [
            "--dpi-desync=fake,disorder2",
            "--dpi-desync-ttl=6",
          ],
        ),
        Zapret2Strategy(
          id: "multisplit_seqovl",
          label: "Multisplit + seqovl",
          args: [
            "--dpi-desync=multisplit",
            "--dpi-desync-split-pos=1,midsld",
            "--dpi-desync-split-seqovl=1",
          ],
        ),
        Zapret2Strategy(
          id: "fake_badseq",
          label: "Fake + badseq",
          args: [
            "--dpi-desync=fake",
            "--dpi-desync-fooling=badseq",
            "--dpi-desync-ttl=4",
          ],
        ),
        Zapret2Strategy(
          id: "fake_md5sig",
          label: "Fake + md5sig",
          args: [
            "--dpi-desync=fake",
            "--dpi-desync-fooling=md5sig",
          ],
        ),
        Zapret2Strategy(
          id: "syndata",
          label: "Syndata",
          args: [
            "--dpi-desync=syndata",
          ],
        ),
        Zapret2Strategy(
          id: "wssize",
          label: "Window-size clamp",
          args: [
            "--wssize=1:6",
          ],
        ),
        // QUIC/UDP path — most useful for YouTube (HTTP/3).
        Zapret2Strategy(
          id: "fake_quic",
          label: "Fake QUIC",
          args: [
            "--dpi-desync=fake",
            "--dpi-desync-repeats=6",
            "--filter-udp=443",
          ],
        ),
      ];
}
