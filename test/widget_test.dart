import 'package:flutter_test/flutter_test.dart';

import 'package:sistembrankas/main.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Karena MyApp membuka LoginScreen, cek apakah AppBar Login terlihat.
    expect(find.text('Login Firebase'), findsOneWidget);

    // Cek apakah tombol sign in / create ada
    expect(find.text('Sign in / Create'), findsOneWidget);

    // Cek juga tombol sign in anonymously ada
    expect(find.text('Sign in anonymously'), findsOneWidget);
  });
}
