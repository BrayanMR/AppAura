import 'package:flutter/foundation.dart';

// URL base del servidor Node.js
// Web usa localhost; Android emulador usa 10.0.2.2
const String kBaseUrl = kIsWeb
    ? 'http://localhost:3000'
    : 'http://10.0.2.2:3000';
