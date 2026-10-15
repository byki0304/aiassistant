import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase web client configuration for aiassistant-49b02.
/// The client key is restricted by Auth, Firestore, and Storage rules.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('aiAssistant is a web app.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyALKoGntuznsGgWe2E4uRk3B4sqeIDYanI',
    appId: '1:148982182247:web:e6249f46620c9699313fc2',
    messagingSenderId: '148982182247',
    projectId: 'aiassistant-49b02',
    authDomain: 'aiassistant-49b02.firebaseapp.com',
    storageBucket: 'aiassistant-49b02.firebasestorage.app',
    measurementId: 'G-ZJJPH7NG99',
  );
}
