import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';

/// Visualizzatore per testo in formato Markdown leggero in stile Cyberpunk RED.
///
/// Risolve il problema del markdown grezzo (`###`, `**`, `-`) mostrato come testo piatto,
/// convertendolo in una gerarchia visiva accattivante con colori, icone e tipografia curate.
class CyberMarkdownView extends StatelessWidget {
  const CyberMarkdownView({
    super.key,
    required this.markdown,
    this.accent,
    this.selectable = true,
  });

  final String markdown;
  final Color? accent;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final Color effectiveAccent = accent ?? CprPalette.cyan;
    final List<String> lines = markdown.split('\n');
    final List<Widget> widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final String rawLine = lines[i];
      final String line = rawLine.trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Intestazioni: ###, ##, #
      if (line.startsWith('### ')) {
        final String title = line.substring(4).trim();
        widgets.add(_buildHeader(title, level: 3, accent: effectiveAccent));
      } else if (line.startsWith('## ')) {
        final String title = line.substring(3).trim();
        widgets.add(_buildHeader(title, level: 2, accent: effectiveAccent));
      } else if (line.startsWith('# ')) {
        final String title = line.substring(2).trim();
        widgets.add(_buildHeader(title, level: 1, accent: effectiveAccent));
      }
      // Elenco puntato: - o *
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        final String itemText = line.substring(2).trim();
        widgets.add(_buildBulletItem(itemText, accent: effectiveAccent));
      }
      // Linea con etichetta evidenziata: **Etichetta:** Valore
      else if (_isKeyValuePair(line)) {
        widgets.add(_buildKeyValuePair(line, accent: effectiveAccent));
      }
      // Testo normale con eventuale grassetto inline
      else {
        widgets.add(_buildParagraph(line));
      }
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  bool _isKeyValuePair(String line) {
    return line.startsWith('**') && line.contains(':**');
  }

  Widget _buildHeader(String title, {required int level, required Color accent}) {
    final double fontSize = level == 1 ? 17.0 : (level == 2 ? 15.0 : 13.5);
    final FontWeight weight = FontWeight.w700;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: level == 1 ? 4 : 3,
            height: fontSize + 2,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    title.toUpperCase(),
                    style: CprType.title.copyWith(
                      fontSize: fontSize,
                      fontWeight: weight,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  )
                : Text(
                    title.toUpperCase(),
                    style: CprType.title.copyWith(
                      fontSize: fontSize,
                      fontWeight: weight,
                      color: accent,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String itemText, {required Color accent}) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 6, right: 8),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Expanded(
            child: _buildRichText(itemText),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValuePair(String line, {required Color accent}) {
    final int splitIdx = line.indexOf(':**');
    final String key = line.substring(2, splitIdx).trim();
    final String val = line.substring(splitIdx + 3).trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$key: ',
            style: CprType.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          Expanded(
            child: _buildRichText(val),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(String line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _buildRichText(line),
    );
  }

  Widget _buildRichText(String text) {
    final List<InlineSpan> spans = _parseInlineSpans(text);
    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
        style: CprType.body.copyWith(height: 1.45, color: CprPalette.ink),
      );
    }
    return RichText(
      text: TextSpan(
        children: spans,
        style: CprType.body.copyWith(height: 1.45, color: CprPalette.ink),
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String text) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    for (final Match match in boldPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      final String boldContent = match.group(1) ?? '';
      spans.add(
        TextSpan(
          text: boldContent,
          style: TextStyle(fontWeight: FontWeight.bold, color: CprPalette.ink),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return spans;
  }
}
