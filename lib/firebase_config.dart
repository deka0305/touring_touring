import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Jembatan ke `firebase_options.dart` yang dibangkitkan flutterfire.
///
/// Berkas itu melempar [UnsupportedError] untuk platform yang belum
/// dikonfigurasi — sekarang hanya Android yang sudah. Di sini kesalahan itu
/// diubah jadi null supaya [Cloud] jatuh ke mode lokal dan app tetap terbuka
/// di web maupun desktop, bukan gagal jalan.
///
/// Sengaja dipisah dari `firebase_options.dart`: berkas itu ditimpa setiap kali
/// `flutterfire configure` dijalankan lagi.
FirebaseOptions? get defaultOptions {
  try {
    return DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    return null;
  }
}
