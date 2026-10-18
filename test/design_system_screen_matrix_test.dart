import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/screens/auth/register_screen.dart';
import 'package:odt/screens/setup/business_setup_screen.dart';
import 'package:odt/screens/intelligence/add_camera_screen.dart';
import 'package:odt/screens/inventory/add_product_screen.dart';
import 'package:odt/models/product.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'restock_flow_test.dart' show RestockDatabase;

void main() {
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('Owner priority forms $width/$scale/$dark', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = RestockDatabase();
          for (final screen in [
            const RegisterScreen(),
            const BusinessSetupScreen(
              ownerName: 'Owner',
              email: 'owner@example.invalid',
            ),
            const AddCameraScreen(),
            AddProductScreen(database: db),
          ]) {
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
                home: screen,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType}',
            );
            final form = find.byType(Form);
            if (form.evaluate().isNotEmpty) {
              tester.state<FormState>(form.first).validate();
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${screen.runtimeType} errors',
              );
            }
            if (screen is AddProductScreen) {
              await tester.ensureVisible(find.text('Restock existing'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Restock existing'));
              db.updates.add([
                Product(
                  id: 'p',
                  name: 'Representative long product name',
                  price: 10,
                  stock: 5,
                ),
              ]);
              await tester.pumpAndSettle();
              final dropdown = find.byIcon(Icons.keyboard_arrow_down_rounded);
              await tester.ensureVisible(dropdown);
              await tester.pumpAndSettle();
              await tester.tap(dropdown);
              await tester.pumpAndSettle();
              await tester.tap(
                find.text('Representative long product name').last,
              );
              await tester.pumpAndSettle();
              await tester.enterText(find.byType(TextFormField).first, '2');
              await tester.enterText(find.byType(TextFormField).last, '12.345');
              tester.state<FormState>(find.byType(Form)).validate();
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.byType(FilledButton));
              await tester.pumpAndSettle();
              expect(find.text('Selling price'), findsOneWidget);
              expect(
                tester.takeException(),
                isNull,
                reason: 'Restock with keyboard and price validation',
              );
            }
            await tester.pumpWidget(const SizedBox());
          }
          await db.updates.close();
        });
      }
    }
  }
}
