import 'dart:io';
import 'dart:ui' as ui;

import 'package:communityshare_app/pages/admin/admin_product_moderation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders product moderation pagination with 50 fake entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 1920));

    final boundaryKey = GlobalKey();
    final reports = _fakeReports(50);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: AdminProductModerationPage(debugReports: reports),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 7'), findsOneWidget);

    final outputDir = Directory('test_outputs');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    await _captureBoundary(
      tester,
      boundaryKey,
      '${outputDir.path}${Platform.pathSeparator}admin_product_moderation_page_page_1.png',
    );

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
    }

    expect(find.text('Page 7 of 7'), findsOneWidget);

    await _captureBoundary(
      tester,
      boundaryKey,
      '${outputDir.path}${Platform.pathSeparator}admin_product_moderation_page_page_7.png',
    );
  });
}

List<Map<String, dynamic>> _fakeReports(int count) {
  return List.generate(count, (index) {
    final n = index + 1;
    return <String, dynamic>{
      'id': 'report_$n',
      'itemId': 'item_$n',
      'productName': 'Sample Product $n',
      'productImage': '',
      'productPrice': 0.0,
      'reporterId': 'reporter_$n',
      'reporterName': 'Reporter $n',
      'sellerId': 'seller_$n',
      'sellerName': 'Seller $n',
      'reason': 'Reason for report $n',
      'description': '',
      'timestamp': DateTime(2026, 7, 17, 10, 0).add(Duration(minutes: n)),
      'status': n % 3 == 0 ? 'Resolved' : 'Pending',
    };
  });
}

Future<void> _captureBoundary(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path,
) async {
  await tester.runAsync(() async {
    final boundaryContext = boundaryKey.currentContext;
    if (boundaryContext == null) {
      throw StateError('RepaintBoundary context not found.');
    }

    final boundary =
        boundaryContext.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Unable to encode screenshot.');
    }

    await File(path).writeAsBytes(byteData.buffer.asUint8List());
  });
}
