import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routes/app_routes.dart';

class SessionService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String tokenKey = 'auth_token';
  static const Duration _doubleBackDuration = Duration(seconds: 2);
  static const int _backPressExitThreshold = 3;
  static Timer? _tokenExpiryTimer;
  static Timer? _doubleBackTimer;
  static bool _logoutInProgress = false;
  static bool _backPressArmed = false;
  static int _backPressCount = 0;

  static Future<void> clearStoredSession() async {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = null;
    _doubleBackTimer?.cancel();
    _doubleBackTimer = null;
    _backPressArmed = false;
    _backPressCount = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  static Future<void> scheduleTokenExpiryLogout(String token) async {
    _tokenExpiryTimer?.cancel();
    _tokenExpiryTimer = null;

    final expiration = _decodeExpiration(token);
    if (expiration == null) return;

    final remaining = expiration.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      await forceLogout(redirect: true);
      return;
    }

    _tokenExpiryTimer = Timer(remaining, () {
      unawaited(forceLogout(redirect: true));
    });
  }

  static Future<void> forceLogout({bool redirect = true}) async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    try {
      await clearStoredSession();
      await FirebaseAuth.instance.signOut();

      if (redirect) {
        final navigator = navigatorKey.currentState;
        if (navigator != null) {
          navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
      }
    } finally {
      _logoutInProgress = false;
    }
  }

  static Future<bool> handleBackPressToExit() async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    _backPressCount += 1;

    if (_backPressCount >= _backPressExitThreshold) {
      _doubleBackTimer?.cancel();
      _doubleBackTimer = null;
      _backPressArmed = false;
      _backPressCount = 0;
      await SystemNavigator.pop();
      return true;
    }

    _doubleBackTimer?.cancel();
    _backPressArmed = true;
    _doubleBackTimer = Timer(_doubleBackDuration, () {
      _backPressArmed = false;
      _doubleBackTimer = null;
      _backPressCount = 0;
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Pulsa atrás 3 veces para salir'),
          duration: Duration(seconds: 2),
        ),
      );
    return true;
  }

  static DateTime? _decodeExpiration(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      final exp = decoded is Map ? decoded['exp'] : null;
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            parsed * 1000,
            isUtc: true,
          );
        }
      }
    } catch (_) {}

    return null;
  }
}
