import 'dart:convert';
import 'package:meowclash/common/common.dart';
import 'package:meowclash/providers/providers.dart';
import 'package:meowclash/state.dart';
import 'package:meowclash/widgets/adaptive/adaptive.dart';
import 'package:meowclash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:emoji_regex/emoji_regex.dart';
import 'package:meowclash/enum/enum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnounceWidget extends ConsumerWidget {
  const AnnounceWidget({super.key});

  List<InlineSpan> _buildTextSpans(
    BuildContext context,
    String text, {
    TextStyle? style,
  }) {
    final textStyle = style ?? Theme.of(context).textTheme.bodyLarge;
    List<InlineSpan> parseEmojis(String plainText, TextStyle? baseStyle) {
      final spans = <InlineSpan>[];
      final matches = emojiRegex().allMatches(plainText);
      var lastMatchEnd = 0;
      for (final match in matches) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: plainText.substring(lastMatchEnd, match.start), style: baseStyle));
        }
        spans.add(TextSpan(text: match.group(0), style: baseStyle?.copyWith(fontFamily: FontFamily.twEmoji.value)));
        lastMatchEnd = match.end;
      }
      if (lastMatchEnd < plainText.length) {
        spans.add(TextSpan(text: plainText.substring(lastMatchEnd), style: baseStyle));
      }
      return spans;
    }
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );
    
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    
    for (final match in urlPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          children: parseEmojis(text.substring(lastIndex, match.start), textStyle),
        ));
      }
      
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: textStyle?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            globalState.openUrl(url);
          },
      ));
      
      lastIndex = match.end;
    }
    
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        children: parseEmojis(text.substring(lastIndex), textStyle),
      ));
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    if (profile == null) {
      return const SizedBox.shrink();
    }

    final encodedText = profile.providerHeaders['announce'];
    String? announceText;

    if (encodedText != null && encodedText.isNotEmpty) {
      var textToDecode = encodedText;
      if (encodedText.startsWith('base64:')) {
        textToDecode = encodedText.substring(7);
      }
      try {
        final normalized = base64.normalize(textToDecode);
        announceText = utf8.decode(base64.decode(normalized));
      } catch (e) {
        announceText = encodedText;
      }
    }

    if (announceText == null || announceText.isEmpty) {
      return const SizedBox.shrink();
    }

    if (AdaptivePlatform.useGlass) {
      final theme = Theme.of(context);
      return AdaptiveWidgetTile(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassWidgetTileHeader(
              info: Info(
                label: appLocalizations.announcement,
                iconData: Icons.campaign_outlined,
              ),
            ),
            GlassWidgetTileBody(
              alignment: AlignmentDirectional.topStart,
              child: RichText(
                text: TextSpan(
                  children: _buildTextSpans(
                    context,
                    announceText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return CommonCard(
      onPressed: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: RichText(
            text: TextSpan(
              children: _buildTextSpans(context, announceText),
            ),
          ),
        ),
      ),
    );
  }
}
