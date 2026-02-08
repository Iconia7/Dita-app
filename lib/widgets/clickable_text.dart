import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/deep_link_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClickableText extends ConsumerWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  const ClickableText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Linkify(
      onOpen: (link) async {
        final uri = Uri.parse(link.url);
        
        // Handle custom ditaapp protocol
        if (uri.scheme == 'ditaapp') {
          DeepLinkService.handleLink(uri, ref);
          return;
        }
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not open link")),
          );
        }
      },
      text: text,
      style: style,
      linkStyle: linkStyle ?? const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      options: const LinkifyOptions(humanize: false),
    );
  }
}
