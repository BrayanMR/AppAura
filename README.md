## Cómo correr el proyecto

### Backend
```bash
cd backend
npm install
npm run dev        # desarrollo con nodemon
# npm start        # producción
```

### Flutter
```bash
flutter pub get
flutter run        # emulador Android: usa http://10.0.2.2:3000
```

## Paleta de colores

| Nombre           | Color     | Hex         | Uso                        |
|------------------|-----------|-------------|----------------------------|
| `primary`        | Índigo    | `#6366F1`   | Buttons, links, focus      |
| `secondary`      | Cyan      | `#06B6D4`   | Acentos, usuario           |
| `rolePsicologo`  | Violeta   | `#8B5CF6`   | Badges y UI del psicólogo  |
| `roleUsuario`    | Cyan      | `#06B6D4`   | Badges y UI del usuario    |
| `background`     | Oscuro    | `#0A0A1A`   | Fondo global               |
| `card`           | Oscuro    | `#1C1C3A`   | Tarjetas y campos          |
| `success`        | Verde     | `#22C55E`   | Confirmaciones             |
| `error`          | Rojo      | `#EF4444`   | Errores                    |
| `warning`        | Ámbar     | `#F59E0B`   | Advertencias               |


## Estructura de carpetas Flutter (`lib/`)

```
lib/
├── main.dart                        # Punto de entrada
├── app.dart                         # MaterialApp + rutas + tema
│
├── config/
│   └── api_config.dart              # URL base del backend
│
├── core/
│   ├── theme/
│   │   ├── app_colors.dart          # Paleta de colores de la app
│   │   ├── app_text_styles.dart     # Tipografía (Poppins)
│   │   └── app_theme.dart           # Tema oscuro global (Material 3)
│   └── utils/
│       └── validators.dart          # Validaciones de formularios
│
├── models/
│   ├── user_model.dart              # Modelo de usuario (roles)
│   ├── cita_model.dart              # Modelo de cita médica
│   ├── nota_clinica_model.dart      # Modelo de nota clínica
│   └── post_foro_model.dart         # Modelo de post del foro
│
├── routes/
│   └── app_routes.dart              # Constantes de rutas de navegación
│
├── services/
│   ├── api_client.dart              # Cliente HTTP base (maneja Bearer Token)
│   ├── auth_service.dart            # /api/auth/*
│   ├── firestore_service.dart       # /api/firestore/*
│   ├── rtdb_service.dart            # /api/rtdb/*
│   ├── messaging_service.dart       # /api/messaging/*
│   └── storage_service.dart         # (desactivado hasta integrar Cloudinary)
│
├── widgets/
│   ├── custom_button.dart           # Botón reutilizable (normal / outlined)
│   └── custom_text_field.dart       # Campo de texto reutilizable
│
└── screens/
    ├── splash/
    │   └── splash_screen.dart       # Animación inicial + verificación de sesión
    ├── auth/
    │   ├── login_screen.dart        # Pantalla de inicio de sesión
    │   └── register_screen.dart     # Pantalla de registro (solo usuarios)
    ├── psicologo/
    │   ├── home_psicologo_screen.dart    # Dashboard + BottomNavBar del psicólogo
    │   ├── pacientes_screen.dart         # Lista de pacientes asignados
    │   ├── citas_psicologo_screen.dart   # Gestión de citas
    │   ├── notas_clinicas_screen.dart    # Notas clínicas por paciente
    │   └── foro_psicologo_screen.dart    # Publicar en el foro
    ├── usuario/
    │   ├── home_usuario_screen.dart      # Dashboard + BottomNavBar del usuario
    │   ├── solicitar_cita_screen.dart    # Solicitar cita con un psicólogo
    │   ├── chat_screen.dart              # Chat con psicólogo (RTDB)
    │   └── foro_usuario_screen.dart      # Leer/participar en foro
    └── shared/
        └── perfil_screen.dart            # Editar perfil (ambos roles)
```
