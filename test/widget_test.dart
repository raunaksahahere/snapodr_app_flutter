import 'package:flutter_test/flutter_test.dart';
import 'package:snapodr_app_flutter/main.dart';

void main() {
  testWidgets('staff login screen is shown', (tester) async {
    await tester.pumpWidget(const SnapOdrApp());
    expect(find.text('SnapOdr Staff'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
