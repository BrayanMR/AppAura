import 'screens/auth/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/autorizacion_padres_screen.dart';
import 'screens/psicologo/home_psicologo_screen.dart';
import 'screens/psicologo/crear_nota_clinica_screen.dart';
import 'screens/usuario/home_usuario_screen.dart';
import 'screens/usuario/chat_screen.dart';
import 'screens/usuario/solicitar_cita_screen.dart';
import 'screens/shared/perfil_screen.dart';
import 'services/session_service.dart';

class AurApp extends StatelessWidget {
  const AurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SessionService.navigatorKey,
      title: 'AurApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [Locale('es', 'ES'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.register: (_) => const RegisterScreen(),
        AppRoutes.autorizacionPadres: (_) => const AutorizacionPadresScreen(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.homePsicologo: (_) => const HomePsicologoScreen(),
        AppRoutes.crearNotaClinica: (_) => const CrearNotaClinicaScreen(),
        AppRoutes.homeUsuario: (_) => const HomeUsuarioScreen(),
        AppRoutes.chat: (_) => const ChatScreen(),
        AppRoutes.solicitarCita: (_) => const SolicitarCitaScreen(),
        AppRoutes.perfil: (_) => const PerfilScreen(),
      },
    );
  }
}
