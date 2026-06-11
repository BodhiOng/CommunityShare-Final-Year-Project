import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Cache for storing decoded base64 images to improve performance
class Base64ImageCache {
  // Private constructor to prevent instantiation
  Base64ImageCache._();
  
  // Static cache map to store decoded images
  static final Map<String, Uint8List> _cache = {};
  
  /// Get decoded image bytes from cache
  static Uint8List? getFromCache(String base64String) {
    // Use a hash of the base64 string as the key to save memory
    final String key = base64String.hashCode.toString();
    return _cache[key];
  }
  
  /// Add decoded image bytes to cache
  static void addToCache(String base64String, Uint8List bytes) {
    // Limit cache size to prevent memory issues
    if (_cache.length > 100) {
      _cache.remove(_cache.keys.first);
    }
    final String key = base64String.hashCode.toString();
    _cache[key] = bytes;
  }
  
  /// Clear the entire cache
  static void clearCache() {
    _cache.clear();
  }
}

class ImageUtils {
  /// Checks if a string is a base64 encoded image
  static bool isBase64Image(String source) {
    if (source.isEmpty) return false;
    // Check for data:image prefix which indicates base64
    return source.startsWith('data:image');
  }
  
  /// Checks if a string is a URL
  static bool isUrl(String source) {
    if (source.isEmpty) return false;
    // Check for common URL prefixes
    return source.startsWith('http://') || 
           source.startsWith('https://') || 
           source.startsWith('www.');
  }
  
  /// Decodes a base64 string to bytes
  static Uint8List decodeBase64Image(String base64String) {
    final imageData = base64String.split(',')[1];
    return base64Decode(imageData);
  }

  /// Converts a string to an Image widget, handling both base64 and URLs
  static Widget base64ToImage(String imageSource, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    try {
      // Handle base64 encoded images
      if (isBase64Image(imageSource)) {
        // Check cache first
        final cachedBytes = Base64ImageCache.getFromCache(imageSource);
        
        if (cachedBytes != null) {
          // Use cached image bytes if available
          return Image.memory(
            cachedBytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? _buildErrorWidget();
            },
          );
        }
        
        // Not in cache, decode and cache
        try {
          final bytes = decodeBase64Image(imageSource);
          Base64ImageCache.addToCache(imageSource, bytes);
          
          return Image.memory(
            bytes,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ?? _buildErrorWidget();
            },
          );
        } catch (e) {
          return errorWidget ?? _buildErrorWidget();
        }
      } 
      // Handle URL images
      else if (isUrl(imageSource)) {
        return Image.network(
          imageSource,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _buildErrorWidget();
          },
        );
      } 
      // If it's neither base64 nor a recognized URL, show error widget
      else {
        return errorWidget ?? _buildErrorWidget();
      }
    } catch (e) {
      return errorWidget ?? _buildErrorWidget();
    }
  }

  /// Creates a default error widget when image loading fails
  static Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 50,
        ),
      ),
    );
  }
}

/// Extension on String to easily convert base64 strings to Image widgets
extension ImageStringExtension on String {
  Widget toImage({
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? errorWidget,
  }) {
    return ImageUtils.base64ToImage(
      this,
      fit: fit,
      width: width,
      height: height,
      errorWidget: errorWidget,
    );
  }

  bool get isBase64Image => ImageUtils.isBase64Image(this);
}
