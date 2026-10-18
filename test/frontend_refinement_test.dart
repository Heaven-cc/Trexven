import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:odt/models/subscription_plan.dart';
import 'package:odt/screens/me/billing_screen.dart';
import 'package:odt/screens/me/profile_screen.dart';
import 'package:odt/widgets/angel_markdown.dart';
import 'package:odt/services/sale_errors.dart';

const response = '''# Sales review
**Clear advice** with *emphasis* and `inline code`.

1. Review your sales.
2. Check your stock.

- [x] Review completed
- [ ] Follow up

> Compare actual business results.

```text
This is a deliberately long code line which must scroll horizontally instead of overflowing the message bubble.
```

| Product | Status | Details |
| --- | --- | --- |
| Example | Available | A longer table cell to exercise narrow layouts |

[Help](https://example.invalid/help)
''';
const plan = SubscriptionPlan(
  tier: SubscriptionTier.core,
  name: 'CORE',
  description: 'Tools for your business.',
  features: [
    'Employee permissions',
    'Advanced inventory',
    'Business analytics',
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.invalid',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    final file = File(r'C:\Windows\Fonts\arial.ttf');
    if (await file.exists()) {
      for (final family in ['Roboto', 'Ahem', 'monospace']) {
        final loader = FontLoader(family)
          ..addFont(
            file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
    final icons = File(
      r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('Angel copy retains the complete original response', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'] as String;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: const Scaffold(
          body: AngelMarkdown(data: '**Complete** response'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Copy response'));
    await tester.pumpAndSettle();
    expect(copied, '**Complete** response');
    expect(find.text('Response copied.'), findsOneWidget);
  });

  test(
    'Presentation masks database internals without inventing status or currency',
    () {
      const error = PostgrestException(
        message: 'secret SQL dump',
        code: '42501',
        details: 'private query',
      );
      expect(CustomerPresentation.error(error), isNot(contains('SQL')));
      expect(CustomerPresentation.error(error), isNot(contains('private')));
      expect(CustomerPresentation.label('sales_employee'), 'Sales employee');
      expect(CustomerPresentation.label('bank_transfer'), 'Bank transfer');
      expect(CustomerPresentation.money(0, currency: 'NGN'), contains('0.00'));
      expect(CustomerPresentation.date('invalid'), 'Not available');
      final parsed = SubscriptionPlan.fromJson({
        'id': 'core',
        'name': 'CORE',
        'features': {'basic_vision': true},
      });
      expect(parsed.features, ['Vision insights']);
      expect(parsed.price, isNull);
    },
  );
  test('Rejected sale messages do not expose RPC or SQL internals', () {
    expect(
      saleErrorMessage(
        const PostgrestException(
          message: 'public.private_rpc() internal failure',
          code: 'P0001',
        ),
      ),
      isNot(contains('private_rpc')),
    );
    expect(
      saleOutcomeIsUnconfirmed(
        const PostgrestException(message: 'rejected', code: 'P0001'),
      ),
      false,
    );
  });
  test(
    'Angel accepts web links and rejects active/local or credential-bearing links',
    () {
      expect(isSafeAngelLink('https://example.invalid/help'), true);
      for (final link in [
        'javascript:alert(1)',
        'file:///C:/secret',
        'data:text/html,test',
        '/relative',
        'https://user:pass@example.invalid',
        null,
      ]) {
        expect(isSafeAngelLink(link), false);
      }
    },
  );

  for (final width in [320.0, 412.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'Markdown, plan and Profile fit $width in ${dark ? 'dark' : 'light'} mode with large text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget app(Widget home) => MaterialApp(
            theme: dark ? TrexvenTheme.darkTheme : TrexvenTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: home,
          );
          await tester.pumpWidget(
            app(
              const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: AngelMarkdown(data: response),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final markdown = tester.widget<MarkdownBody>(
            find.byType(MarkdownBody),
          );
          expect(markdown.selectable, true);
          expect(find.byType(Table), findsOneWidget);
          expect(find.byTooltip('Copy response'), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            app(
              const Scaffold(
                body: SingleChildScrollView(
                  child: BillingPlanCard(plan: plan, current: true),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Current plan'), findsOneWidget);
          expect(find.text('Pricing not configured'), findsNothing);
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Upgrades unavailable'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(
            app(const ProfileScreen(initialName: 'Test Owner')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Billing & Plans'), findsNothing);
          await tester.enterText(find.byType(TextFormField), ' ');
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TrexvenButton));
          await tester.tap(
            find.descendant(
              of: find.byType(TrexvenButton),
              matching: find.byType(TrexvenPressable),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Enter your full name.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Capture actual priority widgets with synthetic display fixtures',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final screens = <String, Widget>{
        'profile': const ProfileScreen(initialName: 'Test Owner'),
        'billing_plan': Scaffold(
          appBar: null,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [BillingPlanCard(plan: plan, current: true)],
            ),
          ),
        ),
        'angel_markdown': const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AngelMarkdown(data: response),
            ),
          ),
        ),
      };
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: TrexvenTheme.lightTheme,
              home: entry.value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/implementation/evidence/frontend_previews/${entry.key}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
