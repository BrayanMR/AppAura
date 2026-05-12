import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'config/firebase_initializer.dart';
import 'services/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebaseInitialized();
  await PushNotificationsService.initialize();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const AurApp());
}
