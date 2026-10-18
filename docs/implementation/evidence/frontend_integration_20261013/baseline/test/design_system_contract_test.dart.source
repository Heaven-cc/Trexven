import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:odt/screens/auth/login_screen.dart';

void main() {
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Shared form $width/$scale/${dark ? 'dark' : 'light'} retains values, labels and dropdown',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final controller = TextEditingController();
            addTearDown(controller.dispose);
            final form = GlobalKey<FormState>();
            String? selected = 'piece';
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: const EdgeInsets.only(bottom: 280),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: Form(
                    key: form,
                    child: ListView(
                      padding: TrexvenSpacing.pagePadding,
                      children: [
                        TrexvenTextFormField(
                          controller: controller,
                          decoration: const TrexvenInputDecoration(
                            labelText: 'Product name',
                            hintText: 'Example product',
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Enter a product name before continuing.'
                              : null,
                        ),
                        TrexvenDropdown<String>(
                          label: 'Unit',
                          initialValue: selected,
                          items: const [
                            DropdownMenuItem(
                              value: 'piece',
                              child: Text('Piece'),
                            ),
                            DropdownMenuItem(
                              value: 'kg',
                              child: Text('Kilogram'),
                            ),
                          ],
                          onChanged: (value) => selected = value,
                        ),
                        TrexvenTextField(
                          label: 'Notes',
                          maxLines: 3,
                          decoration: const TrexvenInputDecoration(
                            helperText: 'Optional details',
                          ),
                        ),
                        TrexvenButton(
                          text: 'Save product changes',
                          onPressed: () => form.currentState!.validate(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(form.currentState!.validate(), isFalse);
            await tester.pumpAndSettle();
            expect(
              find.text('Enter a product name before continuing.'),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<Text>(
                    find.text('Enter a product name before continuing.'),
                  )
                  .maxLines,
              isNull,
              reason:
                  'Validation must grow instead of truncating at large text scales.',
            );
            await tester.enterText(
              find.byType(TextFormField),
              'Retained product',
            );
            expect(form.currentState!.validate(), isTrue);
            await tester.pumpAndSettle();
            expect(find.text('Product name'), findsOneWidget);
            expect(controller.text, 'Retained product');
            final dropdown = find.byIcon(Icons.keyboard_arrow_down_rounded);
            await tester.ensureVisible(dropdown);
            await tester.tap(dropdown);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Kilogram').last);
            await tester.pumpAndSettle();
            expect(selected, 'kg');
            expect(tester.takeException(), isNull);
            final action = find.byType(ElevatedButton);
            await tester.ensureVisible(action);
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            final field = find.byType(TextFormField);
            expect(tester.getSize(field).height, greaterThanOrEqualTo(48));
            if (scale == 1)
              expect(tester.getSize(field).height, lessThanOrEqualTo(56));
            await tester.pumpWidget(const SizedBox());
          },
        );
        testWidgets(
          'Owner login $width/$scale/${dark ? 'dark' : 'light'} fits with keyboard',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: const EdgeInsets.only(bottom: 280),
                  ),
                  child: child!,
                ),
                home: const LoginScreen(),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.enterText(
              find.byType(TextFormField).first,
              'owner@example.invalid',
            );
            await tester.pumpAndSettle();
            expect(
              find.widgetWithText(TrexvenFieldLabel, 'Email Address'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
  test('Both theme variants share geometry and complete surface themes', () {
    for (final theme in [TrexvenTheme.lightTheme, TrexvenTheme.darkTheme]) {
      expect(
        theme.inputDecorationTheme.contentPadding,
        TrexvenSpacing.fieldPadding,
      );
      expect(
        theme.inputDecorationTheme.enabledBorder!.borderSide,
        BorderSide.none,
      );
      expect(
        theme.inputDecorationTheme.focusedBorder!.borderSide.color,
        theme.colorScheme.primary,
      );
      expect(theme.dialogTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.bottomSheetTheme.backgroundColor, theme.colorScheme.surface);
      expect(
        theme.navigationBarTheme.backgroundColor,
        theme.colorScheme.surface,
      );
    }
  });
}
