import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import 'gm_screen.dart';

/// La console del Master come pannello laterale, aperto **mentre si gioca**.
///
/// La differenza rispetto alla schermata non e' estetica. Una schermata a se'
/// stante si apre, si usa e si chiude: quando il Master genera un agguato deve
/// guardare la mappa per decidere dove metterlo, e passare da una schermata
/// all'altra per farlo significa perdere il filo di quello che stava dicendo.
/// Qui la console sta accanto al tavolo, e quello che produce ci finisce
/// direttamente: i PNG diventano token, il bottino entra in inventario, i tiri
/// finiscono nel registro senza cambiare pagina.
///
/// E' larga 420 pixel perche' e' la larghezza a cui le schede degli strumenti
/// stanno in una colonna sola leggibile: piu' stretta, i moduli a tre campi si
/// spezzano; piu' larga, il tavolo resta senza spazio.
class GmPanel extends StatelessWidget {
  const GmPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: CprPalette.surface,
        border: Border(left: BorderSide(color: CprPalette.violet, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
            decoration: const BoxDecoration(
              color: CprPalette.surfaceRaised,
              border: Border(bottom: BorderSide(color: CprPalette.hairline)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.dashboard_customize_outlined, size: 15, color: CprPalette.violet),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('STRUMENTI DEL MASTER', style: CprType.label.copyWith(color: CprPalette.violet)),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClose,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 15, color: CprPalette.inkMuted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: GmConsole(layout: GmConsoleLayout.panel),
            ),
          ),
        ],
      ),
    );
  }
}

/// La linguetta sul bordo destro che apre il pannello.
///
/// Esiste per la stessa ragione di quella dell'assistente: un pannello che si
/// apre solo da una voce di menu, mentre si gioca, e' un pannello che nessuno
/// apre. Sul bordo destro perche' e' il lato in cui le cose che *servono durante*
/// la partita stanno in questa applicazione.
class GmFloatingTab extends StatelessWidget {
  const GmFloatingTab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Strumenti del Master: incontri, bottino, DV, rete',
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
          decoration: BoxDecoration(
            color: CprPalette.surfaceRaised,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
            border: Border.all(color: CprPalette.violet.withValues(alpha: 0.5)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: CprPalette.violet.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(-2, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.casino_outlined, size: 14, color: CprPalette.violet),
              const SizedBox(height: 5),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'MASTER',
                  style: CprType.label.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: CprPalette.violet,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
