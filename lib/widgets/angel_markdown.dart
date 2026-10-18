import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

bool isSafeAngelLink(String? href) {
  final uri = Uri.tryParse(href ?? '');
  return uri != null &&
      ['https', 'http'].contains(uri.scheme) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

/// The stored response stays unchanged; only its display is interpreted.
class AngelMarkdown extends StatelessWidget {
  final String data;
  const AngelMarkdown({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: data,
          selectable: true,
          softLineBreak: true,
          // AI-provided image URLs must not fetch remote content automatically.
          imageBuilder: (uri, title, alt) => Text(alt ?? title ?? 'Image'),
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            h1: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            h2: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            h3: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            blockSpacing: 10,
            code: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            codeblockDecoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            codeblockPadding: EdgeInsets.all(12),
            tableColumnWidth: IntrinsicColumnWidth(),
            tableBorder: TableBorder(),
            tableCellsPadding: EdgeInsets.all(8),
          ),
          onTapLink: (_, href, _) async {
            if (!isSafeAngelLink(href)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('This link cannot be opened safely.')),
              );
              return;
            }
            try {
              if (!await launchUrl(
                    Uri.parse(href!),
                    mode: LaunchMode.externalApplication,
                  ) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('We could not open this link.')),
                );
              }
            } catch (_) {
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('We could not open this link.')),
                );
            }
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Copy response',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.copy_outlined, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted)
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Response copied.')));
            },
          ),
        ),
      ],
    );
  }
}
