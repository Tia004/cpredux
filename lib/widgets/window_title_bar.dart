import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Barra del titolo personalizzata, integrata e immersa nell'interfaccia.
///
/// Su macOS la barra nativa e' resa trasparente con `.fullSizeContentView`:
/// i pulsanti di controllo (semaforo rosso/giallo/verde) fluttuano a sinistra
/// dentro questo spazio dedicato (78 px), mentre il titolo della finestra e'
/// esattamente centrato orizzontalmente come in VS Code / Antigravity IDE.
///
/// Su Windows e altre piattaforme, la barra si fonde senza stacchi con la
/// finestra (`DWMWA_USE_IMMERSIVE_DARK_MODE` e `DWMWA_CAPTION_COLOR`) e
/// mantiene il titolo centrato e lo stile Cyberpunk scuro.
class WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const WindowTitleBar({super.key});

  static const double height = 38.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  bool get _isMac {
    if (kIsWeb) return false;
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  String _screenTitle(AppState state) {
    switch (state.screen) {
      case AppScreen.home:
        return 'Cyberpunk RED Visualizer';
      case AppScreen.sheet:
        final sheet = state.sheet;
        if (sheet == null) return 'Scheda Personaggio';
        final String name = sheet.meta.name.trim();
        final String role = sheet.identity.role.trim();
        if (name.isNotEmpty && role.isNotEmpty) {
          return '$name · $role';
        } else if (name.isNotEmpty) {
          return name;
        } else {
          return 'Nuova Scheda';
        }
      case AppScreen.campaign:
        return 'Tavolo Campagna (Game Master)';
      case AppScreen.compare:
        return 'Confronto Schede';
      case AppScreen.settings:
        return 'Impostazioni';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String activeTitle = _screenTitle(state);
    final bool isMac = _isMac;

    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Stack(
        children: <Widget>[
          // Titolo perfettamente centrato nella finestra
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 90),
              child: RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: CprType.label.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                  children: <TextSpan>[
                    const TextSpan(
                      text: 'CPRedux Desktop',
                      style: TextStyle(
                        color: CprPalette.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(
                      text: ' — ',
                      style: TextStyle(
                        color: CprPalette.inkMuted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: activeTitle,
                      style: const TextStyle(
                        color: CprPalette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Elementi a sinistra
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: isMac
                // Su macOS riserviamo 78 px per i tasti del semaforo nativo
                ? const SizedBox(width: 78)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(width: 14),
                      Container(
                        width: 3,
                        height: 14,
                        color: CprPalette.yellow,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CPRED',
                        style: CprType.label.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: CprPalette.yellow,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
          ),

          // Elementi a destra (indicatore di stato discreto)
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildRightStatus(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightStatus(AppState state) {
    if (state.screen == AppScreen.sheet && state.sheet != null) {
      final bool saved = !state.isDirty;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: saved ? CprPalette.humanityIntact : CprPalette.yellow,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            saved ? 'SALVATO' : 'MODIFICATO',
            style: CprType.caption.copyWith(
              fontSize: 9,
              letterSpacing: 0.5,
              color: saved ? CprPalette.humanityIntact : CprPalette.yellow,
            ),
          ),
        ],
      );
    }

    return Text(
      'v0.2.0',
      style: CprType.caption.copyWith(
        fontSize: 9.5,
        color: CprPalette.veil(CprPalette.inkMuted, 0.6),
        letterSpacing: 0.5,
      ),
    );
  }
}
