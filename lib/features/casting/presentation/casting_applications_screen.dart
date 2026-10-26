import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/features/casting/models/casting_application_model.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/casting/presentation/application_detail_screen.dart';
import 'package:you_too_art/features/casting/providers/casting_provider.dart';
import 'package:you_too_art/features/casting/widgets/delete_casting_modal.dart';

/// Casting Applications management screen matching Figma Image 4 (Screens 1, 2, 3).
class CastingApplicationsScreen extends ConsumerStatefulWidget {
  final CastingCallModel call;

  const CastingApplicationsScreen({
    super.key,
    required this.call,
  });

  @override
  ConsumerState<CastingApplicationsScreen> createState() =>
      _CastingApplicationsScreenState();
}

class _CastingApplicationsScreenState
    extends ConsumerState<CastingApplicationsScreen> {
  int _selectedTabIndex = 0; // 0: Received, 1: Rejected, 2: Wishlist

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(castingProvider);

    // Watch the active call (or fallback if deleted)
    final activeCall = state.calls.firstWhere(
      (c) => c.id == widget.call.id,
      orElse: () => widget.call,
    );

    // Get applications relevant to this call
    final allApps = ref
        .read(castingProvider.notifier)
        .getApplicationsForCall(widget.call.id);

    // Filter by active tab
    final receivedApps = allApps
        .where((a) =>
            a.status == ApplicationStatus.received ||
            a.status == ApplicationStatus.accepted)
        .toList();
    final rejectedApps =
        allApps.where((a) => a.status == ApplicationStatus.rejected).toList();
    final wishlistApps = allApps
        .where((a) =>
            a.isWishlisted || a.status == ApplicationStatus.wishlisted)
        .toList();

    final List<CastingApplicationModel> displayedApps;
    if (_selectedTabIndex == 0) {
      displayedApps = receivedApps;
    } else if (_selectedTabIndex == 1) {
      displayedApps = rejectedApps;
    } else {
      displayedApps = wishlistApps;
    }

    final totalCount = allApps.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Applications title & applicant count
                    const Text(
                      'Applications',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalCount Applicants',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3899F3),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pinned Casting Call Card
                    _buildPinnedCallCard(activeCall),
                    const SizedBox(height: 18),

                    // 3 Tabs: Received, Rejected, Wishlist
                    _buildSubTabs(
                      receivedCount: receivedApps.length,
                      rejectedCount: rejectedApps.length,
                      wishlistCount: wishlistApps.length,
                    ),
                    const SizedBox(height: 18),

                    // Applicants List
                    if (displayedApps.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedApps.length,
                        itemBuilder: (ctx, idx) {
                          final app = displayedApps[idx];
                          return _buildApplicantCard(app);
                        },
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Sticky "Delete This Call" button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      DeleteCastingModal.show(
                        context,
                        call: activeCall,
                        onConfirmDelete: () {
                          ref
                              .read(castingProvider.notifier)
                              .deleteCastingCall(activeCall.id);
                          Navigator.pop(context); // close screen after deletion
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Casting Call deleted successfully'),
                            ),
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      foregroundColor: const Color(0xFFE53935),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Delete This Call',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedCallCard(CastingCallModel call) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            call.projectTitle,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Published, ${call.publishedDateStr}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E95A0),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetaCol('Location', call.locationDisplay),
              _buildMetaCol('Type', call.type),
              _buildMetaCol('Shoot', call.shootDuration),
              _buildMetaCol('Budget', call.budget),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8E95A0),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabs({
    required int receivedCount,
    required int rejectedCount,
    required int wishlistCount,
  }) {
    return Row(
      children: [
        _buildTabPill(0, Icons.description_outlined, 'Received ($receivedCount)'),
        const SizedBox(width: 8),
        _buildTabPill(1, Icons.block_flipped, 'Rejected ($rejectedCount)'),
        const SizedBox(width: 8),
        _buildTabPill(2, Icons.auto_awesome_outlined, 'Wishlist ($wishlistCount)'),
      ],
    );
  }

  Widget _buildTabPill(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0F6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFF3899F3) : const Color(0xFFE0E0E0),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFF3899F3)
                    : const Color(0xFF8E95A0),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF3899F3)
                      : const Color(0xFF8E95A0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicantCard(CastingApplicationModel app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFEFEF), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ApplicationDetailScreen(application: app),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Name + Wishlist/Options
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEEEEEE),
                      backgroundImage: (app.applicantAvatar != null &&
                              app.applicantAvatar!.isNotEmpty)
                          ? NetworkImage(app.applicantAvatar!)
                          : null,
                      child: (app.applicantAvatar == null ||
                              app.applicantAvatar!.isEmpty)
                          ? const Icon(Icons.person,
                              size: 20, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.applicantName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8E95A0),
                              ),
                              children: [
                                const TextSpan(text: 'Applied, '),
                                TextSpan(
                                  text: app.appliedAt,
                                  style: const TextStyle(
                                    color: Color(0xFF3899F3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Wishlist Icon
                    InkWell(
                      onTap: () {
                        ref
                            .read(castingProvider.notifier)
                            .toggleWishlist(app.id);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: app.isWishlisted
                              ? const Color(0xFF3899F3)
                              : Colors.transparent,
                          border: Border.all(
                            color: app.isWishlisted
                                ? const Color(0xFF3899F3)
                                : const Color(0xFFEAEAEA),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          app.isWishlisted
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 16,
                          color: app.isWishlisted
                              ? Colors.white
                              : const Color(0xFF3899F3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // 3-Dots Menu
                    InkWell(
                      onTap: () => _showApplicantMenu(app),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFEAEAEA), width: 0.8),
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          size: 16,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4-Column Metadata
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetaCol('Age', app.age),
                    _buildMetaCol('Height', app.height),
                    _buildMetaCol('Gender', app.gender),
                    _buildMetaCol('Experience', app.experience),
                  ],
                ),
                const SizedBox(height: 14),

                // Action Buttons: Accept & Reject (in Received or Wishlist tab)
                if (_selectedTabIndex != 1) ...[
                  Row(
                    children: [
                      // Accept Button
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: app.isAccepted
                                ? null
                                : () {
                                    ref
                                        .read(castingProvider.notifier)
                                        .updateApplicationStatus(
                                          app.id,
                                          ApplicationStatus.accepted,
                                        );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF00C48C),
                                        content: Text(
                                          'Accepted application from ${app.applicantName}. Notification sent!',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                            icon: const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Color(0xFF00C48C),
                            ),
                            label: Text(
                              app.isAccepted ? 'Accepted' : 'Accept',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00C48C),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F8F3),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Reject Button
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ref
                                  .read(castingProvider.notifier)
                                  .updateApplicationStatus(
                                    app.id,
                                    ApplicationStatus.rejected,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF1A1A2E),
                                  content: Text(
                                    'Moved ${app.applicantName} to Rejected tab',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    textColor: const Color(0xFF3899F3),
                                    onPressed: () {
                                      ref
                                          .read(castingProvider.notifier)
                                          .updateApplicationStatus(
                                            app.id,
                                            ApplicationStatus.received,
                                          );
                                    },
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.block_flipped,
                              size: 16,
                              color: Color(0xFFE53935),
                            ),
                            label: const Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFE53935),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFEBEE),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // If in Rejected tab: option to restore to received
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        ref
                            .read(castingProvider.notifier)
                            .updateApplicationStatus(
                              app.id,
                              ApplicationStatus.received,
                            );
                      },
                      icon: const Icon(Icons.restore_rounded, size: 16),
                      label: const Text('Move to Received'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3899F3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showApplicantMenu(CastingApplicationModel app) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('View Full Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ApplicationDetailScreen(application: app),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  app.isWishlisted ? Icons.bookmark_remove : Icons.bookmark_add,
                  color: const Color(0xFF3899F3),
                ),
                title: Text(
                  app.isWishlisted
                      ? 'Remove from Wishlist'
                      : 'Add to Wishlist',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(castingProvider.notifier).toggleWishlist(app.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_flipped, color: Colors.red),
                title: const Text('Reject Application',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(castingProvider.notifier)
                      .updateApplicationStatus(
                        app.id,
                        ApplicationStatus.rejected,
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              _selectedTabIndex == 1
                  ? Icons.check_circle_outline
                  : Icons.inbox_outlined,
              size: 48,
              color: const Color(0xFFB0B7C3),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedTabIndex == 0
                  ? 'No applications received yet.'
                  : _selectedTabIndex == 1
                      ? 'No rejected applications.'
                      : 'No wishlisted applicants.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E95A0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
