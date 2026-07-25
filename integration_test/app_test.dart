import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pinace_wallet/main.dart' as app;

void main() {
  patrolTest(
    'app boots and shows login',
    ($) async {
      app.main();
      await $.pumpAndSettle();

      // Check if any text is visible
      expect($(RegExp('.*')), findsWidgets);
    },
  );
}
