import 'package:cloud_functions/cloud_functions.dart';

import 'app_text.dart';

class AppFailure implements Exception {
  AppFailure(this.code);
  final String code;

  @override
  String toString() => code;
}

String explainError(Object error, AppText text) {
  final code = switch (error) {
    FirebaseFunctionsException(:final message) => message ?? '',
    AppFailure(:final code) => code,
    _ => '$error',
  };
  return switch (code) {
    'city-not-found' => text.cityNotFound,
    'legacy-office' => text.legacyOffice,
    'gemini-missing' => text.geminiMissing,
    'file-too-large' => text.fileTooBig,
    'bad-extension' => text.badExtension,
    'pdf-font' => text.saveFailed,
    _ => text.saveFailed,
  };
}
