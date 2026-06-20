import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:live_housie/main.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LiveHousieApp(),
      ),
    );

    // Verify the splash screen shows the app name
    expect(find.text('Lootlo'), findsOneWidget);
  });
}
