import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:odt/core/user_provider.dart';
import 'package:odt/models/business.dart';
import 'package:odt/models/product.dart';
import 'package:odt/models/sale.dart';
import 'package:odt/screens/dashboard/dashboard_screen.dart';
import 'package:odt/screens/inventory/inventory_tab.dart';
import 'package:odt/screens/inventory/add_product_screen.dart';
import 'package:odt/screens/finance/finance_tab.dart';
import 'restock_flow_test.dart' show RestockDatabase;
import 'design_system_visual_test.dart' show previewTheme;

class PreviewUser extends UserProvider {
  @override
  String get ownerName => 'Micheal';
  @override
  String get businessName => 'My Business';
  @override
  Business get business => Business(
    id: 'preview',
    ownerId: 'preview',
    businessName: businessName,
    currency: 'NGN',
  );
}

class PreviewDatabase extends RestockDatabase {
  final catalog = [
    Product(id: 'clutch', name: 'Clutch', price: 0, stock: 20),
    Product(id: 'brake', name: 'Brake pad', price: 24000, stock: 27),
  ];
  @override
  Stream<List<Product>> getProductsStream() => Stream.value(catalog);
  @override
  Future<Map<String, dynamic>> getTodayStats() async => {
    'sales': 1235000.0,
    'transactions': 142,
    'stockValue': 648000,
    'lowStock': 0,
  };
  @override
  Future<List<Sale>> getSalesWithProductNames({int? limit}) async =>
      List.generate(
        8,
        (i) => Sale(
          productId: 'brake',
          productName: 'Brake pad',
          quantity: 2,
          unitPrice: 24000,
          totalPrice: 48000 + i * 1000,
          createdAt: DateTime(2026, 10, 10, 9, i),
        ),
      );
  @override
  Future<Map<String, dynamic>> getDetailedDashboardStats() async => {
    'sales': {
      'totalToday': 1235000.0,
      'countToday': 142,
      'totalYesterday': 950000.0,
    },
    'transactions': {'successful': 142},
    'inventory': {'totalValue': 648000.0, 'productCount': 2},
    'lowStock': {'totalCount': 0},
  };
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.invalid',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    final font = File(r'C:\Windows\Fonts\arial.ttf');
    if (font.existsSync()) {
      for (final family in ['TrexvenPreview', 'Roboto', 'Ahem']) {
        await (FontLoader(
          family,
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final width in [320.0, 340.0, 390.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Reference pages $width/$scale/$dark preserve layout and filters',
          (tester) async {
            tester.view.physicalSize = Size(width, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final db = PreviewDatabase();
            final user = PreviewUser();
            for (final entry in <String, Widget>{
              'dashboard': Scaffold(
                body: DashboardScreen(
                  ownerName: user.ownerName,
                  businessName: user.businessName,
                  database: db,
                ),
              ),
              'inventory': InventoryTab(database: db),
              'restock': AddProductScreen(database: db, startInRestock: true),
              'finance': FinanceTab(database: db),
            }.entries) {
              final key = GlobalKey();
              await tester.pumpWidget(
                ChangeNotifierProvider<UserProvider>.value(
                  value: user,
                  child: RepaintBoundary(
                    key: key,
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: previewTheme(
                        dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
                      ),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!,
                      ),
                      home: entry.value,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: entry.key);
              if (entry.key == 'restock') {
                await tester.tap(
                  find.byIcon(Icons.keyboard_arrow_down_rounded).first,
                );
                await tester.pumpAndSettle();
                await tester.tap(find.text('Clutch').last);
                await tester.pumpAndSettle();
                expect(
                  tester
                      .widgetList<TextField>(find.byType(TextField))
                      .any((f) => f.controller?.text == '0.00'),
                  isTrue,
                );
              }
              const folder = String.fromEnvironment('TREXVEN_CAPTURE_DIR');
              if (folder.isNotEmpty && width == 390 && scale == 1) {
                await tester.runAsync(() async {
                  final render =
                      key.currentContext!.findRenderObject()
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
              if (entry.key == 'inventory') {
                await tester.enterText(find.byType(TextField), 'brake');
                await tester.pumpAndSettle();
                expect(find.text('Clutch'), findsNothing);
                expect(find.text('Brake pad'), findsOneWidget);
                expect(tester.takeException(), isNull);
              }
              await tester.pumpWidget(const SizedBox());
            }
            user.dispose();
            await db.updates.close();
            expect(db.writes, 0);
          },
        );
      }
    }
  }
}
