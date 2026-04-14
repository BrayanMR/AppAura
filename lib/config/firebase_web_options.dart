import 'package:firebase_core/firebase_core.dart';

/// Configuración de Firebase para Web.
///
/// Puedes sobrescribir estos valores en build/run usando --dart-define.
/// Ejemplo:
/// flutter run -d chrome \
///   --dart-define=FIREBASE_WEB_API_KEY=... \
///   --dart-define=FIREBASE_WEB_APP_ID=...
class FirebaseWebOptions {
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'AIzaSyBY0gw63NwnFu16tt90-qQ4MP8tMYqcsik',
  );

  static const String _appId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
    defaultValue: '1:436823356091:web:406b901367e080001c6f9e',
  );

  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
    defaultValue: '436823356091',
  );

  static const String _projectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
    defaultValue: 'aura-d3e5f',
  );

  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
    defaultValue: 'aura-d3e5f.firebaseapp.com',
  );

  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
    defaultValue: 'aura-d3e5f.firebasestorage.app',
  );

  static FirebaseOptions get current {
    return const FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: _authDomain,
      storageBucket: _storageBucket,
    );
  }

  static bool get hasPlaceholderAppId =>
      _appId.contains('REEMPLAZA_ESTE_APP_ID');
}
