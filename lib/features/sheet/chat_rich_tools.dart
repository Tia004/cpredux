import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

/// Categorie di emoji tematiche per Cyberpunk RED.
final Map<String, List<String>> kCyberpunkEmojiCategories = <String, List<String>>{
  'Tavolo & Dadi': <String>[
    '🎲', '🎯', '⚔️', '🛡️', '🏹', '💣', '💥', '🚨', '🔥', '⚡', '🏆', '💀',
  ],
  'Cyber & Tech': <String>[
    '🦾', '🧠', '💾', '💻', '🔌', '🔋', '🤖', '🕹️', '📡', '👁️', '🕶️', '⚡',
  ],
  'Street & Vita': <String>[
    '💊', '💉', '🩸', '🍺', '🍸', '🚬', '💵', '💰', '🚗', '🏍️', '🏙️', '🌃',
  ],
  'Reazioni': <String>[
    '😎', '😈', '💀', '😱', '🤯', '👽', '👍', '👎', '❤️', '🔥', '👀', '👏',
  ],
};

/// Preset di GIF Cyberpunk / GDR animate pronte all'uso.
final List<({String title, String url, String category})> kCyberpunkGifs = <({String title, String url, String category})>[
  (
    title: 'Cyberpunk Neon',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExdWJ2eDFqZ21ndHRsOHZhcjN2N3V4aW1hYjRwcnUyaTR4Mmd3bGJ4ZSZlcD12MV9naWZzX3NlYXJjaCZjdD1n/fA7rLtaJ5HxJZa8ulz/giphy.gif',
    category: 'Night City',
  ),
  (
    title: 'Netrunner Hack',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExeGJ3cmh4aHFpczRjbmRydTFsNDZtcTFrcmd0aXFzMWYxNG43NjhzeSZlcD12MV9naWZzX3NlYXJjaCZjdD1n/3oKIPnAiaMCws8nOsE/giphy.gif',
    category: 'Hacking',
  ),
  (
    title: 'Critical Roll',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExcGZhcTllMnA5dzdhdmd3OXV5aGk0NnhzNmszOTRrbDVmaWg5aGNrcyZlcD12MV9naWZzX3NlYXJjaCZjdD1n/26ufdipQqU2lhNA4g/giphy.gif',
    category: 'Dadi',
  ),
  (
    title: 'Combat Ready',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExbXZpczhzc2d1bnh0OXV2NHA2anlsbm14dWFxN3N2anFkcnB4eHV4NyZlcD12MV9naWZzX3NlYXJjaCZjdD1n/9PPwYVFxX8L4Y/giphy.gif',
    category: 'Combattimento',
  ),
  (
    title: 'Glitch System',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExNHRhOHhkMnd3bTVpdDJuamJldHNxdHNndzhyNXV1YnlhZDRreDFoayZlcD12MV9naWZzX3NlYXJjaCZjdD1n/3o7TKSjRrfIPjeiVyM/giphy.gif',
    category: 'Hacking',
  ),
  (
    title: 'Cheers / Drink',
    url: 'https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExOGxjcDF3cm9vdTZudWVqcG9tcXQzN3pncWlzYmFsNXd2bTExdWF3aiZlcD12MV9naWZzX3NlYXJjaCZjdD1n/Zw3oBUuIg23EWxmvWK/giphy.gif',
    category: 'Night City',
  ),
];

/// Mostra il selettore di Emoji in stile Cyberpunk.
Future<String?> showCyberEmojiPicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => const _CyberEmojiDialog(),
  );
}

class _CyberEmojiDialog extends StatefulWidget {
  const _CyberEmojiDialog();

  @override
  State<_CyberEmojiDialog> createState() => _CyberEmojiDialogState();
}

class _CyberEmojiDialogState extends State<_CyberEmojiDialog> {
  String _selectedCategory = 'Tavolo & Dadi';

  @override
  Widget build(BuildContext context) {
    final List<String> emojis = kCyberpunkEmojiCategories[_selectedCategory] ?? <String>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 440),
        child: ChamferPanel(
          accent: CprPalette.yellow,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(width: 4, height: 18, color: CprPalette.yellow),
                    const SizedBox(width: 8),
                    Text(
                      'SELETTORE EMOJI',
                      style: CprType.caption.copyWith(
                        color: CprPalette.yellow,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: CprPalette.inkMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final String cat in kCyberpunkEmojiCategories.keys) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: CprType.caption.copyWith(
                                color: _selectedCategory == cat ? CprPalette.voidBlack : CprPalette.ink,
                                fontWeight: _selectedCategory == cat ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: _selectedCategory == cat,
                            selectedColor: CprPalette.yellow,
                            backgroundColor: CprPalette.surfaceRaised,
                            onSelected: (bool sel) {
                              if (sel) setState(() => _selectedCategory = cat);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (BuildContext context, int i) {
                      final String emoji = emojis[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(emoji),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: CprPalette.hairline),
                            color: CprPalette.surfaceSunken,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mostra il selettore di GIF animate (Tenor/Giphy).
Future<String?> showCyberGifPicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => const _CyberGifDialog(),
  );
}

class _CyberGifDialog extends StatefulWidget {
  const _CyberGifDialog();

  @override
  State<_CyberGifDialog> createState() => _CyberGifDialogState();
}

class _CyberGifDialogState extends State<_CyberGifDialog> {
  final TextEditingController _customUrlController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<({String title, String url, String category})> filtered = kCyberpunkGifs
        .where((g) => _filter.isEmpty || g.title.toLowerCase().contains(_filter.toLowerCase()) || g.category.toLowerCase().contains(_filter.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: ChamferPanel(
          accent: CprPalette.cyan,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(width: 4, height: 18, color: CprPalette.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'SELETTORE GIF ANIMATE (TENOR / GIPHY)',
                      style: CprType.caption.copyWith(
                        color: CprPalette.cyan,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: CprPalette.inkMuted),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceSunken,
                    border: Border.all(color: CprPalette.hairline),
                  ),
                  child: TextField(
                    style: CprType.body.copyWith(color: CprPalette.ink),
                    decoration: InputDecoration(
                      hintText: 'Cerca per titolo o categoria (o inserisci URL personalizzato)',
                      hintStyle: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      prefixIcon: Icon(Icons.search, size: 18, color: CprPalette.cyan),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    onChanged: (String v) => setState(() => _filter = v.trim()),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: CprPalette.surfaceSunken,
                          border: Border.all(color: CprPalette.hairline),
                        ),
                        child: TextField(
                          controller: _customUrlController,
                          style: CprType.body.copyWith(color: CprPalette.ink),
                          decoration: InputDecoration(
                            hintText: 'Incolla URL diretto GIF (Giphy / Tenor)',
                            hintStyle: CprType.caption.copyWith(color: CprPalette.inkFaint),
                            prefixIcon: Icon(Icons.link, size: 18, color: CprPalette.cyan),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TechButton(
                      label: 'Usa URL',
                      icon: Icons.send,
                      variant: TechButtonVariant.primary,
                      compact: true,
                      onPressed: () {
                        final String url = _customUrlController.text.trim();
                        if (url.isNotEmpty) Navigator.of(context).pop(url);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int i) {
                      final item = filtered[i];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(item.url),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CprPalette.surfaceRaised,
                            border: Border.all(color: CprPalette.hairline),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              Image.network(
                                item.url,
                                fit: BoxFit.cover,
                                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(Icons.broken_image_outlined, color: CprPalette.inkMuted),
                                      const SizedBox(height: 4),
                                      Text(item.title, style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
                                    ],
                                  ),
                                ),
                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                                  if (progress == null) return child;
                                  return Center(child: CircularProgressIndicator(strokeWidth: 2, color: CprPalette.cyan));
                                },
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: CprPalette.veil(CprPalette.voidBlack, 0.75),
                                  child: Text(
                                    item.title,
                                    style: CprType.caption.copyWith(
                                      color: CprPalette.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sceglie un file o un'immagine da inviare in peer-to-peer al tavolo.
Future<void> pickAndSendAttachment(
  BuildContext context, {
  required void Function({
    required String fileName,
    required int size,
    required String mimeType,
    required String base64Data,
    String? caption,
  }) onSend,
}) async {
  final String? path = await showFileBrowser(
    context,
    mode: FileBrowserMode.open,
    title: 'Seleziona file o immagine da inviare al tavolo',
    showAllFilesToggle: true,
  );
  if (path == null) return;

  final File file = File(path);
  if (!file.existsSync()) return;

  final int size = file.lengthSync();
  // Limite precauzionale per trasmissione TCP in-memory (15 MB)
  if (size > 15 * 1024 * 1024) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Il file supera il limite massimo di 15 MB per la condivisione diretta.'),
          backgroundColor: CprPalette.danger,
        ),
      );
    }
    return;
  }

  final List<int> bytes = file.readAsBytesSync();
  final String base64Data = base64Encode(bytes);
  final String fileName = p.basename(path);
  final String ext = p.extension(path).toLowerCase();
  String mimeType = 'application/octet-stream';
  if (ext == '.png') {
    mimeType = 'image/png';
  } else if (ext == '.jpg' || ext == '.jpeg') {
    mimeType = 'image/jpeg';
  } else if (ext == '.gif') {
    mimeType = 'image/gif';
  } else if (ext == '.webp') {
    mimeType = 'image/webp';
  } else if (ext == '.txt') {
    mimeType = 'text/plain';
  } else if (ext == '.json') {
    mimeType = 'application/json';
  } else if (ext == '.pdf') {
    mimeType = 'application/pdf';
  }

  onSend(
    fileName: fileName,
    size: size,
    mimeType: mimeType,
    base64Data: base64Data,
    caption: 'Allegato condiviso: $fileName',
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Allegato "$fileName" (${(size / 1024).toStringAsFixed(1)} KB) inviato al tavolo.'),
        backgroundColor: CprPalette.success,
      ),
    );
  }
}

/// Salva su disco un allegato ricevuto in peer-to-peer.
Future<void> saveAttachmentToDisk(
  BuildContext context, {
  required String fileName,
  required String base64Data,
}) async {
  final String? targetPath = await showFileBrowser(
    context,
    mode: FileBrowserMode.save,
    title: 'Salva allegato su disco',
    suggestedName: fileName,
    showAllFilesToggle: true,
  );
  if (targetPath == null) return;

  try {
    final List<int> bytes = base64Decode(base64Data);
    final File f = File(targetPath);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File salvato con successo: ${p.basename(targetPath)}'),
          backgroundColor: CprPalette.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel salvataggio del file: $e'),
          backgroundColor: CprPalette.danger,
        ),
      );
    }
  }
}
