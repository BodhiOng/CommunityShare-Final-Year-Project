// ignore_for_file: use_build_context_synchronously

// ignore_for_file: unused_element

import 'dart:io';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app/user_role.dart';
import 'constants.dart';
import 'widgets/app_forms.dart';
import 'widgets/state_widgets.dart';
import 'utils/image_converter.dart';
import 'utils/image_utils.dart';

class SharedProfilePage extends StatefulWidget {
  const SharedProfilePage({
    super.key,
    required this.role,
  });

  final UserRole role;

  @override
  State<SharedProfilePage> createState() => _SharedProfilePageState();
}

class _SharedProfilePageState extends State<SharedProfilePage> {
  static Future<List<_CountryOption>>? _cachedLocationDatasetFuture;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HttpClient _httpClient = HttpClient();

  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneCountryCodeController =
      TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isLoadingLocationData = true;

  String? _errorMessage;
  String? _locationErrorMessage;
  String _profileImageUrl = '';
  File? _profileImageFile;
  String _status = 'active';
  DateTime? _createdAt;
  List<_CountryOption> _countryOptions = const [];
  List<String> _stateOptions = const [];
  List<String> _cityOptions = const [];
  String _selectedCountry = '';
  String _selectedState = '';
  String _selectedCity = '';
  String _selectedPhoneCountryCode = '';
  String _pendingCountry = '';
  String _pendingState = '';
  String _pendingCity = '';
  String _pendingPhoneCountryCode = '';

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
    _phoneCountryCodeController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapProfile() async {
    await Future.wait([
      _loadLocationData(),
      _loadProfile(),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocationData({bool refresh = false}) async {
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

      await _applyPendingLocationSelections();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationErrorMessage = 'Unable to load location options right now.';
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
      final legacyDoc = await _firestore.collection('users').doc(user.uid).get();

      final data = <String, dynamic>{
        ...?legacyDoc.data(),
        ...?userDoc.data(),
      };

      _fullNameController.text = _stringValue(
        data['fullName'],
        fallback: _stringValue(data['username'], fallback: user.displayName ?? ''),
      );
      _phoneController.text = _stringValue(
        data['phoneNumber'],
        fallback: _stringValue(data['phone']),
      );
      _bioController.text = _stringValue(data['bio']);
      _pendingCountry = _stringValue(data['country']);
      _pendingState = _stringValue(data['state']);
      _pendingCity = _stringValue(data['city']);
      _pendingPhoneCountryCode = _stringValue(data['phoneCountryCode']);
      _phoneController.text = _stripPhoneCountryCode(
        _phoneController.text,
        _pendingPhoneCountryCode,
      );
      _status = _stringValue(data['status'], fallback: 'active');
      _profileImageUrl = _stringValue(data['profileImageUrl']);
      _createdAt = _readDateTime(data['createdAt']);

      if (!mounted) {
        return;
      }

      await _applyPendingLocationSelections();
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

  Future<void> _applyPendingLocationSelections() async {
    if (_countryOptions.isEmpty) {
      _syncLocationControllers();
      return;
    }

    final country = _resolveCountry(_pendingCountry);
    final dialCode = _resolveDialCode(_pendingPhoneCountryCode, country);
    final states = await _fetchStates(country);
    final state = _resolveState(_pendingState, states);
    final cities = await _fetchCities(country, state);
    final city = _resolveCity(_pendingCity, cities);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCountry = country;
      _selectedPhoneCountryCode = dialCode;
      _stateOptions = states;
      _selectedState = state;
      _cityOptions = cities;
      _selectedCity = city;
    });
    _syncLocationControllers();
  }

  Future<List<_CountryOption>> _fetchCountryOptions({bool refresh = false}) async {
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
        .toList(growable: false)
      ..sort((a, b) => a.country.compareTo(b.country));

    return parsedCountries;
  }

  Future<List<String>> _fetchStates(String country) async {
    for (final option in _countryOptions) {
      if (option.country == country) {
        return option.states
            .map((state) => state.name)
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
      }
    }

    return const [];
  }

  Future<List<String>> _fetchCities(String country, String state) async {
    for (final option in _countryOptions) {
      if (option.country == country) {
        for (final region in option.states) {
          if (region.name == state) {
            return region.cities
                .where((item) => item.isNotEmpty)
                .toSet()
                .toList(growable: false)
              ..sort();
          }
        }
      }
    }

    return const [];
  }

  Future<void> _setCountry(String value) async {
    if (_countryOptions.isEmpty) {
      return;
    }

    final country = _countryOptions.any((option) => option.country == value)
        ? value
        : _countryOptions.first.country;
    final dialCode = _countryOptions
        .firstWhere(
          (option) => option.country == country,
          orElse: () => _countryOptions.first,
        )
        .dialCode;
    final states = await _fetchStates(country);
    final state = _resolveState(_selectedState, states);
    final cities = await _fetchCities(country, state);
    final city = _resolveCity(_selectedCity, cities);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedCountry = country;
      _selectedPhoneCountryCode = dialCode;
      _stateOptions = states;
      _selectedState = state;
      _cityOptions = cities;
      _selectedCity = city;
    });
    _syncLocationControllers();
  }

  Future<void> _setState(String value) async {
    if (_selectedCountry.isEmpty) {
      return;
    }

    final states = _stateOptions;
    if (states.isEmpty) {
      return;
    }

    final state = states.contains(value) ? value : states.first;
    final cities = await _fetchCities(_selectedCountry, state);
    final city = _resolveCity(_selectedCity, cities);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedState = state;
      _cityOptions = cities;
      _selectedCity = city;
    });
    _syncLocationControllers();
  }

  void _setCity(String value) {
    if (_cityOptions.isEmpty) {
      return;
    }

    final city = _cityOptions.contains(value) ? value : _cityOptions.first;
    setState(() {
      _selectedCity = city;
    });
    _syncLocationControllers();
  }

  Future<void> _setPhoneCountryCode(String value) async {
    if (_countryOptions.isEmpty) {
      return;
    }

    final code = _countryOptions.any((option) => option.dialCode == value)
        ? value
        : _countryOptions.first.dialCode;
    final country = _countryForDialCode(code);
    if (country.isNotEmpty) {
      await _setCountry(country);
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPhoneCountryCode = code;
    });
    _syncLocationControllers();
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

  String _resolveState(String? value, List<String> states) {
    if (states.isEmpty) {
      return '';
    }

    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      for (final state in states) {
        if (state.toLowerCase() == trimmed.toLowerCase()) {
          return state;
        }
      }
    }

    return states.first;
  }

  String _resolveCity(String? value, List<String> cities) {
    if (cities.isEmpty) {
      return '';
    }

    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      for (final city in cities) {
        if (city.toLowerCase() == trimmed.toLowerCase()) {
          return city;
        }
      }
    }

    return cities.first;
  }

  String _resolveCountry(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _countryOptions.first.country;
    }

    for (final option in _countryOptions) {
      if (option.country.toLowerCase() == trimmed.toLowerCase()) {
        return option.country;
      }
    }

    return _countryOptions.first.country;
  }

  String _countryForDialCode(String dialCode) {
    for (final option in _countryOptions) {
      if (option.dialCode == dialCode) {
        return option.country;
      }
    }
    return '';
  }

  void _syncLocationControllers() {
    _phoneCountryCodeController.text = _selectedPhoneCountryCode;
    _countryController.text = _selectedCountry;
    _stateController.text = _selectedState;
    _cityController.text = _selectedCity;
  }

  String _resolveDialCode(String? value, String country) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty &&
        _countryOptions.any((option) => option.dialCode == trimmed)) {
      return trimmed;
    }

    return _countryOptions
        .firstWhere(
          (option) => option.country == country,
          orElse: () => _countryOptions.first,
        )
        .dialCode;
  }

  String _flagEmojiFromCountryCode(String code) {
    final letters = code.trim().toUpperCase().codeUnits;
    if (letters.length != 2) {
      return '🏳️';
    }

    final offset = 0x1F1E6 - 65;
    return String.fromCharCodes([
      letters[0] + offset,
      letters[1] + offset,
    ]);
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
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
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
        .toList(growable: false)
      ..sort();
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
      return ImageConverter.fileToBase64(_profileImageFile!);
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
        'city': _selectedCity,
        'state': _selectedState,
        'country': _selectedCountry,
        'role': widget.role.key,
        'status': _status,
        'profileImageUrl': _profileImageUrl,
        'createdAt': _createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(_createdAt!),
      };

      await _firestore
          .collection('USER')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'fullName': _fullNameController.text.trim(),
        'username': _fullNameController.text.trim(),
        'email': user.email ?? '',
        'phoneCountryCode': _selectedPhoneCountryCode,
        'phoneNumber':
            '$_selectedPhoneCountryCode${_phoneController.text.trim()}',
        'phoneLocalNumber': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'city': _selectedCity,
        'state': _selectedState,
        'country': _selectedCountry,
        'role': widget.role.key,
        'status': _status,
        'profileImageUrl': _profileImageUrl,
      }, SetOptions(merge: true));

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated.'),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out.')),
    );
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
      return AppErrorState(
        message: _errorMessage!,
        onRetry: _bootstrapProfile,
      );
    }

    final states = _stateOptions.isNotEmpty
        ? _stateOptions
        : const <String>[];
    final cities = _cityOptions.isNotEmpty
        ? _cityOptions
        : const <String>[];
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
          fullName: _fullNameController.text.trim().isNotEmpty
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
                            child: profileImageProvider == null
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
                    label: 'Full Name',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your full name.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isLoadingLocationData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: AppLoadingState(message: 'Loading location options...'),
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
                          label: 'Code',
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
                            if (code.isEmpty) {
                              return 'Select a code.';
                            }
                            if (!phoneCodes.contains(code)) {
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
                            label: 'Phone Number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: const Icon(Icons.phone_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your phone number.';
                              }
                              if (!RegExp(r'^[0-9\s-]{6,}$')
                                  .hasMatch(value.trim())) {
                                return 'Use digits only for the local phone number.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SearchableFormField(
                      controller: _countryController,
                      label: 'Country',
                      hint: 'Type to search',
                      options: countries.map((option) => option.country).toList(growable: false),
                      prefixIcon: const Icon(Icons.public_outlined),
                      optionLabelBuilder: (country) {
                        final option = countries.firstWhere(
                          (item) => item.country == country,
                          orElse: () => countries.first,
                        );
                        return '${option.flag} ${option.country}';
                      },
                      validator: (value) {
                        final country = value?.trim() ?? '';
                        if (country.isEmpty) {
                          return 'Select your country.';
                        }
                        if (!countries.any((option) => option.country == country)) {
                          return 'Pick a valid country.';
                        }
                        return null;
                      },
                      onSelected: _setCountry,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SearchableFormField(
                      controller: _stateController,
                      label: 'State',
                      hint: _selectedCountry.isEmpty
                          ? 'Select a country first'
                          : 'Type to search',
                      options: states,
                      enabled: _selectedCountry.isNotEmpty,
                      prefixIcon: const Icon(Icons.map_outlined),
                      optionLabelBuilder: (state) => state,
                      validator: (value) {
                        final state = value?.trim() ?? '';
                        if (_selectedCountry.isEmpty) {
                          return 'Select your country first.';
                        }
                        if (state.isEmpty) {
                          return 'Select your state.';
                        }
                        if (!states.contains(state)) {
                          return 'Pick a valid state.';
                        }
                        return null;
                      },
                      onSelected: _setState,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SearchableFormField(
                      controller: _cityController,
                      label: 'City',
                      hint: _selectedState.isEmpty
                          ? 'Select a state first'
                          : 'Type to search',
                      options: cities,
                      enabled: _selectedState.isNotEmpty,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      optionLabelBuilder: (city) => city,
                      validator: (value) {
                        final city = value?.trim() ?? '';
                        if (_selectedState.isEmpty) {
                          return 'Select your state first.';
                        }
                        if (city.isEmpty) {
                          return 'Select your city.';
                        }
                        if (!cities.contains(city)) {
                          return 'Pick a valid city.';
                        }
                        return null;
                      },
                      onSelected: _setCity,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint: 'Tell people a little about yourself. Max 150 characters.',
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
                    onPressed: (_isSavingProfile ||
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

  String _normalizeCountry(String value) {
    final trimmed = value.trim();
    for (final option in _countryOptions) {
      if (option.country.toLowerCase() == trimmed.toLowerCase()) {
        return option.country;
      }
    }
    return _countryOptions.first.country;
  }

  String _normalizeState(String value, String country) {
    final states = _statesFor(country);
    final trimmed = value.trim();
    for (final state in states) {
      if (state.toLowerCase() == trimmed.toLowerCase()) {
        return state;
      }
    }
    return states.first;
  }

  String _normalizeCity(String value, String country, String state) {
    final cities = _citiesFor(country, state);
    final trimmed = value.trim();
    for (final city in cities) {
      if (city.toLowerCase() == trimmed.toLowerCase()) {
        return city;
      }
    }
    return cities.first;
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

  List<String> _statesFor(String country) {
    for (final option in _countryOptions) {
      if (option.country == country) {
        return option.states
            .map((state) => state.name)
            .toSet()
            .toList(growable: false);
      }
    }
    return _countryOptions.first.states
        .map((state) => state.name)
        .toSet()
        .toList(growable: false);
  }

  List<String> _citiesFor(String country, String state) {
    for (final option in _countryOptions) {
      if (option.country == country) {
        for (final region in option.states) {
          if (region.name == state) {
            return region.cities.toSet().toList(growable: false);
          }
        }
        return option.states.first.cities.toSet().toList(growable: false);
      }
    }
    return _countryOptions.first.states.first.cities.toSet().toList(
          growable: false,
        );
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
    this.prefixIcon,
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
  final Widget? prefixIcon;
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
                  prefixIcon: widget.prefixIcon,
                  isDense: widget.width != null,
                  contentPadding: widget.width != null
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
  const _StateOption({
    required this.name,
    required this.cities,
  });

  final String name;
  final List<String> cities;
}

const List<_CountryOption> _countryOptions = [
  _CountryOption(
    country: 'Singapore',
    flag: '🇸🇬',
    dialCode: '+65',
    states: [
      _StateOption(
        name: 'Singapore',
        cities: ['Singapore'],
      ),
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
              child: profileImageProvider == null
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
