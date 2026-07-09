import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ImageStorageService {
  ImageStorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String> uploadFile({
    required File file,
    required String folder,
    required String fileName,
  }) async {
    final extension = _normalizedExtension(file.path);
    final ref = _storage.ref().child('$folder/$fileName$extension');
    final metadata = SettableMetadata(contentType: _contentTypeFor(extension));
    final snapshot = await ref.putFile(file, metadata);
    return snapshot.ref.getDownloadURL();
  }

  String _normalizedExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot < 0) {
      return '.jpg';
    }

    final extension = path.substring(lastDot).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.webp':
        return extension;
      default:
        return '.jpg';
    }
  }

  String _contentTypeFor(String extension) {
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
