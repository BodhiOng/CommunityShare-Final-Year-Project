// ignore_for_file: use_build_context_synchronously

// ignore_for_file: unused_element

import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/user_role.dart';
import '../../constants.dart';
import '../../services/image_storage_service.dart';
import '../../widgets/app_forms.dart';
import '../../widgets/state_widgets.dart';
import '../../utils/image_converter.dart';
import '../../utils/image_utils.dart';

const List<String> _weekdayOptions = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class SharedProfilePage extends StatefulWidget {
  const SharedProfilePage({super.key, required this.role});

  final UserRole role;

  @override
  State<SharedProfilePage> createState() => _SharedProfilePageState();
}

class _SharedProfilePageState extends State<SharedProfilePage> {
  static Future<List<_CountryOption>>? _cachedLocationDatasetFuture;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HttpClient _httpClient = HttpClient();
  final ImageStorageService _imageStorageService = ImageStorageService();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneCountryCodeController =
      TextEditingController();
  final TextEditingController _hubContactCountryCodeController =
      TextEditingController();
  final TextEditingController _hubNameController = TextEditingController();
  final TextEditingController _hubOperatingHoursController =
      TextEditingController();
  final TextEditingController _hubOperatingStartTimeController =
      TextEditingController();
  final TextEditingController _hubOperatingEndTimeController =
      TextEditingController();
  final TextEditingController _hubContactNumberController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isLoadingLocationData = true;

  String? _errorMessage;
  String? _locationErrorMessage;
  String _profileImageUrl = '';
  File? _profileImageFile;
  String _status = 'active';
  String _hubDocId = '';
  String _hubId = '';
  DateTime? _createdAt;
  List<_CountryOption> _countryOptions = const [];
  String _selectedPhoneCountryCode = '';
  String _pendingPhoneCountryCode = '';
  String _pendingHubContactNumber = '';
  String _legacyHubOperatingHours = '';
  String _hubOperatingStartDay = '';
  String _hubOperatingEndDay = '';
  TimeOfDay? _hubOperatingStartTime;
  TimeOfDay? _hubOperatingEndTime;

  @override
  void initState() {
    super.initState();
    _bootstrapProfile();
  }

  @override
  void dispose() {
    _httpClient.close(force: true);
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _phoneCountryCodeController.dispose();
    _hubContactCountryCodeController.dispose();
    _hubNameController.dispose();
    _hubOperatingHoursController.dispose();
    _hubOperatingStartTimeController.dispose();
    _hubOperatingEndTimeController.dispose();
    _hubContactNumberController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapProfile() async {
    await Future.wait([_loadLocationData(), _loadProfile()]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocationData({bool refresh = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _locationErrorMessage = null;
      _isLoadingLocationData = true;
    });

    try {
      final countries = await _fetchCountryOptions(refresh: refresh);

      if (!mounted) {
        return;
      }

      setState(() {
        _countryOptions = countries;
        _isLoadingLocationData = false;
      });

      _syncPhoneCountryCodeController();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationErrorMessage = 'Unable to load phone code options right now.';
        _isLoadingLocationData = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'You need to sign in to view this profile.';
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('USER').doc(user.uid).get();
      final legacyDoc = await _firestore.collection('USER').doc(user.uid).get();
      final hubDoc =
          await _firestore.collection('COMMUNITY_HUB').doc(user.uid).get();

      final data = <String, dynamic>{...?legacyDoc.data(), ...?userDoc.data()};
      final hubData = hubDoc.data() ?? const <String, dynamic>{};

      _fullNameController.text = _stringValue(
        data['fullName'],
        fallback: _stringValue(
          data['username'],
          fallback: user.displayName ?? '',
        ),
      );
      _phoneController.text = _stringValue(
        data['phoneNumber'],
        fallback: _stringValue(data['phone']),
      );
      _bioController.text = _stringValue(data['bio']);
      _addressController.text = _stringValue(
        data['address'],
        fallback: _stringValue(hubData['address']),
      );
      _pendingPhoneCountryCode = _stringValue(data['phoneCountryCode']);
      _phoneController.text = _stripPhoneCountryCode(
        _phoneController.text,
        _pendingPhoneCountryCode,
      );
      _pendingHubContactNumber = _stringValue(
        hubData['contactNumber'],
        fallback:
            '${_stringValue(hubData['contactCountryCode'])}${_stringValue(hubData['contactLocalNumber'])}',
      );
      _legacyHubOperatingHours = _stringValue(hubData['operatingHours']);
      _hubOperatingStartDay = _stringValue(hubData['operatingStartDay']);
      _hubOperatingEndDay = _stringValue(hubData['operatingEndDay']);
      _hubOperatingStartTime = _readTimeOfDay(hubData['operatingStartTime']);
      _hubOperatingEndTime = _readTimeOfDay(hubData['operatingEndTime']);
      _status = _stringValue(data['status'], fallback: 'active');
      _profileImageUrl = _stringValue(data['profileImageUrl']);
      _createdAt = _readDateTime(data['createdAt']);

      _hubDocId = hubDoc.exists ? hubDoc.id : '';
      _hubId = _stringValue(
        hubData['hubId'],
        fallback: _hubDocId.isNotEmpty ? _hubDocId : '',
      );
      _hubNameController.text = _stringValue(
        hubData['hubName'],
        fallback: _fullNameController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      _syncPhoneCountryCodeController();
      _syncHubOperatingScheduleControllers();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to load your profile right now.';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _profileImageFile = File(image.path);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick a profile image.')),
      );
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImageFile = null;
      _profileImageUrl = '';
    });
  }

  Future<List<_CountryOption>> _fetchCountryOptions({
    bool refresh = false,
  }) async {
    if (!refresh && _cachedLocationDatasetFuture != null) {
      return _cachedLocationDatasetFuture!;
    }

    final future = _loadLocationDataset();
    _cachedLocationDatasetFuture = future;

    try {
      return await future;
    } catch (_) {
      if (identical(_cachedLocationDatasetFuture, future)) {
        _cachedLocationDatasetFuture = null;
      }
      rethrow;
    }
  }

  Future<List<_CountryOption>> _loadLocationDataset() async {
    final json = await _getJson(
      Uri.parse(
        'https://raw.githubusercontent.com/dr5hn/countries-states-cities-database/refs/heads/master/json/countries%2Bstates%2Bcities.json',
      ),
    );

    if (json is! List) {
      throw const FormatException('Invalid location dataset response');
    }

    final parsedCountries = json
      .whereType<Map>()
      .map(
        (item) => _CountryOption(
          country: _stringValue(item['name']),
          flag: _stringValue(item['emoji'], fallback: '🏳️'),
          dialCode: '+${_stringValue(item['phonecode'])}',
          states: _parseStates(item['states']),
        ),
      )
      .where((item) => item.country.isNotEmpty && item.dialCode.isNotEmpty)
      .toList(growable: false)..sort((a, b) => a.country.compareTo(b.country));

    return parsedCountries;
  }

  Future<void> _setPhoneCountryCode(String value) async {
    if (_countryOptions.isEmpty) {
      return;
    }

    final code =
        _countryOptions.any((option) => option.dialCode == value)
            ? value
            : _countryOptions.first.dialCode;
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPhoneCountryCode = code;
    });
    _syncPhoneCountryCodeController();
  }

  Future<void> _setHubContactCountryCode(String value) async {
    if (_countryOptions.isEmpty) {
      return;
    }

    final code =
        _countryOptions.any((option) => option.dialCode == value)
            ? value
            : '';
    if (!mounted) {
      return;
    }

    setState(() {
      _hubContactCountryCodeController.text = code;
    });
  }

  Future<dynamic> _getJson(Uri uri) async {
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GET ${uri.toString()} failed with ${response.statusCode}: $body',
        uri: uri,
      );
    }
    return jsonDecode(body);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> payload,
  ) async {
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'POST ${uri.toString()} failed with ${response.statusCode}: $body',
        uri: uri,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Unexpected response format');
  }

  void _syncPhoneCountryCodeController() {
    _phoneCountryCodeController.text = _selectedPhoneCountryCode;
  }

  void _syncHubContactControllers() {
    final countryCode = _inferPhoneCountryCode(_pendingHubContactNumber);
    _hubContactCountryCodeController.text = countryCode;
    _hubContactNumberController.text = _stripPhoneCountryCode(
      _pendingHubContactNumber,
      countryCode,
    );
  }

  void _syncHubOperatingScheduleControllers() {
    _hubOperatingHoursController.text = _formatOperatingHoursRange(context);
    _hubOperatingStartTimeController.text = _formatTime(
      _hubOperatingStartTime,
    );
    _hubOperatingEndTimeController.text = _formatTime(_hubOperatingEndTime);
  }

  String _resolveDialCode(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty &&
        _countryOptions.any((option) => option.dialCode == trimmed)) {
      return trimmed;
    }
    return _countryOptions.isNotEmpty ? _countryOptions.first.dialCode : '';
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

  bool _hasAnyHubOperatingScheduleInput() {
    return _hubOperatingStartDay.trim().isNotEmpty ||
        _hubOperatingEndDay.trim().isNotEmpty ||
        _hubOperatingStartTime != null ||
        _hubOperatingEndTime != null;
  }

  bool _hasCompleteHubOperatingSchedule() {
    return _hubOperatingStartDay.trim().isNotEmpty &&
        _hubOperatingEndDay.trim().isNotEmpty &&
        _hubOperatingStartTime != null &&
        _hubOperatingEndTime != null;
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
    final startDay = _hubOperatingStartDay.trim();
    final endDay = _hubOperatingEndDay.trim();
    final startTime = _hubOperatingStartTime;
    final endTime = _hubOperatingEndTime;
    if (startDay.isEmpty ||
        endDay.isEmpty ||
        startTime == null ||
        endTime == null) {
      return _legacyHubOperatingHours;
    }

    final localizations = MaterialLocalizations.of(context);
    final startTimeText = localizations.formatTimeOfDay(startTime);
    final endTimeText = localizations.formatTimeOfDay(endTime);
    return '${_shortDayLabel(startDay)}-${_shortDayLabel(endDay)}, $startTimeText - $endTimeText';
  }

  Future<void> _pickHubOperatingStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hubOperatingStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _hubOperatingStartTime = picked;
      _hubOperatingStartTimeController.text = _formatTime(picked);
      _hubOperatingHoursController.text = _formatOperatingHoursRange(context);
    });
  }

  Future<void> _pickHubOperatingEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _hubOperatingEndTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _hubOperatingEndTime = picked;
      _hubOperatingEndTimeController.text = _formatTime(picked);
      _hubOperatingHoursController.text = _formatOperatingHoursRange(context);
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

  String _inferPhoneCountryCode(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    for (final option in _countryOptions) {
      if (trimmed.startsWith(option.dialCode)) {
        return option.dialCode;
      }
    }

    return '';
  }

  bool _hasBaseProfileRequirements() {
    return _fullNameController.text.trim().isNotEmpty &&
        _selectedPhoneCountryCode.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty &&
        _addressController.text.trim().isNotEmpty;
  }

  bool _hasHubProfileRequirements() {
    return true;
  }

  bool _shouldBeActive() {
    return _hasBaseProfileRequirements() && _hasHubProfileRequirements();
  }

  String _flagEmojiFromCountryCode(String code) {
    final letters = code.trim().toUpperCase().codeUnits;
    if (letters.length != 2) {
      return '🏳️';
    }

    final offset = 0x1F1E6 - 65;
    return String.fromCharCodes([letters[0] + offset, letters[1] + offset]);
  }

  List<_StateOption> _parseStates(dynamic statesValue) {
    if (statesValue is! List) {
      return const [];
    }

    return statesValue
      .whereType<Map>()
      .map(
        (item) => _StateOption(
          name: _stringValue(item['name']),
          cities: _parseCities(item['cities']),
        ),
      )
      .where((state) => state.name.isNotEmpty)
      .toList(growable: false)..sort((a, b) => a.name.compareTo(b.name));
  }

  List<String> _parseCities(dynamic citiesValue) {
    if (citiesValue is! List) {
      return const [];
    }

    return citiesValue
      .whereType<Map>()
      .map((item) => _stringValue(item['name']))
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false)..sort();
  }

  ImageProvider? _profileImageProvider() {
    if (_profileImageFile != null) {
      return FileImage(_profileImageFile!);
    }

    if (_profileImageUrl.isEmpty) {
      return null;
    }

    if (_looksLikeBase64Image(_profileImageUrl)) {
      final bytes = ImageConverter.base64ToBytes(_profileImageUrl);
      if (bytes.isNotEmpty) {
        return MemoryImage(bytes);
      }
      return null;
    }

    if (ImageUtils.isUrl(_profileImageUrl)) {
      return NetworkImage(_profileImageUrl);
    }

    return null;
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImageFile == null) {
      return null;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return null;
      }

      return _imageStorageService.uploadFile(
        file: _profileImageFile!,
        folder: 'profile_images/$userId',
        fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final newImageUrl = await _uploadProfileImage();
      if (newImageUrl != null && newImageUrl.isNotEmpty) {
        _profileImageUrl = newImageUrl;
      }

      final wasInactive = _status.toLowerCase() == 'inactive';
      final nextStatus = _shouldBeActive() ? 'active' : 'inactive';

      if (_fullNameController.text.trim().isNotEmpty &&
          _fullNameController.text.trim() != (user.displayName ?? '')) {
        await user.updateDisplayName(_fullNameController.text.trim());
      }

      final payload = <String, dynamic>{
        'userId': user.uid,
        'fullName': _fullNameController.text.trim(),
        'email': user.email ?? '',
        'phoneCountryCode': _selectedPhoneCountryCode,
        'phoneNumber':
            '$_selectedPhoneCountryCode${_phoneController.text.trim()}',
        'phoneLocalNumber': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'address': _addressController.text.trim(),
        'role': widget.role.key,
        'status': nextStatus,
        'profileImageUrl': _profileImageUrl,
        'createdAt':
            _createdAt == null
                ? FieldValue.serverTimestamp()
                : Timestamp.fromDate(_createdAt!),
      };

      await _firestore
          .collection('USER')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      await _firestore.collection('USER').doc(user.uid).set({
        'fullName': _fullNameController.text.trim(),
        'username': _fullNameController.text.trim(),
        'email': user.email ?? '',
        'phoneCountryCode': _selectedPhoneCountryCode,
        'phoneNumber':
            '$_selectedPhoneCountryCode${_phoneController.text.trim()}',
        'phoneLocalNumber': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'address': _addressController.text.trim(),
        'role': widget.role.key,
        'status': nextStatus,
        'profileImageUrl': _profileImageUrl,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _status = nextStatus;
        _isSavingProfile = false;
        if (widget.role == UserRole.hub) {
          _hubDocId = _hubDocId.isNotEmpty ? _hubDocId : user.uid;
          _hubId = _hubId.isNotEmpty ? _hubId : _hubDocId;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'active'
                ? wasInactive
                    ? 'Profile updated. Your account is now active.'
                    : 'Profile updated.'
                : 'Profile saved. Complete the required fields to activate your account.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      setState(() {
        _isSavingProfile = false;
      });

      final message = switch (error.code) {
        'requires-recent-login' =>
          'Re-authenticate before saving profile changes.',
        _ => 'Unable to update profile right now.',
      };

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      setState(() {
        _isSavingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile right now.')),
      );
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Signed out.')));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final profileImageProvider = _profileImageProvider();
    final countries = _countryOptions;
    if (_isLoading) {
      return const AppLoadingState(message: 'Loading profile...');
    }

    if (_errorMessage != null) {
      return AppErrorState(message: _errorMessage!, onRetry: _bootstrapProfile);
    }

    final phoneCodes = countries
        .map((option) => option.dialCode)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _ProfileHero(
          profileImageProvider: profileImageProvider,
          onEditImage: _pickProfileImage,
          userId: user?.uid ?? 'Not available',
          fullName:
              _fullNameController.text.trim().isNotEmpty
                  ? _fullNameController.text.trim()
                  : (user?.displayName ?? user?.email ?? 'CommunityShare user'),
          roleLabel: widget.role.label,
          status: _status,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _profileFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.forest,
                            backgroundImage: profileImageProvider,
                            child:
                                profileImageProvider == null
                                    ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 42,
                                      color: AppColors.sand,
                                    )
                                    : null,
                          ),
                        ),
                        if (_profileImageProvider() != null ||
                            _profileImageFile != null ||
                            _profileImageUrl.isNotEmpty)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Material(
                              color: AppColors.coral,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _removeProfileImage,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _fullNameController,
                    label: 'Full Name *',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    validator: (value) {
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isLoadingLocationData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: AppLoadingState(
                        message: 'Loading phone code options...',
                      ),
                    )
                  else if (_locationErrorMessage != null) ...[
                    AppErrorState(
                      message: _locationErrorMessage!,
                      onRetry: () => _loadLocationData(refresh: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchableFormField(
                          width: 88,
                          controller: _phoneCountryCodeController,
                          label: 'Code *',
                          hint: '+65',
                          options: phoneCodes,
                          enabled: phoneCodes.isNotEmpty,
                          optionLabelBuilder: (code) {
                            final option = _countryOptions.firstWhere(
                              (item) => item.dialCode == code,
                              orElse: () => _countryOptions.first,
                            );
                            return '${option.flag} $code';
                          },
                          validator: (value) {
                            final code = value?.trim() ?? '';
                            if (code.isNotEmpty && !phoneCodes.contains(code)) {
                              return 'Pick a valid code.';
                            }
                            return null;
                          },
                          onSelected: _setPhoneCountryCode,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppTextField(
                            controller: _phoneController,
                            label: 'Phone Number *',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isNotEmpty &&
                                  !RegExp(
                                    r'^[0-9\s-]{6,}$',
                                  ).hasMatch(trimmed)) {
                                return 'Use digits only for the local phone number.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _addressController,
                      label: 'Address *',
                      hint: 'Enter your address',
                      prefixIcon: const Icon(Icons.place_outlined),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter your address.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint:
                        'Tell people a little about yourself. Max 150 characters.',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    validator: (value) {
                      if ((value ?? '').trim().length > 150) {
                        return 'Bio must be 150 characters or fewer.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: 'Save profile',
                    isLoading: _isSavingProfile,
                    onPressed:
                        (_isSavingProfile ||
                                _isLoadingLocationData ||
                                countries.isEmpty)
                            ? null
                            : _saveProfile,
                    icon: const Icon(Icons.save_outlined),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Sign out',
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    return fallback;
  }

  static bool _looksLikeBase64Image(String source) {
    if (source.startsWith('data:image/')) {
      return true;
    }

    final rawBase64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
    return rawBase64.hasMatch(source) && source.length % 4 == 0;
  }

  String _normalizePhoneCountryCode(String value, String fullPhone) {
    final trimmed = value.trim();
    if (_countryOptions.any((option) => option.dialCode == trimmed)) {
      return trimmed;
    }

    final phone = fullPhone.trim();
    for (final option in _countryOptions) {
      if (phone.startsWith(option.dialCode)) {
        return option.dialCode;
      }
    }

    return _countryOptions.first.dialCode;
  }

  String _stripPhoneCountryCode(String phone, String countryCode) {
    final trimmed = phone.trim();
    if (trimmed.startsWith(countryCode)) {
      return trimmed.substring(countryCode.length).trimLeft();
    }
    return trimmed;
  }
}

class _SearchableFormField extends StatefulWidget {
  const _SearchableFormField({
    required this.controller,
    required this.label,
    required this.options,
    required this.onSelected,
    required this.optionLabelBuilder,
    this.width,
    this.enabled = true,
    this.hint,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final String Function(String value) optionLabelBuilder;
  final double? width;
  final bool enabled;
  final FormFieldValidator<String>? validator;

  @override
  State<_SearchableFormField> createState() => _SearchableFormFieldState();
}

class _SearchableFormFieldState extends State<_SearchableFormField> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = widget.width ?? constraints.maxWidth;

        String? resolveExactMatch(String value) {
          final trimmed = value.trim();
          for (final option in widget.options) {
            if (option.toLowerCase() == trimmed.toLowerCase()) {
              return option;
            }
          }
          return null;
        }

        return SizedBox(
          width: widget.width,
          child: RawAutocomplete<String>(
            textEditingController: widget.controller,
            focusNode: _focusNode,
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (!widget.enabled) {
                return const Iterable<String>.empty();
              }

              final query = textEditingValue.text.trim().toLowerCase();
              if (query.isEmpty) {
                return widget.options;
              }

              return widget.options.where(
                (option) => option.toLowerCase().contains(query),
              );
            },
            displayStringForOption: (option) => option,
            onSelected: widget.onSelected,
            fieldViewBuilder: (
              context,
              fieldController,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextFormField(
                controller: fieldController,
                focusNode: focusNode,
                enabled: widget.enabled,
                validator: widget.validator,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  isDense: widget.width != null,
                  contentPadding:
                      widget.width != null
                          ? const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          )
                          : null,
                ),
                onFieldSubmitted: (_) {
                  final exact = resolveExactMatch(fieldController.text);
                  if (exact != null) {
                    fieldController.text = exact;
                    fieldController.selection = TextSelection.collapsed(
                      offset: exact.length,
                    );
                    widget.onSelected(exact);
                  }
                  onFieldSubmitted();
                },
              );
            },
            optionsViewBuilder: (context, onOptionSelected, optionList) {
              final availableOptions = optionList.toList(growable: false);
              if (availableOptions.isEmpty) {
                return const SizedBox.shrink();
              }

              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  color: AppColors.night,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: fieldWidth,
                      maxWidth: fieldWidth,
                      maxHeight: 240,
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: availableOptions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = availableOptions[index];
                        return ListTile(
                          dense: true,
                          title: Text(widget.optionLabelBuilder(option)),
                          onTap: () {
                            onOptionSelected(option);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CountryOption {
  const _CountryOption({
    required this.country,
    required this.flag,
    required this.dialCode,
    required this.states,
  });

  final String country;
  final String flag;
  final String dialCode;
  final List<_StateOption> states;
}

class _StateOption {
  const _StateOption({required this.name, required this.cities});

  final String name;
  final List<String> cities;
}

const List<_CountryOption> _countryOptions = [
  _CountryOption(
    country: 'Singapore',
    flag: '🇸🇬',
    dialCode: '+65',
    states: [
      _StateOption(name: 'Singapore', cities: ['Singapore']),
    ],
  ),
  _CountryOption(
    country: 'Malaysia',
    flag: '🇲🇾',
    dialCode: '+60',
    states: [
      _StateOption(name: 'Johor', cities: ['Johor Bahru', 'Batu Pahat']),
      _StateOption(name: 'Kuala Lumpur', cities: ['Kuala Lumpur']),
      _StateOption(name: 'Selangor', cities: ['Shah Alam', 'Petaling Jaya']),
    ],
  ),
  _CountryOption(
    country: 'Indonesia',
    flag: '🇮🇩',
    dialCode: '+62',
    states: [
      _StateOption(name: 'Jakarta', cities: ['Jakarta']),
      _StateOption(name: 'West Java', cities: ['Bandung', 'Bekasi']),
      _StateOption(name: 'East Java', cities: ['Surabaya', 'Malang']),
    ],
  ),
  _CountryOption(
    country: 'Philippines',
    flag: '🇵🇭',
    dialCode: '+63',
    states: [
      _StateOption(name: 'Metro Manila', cities: ['Manila', 'Quezon City']),
      _StateOption(name: 'Cebu', cities: ['Cebu City']),
      _StateOption(name: 'Davao', cities: ['Davao City']),
    ],
  ),
  _CountryOption(
    country: 'United States',
    flag: '🇺🇸',
    dialCode: '+1',
    states: [
      _StateOption(name: 'California', cities: ['Los Angeles', 'San Diego']),
      _StateOption(name: 'New York', cities: ['New York']),
      _StateOption(name: 'Texas', cities: ['Houston', 'Dallas']),
    ],
  ),
  _CountryOption(
    country: 'United Kingdom',
    flag: '🇬🇧',
    dialCode: '+44',
    states: [
      _StateOption(name: 'England', cities: ['London', 'Manchester']),
      _StateOption(name: 'Scotland', cities: ['Edinburgh', 'Glasgow']),
      _StateOption(name: 'Wales', cities: ['Cardiff']),
    ],
  ),
  _CountryOption(
    country: 'Australia',
    flag: '🇦🇺',
    dialCode: '+61',
    states: [
      _StateOption(name: 'New South Wales', cities: ['Sydney']),
      _StateOption(name: 'Victoria', cities: ['Melbourne']),
      _StateOption(name: 'Queensland', cities: ['Brisbane']),
    ],
  ),
  _CountryOption(
    country: 'India',
    flag: '🇮🇳',
    dialCode: '+91',
    states: [
      _StateOption(name: 'Maharashtra', cities: ['Mumbai', 'Pune']),
      _StateOption(name: 'Karnataka', cities: ['Bengaluru']),
      _StateOption(name: 'Delhi', cities: ['New Delhi']),
    ],
  ),
];

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profileImageProvider,
    required this.onEditImage,
    required this.userId,
    required this.fullName,
    required this.roleLabel,
    required this.status,
  });

  final ImageProvider? profileImageProvider;
  final VoidCallback onEditImage;
  final String userId;
  final String fullName;
  final String roleLabel;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          colors: [AppColors.forest, AppColors.pine],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onEditImage,
            child: CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.white.withValues(alpha: 0.14),
              backgroundImage: profileImageProvider,
              child:
                  profileImageProvider == null
                      ? const Icon(
                        Icons.person_outline_rounded,
                        size: 30,
                        color: AppColors.sand,
                      )
                      : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ACCOUNT',
                  style: TextStyle(
                    color: AppColors.sand,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'User ID: $userId',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.sand,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _HeroChip(label: roleLabel),
                    _HeroChip(label: 'Status: $status'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.sand,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
