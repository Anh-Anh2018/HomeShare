import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/auth/services/role_resolver.dart';

void main() {
  group('1. Role Normalization (RoleResolver.normalizeRole)', () {
    test(
      'Chuẩn hóa đúng các alias của Renter: renter, tenant, nguoiDung, 1',
      () {
        expect(
          RoleResolver.normalizeRole('renter'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('Renter'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('RENTER'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole(' tenant '),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('Tenant'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('nguoiDung'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('nguoi_dung'),
          equals(RoleResolver.renter),
        );
        expect(
          RoleResolver.normalizeRole('NGUOIDUNG'),
          equals(RoleResolver.renter),
        );
        expect(RoleResolver.normalizeRole('1'), equals(RoleResolver.renter));
        expect(RoleResolver.normalizeRole(1), equals(RoleResolver.renter));
      },
    );

    test('Chuẩn hóa đúng các alias của Host: host, landlord, chutro, 2', () {
      expect(RoleResolver.normalizeRole('host'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('Host'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('HOST'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('landlord'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('LandLord'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('chutro'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('chu_tro'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole(' ChuTro '), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole('2'), equals(RoleResolver.host));
      expect(RoleResolver.normalizeRole(2), equals(RoleResolver.host));
    });

    test(
      'Chuẩn hóa đúng các alias của Admin: admin, administrator, quantri, 3',
      () {
        expect(RoleResolver.normalizeRole('admin'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole('Admin'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole('ADMIN'), equals(RoleResolver.admin));
        expect(
          RoleResolver.normalizeRole('administrator'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('Administrator'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('quantri'),
          equals(RoleResolver.admin),
        );
        expect(
          RoleResolver.normalizeRole('quan_tri'),
          equals(RoleResolver.admin),
        );
        expect(RoleResolver.normalizeRole('3'), equals(RoleResolver.admin));
        expect(RoleResolver.normalizeRole(3), equals(RoleResolver.admin));
      },
    );

    test(
      'Tuyệt đối không ép host/admin hoặc role sai thành renter (Fail-closed)',
      () {
        expect(
          RoleResolver.normalizeRole('host'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('admin'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('chutro'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(
          RoleResolver.normalizeRole('landlord'),
          isNot(equals(RoleResolver.renter)),
        );
        expect(RoleResolver.normalizeRole('unknown_role'), isNull);
        expect(RoleResolver.normalizeRole('guest'), isNull);
        expect(RoleResolver.normalizeRole('hacker'), isNull);
        expect(RoleResolver.normalizeRole(''), isNull);
        expect(RoleResolver.normalizeRole('   '), isNull);
        expect(RoleResolver.normalizeRole(null), isNull);
        expect(RoleResolver.normalizeRole(999), isNull);
      },
    );
  });

  group('2. Firestore Map Extraction (RoleResolver.extractRoleFromMap)', () {
    test('Đọc thành công từ khóa `role`', () {
      expect(
        RoleResolver.extractRoleFromMap({'role': 'renter'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'role': 'host'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'role': 'admin'}),
        equals(RoleResolver.admin),
      );
    });

    test('Đọc thành công từ khóa tiếng Việt `vaiTro`', () {
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'tenant'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'chutro'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'admin'}),
        equals(RoleResolver.admin),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'nguoiDung'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro': 'landlord'}),
        equals(RoleResolver.host),
      );
    });

    test('Đọc thành công từ khóa định danh số hoặc chuỗi `vaiTro_id`', () {
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 1}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': '1'}),
        equals(RoleResolver.renter),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 2}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': '2'}),
        equals(RoleResolver.host),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 3}),
        equals(RoleResolver.admin),
      );
      expect(
        RoleResolver.extractRoleFromMap({'vaiTro_id': 'host'}),
        equals(RoleResolver.host),
      );
    });

    test('Tuân thủ thứ tự ưu tiên: role > vaiTro > vaiTro_id', () {
      // role có giá trị -> dùng role
      final mapWithAll = {'role': 'host', 'vaiTro': 'renter', 'vaiTro_id': 1};
      expect(
        RoleResolver.extractRoleFromMap(mapWithAll),
        equals(RoleResolver.host),
      );

      // role rỗng -> kiểm tra vaiTro
      final mapEmptyRole = {'role': '', 'vaiTro': 'admin', 'vaiTro_id': 2};
      expect(
        RoleResolver.extractRoleFromMap(mapEmptyRole),
        equals(RoleResolver.admin),
      );

      // role & vaiTro rỗng -> kiểm tra vaiTro_id
      final mapOnlyId = {'role': null, 'vaiTro': '', 'vaiTro_id': 2};
      expect(
        RoleResolver.extractRoleFromMap(mapOnlyId),
        equals(RoleResolver.host),
      );
    });

    test(
      'Dữ liệu không hợp lệ hoặc thiếu khóa phải trả về null (Không fallback về renter)',
      () {
        expect(RoleResolver.extractRoleFromMap({}), isNull);
        expect(RoleResolver.extractRoleFromMap(null), isNull);
        expect(RoleResolver.extractRoleFromMap({'hoTen': 'Test'}), isNull);
        expect(RoleResolver.extractRoleFromMap({'role': 'invalid'}), isNull);
        expect(
          RoleResolver.extractRoleFromMap({'vaiTro': 'unsupported'}),
          isNull,
        );
        expect(RoleResolver.extractRoleFromMap({'vaiTro_id': 999}), isNull);
      },
    );
  });

  group('3. Pure Auth Destination Resolution (resolveAuthDestination)', () {
    final validRenterProfile = UserProfile(
      uid: 'u_renter',
      email: 'renter@test.vn',
      displayName: 'Nguyễn Renter',
      phoneNumber: '0901111111',
      role: 'renter',
    );

    final validHostProfile = UserProfile(
      uid: 'u_host',
      email: 'host@test.vn',
      displayName: 'Trần Host',
      phoneNumber: '0902222222',
      role: 'host',
    );

    final validAdminProfile = UserProfile(
      uid: 'u_admin',
      email: 'admin@test.vn',
      displayName: 'Lê Admin',
      phoneNumber: '0903333333',
      role: 'admin',
    );

    test('Chưa xác thực -> điều hướng unauthenticated', () {
      final dest = resolveAuthDestination(isAuthenticated: false, role: null);
      expect(dest, equals(AuthDestination.unauthenticated));
    });

    test('Đang tải profile -> điều hướng loading', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        isProfileLoading: true,
        role: null,
      );
      expect(dest, equals(AuthDestination.loading));
    });

    test('Gặp lỗi tải profile -> điều hướng error', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        error: 'Firestore connection failure',
        role: null,
      );
      expect(dest, equals(AuthDestination.error));
    });

    test('Đã đăng nhập và role renter -> điều hướng renter', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        role: validRenterProfile.role,
      );
      expect(dest, equals(AuthDestination.renter));
    });

    test('Đã đăng nhập và role host -> điều hướng host (Không ép renter)', () {
      final dest = resolveAuthDestination(
        isAuthenticated: true,
        role: validHostProfile.role,
      );
      expect(dest, equals(AuthDestination.host));
    });

    test(
      'Đã đăng nhập và role admin -> điều hướng admin (Không ép renter)',
      () {
        final dest = resolveAuthDestination(
          isAuthenticated: true,
          role: validAdminProfile.role,
        );
        expect(dest, equals(AuthDestination.admin));
      },
    );

    test(
      'Role không hợp lệ hoặc null -> điều hướng invalidRole (Fail-closed)',
      () {
        final nullRoleDest = resolveAuthDestination(
          isAuthenticated: true,
          role: null,
        );
        expect(nullRoleDest, equals(AuthDestination.invalidRole));

        final invalidProfile = UserProfile(
          uid: 'u_invalid',
          email: 'invalid@test.vn',
          displayName: 'Invalid User',
          phoneNumber: '0904444444',
          role: 'invalid_role',
        );
        final invalidDest = resolveAuthDestination(
          isAuthenticated: true,
          role: invalidProfile.role,
        );
        expect(invalidDest, equals(AuthDestination.invalidRole));

        final emptyRoleProfile = UserProfile(
          uid: 'u_empty',
          email: 'empty@test.vn',
          displayName: 'Empty Role',
          phoneNumber: '0905555555',
          role: '',
        );
        final emptyDest = resolveAuthDestination(
          isAuthenticated: true,
          role: emptyRoleProfile.role,
        );
        expect(emptyDest, equals(AuthDestination.invalidRole));
      },
    );
  });

  group('4. UserProfile.fromMap Integration Tests', () {
    test('UserProfile.fromMap phân giải đúng role host và cờ isHost', () {
      final hostData = {
        'hoTen': 'Chủ Nhà Trọ',
        'email': 'chunha@gmail.com',
        'soDienThoai': '0981234567',
        'vaiTro': 'chutro',
      };
      final profile = UserProfile.fromMap(hostData, 'host_101');
      expect(profile.role, equals('host'));
      expect(profile.isHost, isTrue);
      expect(profile.isRenter, isFalse);
      expect(profile.isAdmin, isFalse);
      expect(profile.hasValidRole, isTrue);
    });

    test('UserProfile.fromMap phân giải đúng role admin và cờ isAdmin', () {
      final adminData = {
        'hoTen': 'Quản Trị Viên',
        'email': 'admin@homeshare.vn',
        'soDienThoai': '0989999999',
        'role': 'admin',
      };
      final profile = UserProfile.fromMap(adminData, 'admin_001');
      expect(profile.role, equals('admin'));
      expect(profile.isAdmin, isTrue);
      expect(profile.isHost, isFalse);
      expect(profile.isRenter, isFalse);
      expect(profile.hasValidRole, isTrue);
    });

    test(
      'UserProfile.fromMap phân giải đúng role renter khi có alias tenant / nguoiDung',
      () {
        final tenantData = {
          'hoTen': 'Người Thuê Trọ',
          'email': 'tenant@gmail.com',
          'soDienThoai': '0912345678',
          'vaiTro': 'tenant',
        };
        final profile = UserProfile.fromMap(tenantData, 'renter_202');
        expect(profile.role, equals('renter'));
        expect(profile.isRenter, isTrue);
        expect(profile.isHost, isFalse);
        expect(profile.isAdmin, isFalse);
        expect(profile.hasValidRole, isTrue);
      },
    );

    test(
      'UserProfile.fromMap KHÔNG tự ý ép về renter khi dữ liệu thiếu role (Fail-closed)',
      () {
        final dataWithoutRole = {
          'hoTen': 'Người Dùng Chưa Xác Định',
          'email': 'unknown@gmail.com',
          'soDienThoai': '0933333333',
        };
        final profile = UserProfile.fromMap(dataWithoutRole, 'unknown_303');
        expect(profile.role, equals(''));
        expect(profile.hasValidRole, isFalse);
        expect(profile.isRenter, isFalse);
        expect(profile.isHost, isFalse);
        expect(profile.isAdmin, isFalse);
      },
    );

    test(
      'UserProfile.fromMap KHÔNG tự ý ép về renter khi role không hợp lệ (Fail-closed)',
      () {
        final dataWithInvalidRole = {
          'hoTen': 'Người Dùng Hack',
          'email': 'hacker@test.com',
          'soDienThoai': '0944444444',
          'role': 'super_admin_hacker',
        };
        final profile = UserProfile.fromMap(dataWithInvalidRole, 'hacker_404');
        expect(profile.role, equals(''));
        expect(profile.hasValidRole, isFalse);
        expect(profile.isRenter, isFalse);
      },
    );
  });

  group('5. Fail-closed Serialization & toMap Regression Tests', () {
    test('toMap sinh vaiTro_id = 1 cho renter, 2 cho host, 3 cho admin', () {
      final renter = UserProfile(
        uid: 'u_renter_map',
        email: 'renter@test.vn',
        displayName: 'Nguyễn Renter',
        phoneNumber: '0901111111',
        role: 'renter',
      );
      final host = UserProfile(
        uid: 'u_host_map',
        email: 'host@test.vn',
        displayName: 'Trần Host',
        phoneNumber: '0902222222',
        role: 'host',
      );
      final admin = UserProfile(
        uid: 'u_admin_map',
        email: 'admin@test.vn',
        displayName: 'Lê Admin',
        phoneNumber: '0903333333',
        role: 'admin',
      );

      final renterMap = renter.toMap();
      final hostMap = host.toMap();
      final adminMap = admin.toMap();

      expect(renterMap['vaiTro_id'], equals(1));
      expect(hostMap['vaiTro_id'], equals(2));
      expect(adminMap['vaiTro_id'], equals(3));
    });

    test(
      'toMap KHÔNG sinh vaiTro_id (omit) khi role invalid hoặc rỗng (Không sinh id=1)',
      () {
        final invalidProfile = UserProfile(
          uid: 'u_invalid_map',
          email: 'invalid@test.vn',
          displayName: 'Invalid User',
          phoneNumber: '0904444444',
          role: 'hacker_role',
        );
        final emptyRoleProfile = UserProfile(
          uid: 'u_empty_map',
          email: 'empty@test.vn',
          displayName: 'Empty Role User',
          phoneNumber: '0905555555',
          role: '',
        );

        final invalidMap = invalidProfile.toMap();
        final emptyMap = emptyRoleProfile.toMap();

        // Key vaiTro_id hoàn toàn không xuất hiện (omitted) và không sinh id=1
        expect(invalidMap.containsKey('vaiTro_id'), isFalse);
        expect(invalidMap['vaiTro_id'], isNull);
        expect(invalidMap['vaiTro_id'], isNot(equals(1)));

        expect(emptyMap.containsKey('vaiTro_id'), isFalse);
        expect(emptyMap['vaiTro_id'], isNull);
        expect(emptyMap['vaiTro_id'], isNot(equals(1)));
      },
    );

    test(
      'Round-trip serialization: toMap -> fromMap bảo toàn tính Fail-closed, không biến invalid thành renter',
      () {
        final invalidProfile = UserProfile(
          uid: 'u_rt_invalid',
          email: 'rt_invalid@test.vn',
          displayName: 'RoundTrip Invalid',
          phoneNumber: '0906666666',
          role: 'invalid_role_xyz',
        );

        final serializedMap = invalidProfile.toMap();
        expect(serializedMap.containsKey('vaiTro_id'), isFalse);

        final reconstructed = UserProfile.fromMap(
          serializedMap,
          'u_rt_invalid',
        );
        expect(reconstructed.role, equals(''));
        expect(reconstructed.hasValidRole, isFalse);
        expect(reconstructed.isRenter, isFalse);
        expect(reconstructed.isHost, isFalse);
        expect(reconstructed.isAdmin, isFalse);
      },
    );

    test(
      'Round-trip serialization: toMap -> fromMap bảo toàn chính xác vai trò hợp lệ',
      () {
        final renter = UserProfile(
          uid: 'u_rt_renter',
          email: 'renter@test.vn',
          displayName: 'Renter RT',
          phoneNumber: '0907777777',
          role: 'renter',
        );
        final host = UserProfile(
          uid: 'u_rt_host',
          email: 'host@test.vn',
          displayName: 'Host RT',
          phoneNumber: '0908888888',
          role: 'host',
        );
        final admin = UserProfile(
          uid: 'u_rt_admin',
          email: 'admin@test.vn',
          displayName: 'Admin RT',
          phoneNumber: '0909999999',
          role: 'admin',
        );

        final reconstructedRenter = UserProfile.fromMap(
          renter.toMap(),
          'u_rt_renter',
        );
        final reconstructedHost = UserProfile.fromMap(
          host.toMap(),
          'u_rt_host',
        );
        final reconstructedAdmin = UserProfile.fromMap(
          admin.toMap(),
          'u_rt_admin',
        );

        expect(reconstructedRenter.role, equals('renter'));
        expect(reconstructedRenter.isRenter, isTrue);

        expect(reconstructedHost.role, equals('host'));
        expect(reconstructedHost.isHost, isTrue);

        expect(reconstructedAdmin.role, equals('admin'));
        expect(reconstructedAdmin.isAdmin, isTrue);
      },
    );
  });
}
