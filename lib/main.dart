import 'package:flutter/material.dart';
import 'app.dart';
import 'config/firebase_initializer.dart';
import 'services/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebaseInitialized();
  await PushNotificationsService.initialize();

  runApp(const AurApp());
}
