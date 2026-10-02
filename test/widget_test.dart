import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/app_colors.dart';

void main() {
  testWidgets('App colors and basic theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: const Center(
            child: Text(
              'HomeShare Renter Suite',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );

    expect(find.text('HomeShare Renter Suite'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
