import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/state_widgets.dart';

const List<String> _weekdayOptions = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class ManageHubProfilePage extends StatefulWidget {
  const ManageHubProfilePage({super.key});

  @override
  State<ManageHubProfilePage> createState() => _ManageHubProfilePageState();
}

class _ManageHubProfilePageState extends State<ManageHubProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _hubNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _operatingStartTimeController =
      TextEditingController();
  final TextEditingController _operatingEndTimeController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  String _status = 'active';
  String _hubDocId = '';
  String _hubId = '';
  String _legacyOperatingHours = '';
  String _operatingStartDay = '';
  String _operatingEndDay = '';
  TimeOfDay? _operatingStartTime;
  TimeOfDay? _operatingEndTime;

  @override
  void initState() {
    super.initState();
    _loadHubProfile();
  }

  @override
  void dispose() {
    _hubNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _operatingStartTimeController.dispose();
    _operatingEndTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadHubProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore
          .collection('COMMUNITY_HUB')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final doc = snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
      final data = doc?.data() ?? const <String, dynamic>{};

      _hubNameController.text = _stringValue(data['hubName']);
      _addressController.text = _stringValue(data['address']);
      _contactNumberController.text = _stringValue(data['contactNumber']);
      _legacyOperatingHours = _stringValue(data['operatingHours']);
      _operatingStartDay = _stringValue(data['operatingStartDay']);
      _operatingEndDay = _stringValue(data['operatingEndDay']);
      _operatingStartTime = _readTimeOfDay(data['operatingStartTime']);
      _operatingEndTime = _readTimeOfDay(data['operatingEndTime']);

      if (!mounted) {
        return;
      }

      _syncOperatingScheduleControllers();

      setState(() {
        _hubDocId = doc?.id ?? userId;
        _hubId = _stringValue(data['hubId'], fallback: doc?.id ?? userId);
        _status = _stringValue(data['status'], fallback: 'active');
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load hub profile: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveHubProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final docId = _hubDocId.isNotEmpty ? _hubDocId : userId;
      final hubId = _hubId.isNotEmpty ? _hubId : docId;
      final hasAnyScheduleInput = _hasAnyOperatingScheduleInput();
      final hasCompleteSchedule = _hasCompleteOperatingSchedule();

      if (hasAnyScheduleInput && !hasCompleteSchedule) {
        throw Exception(
          'Fill start day, end day, start time, and end time together.',
        );
      }

      final operatingHours =
          hasCompleteSchedule
              ? _formatOperatingHoursRange(context)
              : _legacyOperatingHours;

      await _firestore.collection('COMMUNITY_HUB').doc(docId).set({
        'hubId': hubId,
        'userId': userId,
        'hubName': _hubNameController.text.trim(),
        'address': _addressController.text.trim(),
        'operatingHours': operatingHours,
        'operatingStartDay': _operatingStartDay,
        'operatingEndDay': _operatingEndDay,
        'operatingStartTime': _operatingStartTime == null
            ? null
            : _formatTimeForStorage(_operatingStartTime!),
        'operatingEndTime': _operatingEndTime == null
            ? null
            : _formatTimeForStorage(_operatingEndTime!),
        'contactNumber': _contactNumberController.text.trim(),
        'status': _status,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _hubDocId = docId;
        _hubId = hubId;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hub profile updated.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save hub profile: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading hub profile...');
    }

    if (_errorMessage.isNotEmpty) {
      return AppErrorState(
        message: _errorMessage,
        onRetry: _loadHubProfile,
      );
    }

    final hubLabel = _hubNameController.text.trim().isNotEmpty
        ? _hubNameController.text.trim()
        : 'Community Hub';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HubProfileHero(
          hubName: hubLabel,
          hubId: _hubId.isNotEmpty ? _hubId : _hubDocId,
          status: _status,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Hub Details',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Update the community hub information that donors and recipients rely on during handover.',
                    style: TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _hubNameController,
                    label: 'Hub Name',
                    hint: 'Enter your hub name',
                    prefixIcon: const Icon(Icons.holiday_village_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter a hub name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'Enter the hub address',
                    prefixIcon: const Icon(Icons.place_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter the hub address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _weekdayOptions.contains(_operatingStartDay)
                            ? _operatingStartDay
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'Start Day',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    items: _weekdayOptions
                        .map(
                          (day) => DropdownMenuItem<String>(
                            value: day,
                            child: Text(day),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _operatingStartDay = value ?? '';
                            });
                          },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty &&
                          _hasAnyOperatingScheduleInput()) {
                        return 'Select a start day.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue:
                        _weekdayOptions.contains(_operatingEndDay)
                            ? _operatingEndDay
                            : null,
                    decoration: const InputDecoration(
                      labelText: 'End Day',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    items: _weekdayOptions
                        .map(
                          (day) => DropdownMenuItem<String>(
                            value: day,
                            child: Text(day),
                          ),
                        )
                        .toList(),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() {
                              _operatingEndDay = value ?? '';
                            });
                          },
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty &&
                          _hasAnyOperatingScheduleInput()) {
                        return 'Select an end day.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _operatingStartTimeController,
                    label: 'Start Time',
                    hint: 'Select start time',
                    readOnly: true,
                    onTap: _pickOperatingStartTime,
                    prefixIcon: const Icon(Icons.schedule_outlined),
                    suffixIcon: IconButton(
                      onPressed: _pickOperatingStartTime,
                      icon: const Icon(Icons.access_time_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _operatingEndTimeController,
                    label: 'End Time',
                    hint: 'Select end time',
                    readOnly: true,
                    onTap: _pickOperatingEndTime,
                    prefixIcon: const Icon(Icons.schedule_outlined),
                    suffixIcon: IconButton(
                      onPressed: _pickOperatingEndTime,
                      icon: const Icon(Icons.access_time_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Leave blank to keep the current schedule, or fill all four fields together.',
                    style: TextStyle(color: AppColors.mist, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _contactNumberController,
                    label: 'Contact Number',
                    hint: 'Enter the hub contact number',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter a contact number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Hub Status',
                      prefixIcon: Icon(Icons.verified_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _status = value;
                            });
                          },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Save Hub Profile',
                    isLoading: _isSaving,
                    onPressed: _saveHubProfile,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static TimeOfDay? _readTimeOfDay(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      final parts = trimmed.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    }
    return null;
  }

  void _syncOperatingScheduleControllers() {
    _operatingStartTimeController.text = _formatTime(_operatingStartTime);
    _operatingEndTimeController.text = _formatTime(_operatingEndTime);
  }

  bool _hasAnyOperatingScheduleInput() {
    return _operatingStartDay.trim().isNotEmpty ||
        _operatingEndDay.trim().isNotEmpty ||
        _operatingStartTime != null ||
        _operatingEndTime != null;
  }

  bool _hasCompleteOperatingSchedule() {
    return _operatingStartDay.trim().isNotEmpty &&
        _operatingEndDay.trim().isNotEmpty &&
        _operatingStartTime != null &&
        _operatingEndTime != null;
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) {
      return '';
    }
    return MaterialLocalizations.of(context).formatTimeOfDay(value);
  }

  String _formatTimeForStorage(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatOperatingHoursRange(BuildContext context) {
    final startDay = _operatingStartDay.trim();
    final endDay = _operatingEndDay.trim();
    final startTime = _operatingStartTime;
    final endTime = _operatingEndTime;
    if (startDay.isEmpty ||
        endDay.isEmpty ||
        startTime == null ||
        endTime == null) {
      return _legacyOperatingHours;
    }

    final localizations = MaterialLocalizations.of(context);
    final startTimeText = localizations.formatTimeOfDay(startTime);
    final endTimeText = localizations.formatTimeOfDay(endTime);
    return '${_shortDayLabel(startDay)}-${_shortDayLabel(endDay)}, $startTimeText - $endTimeText';
  }

  Future<void> _pickOperatingStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _operatingStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _operatingStartTime = picked;
      _operatingStartTimeController.text = _formatTime(picked);
    });
  }

  Future<void> _pickOperatingEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _operatingEndTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _operatingEndTime = picked;
      _operatingEndTimeController.text = _formatTime(picked);
    });
  }

  static String _shortDayLabel(String day) {
    return switch (day.toLowerCase()) {
      'monday' => 'Mon',
      'tuesday' => 'Tue',
      'wednesday' => 'Wed',
      'thursday' => 'Thu',
      'friday' => 'Fri',
      'saturday' => 'Sat',
      'sunday' => 'Sun',
      _ => day,
    };
  }
}

class _HubProfileHero extends StatelessWidget {
  const _HubProfileHero({
    required this.hubName,
    required this.hubId,
    required this.status,
  });

  final String hubName;
  final String hubId;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.pine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'COMMUNITY HUB',
            style: TextStyle(
              color: AppColors.sand,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            hubName,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hub ID: ${hubId.isEmpty ? 'Not created yet' : hubId}',
            style: const TextStyle(color: AppColors.sand),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              'Status: ${status[0].toUpperCase()}${status.substring(1)}',
              style: const TextStyle(
                color: AppColors.sand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
