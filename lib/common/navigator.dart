import 'package:meow_clash/enum/enum.dart';
import 'package:meow_clash/models/app.dart';
import 'package:meow_clash/state.dart';
import 'package:flutter/material.dart';

class BaseNavigator {
  static Future<T?> push<T>(BuildContext context, Widget child) async {
    if (globalState.appState.viewMode != ViewMode.mobile) {
      return await Navigator.of(
        context,
      ).push<T>(CommonDesktopRoute(builder: (context) => child));
    }
    return await Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (context) => child));
  }
}

class CommonDesktopRoute<T> extends PageRoute<T> {
  final Widget Function(BuildContext context) builder;

  CommonDesktopRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final Widget result = builder(context);
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: FadeTransition(opacity: animation, child: result),
    );
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => Duration(milliseconds: 200);
}
