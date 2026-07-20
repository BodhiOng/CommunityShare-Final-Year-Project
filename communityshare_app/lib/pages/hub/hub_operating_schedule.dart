import 'package:flutter/material.dart';

bool hasAnyOperatingScheduleInput({
  required String startDay,
  required String endDay,
  required TimeOfDay? startTime,
  required TimeOfDay? endTime,
}) {
  return startDay.trim().isNotEmpty ||
      endDay.trim().isNotEmpty ||
      startTime != null ||
      endTime != null;
}

bool hasCompleteOperatingSchedule({
  required String startDay,
  required String endDay,
  required TimeOfDay? startTime,
  required TimeOfDay? endTime,
}) {
  return startDay.trim().isNotEmpty &&
      endDay.trim().isNotEmpty &&
      startTime != null &&
      endTime != null;
}

String formatCommunityHubOperatingHours(Map<String, dynamic> data) {
  final startDay = readScheduleString(data['operatingStartDay']);
  final endDay = readScheduleString(data['operatingEndDay']);
  final startTime = formatStoredOperatingTime(data['operatingStartTime']);
  final endTime = formatStoredOperatingTime(data['operatingEndTime']);

  if (startDay.isEmpty ||
      endDay.isEmpty ||
      startTime.isEmpty ||
      endTime.isEmpty) {
    return '';
  }

  return '$startDay-$endDay, $startTime - $endTime';
}

String readScheduleString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
  return fallback;
}

String formatStoredOperatingTime(dynamic value) {
  final raw = readScheduleString(value);
  if (raw.isEmpty) {
    return '';
  }

  final parts = raw.split(':');
  if (parts.length >= 2) {
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9].*'), ''));
    if (hour != null && minute != null) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    }
  }

  return raw;
}
