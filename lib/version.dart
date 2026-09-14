/// La versione di questa copia del programma.
///
/// Vive in un file suo, e non dentro `Updater`, perche' la usano cose che non
/// hanno niente a che vedere con gli aggiornamenti: il titolo della finestra, la
/// schermata delle impostazioni, la presenza Discord, il manifesto che genera la
/// CI. Averla in un posto solo significa che non puo' esistere una schermata che
/// dichiara una versione diversa dalle altre.
///
/// **Deve coincidere con `version:` in `pubspec.yaml`.** Un test lo verifica
/// leggendo il pubspec: una versione disallineata rende invisibile la funzione
/// di aggiornamento, perche' il programma crederebbe di essere piu' vecchio o
/// piu' nuovo di quello che e' e non riconoscerebbe mai la versione giusta.
const String appVersion = '0.2.4';

/// Il canale di rilascio, per distinguere un build stabile da uno di prova.
const String appChannel =
    String.fromEnvironment('CPREDUX_CHANNEL', defaultValue: 'stable');
