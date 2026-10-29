import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:odt/screens/finance/finance_tab.dart';
import 'package:odt/services/business_currency.dart';
import 'package:odt/services/business_reporting.dart';
import 'package:odt/services/vision_service.dart';

import 'record_sale_flow_test.dart' show FakeDatabase;

class PendingFinanceDatabase extends FakeDatabase {
  final response = Completer<FinanceReport>();
  @override
  Future<FinanceReport> getFinanceReport(
    String duration, {
    DateTime? customStart,
    DateTime? customEnd,
  }) => response.future;
}

void main() {
  testWidgets('Finance keeps Insights in place while the summary loads', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = PendingFinanceDatabase();
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: FinanceTab(database: db),
      ),
    );
    await tester.pump();
    final before = tester.getTopLeft(find.text('Financial Insights')).dy;
    expect(find.text('Financial Breakdown'), findsOneWidget);
    expect(find.text('Business Expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
    db.response.complete(
      FinanceReport(
        BusinessPeriod.fromDay({
          'timezone': 'Africa/Lagos',
          'local_date': '2026-10-29',
        }, 'today'),
        {'gross_sales': 500, 'net_collected': 500},
        const [],
        const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Financial Insights')).dy,
      closeTo(before, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'Chart skeleton fits a narrow screen with large text: $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? TrexvenTheme.lightTheme
                : TrexvenTheme.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: TrexvenSkeleton(
                      kind: TrexvenSkeletonKind.financeChart,
                      scrollable: false,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  test('Money respects the business currency without conversion', () {
    expect(BusinessCurrency.formatter('NGN').format(1234.5), '₦1,234.50');
    expect(BusinessCurrency.formatter('GHS').format(1234.5), 'GH₵1,234.50');
    expect(BusinessCurrency.formatter('XOF').format(1234), 'CFA 1,234');
    expect(BusinessCurrency.formatter('XYZ').format(1234.5), 'XYZ 1,234.50');
  });

  test(
    'Cloud Vision rejects LAN addresses, plain HTTP and embedded credentials',
    () {
      expect(
        VisionService.normalizeCloudUrl('https://vision.example.com/'),
        'https://vision.example.com',
      );
      for (final address in [
        'http://vision.example.com',
        'https://192.168.1.19',
        'https://localhost',
        'https://camera.local',
        'https://user:secret@vision.example.com',
      ]) {
        expect(
          () => VisionService.normalizeCloudUrl(address),
          throwsFormatException,
        );
      }
    },
  );
}
