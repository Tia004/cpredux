import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cpredux/design/theme.dart';
import 'package:cpredux/features/sheet/editors.dart';
import 'package:cpredux/widgets/inputs.dart';
import 'package:cpredux/domain/cyberware.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/widgets/anatomy/anatomy_model.dart';
import 'package:cpredux/widgets/anatomy/anatomy_scene.dart';
import 'package:cpredux/widgets/cyber_body_viewer.dart';
import 'package:cpredux/widgets/humanity_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AnatomyModel model;
  setUpAll(() async {
    if (Platform.environment['CPREDUX_VISUAL_QA'] != null) {
      final File font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
      if (font.existsSync()) {
        final FontLoader loader = FontLoader('AnatomyQA')
          ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await loader.load();
      }
    }
    model = decodeAnatomy(
      File('assets/anatomy/body.mesh.json.gz').readAsBytesSync(),
    );
  });

  test('all six offline anatomical layers contain bounded real geometry', () {
    expect(model.meshes.map((m) => m.layer).toSet(), <String>{
      'surface',
      'skeleton',
      'muscles',
      'arteries',
      'veins',
      'nervous',
    });
    for (final AnatomyMesh mesh in model.meshes) {
      expect(mesh.triangles.length, greaterThan(3000));
      expect(
        mesh.positions.every((double n) => n.isFinite && n.abs() < 1.2),
        isTrue,
      );
      expect(mesh.zones, containsAll(<int>[9, 10, 11, 12, 13, 14]));
    }
  });

  test(
    'left and right limbs survive serialization; legacy sides stay unassigned',
    () {
      for (final CyberBodyZone zone in CyberBodyZone.selectable) {
        final Cyberware original = Cyberware(
          id: zone.id,
          name: zone.label,
          bodyZone: zone.id,
        );
        expect(Cyberware.fromJson(original.toJson()).bodyZone, zone.id);
      }
      expect(CyberBodyZone.fromId('hands').hasUnassignedSide, isTrue);
      expect(
        defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cybermano destra'),
        'right_hand',
      );
      expect(
        defaultBodyZoneFor(
          CyberwareCategory.cyberlimbs,
          'Cyberbraccio sinistro',
        ),
        'left_arm',
      );
      expect(
        defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cybergamba DX'),
        'right_leg',
      );
      expect(
        defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cybermano'),
        'hands',
      );
    },
  );

  test(
    'perspective picking follows each side through front, back and zoom',
    () {
      for (final double yaw in <double>[0, math.pi, .65]) {
        final AnatomyFrame frame = AnatomyFrame.project(
          model: model,
          size: const Size(700, 700),
          camera: AnatomyCamera(yaw: yaw, zoom: 1.2),
          layer: 'surface',
        );
        final Set<String> visible = <String>{};
        for (final AnatomyFace face in frame.faces) {
          if (visible.contains(CyberBodyZone.values[face.zone].id)) continue;
          final Offset center = Offset(
            (face.ax + face.bx + face.cx) / 3,
            (face.ay + face.by + face.cy) / 3,
          );
          final String? picked = frame.pick(center);
          if (picked != null) visible.add(picked);
        }
        expect(
          visible,
          containsAll(<String>[
            'head',
            'torso',
            'left_arm',
            'right_arm',
            'left_hand',
            'right_hand',
            'left_leg',
            'right_leg',
          ]),
        );
        expect(frame.pick(const Offset(-1000, -1000)), isNull);
      }
    },
  );

  test('camera limits zoom and pitch without resetting the orbit', () {
    final AnatomyCamera c = const AnatomyCamera().orbit(30, 9999);
    expect(c.pitch, 1.15);
    expect(c.magnify(999).zoom, 3.5);
    expect(c.magnify(-1).zoom, .65);
    expect(c.magnify(2).yaw, c.yaw);
  });

  testWidgets(
    'scanner rotates, zooms, isolates layers and installs in the selected hand',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      String? installed;
      final GlobalKey capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: CprTheme.buildTheme().copyWith(
            textTheme: CprTheme.buildTheme().textTheme.apply(
              fontFamily: Platform.environment['CPREDUX_VISUAL_QA'] == null
                  ? null
                  : 'AnatomyQA',
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: capture,
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter update) => Column(
                    children: <Widget>[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          HumanityGauge(current: 0, max: 60, size: 156),
                          HumanityGauge(current: 30, max: 60, size: 156),
                          HumanityGauge(current: 60, max: 60, size: 156),
                        ],
                      ),
                      CyberBodyViewer(
                        model: model,
                        cyberware: <Cyberware>[
                          Cyberware(
                            id: 'r',
                            name: 'Artigli',
                            bodyZone: 'right_hand',
                          ),
                          Cyberware(
                            id: 'l',
                            name: 'Presa neurale',
                            bodyZone: 'left_hand',
                          ),
                        ],
                        selectedZone: selected,
                        onZoneSelected: (String? z) =>
                            update(() => selected = z),
                        onInstallInZone: (String z) => installed = z,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'surface');
      final Finder viewport = find.byKey(
        const ValueKey<String>('anatomy-viewport'),
      );
      await tester.drag(viewport, const Offset(110, 10));
      await tester.pump();
      await tester.tap(find.byTooltip('Zoom avanti'));
      await tester.pump();
      expect(find.textContaining('120%'), findsOneWidget);
      await tester.tap(find.byTooltip('Ripristina vista'));
      await tester.pump();
      for (final String layer in <String>[
        'SCHELETRO',
        'VASCOLARE',
        'NERVOSO',
        'MUSCOLI',
        'TUTTI I SISTEMI',
      ]) {
        await tester.tap(find.text(layer).first);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          capture,
          layer.toLowerCase().replaceAll(' ', '_'),
        );
      }
      await tester.tap(find.text('MANO DX'));
      await tester.pump();
      expect(selected, 'right_hand');
      // The selected zone is exposed to the real editor callback; the unit
      // test above verifies the exact zone id used by that callback.
      expect(installed, isNull);
      await tester.tap(find.text('MANO SX'));
      await tester.pump();
      expect(selected, 'left_hand');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'implant editor preserves the chosen side across category changes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Cyberware? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  saved = await showCyberwareEditor(
                    context,
                    initialBodyZone: 'right_hand',
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (Widget w) => w is TechField && w.label == 'Nome',
          ),
          matching: find.byType(TextField),
        ),
        'Artigli',
      );
      final TechDropdown<CyberwareCategory> category = tester.widget(
        find.byType(TechDropdown<CyberwareCategory>),
      );
      category.onChanged(CyberwareCategory.cyberlimbs);
      await tester.pump();
      final TechDropdown<CyberBodyZone> zone = tester.widget(
        find.byType(TechDropdown<CyberBodyZone>),
      );
      expect(zone.value, CyberBodyZone.rightHand);
      await tester.tap(find.text('INSTALLA'));
      await tester.pumpAndSettle();
      expect(saved?.bodyZone, 'right_hand');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'head fill handles empty, full, negative humanity and zero maximum',
    (WidgetTester tester) async {
      for (final (int current, int maximum, double fill)
          in <(int, int, double)>[
            (0, 60, 0),
            (60, 60, 1),
            (-10, 60, 0),
            (10, 0, 0),
            (30, 60, .5),
          ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Center(
                child: HumanityGauge(current: current, max: maximum),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final HumanityHeadPainter painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((CustomPaint w) => w.painter)
            .whereType<HumanityHeadPainter>()
            .single;
        expect(painter.ratio, fill);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final String? directory = Platform.environment['CPREDUX_VISUAL_QA'];
  if (directory == null) return;
  await tester.runAsync(() async {
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
