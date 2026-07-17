import 'package:flutter_test/flutter_test.dart';
import 'package:sentinel/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const SentinelApp());
    expect(find.text('Sentinel'), findsOneWidget);
  });
}
