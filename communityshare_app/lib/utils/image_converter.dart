import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ImageConverter {
  /// Convert a File to base64 string with data URI scheme
  static Future<String> fileToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Add data URI scheme prefix based on file extension
      final extension = file.path.split('.').last.toLowerCase();
      String mimeType;
      
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg'; // Default to JPEG
      }
      
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error converting image to base64: $e');
      }
      return '';
    }
  }
  
  /// Convert a base64 string to Uint8List
  static Uint8List base64ToBytes(String base64String) {
    try {
      // Remove data URI scheme if present
      final String sanitized = base64String.contains(',') 
          ? base64String.split(',')[1] 
          : base64String;
      
      return base64Decode(sanitized);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error converting base64 to bytes: $e');
      }
      return Uint8List(0);
    }
  }
}
