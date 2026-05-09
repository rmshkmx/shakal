import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3shakal/main.dart';

void main() {
  testWidgets('renders shakal compressor screen', (tester) async {
    await tester.pumpWidget(const ShakalApp());
    await tester.pump();

    expect(find.text('\u0428\u041a\u041b'), findsOneWidget);
    expect(find.text('Выбрать фото'), findsOneWidget);
    expect(find.text('Степень сжатия'), findsOneWidget);
    expect(find.text('Интенсивность\nартефактов'), findsOneWidget);
    expect(find.byIcon(Icons.auto_fix_high_rounded), findsOneWidget);
    expect(find.byIcon(Icons.save_alt_rounded), findsOneWidget);
  });
}
