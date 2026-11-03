import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starq_app/app/router/app_routes.dart';
import 'package:starq_app/app/theme/app_theme.dart';
import 'package:starq_app/core/network/api_client.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';
import 'package:starq_app/features/auth/presentation/auth_provider.dart';
import 'package:starq_app/features/providers/vehicle_provider.dart';
import 'package:starq_app/features/providers/booking_provider.dart';
import 'package:starq_app/features/providers/address_provider.dart';
import 'package:starq_app/features/providers/partner_provider.dart';
import 'package:starq_app/features/providers/admin_provider.dart';
import 'package:starq_app/core/storage/local_cache_service.dart';
import 'package:starq_app/features/vehicles/presentation/garage_provider.dart';
import 'package:starq_app/features/booking/presentation/booking_flow_provider.dart';
import 'package:starq_app/core/config/env_config.dart';

import 'package:starq_app/features/providers/rewards_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService().init();
  await EnvConfig.init();
  final apiClient = ApiClient();
  apiClient.configure(); // Using singleton

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(apiClient, SecureStorageService()),
        ),
        ChangeNotifierProvider(
          create: (_) => VehicleProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => GarageProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookingFlowProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => BookingProvider(apiClient)..fetchCatalog(),
        ),
        ChangeNotifierProvider(
          create: (_) => AddressProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => PartnerProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminProvider(apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => RewardsProvider(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return MaterialApp.router(
      routerConfig: createAppRouter(authProvider),
      theme: appTheme,
    );
  }
}