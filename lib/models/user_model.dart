/// Roles disponibles en AurApp
enum UserRole { usuario, psicologo, admin }

class UserModel {
  final String uid;
  final String email;
  final String nombre;
  final String apellido;
  final String documento;
  final String? telefono;
  final DateTime? fechaNacimiento;
  final int? edad;
  final UserRole role;
  final String? imagenUrl;
  final String? reporte;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.apellido,
    required this.documento,
    required this.role,
    this.telefono,
    this.fechaNacimiento,
    this.edad,
    this.imagenUrl,
    this.reporte,
    this.createdAt,
  });

  bool get isPsicolo => role == UserRole.psicologo;
  bool get isUsuario => role == UserRole.usuario;
  bool get isAdmin => role == UserRole.admin;

  String get displayName => '$nombre $apellido';

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      nombre: map['nombre'] as String? ?? '',
      apellido: map['apellido'] as String? ?? '',
      documento: map['documento'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == (map['role'] as String? ?? 'usuario'),
        orElse: () => UserRole.usuario,
      ),
      telefono: map['telefono'] as String?,
      fechaNacimiento: map['fechaNacimiento'] != null
          ? DateTime.tryParse(map['fechaNacimiento'] as String)
          : null,
      edad: map['edad'] as int?,
      imagenUrl: map['imagenUrl'] as String?,
      reporte: map['reporte'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'nombre': nombre,
    'apellido': apellido,
    'documento': documento,
    'role': role.name,
    if (telefono != null) 'telefono': telefono,
    if (fechaNacimiento != null)
      'fechaNacimiento': fechaNacimiento!.toIso8601String(),
    if (edad != null) 'edad': edad,
    if (imagenUrl != null) 'imagenUrl': imagenUrl,
    if (reporte != null) 'reporte': reporte,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  UserModel copyWith({
    String? nombre,
    String? apellido,
    String? documento,
    String? telefono,
    DateTime? fechaNacimiento,
    int? edad,
    String? imagenUrl,
    String? reporte,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      documento: documento ?? this.documento,
      role: role,
      telefono: telefono ?? this.telefono,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      edad: edad ?? this.edad,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      reporte: reporte ?? this.reporte,
      createdAt: createdAt,
    );
  }
}
