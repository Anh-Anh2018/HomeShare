import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/home/models/profile_overview.dart';
import 'package:home_share/features/home/widgets/personal_profile_content.dart';
import 'package:home_share/features/home/widgets/profile_actions_card.dart';
import 'package:home_share/features/home/widgets/profile_completion_card.dart';
import 'package:home_share/features/home/widgets/profile_header_card.dart';
import 'package:home_share/features/home/widgets/profile_stats_card.dart';

void main() {
  BookingRequestModel createBooking({
    required String id,
    required String status,
  }) {
    return BookingRequestModel(
      id: id,
      renterId: 'renter_1',
      renterName: 'Renter Test',
      renterPhone: '0901234567',
      roomId: 'room_1',
      roomTitle: 'Phòng trọ test',
      roomAddress: '123 Đường Test, Q1',
      roomPrice: 3000000,
      deposit: 3000000,
      totalAmount: 6000000,
      rentalMonths: 6,
      hostId: 'host_1',
      hostName: 'Chủ trọ Test',
      status: status,
      moveInDate: DateTime(2026, 10, 1),
      note: 'Ghi chú',
      createdAt: DateTime(2026, 9, 1),
    );
  }

  final sampleProfile = UserProfile(
    uid: 'usr_renter_001',
    userCode: '829AB',
    displayName: 'Nguyễn Hoàng Long',
    email: 'hoanglong@test.vn',
    phoneNumber: '0912345678',
    role: 'renter',
    address: '789 Nguyễn Huệ, Q1',
    avatarUrl: '',
    isCccdVerified: false,
  );

  final longDataProfile = UserProfile(
    uid: 'usr_long_002',
    userCode: '999XYZ_LONG_CODE',
    displayName: 'Nguyễn Trần Hoàng Long Bảo Ngọc Khánh',
    email: 'nguyen.tran.hoang.long@super-long-domain-homeshare.vn',
    phoneNumber: '0912345678',
    role: 'renter',
    address:
        'Số 1234 Đường Nguyễn Thị Thập, Phường Tân Phú, Quận 7, TP. Hồ Chí Minh',
    avatarUrl: '',
    isCccdVerified: false,
  );

  Widget buildTestWidget({
    UserProfile? profile,
    ProfileOverviewStats stats = const ProfileOverviewStats(
      totalBookings: 3,
      pendingCount: 2,
      activeCount: 1,
    ),
    bool isBookingsLoading = false,
    bool hasBookingsError = false,
    VoidCallback? onOpenAccountSettings,
    VoidCallback? onOpenCccdVerification,
    VoidCallback? onOpenBookings,
    VoidCallback? onSignOut,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PersonalProfileContent(
          profile: profile ?? sampleProfile,
          stats: stats,
          isBookingsLoading: isBookingsLoading,
          hasBookingsError: hasBookingsError,
          onOpenAccountSettings: onOpenAccountSettings,
          onOpenCccdVerification: onOpenCccdVerification,
          onOpenBookings: onOpenBookings,
          onSignOut: onSignOut,
        ),
      ),
    );
  }

  group('1. ProfileOverviewHelper — Thống kê Đơn thuê & Lịch hẹn', () {
    test(
      'calculateStats với danh sách rỗng hoặc null trả về các chỉ số bằng 0',
      () {
        final statsNull = ProfileOverviewHelper.calculateStats(null);
        expect(statsNull.totalBookings, equals(0));
        expect(statsNull.pendingCount, equals(0));
        expect(statsNull.activeCount, equals(0));

        final statsEmpty = ProfileOverviewHelper.calculateStats([]);
        expect(statsEmpty.totalBookings, equals(0));
        expect(statsEmpty.pendingCount, equals(0));
        expect(statsEmpty.activeCount, equals(0));
      },
    );

    test(
      'calculateStats tính đúng các trạng thái chờ/đang xử lý (pending, pending_payment, approved, paid)',
      () {
        final bookings = [
          createBooking(id: 'b1', status: 'pending'),
          createBooking(id: 'b2', status: 'pending_payment'),
          createBooking(id: 'b3', status: 'approved'),
          createBooking(id: 'b4', status: 'paid'),
          createBooking(id: 'b5', status: 'choDuyet'),
          createBooking(id: 'b6', status: 'daDuyet'),
        ];

        final stats = ProfileOverviewHelper.calculateStats(bookings);
        expect(stats.totalBookings, equals(6));
        expect(stats.pendingCount, equals(6));
        expect(stats.activeCount, equals(0));
      },
    );

    test('calculateStats tính đúng trạng thái đang thuê (active, dangO)', () {
      final bookings = [
        createBooking(id: 'b1', status: 'active'),
        createBooking(id: 'b2', status: 'dangO'),
        createBooking(id: 'b3', status: 'dang_o'),
      ];

      final stats = ProfileOverviewHelper.calculateStats(bookings);
      expect(stats.totalBookings, equals(3));
      expect(stats.pendingCount, equals(0));
      expect(stats.activeCount, equals(3));
    });

    test(
      'calculateStats không tính đơn đã hủy hoặc từ chối vào pending hay active',
      () {
        final bookings = [
          createBooking(id: 'b1', status: 'cancelled'),
          createBooking(id: 'b2', status: 'rejected'),
          createBooking(id: 'b3', status: 'daHuy'),
          createBooking(id: 'b4', status: 'tuChoi'),
        ];

        final stats = ProfileOverviewHelper.calculateStats(bookings);
        expect(stats.totalBookings, equals(4));
        expect(stats.pendingCount, equals(0));
        expect(stats.activeCount, equals(0));
      },
    );

    test('calculateStats tính toán chính xác trên tập dữ liệu hỗn hợp', () {
      final bookings = [
        createBooking(id: 'b1', status: 'pending'),
        createBooking(id: 'b2', status: 'approved'),
        createBooking(id: 'b3', status: 'active'),
        createBooking(id: 'b4', status: 'cancelled'),
        createBooking(id: 'b5', status: 'rejected'),
      ];

      final stats = ProfileOverviewHelper.calculateStats(bookings);
      expect(stats.totalBookings, equals(5));
      expect(stats.pendingCount, equals(2));
      expect(stats.activeCount, equals(1));
    });
  });

  group('2. ProfileOverviewHelper — Tỷ lệ Hoàn thiện Hồ sơ', () {
    test(
      'calculateCompletionPercentage trả về 0% khi profile null hoặc hoàn toàn rỗng',
      () {
        expect(
          ProfileOverviewHelper.calculateCompletionPercentage(null),
          equals(0),
        );
        expect(
          ProfileOverviewHelper.calculateCompletionRatio(null),
          equals(0.0),
        );

        final emptyProfile = UserProfile(
          uid: 'u_empty',
          email: '',
          displayName: 'Người dùng HomeShare',
          phoneNumber: '',
          address: '',
          avatarUrl: '',
          isCccdVerified: false,
        );

        expect(
          ProfileOverviewHelper.countCompletedFields(emptyProfile),
          equals(0),
        );
        expect(
          ProfileOverviewHelper.calculateCompletionPercentage(emptyProfile),
          equals(0),
        );
        expect(
          ProfileOverviewHelper.calculateCompletionRatio(emptyProfile),
          equals(0.0),
        );
      },
    );

    test(
      'calculateCompletionPercentage tính chính xác khi hoàn thành một phần (3/6 trường = 50%)',
      () {
        final partialProfile = UserProfile(
          uid: 'u_partial',
          displayName: 'Nguyễn Văn An',
          email: 'an@gmail.com',
          phoneNumber: '0901234567',
          address: '',
          avatarUrl: '',
          isCccdVerified: false,
        );

        expect(
          ProfileOverviewHelper.countCompletedFields(partialProfile),
          equals(3),
        );
        expect(
          ProfileOverviewHelper.calculateCompletionPercentage(partialProfile),
          equals(50),
        );
        expect(
          ProfileOverviewHelper.calculateCompletionRatio(partialProfile),
          closeTo(0.5, 0.01),
        );
      },
    );

    test('calculateCompletionPercentage tính 100% khi đủ cả 6 trường', () {
      final fullProfile = UserProfile(
        uid: 'u_full',
        displayName: 'Trần Thị Bình',
        email: 'binh@gmail.com',
        phoneNumber: '0988888888',
        address: '456 Lê Lợi, Q1, TP.HCM',
        avatarUrl: 'https://example.com/avatar.jpg',
        isCccdVerified: true,
      );

      expect(
        ProfileOverviewHelper.countCompletedFields(fullProfile),
        equals(6),
      );
      expect(
        ProfileOverviewHelper.calculateCompletionPercentage(fullProfile),
        equals(100),
      );
      expect(
        ProfileOverviewHelper.calculateCompletionRatio(fullProfile),
        equals(1.0),
      );
    });
  });

  group('3. PersonalProfileContent — Widget Tests (Không phụ thuộc Firebase)', () {
    testWidgets(
      'UI hiển thị dữ liệu thật và tuyệt đối KHÔNG chứa dữ liệu giả cũ',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Phải có thông tin thật
        expect(find.text('Nguyễn Hoàng Long'), findsOneWidget);
        expect(find.text('ID: 829AB'), findsOneWidget);
        expect(find.text('hoanglong@test.vn'), findsOneWidget);
        expect(find.text('SĐT: 0912345678'), findsOneWidget);
        expect(find.text('Người thuê'), findsOneWidget);

        // Phải có số liệu thống kê thật truyền vào (3, 2, 1) và nhãn "Đang xử lý"
        expect(find.text('3'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('Đang xử lý'), findsOneWidget);

        // Tuyệt đối KHÔNG có dữ liệu hardcode giả cũ
        expect(find.text('08'), findsNothing);
        expect(find.text('02'), findsNothing);
        expect(find.text('user@homeshare.vn'), findsNothing);
        expect(find.text('ADM01'), findsNothing);
        expect(find.text('Phòng đã lưu'), findsNothing);
        expect(find.text('Phòng đang thuê (Nhà của tôi)'), findsNothing);
        expect(find.text('Báo cáo sự cố phòng trọ'), findsNothing);
        expect(find.text('Đang chờ duyệt'), findsNothing);
      },
    );

    testWidgets(
      'Hiển thị đầy đủ 4 mục menu hoạt động và kích hoạt đúng callback với ensureVisible',
      (tester) async {
        bool openedSettings = false;
        bool openedCccd = false;
        bool openedBookings = false;
        bool signedOut = false;

        await tester.pumpWidget(
          buildTestWidget(
            onOpenAccountSettings: () => openedSettings = true,
            onOpenCccdVerification: () => openedCccd = true,
            onOpenBookings: () => openedBookings = true,
            onSignOut: () => signedOut = true,
          ),
        );

        // 1. Kiểm tra mục Đơn thuê & Lịch hẹn
        final bookingsItem = find.text('Đơn thuê & Lịch hẹn');
        await tester.ensureVisible(bookingsItem);
        await tester.pumpAndSettle();
        await tester.tap(bookingsItem);
        await tester.pumpAndSettle();
        expect(openedBookings, isTrue);

        // 2. Kiểm tra mục Cài đặt tài khoản
        final settingsItem = find.text('Cài đặt tài khoản');
        await tester.ensureVisible(settingsItem);
        await tester.pumpAndSettle();
        await tester.tap(settingsItem);
        await tester.pumpAndSettle();
        expect(openedSettings, isTrue);

        // 3. Kiểm tra mục Xác thực danh tính
        final cccdItem = find.text('Xác thực danh tính (CCCD)');
        await tester.ensureVisible(cccdItem);
        await tester.pumpAndSettle();
        await tester.tap(cccdItem);
        await tester.pumpAndSettle();
        expect(openedCccd, isTrue);

        // 4. Kiểm tra mục Đăng xuất & Hộp thoại xác nhận
        final signOutMenuItem = find.text('Đăng xuất');
        await tester.ensureVisible(signOutMenuItem);
        await tester.pumpAndSettle();
        await tester.tap(signOutMenuItem);
        await tester.pumpAndSettle();

        // Hộp thoại xác nhận xuất hiện
        expect(find.text('Xác nhận đăng xuất'), findsOneWidget);
        expect(
          find.text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản HomeShare không?',
          ),
          findsOneWidget,
        );

        // Finder cụ thể cho nút Đăng xuất trong AlertDialog
        final dialogSignOutButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Đăng xuất'),
        );
        expect(dialogSignOutButton, findsOneWidget);
        await tester.tap(dialogSignOutButton);
        await tester.pumpAndSettle();

        expect(signedOut, isTrue);
      },
    );

    testWidgets(
      'Xử lý đúng trạng thái eKYC CCCD: Chưa xác thực vs Đã xác thực',
      (tester) async {
        // Chưa xác thực
        await tester.pumpWidget(buildTestWidget());
        expect(find.text('Chưa xác thực CCCD (Quét ngay)'), findsOneWidget);
        expect(find.text('CHƯA XÁC THỰC'), findsOneWidget);
        expect(find.text('Đã xác thực CCCD (eKYC) ✓'), findsNothing);

        // Đã xác thực
        final verifiedProfile = sampleProfile.copyWith(
          isCccdVerified: true,
          cccdNumber: '079204001234',
        );
        await tester.pumpWidget(buildTestWidget(profile: verifiedProfile));
        expect(find.text('Đã xác thực CCCD (eKYC) ✓'), findsOneWidget);
        expect(find.text('ĐÃ XÁC THỰC'), findsOneWidget);
        expect(find.text('Chưa xác thực CCCD (Quét ngay)'), findsNothing);
      },
    );

    testWidgets('Thẻ Hoàn thiện hồ sơ hiển thị thanh tiến độ và nút Cập nhật', (
      tester,
    ) async {
      bool openedSettings = false;

      await tester.pumpWidget(
        buildTestWidget(onOpenAccountSettings: () => openedSettings = true),
      );

      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);

      final updateBtn = find.widgetWithText(TextButton, 'Cập nhật');
      await tester.ensureVisible(updateBtn);
      await tester.pumpAndSettle();
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();
      expect(openedSettings, isTrue);
    });

    testWidgets(
      'Avatar có URL hỏng fallback về initials an toàn nhờ errorBuilder',
      (tester) async {
        final profileWithBadAvatar = sampleProfile.copyWith(
          avatarUrl: 'https://invalid-non-existent-url.org/bad_image.png',
        );

        await tester.pumpWidget(buildTestWidget(profile: profileWithBadAvatar));
        await tester.pump();

        expect(find.text('N'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('4. Cô lập & Responsive Tests (320x568 + Text Scale 1.3x)', () {
    Widget wrapWithNarrowScale(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    testWidgets(
      '4.1 Cô lập ProfileHeaderCard ở 320x568 + text scale 1.3x không overflow (chưa eKYC)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithNarrowScale(ProfileHeaderCard(profile: sampleProfile)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.2 Cô lập ProfileHeaderCard ở 320x568 + text scale 1.3x không overflow (đã eKYC)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final verifiedProfile = sampleProfile.copyWith(isCccdVerified: true);
        await tester.pumpWidget(
          wrapWithNarrowScale(ProfileHeaderCard(profile: verifiedProfile)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.3 Cô lập ProfileHeaderCard với chuỗi cực dài (tên, email, ID) ở 320x568 + 1.3x không overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithNarrowScale(ProfileHeaderCard(profile: longDataProfile)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.4 Cô lập ProfileCompletionCard ở 320x568 + text scale 1.3x không overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          wrapWithNarrowScale(ProfileCompletionCard(profile: sampleProfile)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.5 Cô lập ProfileStatsCard ở 320x568 + text scale 1.3x không overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const stats = ProfileOverviewStats(
          totalBookings: 12,
          pendingCount: 5,
          activeCount: 2,
        );
        await tester.pumpWidget(
          wrapWithNarrowScale(const ProfileStatsCard(stats: stats)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.6 Cô lập ProfileActionsCard ở 320x568 + text scale 1.3x không overflow (cả unverified và verified)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Kiểm tra trạng thái CHƯA XÁC THỰC
        await tester.pumpWidget(
          wrapWithNarrowScale(const ProfileActionsCard(isCccdVerified: false)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Kiểm tra trạng thái ĐÃ XÁC THỰC
        await tester.pumpWidget(
          wrapWithNarrowScale(const ProfileActionsCard(isCccdVerified: true)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '4.7 Composition tổng PersonalProfileContent ở 320x568 + text scale 1.3x không overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: PersonalProfileContent(
                  profile: longDataProfile,
                  stats: const ProfileOverviewStats(
                    totalBookings: 8,
                    pendingCount: 4,
                    activeCount: 1,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
