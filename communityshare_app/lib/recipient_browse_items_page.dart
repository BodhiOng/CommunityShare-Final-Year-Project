import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';
import 'models/item_listing.dart';
import 'recipient_item_details_page.dart';
import 'utils/image_utils.dart';
import 'widgets/state_widgets.dart';

class RecipientBrowseItemsPage extends StatefulWidget {
  const RecipientBrowseItemsPage({super.key});

  @override
  State<RecipientBrowseItemsPage> createState() =>
      _RecipientBrowseItemsPageState();
}

class _RecipientBrowseItemsPageState extends State<RecipientBrowseItemsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  bool _showFilters = false;
  List<ItemListing> _allListings = const [];

  String _selectedCategory = 'All';
  String _selectedCondition = 'All';
  String _selectedAvailability = 'Available';

  static const List<String> _availabilityOptions = [
    'Available',
    'All',
    'Reserved',
    'Claimed',
    'Expired',
  ];

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('ITEM_LISTING')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      final listings = snapshot.docs
          .map(ItemListing.fromFirestore)
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _allListings = listings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Unable to load recent listings. Check the ITEM_LISTING collection and try again.';
        _isLoading = false;
      });
    }
  }

  List<ItemListing> get _filteredListings {
    final query = _searchController.text.trim().toLowerCase();

    return _allListings.where((listing) {
      final matchesSearch = query.isEmpty ||
          listing.title.toLowerCase().contains(query) ||
          listing.description.toLowerCase().contains(query) ||
          listing.category.toLowerCase().contains(query);

      final matchesCategory = _selectedCategory == 'All' ||
          listing.category.toLowerCase() == _selectedCategory.toLowerCase();

      final matchesCondition = _selectedCondition == 'All' ||
          listing.condition.toLowerCase() == _selectedCondition.toLowerCase();

      final matchesAvailability = switch (_selectedAvailability) {
        'All' => true,
        'Available' => listing.isAvailable,
        _ => listing.availabilityStatus.toLowerCase() ==
            _selectedAvailability.toLowerCase(),
      };

      return matchesSearch &&
          matchesCategory &&
          matchesCondition &&
          matchesAvailability;
    }).toList(growable: false);
  }

  List<String> get _categories {
    final values = _allListings
        .map((listing) => listing.category)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<String> get _conditions {
    final values = _allListings
        .map((listing) => listing.condition)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredListings;

    return RefreshIndicator(
      onRefresh: _fetchListings,
      color: AppColors.mint,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by title, category, or description',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatusChip(
                      icon: Icons.schedule_rounded,
                      label: 'Recent first',
                    ),
                    _StatusChip(
                      icon: Icons.inventory_2_outlined,
                      label: '${filtered.length} shown',
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters
                      ? Icons.filter_alt_off_rounded
                      : Icons.tune_rounded,
                ),
                label: Text(_showFilters ? 'Hide filters' : 'Filters'),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedAvailability,
                      decoration: const InputDecoration(
                        labelText: 'Availability',
                      ),
                      items: _availabilityOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedAvailability = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      decoration: const InputDecoration(labelText: 'Condition'),
                      items: _conditions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCondition = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const SizedBox(
              height: 360,
              child: AppLoadingState(message: 'Loading item listings...'),
            )
          else if (_errorMessage != null)
            SizedBox(
              height: 360,
              child: AppErrorState(
                message: _errorMessage!,
                onRetry: _fetchListings,
              ),
            )
          else if (filtered.isEmpty)
            const SizedBox(
              height: 360,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching items',
                message:
                    'Try a broader search or reset the filters to see more listings.',
              ),
            )
          else
            ...filtered.map(
              (listing) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ListingCard(listing: listing),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing});

  final ItemListing listing;

  @override
  Widget build(BuildContext context) {
    final createdLabel = listing.createdAt != null
        ? DateFormat('MMM d, yyyy').format(listing.createdAt!)
        : 'Unknown date';
    final showExpiry = listing.category.toLowerCase() == 'consumables';
    final expiryLabel = showExpiry && listing.expiryDate != null
        ? DateFormat('MMM d, yyyy').format(listing.expiryDate!)
        : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecipientItemDetailsPage(item: listing),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: ImageUtils.base64ToImage(
                  listing.photoUrl,
                  width: 108,
                  height: 108,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    width: 108,
                    height: 108,
                    color: AppColors.night,
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.mint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _PillLabel(label: listing.category),
                        _PillLabel(
                          label: listing.isAvailable
                              ? 'Available'
                              : listing.availabilityStatus,
                          color: listing.isAvailable
                              ? AppColors.mint
                              : AppColors.coral,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      listing.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      listing.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mist,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetaText(
                          icon: Icons.layers_outlined,
                          text: 'Qty ${listing.quantity}',
                        ),
                        _MetaText(
                          icon: Icons.verified_outlined,
                          text: listing.condition,
                        ),
                        _MetaText(
                          icon: Icons.calendar_today_outlined,
                          text: 'Listed $createdLabel',
                        ),
                        if (showExpiry)
                          _MetaText(
                            icon: Icons.event_busy_outlined,
                            text: 'Expiry ${expiryLabel.isNotEmpty ? expiryLabel : 'Not set'}',
                          ),
                      ],
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
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
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
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.pine ? AppColors.sand : color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
  }) : light = false;

  final IconData icon;
  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final background = light
        ? AppColors.white.withValues(alpha: 0.12)
        : AppColors.forest;
    final foreground = light ? AppColors.white : AppColors.mint;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: light ? AppColors.sand : AppColors.mist,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.mint),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.mist,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
