import 'dart:async';
import 'dart:math';

import 'package:meowclash/common/common.dart';
import 'package:meowclash/models/models.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/fade_box.dart';
import 'package:flutter/material.dart';

class MessageManager extends StatefulWidget {

  const MessageManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  State<MessageManager> createState() => MessageManagerState();
}

/// Optional trailing action of a message; glass toasts only.
class _MessageAction {
  const _MessageAction(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;
}

class MessageManagerState extends State<MessageManager> {
  final _messagesNotifier = ValueNotifier<List<CommonMessage>>([]);
  final List<CommonMessage> _bufferMessages = [];
  // Keyed by message id, so the freezed `CommonMessage` stays unchanged.
  final Map<String, _MessageAction> _actions = {};
  bool _pushing = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messagesNotifier.dispose();
    super.dispose();
  }

  /// Shows [text] as the app notifier.
  ///
  /// [actionLabel] with [onAction] adds a trailing action and [duration]
  /// replaces the default display time. The action is rendered by the
  /// Darwin glass toast only; the Material card shows the text alone, so
  /// Material callers keep their own affordance (e.g. a SnackBar).
  Future<void> message(
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) async {
    final id = utils.uuidV4;
    final commonMessage = duration == null
        ? CommonMessage(id: id, text: text)
        : CommonMessage(id: id, text: text, duration: duration);
    if (actionLabel != null && onAction != null) {
      _actions[id] = _MessageAction(actionLabel, onAction);
    }
    commonPrint.log(text);
    _bufferMessages.add(commonMessage);
    await _showMessage();
  }

  Future<void> _showMessage() async {
    if (_pushing == true) {
      return;
    }
    _pushing = true;
    while (_bufferMessages.isNotEmpty) {
      final commonMessage = _bufferMessages.removeAt(0);
      _messagesNotifier.value = List.from(_messagesNotifier.value)
        ..add(
          commonMessage,
        );
      await Future.delayed(const Duration(seconds: 1));
      Future.delayed(commonMessage.duration, () {
        _handleRemove(commonMessage);
      });
      if (_bufferMessages.isEmpty) {
        _pushing = false;
      }
    }
  }

  Future<void> _handleRemove(CommonMessage commonMessage) async {
    _actions.remove(commonMessage.id);
    if (!mounted) return;
    _messagesNotifier.value = List<CommonMessage>.from(_messagesNotifier.value)
      ..remove(commonMessage);
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePlatform.useGlass) return _buildGlass(context);
    return Stack(
      children: [
        widget.child,
        ValueListenableBuilder(
          valueListenable: _messagesNotifier,
          builder: (_, messages, __) => FadeThroughBox(
              margin: const EdgeInsets.only(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
              ),
              alignment: Alignment.topRight,
              child: messages.isEmpty
                  ? const SizedBox()
                  : LayoutBuilder(
                      key: Key(messages.last.id),
                      builder: (_, constraints) => Card(
                          shape: const RoundedSuperellipseBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12.0),
                            ),
                          ),
                          elevation: 10,
                          color: context.colorScheme.surfaceContainerHigh,
                          child: Container(
                            width: min(
                              constraints.maxWidth,
                              500,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            child: Text(
                              messages.last.text,
                            ),
                          ),
                        ),
                    ),
            ),
        ),
      ],
    );
  }

  /// Darwin: a glass toast banner. macOS puts it in the top trailing corner
  /// under the unified toolbar, iOS centers it under the status bar.
  Widget _buildGlass(BuildContext context) {
    final mac = AdaptivePlatform.isMacOSGlass;
    final padding = MediaQuery.paddingOf(context);
    final alignment = mac ? Alignment.topRight : Alignment.topCenter;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: (mac ? GlassTokens.toolbarHeightMac : padding.top) +
              GlassTokens.toastTopGap,
          left: padding.left + GlassTokens.toastMargin,
          right: padding.right + GlassTokens.toastMargin,
          child: Align(
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mac
                    ? GlassTokens.toastMaxWidthMac
                    : GlassTokens.toastMaxWidthIos,
              ),
              child: ValueListenableBuilder(
                valueListenable: _messagesNotifier,
                builder: (_, messages, __) => GlassToastSwitcher(
                  alignment: alignment,
                  child: messages.isEmpty
                      ? const SizedBox.shrink()
                      : _buildGlassToast(messages.last),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassToast(CommonMessage message) {
    final action = _actions[message.id];
    return GlassToast(
      key: ValueKey(message.id),
      text: message.text,
      actionLabel: action?.label,
      onAction: action == null
          ? null
          : () {
              // Tapping the action dismisses the toast right away.
              unawaited(_handleRemove(message));
              action.onPressed();
            },
    );
  }
}
