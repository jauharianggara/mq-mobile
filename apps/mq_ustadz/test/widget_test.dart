import 'package:flutter_test/flutter_test.dart';
import 'package:mq_ustadz/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MqUstadzApp());
  });
}
