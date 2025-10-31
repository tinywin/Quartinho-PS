import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_service.dart';
import 'core/navigation.dart';
import 'core/constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Background handler registration
  FirebaseMessaging.onBackgroundMessage(PushService.backgroundHandler);
  final prefs = await SharedPreferences.getInstance();
  final alreadyReset = prefs.getBool('firstRunResetPerformed') ?? false;
  if (!alreadyReset) {
    await prefs.clear();
    await prefs.setBool('firstRunResetPerformed', true);
  }
  // register device token if user already logged in
  final token = prefs.getString('jwt_token');
  await PushService.init();
  if (token != null) {
    // register + listeners
    await PushService.registerDevice(baseUrl: backendHost, jwtToken: token);
    PushService.configureListeners(jwtToken: token);
  }
  runApp(const QuartinhoApp());
}

class QuartinhoApp extends StatelessWidget {
  const QuartinhoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quartinho',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
