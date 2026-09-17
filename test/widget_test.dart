import 'package:flutter_test/flutter_test.dart';
import 'package:campusride/main.dart';

void main() {
  testWidgets('CampusRide app loads successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusRideApp());

    expect(find.text('CampusRide'), findsWidgets);
  });
}
