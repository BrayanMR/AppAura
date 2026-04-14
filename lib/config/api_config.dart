// URL base del backend.
// Puedes sobrescribirla al ejecutar con:
// flutter run --dart-define=API_BASE_URL=http://TU_IP_LOCAL:3000
const String _defaultProdBaseUrl = 'https://backend-aura-d0or.onrender.com';

const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultProdBaseUrl,
);

// Referencia útil para debug local en emulador Android:
const String kAndroidEmulatorLocalBaseUrl = 'http://10.0.2.2:3000';
