import 'package:anatomy_atlas/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('opens bundled heart content without a network dependency', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AnatomyAtlasApp()));
    await tester.pumpAndSettle();
    expect(find.textContaining('أطلس'), findsWidgets);
    await tester.tap(find.text('القلب').first);
    await tester.pumpAndSettle();
    expect(find.text('القلب'), findsWidgets);
    expect(find.textContaining('تعليمي'), findsWidgets);
  });
}
