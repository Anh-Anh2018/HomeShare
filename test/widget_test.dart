import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_share/core/constants/app_colors.dart';
import 'package:home_share/core/theme/phong_sang_theme.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/renter/screens/roommate_post_detail_screen.dart';

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

  testWidgets('Chi tiết bài ở ghép layout được và nhận chạm', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final post = RoommatePostModel(
      id: 'rm_test',
      authorId: 'author_1',
      authorName: 'Minh Trang',
      authorAge: 21,
      authorGender: 'Nữ',
      authorOccupation: 'Sinh viên',
      title: 'Cần tìm bạn ở ghép',
      description: 'Phòng thoáng',
      budgetMin: 1500000,
      budgetMax: 2000000,
      district: 'TP. Thủ Đức',
      targetGender: 'Nữ',
      habits: const ['Yên tĩnh sau 23h'],
      images: const [
        'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDABALDA4MChAODQ4SERATGCgaGBYWGDEjJR0oOjM9PDkzODdASFxOQERXRTc4UG1RV19iZ2hnPk1xeXBkeFxlZ2P/2wBDARESEhgVGC8aGi9jQjhCY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2NjY2P/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAj/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA//2Q==',
      ],
      imageCaptions: const ['Phòng ngủ'],
      hasRoom: true,
      contactPhone: '0900000000',
      createdAt: DateTime(2026, 10, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PhongSangTheme.light,
          home: RoommatePostDetailScreen(post: post),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Cần tìm bạn ở ghép'), findsOneWidget);
    expect(find.text('Gọi điện'), findsOneWidget);

    await tester.tap(find.text('Cần tìm bạn ở ghép'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nút Thêm trong hàng không làm trắng màn Đăng tin', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PhongSangTheme.light,
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: SizedBox(height: 42)),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Thêm'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Thêm'), findsOneWidget);
  });
}
