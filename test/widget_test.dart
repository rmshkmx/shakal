import 'package:flutter_test/flutter_test.dart';
import 'package:md3shakal/main.dart';

void main() {
  testWidgets('renders shakal compressor screen', (tester) async {
    await tester.pumpWidget(const ShakalApp());
    await tester.pumpAndSettle();

    expect(find.text('\u0428\u041a\u041b'), findsOneWidget);
    expect(find.text('Compression Quality'), findsOneWidget);
    expect(find.text('Downscale factor'), findsOneWidget);
    expect(
      find.text('\u0417\u0410\u0428\u0410\u041a\u0410\u041b\u0418\u0422\u042c'),
      findsOneWidget,
    );
    expect(
      find.text('\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c'),
      findsOneWidget,
    );
  });
}
