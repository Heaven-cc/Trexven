import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/screens/auth/login_screen.dart';
import 'package:odt/screens/setup/business_setup_screen.dart';
import 'package:odt/screens/intelligence/add_camera_screen.dart';

ThemeData previewTheme(ThemeData source) {
  ButtonStyle fontStyle(ButtonStyle? style) =>
      (style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) => (style?.textStyle?.resolve(states) ?? const TextStyle())
              .copyWith(fontFamily: 'TrexvenPreview'),
        ),
      );
  return source.copyWith(
    textTheme: source.textTheme.apply(fontFamily: 'TrexvenPreview'),
    chipTheme: source.chipTheme.copyWith(
      labelStyle: source.chipTheme.labelStyle?.copyWith(
        fontFamily: 'TrexvenPreview',
      ),
    ),
    appBarTheme: source.appBarTheme.copyWith(
      titleTextStyle: source.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: 'TrexvenPreview',
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: fontStyle(source.elevatedButtonTheme.style),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: fontStyle(source.filledButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: fontStyle(source.outlinedButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: fontStyle(source.textButtonTheme.style),
    ),
  );
}

void main() {
  setUpAll(() async {
    final font = File(r'C:\Windows\Fonts\arial.ttf');
    if (font.existsSync()) {
      for (final family in ['TrexvenPreview', 'Roboto', 'Ahem', 'monospace']) {
        final loader = FontLoader(family)
          ..addFont(font.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final entry in <String, Widget>{
    'login': const LoginScreen(),
    'setup': const BusinessSetupScreen(
      ownerName: 'Owner',
      email: 'owner@example.invalid',
    ),
    'camera': const AddCameraScreen(),
  }.entries) {
    for (final dark in [false, true]) {
      testWidgets('Owner ${entry.key} visual ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: previewTheme(
                dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
              ),
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        const folder = String.fromEnvironment('TREXVEN_CAPTURE_DIR');
        if (folder.isNotEmpty) {
          await tester.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final picture = await render.toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(folder).create(recursive: true);
            await File(
              '$folder/owner-${entry.key}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
      });
    }
  }
}
