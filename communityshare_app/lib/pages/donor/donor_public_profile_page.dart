import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/item_listing.dart';
import '../../utils/image_utils.dart';
import '../../widgets/state_widgets.dart';

class DonorPublicProfilePage extends StatefulWidget {
  const DonorPublicProfilePage({
    super.key,
    required this.donorId,
    this.initialDonorData,
    this.highlightedItemId,
  });

  final String donorId;
  final Map<String, dynamic>? initialDonorData;
  final String? highlightedItemId;

  @override
  State<DonorPublicProfilePage> createState() => _DonorPublicProfilePageState();
}

class _DonorPublicProfilePageState extends State<DonorPublicProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoadingProfile = true;
  bool _isLoadingListings = true;
  Map<String, dynamic>? _donorData;
  List<ItemListing> _listings = const [];
  int _currentPage = 0;

  static const int _listingsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _donorData = widget.initialDonorData;
    _isLoadingProfile = widget.initialDonorData == null;
    _loadProfile();
    _loadListings();
  }

  Future<void> _loadProfile() async {
    try {
      final userDoc =
          await _firestore.collection('USER').doc(widget.donorId).get();
      final legacyDoc =
          await _firestore.collection('USER').doc(widget.donorId).get();
      final data = <String, dynamic>{
        ...?legacyDoc.data(),
        ...?userDoc.data(),
      };

      if (!mounted) {
        return;
      }

      setState(() {
        _donorData = data;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadListings() async {
    try {
      final snapshot = await _firestore
          .collection('ITEM_LISTING')
          .where('donorId', isEqualTo: widget.donorId)
          .get();

      final listings = snapshot.docs
          .map(ItemListing.fromFirestore)
          .toList(growable: false)
        ..sort((left, right) {
          final leftDate =
              left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        });

      if (!mounted) {
        return;
      }

      setState(() {
        _listings = listings;
        _currentPage = 0;
        _isLoadingListings = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _listings = const [];
        _isLoadingListings = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeListings = _listings.where((item) => item.isAvailable).length;
    final paginatedListings = _paginatedListings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_isLoadingProfile)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: AppLoadingState(message: 'Loading donor profile...'),
            )
          else
            _DonorHeroCard(
              donorId: widget.donorId,
              name: _donorDisplayName,
              roleLabel: _donorRoleLabel,
              statusLabel: _donorStatusLabel,
              bio: _donorBio,
              location: _donorLocation,
              phone: _donorPhoneLabel,
              profileImageUrl: _donorProfileImageUrl,
            ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryStat(
                      label: 'Listings',
                      value: '${_listings.length}',
                    ),
                  ),
                  Expanded(
                    child: _SummaryStat(
                      label: 'Available',
                      value: '$activeListings',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Donation / Listing History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Latest donations and listings from this donor.',
            style: TextStyle(color: AppColors.mist),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoadingListings)
            const AppLoadingState(message: 'Loading listing history...')
          else if (_listings.isEmpty)
            const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No donation history yet',
              message: 'This donor does not have any recorded listings yet.',
            )
          else
            ...paginatedListings.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ListingHistoryCard(
                  item: item,
                  highlighted: item.itemId == widget.highlightedItemId,
                ),
              ),
            ),
          if (_listings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPrevious:
                  _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
              onNext: _currentPage + 1 < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  String get _donorDisplayName {
    final fullName = (_donorData?['fullName'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final displayName = (_donorData?['displayName'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = (_donorData?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    return widget.donorId;
  }

  String get _donorBio {
    return (_donorData?['bio'] as String?)?.trim() ?? '';
  }

  String get _donorLocation {
    final city = (_donorData?['city'] as String?)?.trim();
    final state = (_donorData?['state'] as String?)?.trim();
    final country = (_donorData?['country'] as String?)?.trim();
    final parts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (state != null && state.isNotEmpty) state,
      if (country != null && country.isNotEmpty) country,
    ];

    return parts.isEmpty ? 'Location not provided' : parts.join(', ');
  }

  String get _donorPhoneLabel {
    final phone = (_donorData?['phoneNumber'] as String?)?.trim();
    final phoneCode = (_donorData?['phoneCountryCode'] as String?)?.trim();
    final localPhone = (_donorData?['phoneLocalNumber'] as String?)?.trim();

    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    final combined = [
      if (phoneCode != null && phoneCode.isNotEmpty) phoneCode,
      if (localPhone != null && localPhone.isNotEmpty) localPhone,
    ].join(' ').trim();

    return combined.isNotEmpty ? combined : 'Phone not provided';
  }

  String get _donorRoleLabel {
    final role = (_donorData?['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) {
      return _titleCaseLabel(role);
    }
    return 'Donor';
  }

  String get _donorStatusLabel {
    final status = (_donorData?['status'] as String?)?.trim();
    if (status != null && status.isNotEmpty) {
      return _titleCaseLabel(status);
    }
    return 'Active';
  }

  String get _donorProfileImageUrl {
    return (_donorData?['profileImageUrl'] as String?)?.trim() ?? '';
  }

  List<ItemListing> get _paginatedListings {
    final start = _currentPage * _listingsPerPage;
    if (start >= _listings.length) {
      return const [];
    }
    final end = (start + _listingsPerPage).clamp(0, _listings.length);
    return _listings.sublist(start, end);
  }

  int get _totalPages {
    if (_listings.isEmpty) {
      return 1;
    }
    return (_listings.length / _listingsPerPage).ceil();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) {
      return;
    }
    setState(() => _currentPage = page);
  }

  static String _titleCaseLabel(String value) {
    return value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final lower = part.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Page ${currentPage + 1} of $totalPages',
          style: const TextStyle(
            color: AppColors.sand,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: onPrevious == null ? AppColors.slate : AppColors.mint,
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: onNext == null ? AppColors.slate : AppColors.mint,
        ),
      ],
    );
  }
}

class _DonorHeroCard extends StatelessWidget {
  const _DonorHeroCard({
    required this.donorId,
    required this.name,
    required this.roleLabel,
    required this.statusLabel,
    required this.bio,
    required this.location,
    required this.phone,
    required this.profileImageUrl,
  });

  final String donorId;
  final String name;
  final String roleLabel;
  final String statusLabel;
  final String bio;
  final String location;
  final String phone;
  final String profileImageUrl;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: _profileImage(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DONOR',
                      style: TextStyle(
                        color: AppColors.sand,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'User ID: $donorId',
                      style: const TextStyle(
                        color: AppColors.sand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _HeroChip(label: roleLabel),
              _HeroChip(label: 'Status: $statusLabel'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoLine(icon: Icons.location_on_outlined, value: location),
          const SizedBox(height: AppSpacing.xs),
          _InfoLine(icon: Icons.phone_outlined, value: phone),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              bio,
              style: const TextStyle(color: AppColors.mist, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _profileImage() {
    if (profileImageUrl.isNotEmpty) {
      return ImageUtils.base64ToImage(
        profileImageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: _fallbackImage(),
      );
    }

    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: AppColors.forest,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        size: 34,
        color: AppColors.sand,
      ),
    );
  }
}

class _ListingHistoryCard extends StatelessWidget {
  const _ListingHistoryCard({
    required this.item,
    required this.highlighted,
  });

  final ItemListing item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlighted ? AppColors.mint : AppColors.pine,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: item.photoUrl.trim().isNotEmpty
                      ? ImageUtils.base64ToImage(
                          item.photoUrl,
                          fit: BoxFit.cover,
                          errorWidget: _imageFallback(),
                        )
                      : _imageFallback(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _HistoryPill(label: _titleCaseLabel(item.category)),
                        _HistoryPill(
                          label: item.isAvailable
                              ? 'Available'
                              : _titleCaseLabel(item.availabilityStatus),
                          color:
                              item.isAvailable ? AppColors.mint : AppColors.sand,
                        ),
                        if (highlighted)
                          const _HistoryPill(
                            label: 'Current item',
                            color: AppColors.sun,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mist,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Condition: ${item.condition}  |  Qty: ${item.quantity}',
                      style: const TextStyle(color: AppColors.sand),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Listed: ${_formatDate(item.createdAt)}',
                      style: const TextStyle(color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.night,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.mint,
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('MMM d, yyyy').format(value);
  }

  static String _titleCaseLabel(String value) {
    return value
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final lower = part.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: const TextStyle(color: AppColors.sand),
        ),
      ],
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

class _HistoryPill extends StatelessWidget {
  const _HistoryPill({
    required this.label,
    this.color = AppColors.pine,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.pine ? AppColors.sand : color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.value,
  });

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.sand),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.mist, height: 1.45),
          ),
        ),
      ],
    );
  }
}
