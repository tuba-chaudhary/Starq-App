import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/features/home/home_dashboard_screen.dart';
import 'package:starq_app/features/points/points_repository.dart';
import 'package:starq_app/features/points/rewards_screen.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/providers/rewards_provider.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class StubApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubPointsRepository implements PointsRepository {
  @override
  Future<PointsSummary> getSummary() async => const PointsSummary(balance: 100);

  @override
  Future<List<PointsEntry>> getHistory({int limit = 50}) async => [];

  @override
  Future<String> getReferralCode() async => 'STARQTEST';

  @override
  Future<ReferralSummary> getReferralSummary() async => const ReferralSummary(
        referralCode: 'STARQTEST',
        totalReferrals: 0,
        successfulReferrals: 0,
        pendingReferrals: 0,
        totalPointsEarned: 0,
        referrals: [],
      );
}

void main() {
  setUpAll(() {
    dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://localhost:3000/api/v1'});
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (ByteData? message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          final manifestMap = <Object?, Object?>{
            'assets/images/bike image.png': <Object?>[<Object?, Object?>{}],
            'assets/images/car image.png': <Object?>[<Object?, Object?>{}],
            'assets/images/starq_logo.png': <Object?>[<Object?, Object?>{}],
          };
          return const StandardMessageCodec().encodeMessage(manifestMap);
        }
        if (key == 'AssetManifest.json') {
          return ByteData.view(Uint8List.fromList(utf8.encode(jsonEncode({
            'assets/images/bike image.png': ['assets/images/bike image.png'],
            'assets/images/car image.png': ['assets/images/car image.png'],
            'assets/images/starq_logo.png': ['assets/images/starq_logo.png'],
          }))).buffer);
        }
        return ByteData.view(kTransparentImage.buffer);
      },
    );
  });

  group('Phase 1 - Profile Avatar Navigation Tests', () {
    testWidgets('Tapping profile avatar on HomeDashboardScreen pushes /profile', (tester) async {
      String? pushedRoute;

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeDashboardScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              pushedRoute = '/profile';
              return const Scaffold(body: Text('Profile Screen Target'));
            },
          ),
        ],
      );

      final apiClient = StubApiClient();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<VehicleProvider>(create: (_) => VehicleProvider(apiClient)),
            ChangeNotifierProvider<GarageProvider>(create: (_) => GarageProvider()),
            ChangeNotifierProvider<BookingProvider>(create: (_) => BookingProvider(apiClient)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the CircleAvatar with person icon in the header
      final avatarFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byWidgetPredicate(
          (widget) => widget is CircleAvatar && widget.child is Icon && (widget.child as Icon).icon == Icons.person,
        ),
      );

      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(pushedRoute, '/profile');
      expect(find.text('Profile Screen Target'), findsOneWidget);
    });

    testWidgets('Tapping profile avatar on RewardsScreen pushes /profile', (tester) async {
      String? pushedRoute;

      final router = GoRouter(
        initialLocation: '/rewards',
        routes: [
          GoRoute(
            path: '/rewards',
            builder: (context, state) => const RewardsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) {
              pushedRoute = '/profile';
              return const Scaffold(body: Text('Profile Screen Target'));
            },
          ),
        ],
      );

      final rewardsRepo = StubPointsRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<RewardsProvider>(create: (_) => RewardsProvider(rewardsRepo)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the CircleAvatar with person icon in the header
      final avatarFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byWidgetPredicate(
          (widget) => widget is CircleAvatar && widget.child is Icon && (widget.child as Icon).icon == Icons.person,
        ),
      );

      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      expect(pushedRoute, '/profile');
      expect(find.text('Profile Screen Target'), findsOneWidget);
    });
  });
}
