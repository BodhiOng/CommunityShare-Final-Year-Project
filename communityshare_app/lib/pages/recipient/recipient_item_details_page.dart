// ignore_for_file: use_build_context_synchronously

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../donor/donor_public_profile_page.dart';
import '../donor/donor_incoming_requests_page.dart';
import '../../models/item_listing.dart';
import 'recipient_request_status_page.dart';
import '../../utils/image_utils.dart';
import '../../widgets/state_widgets.dart';

class RecipientItemDetailsPage extends StatefulWidget {
  const RecipientItemDetailsPage({super.key, required this.item});

  final ItemListing item;

  @override
  State<RecipientItemDetailsPage> createState() =>
      _RecipientItemDetailsPageState();
}

enum _ItemDetailsMenuAction { report }

class _RecipientItemDetailsPageState extends State<RecipientItemDetailsPage> {
  static final Random _random = Random.secure();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _requestNoteController = TextEditingController();
  final TextEditingController _reportReasonController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSubmittingReport = false;
  bool _isLoadingDonor = true;
  bool _isLoadingRequest = true;
  Map<String, dynamic>? _donorData;
  RecipientRequestRecord? _currentRequest;
  late String _selectedHandoverType;

  @override
  void initState() {
    super.initState();
    _selectedHandoverType = _defaultHandoverType();
    _loadDonor();
    _loadCurrentRequest();
  }

  @override
  void dispose() {
    _requestNoteController.dispose();
    _reportReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDonor() async {
    try {
      final userDoc =
          await _firestore.collection('USER').doc(widget.item.donorId).get();
      final legacyDoc =
          await _firestore.collection('USER').doc(widget.item.donorId).get();
      final data = <String, dynamic>{...?legacyDoc.data(), ...?userDoc.data()};

      if (!mounted) {
        return;
      }

      setState(() {
        _donorData = data;
        _isLoadingDonor = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDonor = false;
      });
    }
  }

  Future<void> _loadCurrentRequest() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRequest = null;
        _isLoadingRequest = false;
      });
      return;
    }

    try {
      final snapshot =
          await _firestore
              .collection('ITEM_REQUEST')
              .where('itemId', isEqualTo: widget.item.itemId)
              .where('recipientId', isEqualTo: user.uid)
              .limit(10)
              .get();

      final docs = [...snapshot.docs]..sort((left, right) {
        final leftDate =
            _readDateTime(left.data()['updatedAt']) ??
            _readDateTime(left.data()['requestedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final rightDate =
            _readDateTime(right.data()['updatedAt']) ??
            _readDateTime(right.data()['requestedAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return rightDate.compareTo(leftDate);
      });

      QueryDocumentSnapshot<Map<String, dynamic>>? selected;
      for (final doc in docs) {
        final status = doc.data()['requestStatus']?.toString().trim() ?? '';
        if (_isActiveRequestStatus(status)) {
          selected = doc;
          break;
        }
      }
      selected ??= docs.isNotEmpty ? docs.first : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _currentRequest = selected == null ? null : _toRequestRecord(selected);
        _isLoadingRequest = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRequest = null;
        _isLoadingRequest = false;
      });
    }
  }

  Future<bool> _submitRequest() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to sign in before requesting an item.'),
        ),
      );
      return false;
    }

    if (!widget.item.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This listing is not available for requests.'),
        ),
      );
      return false;
    }

    final requestNote = _requestNoteController.text.trim();
    final handoverType = _selectedHandoverType;

    if (!_isAllowedHandoverType(handoverType)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose one of the handover methods offered by the donor.',
          ),
        ),
      );
      return false;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final existing =
          await _firestore
              .collection('ITEM_REQUEST')
              .where('itemId', isEqualTo: widget.item.itemId)
              .where('recipientId', isEqualTo: user.uid)
              .limit(10)
              .get();

      final hasActiveRequest = existing.docs.any((doc) {
        final data = doc.data();
        final status = (data['requestStatus'] as String? ?? '').toLowerCase();
        return status != 'cancelled' &&
            status != 'rejected' &&
            status != 'completed';
      });

      if (hasActiveRequest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You already have an active request for this item.'),
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return false;
      }

      final requestId = _newRequestId();
      final payload = <String, dynamic>{
        'requestId': requestId,
        'handoverType': handoverType,
        'itemId': widget.item.itemId,
        'recipientId': user.uid,
        'requestStatus': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (handoverType == 'community_hub_pickup') {
        payload['hubId'] = widget.item.hubId;
        payload['hubName'] = widget.item.hubName;
      }

      if (requestNote.isNotEmpty) {
        payload['requestNote'] = requestNote;
      }

      await _firestore.collection('ITEM_REQUEST').doc(requestId).set(payload);

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted. The donor can review it now.'),
        ),
      );
      await _loadCurrentRequest();
      return true;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit request: $e')));
      setState(() {
        _isSubmitting = false;
      });
      return false;
    }
  }

  String _newRequestId() {
    final digits = List.generate(13, (_) => _random.nextInt(10)).join();
    return 'req_$digits';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          PopupMenuButton<_ItemDetailsMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              switch (action) {
                case _ItemDetailsMenuAction.report:
                  if (!_isSubmittingReport) {
                    _showReportSheet();
                  }
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem<_ItemDetailsMenuAction>(
                    value: _ItemDetailsMenuAction.report,
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: AppColors.coral),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Report item/user',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: AppColors.coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 190),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ImageUtils.base64ToImage(
              item.photoUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: AppColors.forest,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 54,
                    color: AppColors.mint,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _DetailPill(
                      label: titleCaseLabel(item.category),
                      color: AppColors.pine,
                    ),
                    _DetailPill(
                      label:
                          item.isAvailable
                              ? 'Available'
                              : item.availabilityStatus,
                      color:
                          item.isAvailable ? AppColors.mint : AppColors.coral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        _DetailRow(label: 'Condition', value: item.condition),
                        _DetailRow(
                          label: 'Quantity',
                          value: '${item.quantity}',
                        ),
                        _DetailRow(
                          label: 'Listed',
                          value: _formatDate(item.createdAt),
                        ),
                        if (item.category.toLowerCase() == 'consumables')
                          _DetailRow(
                            label: 'Expiry',
                            value: _formatDate(item.expiryDate),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Description',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.description,
                  style: const TextStyle(color: AppColors.mist, height: 1.6),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Donor',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isLoadingDonor)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: AppLoadingState(message: 'Loading donor details...'),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => DonorPublicProfilePage(
                                donorId: widget.item.donorId,
                                initialDonorData: _donorData,
                                highlightedItemId: widget.item.itemId,
                              ),
                        ),
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipOval(
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: _donorProfileImage(),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _donorDisplayName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.sand,
                                ),
                              ],
                            ),
                            if (_donorBio.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                _donorBio,
                                style: const TextStyle(
                                  color: AppColors.mist,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                _DetailPill(
                                  label: _donorRoleLabel,
                                  color: AppColors.pine,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (item.category.toLowerCase() == 'consumables' &&
                    item.isExpired) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const AppErrorState(
                    message:
                        'This item is past its expiry date and cannot be requested.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: AppColors.night,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: _buildPrimaryActionButton(item),
          ),
        ),
      ),
    );
  }

  Future<void> _showRequestSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request ${widget.item.title}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _requestSheetDescription(),
                      style: const TextStyle(
                        color: AppColors.mist,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Handover Method',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const Text(
                              'Choose from the methods enabled by the donor for this listing.',
                              style: TextStyle(
                                color: AppColors.mist,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            RadioGroup<String>(
                              groupValue: _selectedHandoverType,
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setSheetState(() {
                                  _selectedHandoverType = value;
                                });
                              },
                              child: Column(
                                children: [
                                  if (widget.item.allowsIndependentPickup)
                                    const RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      value: 'independent_pickup',
                                      title: Text('Independent Pickup'),
                                      subtitle: Text(
                                        'Arrange the handover directly with the donor through the app.',
                                      ),
                                    ),
                                  if (_supportsCommunityHubPickup) ...[
                                    RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      value: 'community_hub_pickup',
                                      title: const Text('Community Hub Pickup'),
                                      subtitle: Text(
                                        widget.item.hubName.isNotEmpty
                                            ? 'Pick up through ${widget.item.hubName}.'
                                            : 'Pick up through the donor-selected community hub.',
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _SelectedHubSummary(
                                      hubName: widget.item.hubName,
                                      hubId: widget.item.hubId,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _requestNoteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Request note (optional)',
                        hintText: 'Add a note, or leave this blank.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () async {
                                  final success = await _submitRequest();
                                  if (success && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                        child: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit request',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showReportSheet() async {
    _reportReasonController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.forest,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
                final success = await _submitReport();
                if (success && context.mounted) {
                  Navigator.of(context).pop();
                } else if (context.mounted) {
                  setSheetState(() {});
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report ${widget.item.title}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Tell us why this listing is offensive, harmful, or inappropriate.',
                      style: TextStyle(color: AppColors.mist, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _reportReasonController,
                      maxLines: 5,
                      maxLength: 300,
                      decoration: InputDecoration(
                        labelText: 'Reason for report',
                        hintText: 'Type the reason for this report.',
                        fillColor: AppColors.night,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                          borderSide: BorderSide(
                            color: AppColors.coral.withValues(alpha: 0.28),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.coral,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmittingReport ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: AppColors.white,
                        ),
                        icon:
                            _isSubmittingReport
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                                : const Icon(Icons.flag_outlined),
                        label: Text(
                          _isSubmittingReport
                              ? 'Submitting report...'
                              : 'Submit report',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _submitReport() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to sign in before reporting an item.'),
        ),
      );
      return false;
    }

    if (user.uid == widget.item.donorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot report your own listing.')),
      );
      return false;
    }

    final reason = _reportReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a reason for the report.')),
      );
      return false;
    }

    setState(() {
      _isSubmittingReport = true;
    });

    try {
      final reportId = _newReportId();
      await _firestore.collection('REPORT').doc(reportId).set({
        'reportId': reportId,
        'reporterUserId': user.uid,
        'reportedUserId': widget.item.donorId,
        'itemId': widget.item.itemId,
        'reason': reason,
        'reportStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return false;
      }

      setState(() {
        _isSubmittingReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      setState(() {
        _isSubmittingReport = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit report: $error')),
      );
      return false;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Not set';
    }
    return DateFormat('MMM d, yyyy').format(value);
  }

  String _newReportId() {
    final digits = List.generate(13, (_) => _random.nextInt(10)).join();
    return 'report_$digits';
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

    return widget.item.donorId;
  }

  String get _donorBio {
    final bio = (_donorData?['bio'] as String?)?.trim();
    if (bio != null && bio.isNotEmpty) {
      return bio;
    }

    return '';
  }

  String get _donorRoleLabel {
    final role = (_donorData?['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty) {
      return role.toUpperCase();
    }

    return 'DONOR';
  }

  Widget _donorProfileImage() {
    final source = (_donorData?['profileImageUrl'] as String?)?.trim() ?? '';
    if (source.isNotEmpty) {
      return ImageUtils.base64ToImage(
        source,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: Container(
          color: AppColors.forest,
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.sand,
            size: 28,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.forest,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        color: AppColors.sand,
        size: 28,
      ),
    );
  }

  RecipientRequestRecord _toRequestRecord(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RecipientRequestRecord(
      requestId:
          data['requestId']?.toString().trim().isNotEmpty == true
              ? data['requestId'].toString().trim()
              : doc.id,
      docId: doc.id,
      itemId: data['itemId']?.toString().trim() ?? widget.item.itemId,
      itemDocId: '',
      itemTitle: widget.item.title,
      itemCategory: widget.item.category,
      itemQuantity: widget.item.quantity,
      availabilityStatus: widget.item.availabilityStatus,
      donorId: widget.item.donorId,
      handoverType: data['handoverType']?.toString().trim() ?? '',
      hubId: data['hubId']?.toString().trim() ?? '',
      hubName: data['hubName']?.toString().trim() ?? widget.item.hubName,
      requestNote: data['requestNote']?.toString().trim() ?? '',
      requestStatus: data['requestStatus']?.toString().trim() ?? 'pending',
      requestedAt: _readDateTime(data['requestedAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  Widget _buildPrimaryActionButton(ItemListing item) {
    if (_isLoadingRequest) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Checking request status...'),
      );
    }

    final request = _currentRequest;
    if (request != null && request.requestStatus.toLowerCase() == 'pending') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_top_rounded),
              label: const Text('Request Pending'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => RecipientRequestStatusPage(request: request),
                  ),
                );
                if (mounted) {
                  await _loadCurrentRequest();
                }
              },
              icon: const Icon(Icons.timeline_outlined),
              label: const Text('View Request Status'),
            ),
          ),
        ],
      );
    }

    if (request != null && _canTrackRequest(request.requestStatus)) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecipientRequestStatusPage(request: request),
              ),
            );
            if (mounted) {
              await _loadCurrentRequest();
            }
          },
          icon: const Icon(Icons.timeline_outlined),
          label: const Text('Track Request Status'),
        ),
      );
    }

    final canRequest = item.isAvailable && _hasRequestableHandoverOptions(item);
    return ElevatedButton.icon(
      onPressed: canRequest ? _showRequestSheet : null,
      icon:
          _isSubmitting
              ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
              : const Icon(Icons.volunteer_activism_outlined),
      label: Text(canRequest ? 'Request Item' : 'Not Requestable'),
    );
  }

  bool get _supportsCommunityHubPickup {
    return widget.item.allowsCommunityHubPickup && widget.item.hubId.isNotEmpty;
  }

  String _defaultHandoverType() {
    if (widget.item.allowsIndependentPickup) {
      return 'independent_pickup';
    }
    if (_supportsCommunityHubPickup) {
      return 'community_hub_pickup';
    }
    return '';
  }

  bool _isAllowedHandoverType(String value) {
    switch (value) {
      case 'independent_pickup':
        return widget.item.allowsIndependentPickup;
      case 'community_hub_pickup':
        return _supportsCommunityHubPickup;
      default:
        return false;
    }
  }

  bool _hasRequestableHandoverOptions(ItemListing item) {
    return item.allowsIndependentPickup ||
        (item.allowsCommunityHubPickup && item.hubId.isNotEmpty);
  }

  String _requestSheetDescription() {
    if (widget.item.allowsIndependentPickup && _supportsCommunityHubPickup) {
      return 'Choose either independent pickup or the donor-selected community hub when you submit this request.';
    }
    if (_supportsCommunityHubPickup) {
      return 'This listing is available through the donor-selected community hub only.';
    }
    return 'This listing is available through independent pickup only.';
  }

  static bool _isActiveRequestStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'approved':
      case 'reserved':
      case 'delivering':
      case 'delivering_to_hub':
      case 'delivering_to_recipient':
      case 'item_at_community_hub':
        return true;
      default:
        return false;
    }
  }

  static bool _canTrackRequest(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'reserved':
      case 'delivering':
      case 'delivering_to_hub':
      case 'delivering_to_recipient':
      case 'item_at_community_hub':
      case 'completed':
        return true;
      default:
        return false;
    }
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
}

class _SelectedHubSummary extends StatelessWidget {
  const _SelectedHubSummary({required this.hubName, required this.hubId});

  final String hubName;
  final String hubId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.mint.withValues(alpha: 0.35)),
        color: AppColors.pine.withValues(alpha: 0.18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hubName.isNotEmpty ? hubName : 'Community Hub',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Hub ID: ${hubId.isNotEmpty ? hubId : 'Not available'}',
            style: const TextStyle(color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'This hub was preselected by the donor for community hub pickup.',
            style: TextStyle(color: AppColors.mist, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.color});

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
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.pine ? AppColors.sand : color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.mist)),
          ),
        ],
      ),
    );
  }
}
