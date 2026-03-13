class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Psicólogo
  static const String homePsicologo = '/psicologo/home';
  static const String pacientes = '/psicologo/pacientes';
  static const String citasPsicologo = '/psicologo/citas';
  static const String notasClinicas = '/psicologo/notas';
  static const String foroPsicologo = '/psicologo/foro';

  // Usuario
  static const String homeUsuario = '/usuario/home';
  static const String solicitarCita = '/usuario/cita';
  static const String chat = '/usuario/chat';
  static const String foroUsuario = '/usuario/foro';

  // Compartido
  static const String perfil = '/perfil';
}
