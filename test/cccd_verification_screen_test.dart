import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/profile/screens/cccd_verification_screen.dart';

void main() {
  group('CccdVerificationScreen Widget Tests', () {
    testWidgets(
      'Khởi tạo ban đầu: hiển thị trạng thái "Cần chọn ảnh mới để xác nhận" cho cả 2 mặt và nút submit bị disabled',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWith((ref) => Stream.value(null)),
            ],
            child: const MaterialApp(
              home: CccdVerificationScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Xác nhận trạng thái ban đầu hiển thị "Cần chọn ảnh mới để xác nhận" cho cả 2 mặt
        expect(find.text('Cần chọn ảnh mới để xác nhận'), findsNWidgets(2));

        // 2. Xác nhận nút lưu/xác thực ban đầu bị disabled (onPressed == null)
        final submitButtonFinder = find.byType(ElevatedButton);
        expect(submitButtonFinder, findsOneWidget);

        final submitButton = tester.widget<ElevatedButton>(submitButtonFinder);
        expect(submitButton.onPressed, isNull);

        // 3. Xác nhận hiển thị thông điệp chưa đủ điều kiện xác thực
        expect(find.textContaining('CHƯA ĐỦ ĐIỀU KIỆN XÁC THỰC'), findsOneWidget);
      },
    );
  });
}
