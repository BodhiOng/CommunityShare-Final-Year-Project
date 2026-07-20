import 'package:communityshare_app/pages/hub/hub_operating_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hub_manage_profile_page.dart operating schedule rules', () {
    test('TC4 incomplete operating schedule is detected', () {
      final hasAny = hasAnyOperatingScheduleInput(
        startDay: 'Monday',
        endDay: '',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0),
      );
      final hasComplete = hasCompleteOperatingSchedule(
        startDay: 'Monday',
        endDay: '',
        startTime: const TimeOfDay(hour: 10, minute: 0),
        endTime: const TimeOfDay(hour: 22, minute: 0),
      );

      expect(hasAny, isTrue);
      expect(hasComplete, isFalse);
    });

    test('TC5 complete operating schedule is accepted', () {
      expect(
        hasCompleteOperatingSchedule(
          startDay: 'Monday',
          endDay: 'Friday',
          startTime: const TimeOfDay(hour: 10, minute: 0),
          endTime: const TimeOfDay(hour: 22, minute: 0),
        ),
        isTrue,
      );
    });
  });

  group('RecipientBrowseCommunityHubsPage operating hours formatting', () {
    test(
      'TC4 complete operating hour fields are displayed from four fields',
      () {
        final output = formatCommunityHubOperatingHours({
          'operatingStartDay': 'Monday',
          'operatingEndDay': 'Friday',
          'operatingStartTime': '10:00',
          'operatingEndTime': '22:00',
        });

        expect(output, 'Monday-Friday, 10:00 AM - 10:00 PM');
      },
    );

    test('TC5 incomplete operating hour fields return empty display value', () {
      final output = formatCommunityHubOperatingHours({
        'operatingStartDay': 'Monday',
        'operatingEndDay': 'Friday',
        'operatingStartTime': '10:00',
      });

      expect(output, isEmpty);
    });
  });
}
