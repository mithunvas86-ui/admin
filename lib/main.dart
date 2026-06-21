import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/shared_orders_service.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_menu_provider.dart';
import 'providers/admin_order_provider.dart';
import 'providers/admin_orders_provider.dart';
import 'providers/customer_info_provider.dart';
import 'theme/app_theme.dart';
import 'router.dart';

/// Admin app entry point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env file not found on web - expected, using fallback credentials
  }
  await SupabaseService.initialize();
  await SharedOrdersService().init();

  runApp(const MPROTIDiningAdminApp());
}

class MPROTIDiningAdminApp extends StatelessWidget {
  const MPROTIDiningAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: adminAuth),
        ChangeNotifierProvider(create: (_) => AdminMenuProvider()),
        ChangeNotifierProvider(create: (_) => AdminOrderProvider()),
        ChangeNotifierProvider(create: (_) => AdminOrdersProvider()),
        ChangeNotifierProvider(create: (_) => CustomerInfoProvider()),
      ],
      child: MaterialApp.router(
        title: 'M·PROTI Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        routerConfig: router,
      ),
    );
  }
}
