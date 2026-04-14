import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_web_options.dart';

/// Ensures Firebase is initialized exactly once before any Firebase service use.
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;

  final isDesktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  if (kIsWeb || isDesktop) {
    await Firebase.initializeApp(options: FirebaseWebOptions.current);
    return;
  }

  await Firebase.initializeApp();
}
