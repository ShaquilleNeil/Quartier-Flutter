import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quartier/widgets/common.dart';

void main() {
  testWidgets('NetImage shows the bundled fallback when there is no url',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: NetImage(null)));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/apartment1.jpg');
  });

  testWidgets('NetImage uses a custom fallback when given one', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: NetImage('', fallback: Text('no photo')),
    ));

    expect(find.text('no photo'), findsOneWidget);
  });
}
