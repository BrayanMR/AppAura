class Validators {
  Validators._();

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo es requerido';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Ingresa un correo válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
    if (value.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña';
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es requerido';
    return null;
  }

  static String? nombre(String? value) {
    if (value == null || value.trim().isEmpty) return 'El nombre es requerido';
    if (value.trim().length < 3) return 'Mínimo 3 caracteres';
    return null;
  }

  static String? telefono(String? value) {
    if (value == null || value.isEmpty) return null; // opcional
    final regex = RegExp(r'^\+?[\d\s\-]{7,15}$');
    if (!regex.hasMatch(value)) return 'Número de teléfono inválido';
    return null;
  }

  static String? minLength(
    String? value,
    int min, {
    String field = 'El campo',
  }) {
    if (value == null || value.trim().isEmpty) return '$field es requerido';
    if (value.trim().length < min) {
      return '$field debe tener al menos $min caracteres';
    }
    return null;
  }
}
