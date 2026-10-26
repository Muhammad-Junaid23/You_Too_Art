import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/features/casting/models/casting_application_model.dart';
import 'package:you_too_art/features/casting/providers/casting_provider.dart';

/// Applicant details screen matching Figma Image 4 (Screen 5).
class ApplicationDetailScreen extends ConsumerWidget {
  final CastingApplicationModel application;

  const ApplicationDetailScreen({
    super.key,
    required this.application,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch state to get reactive updates when status changes
    final state = ref.watch(castingProvider);
    final activeApp = state.applications.firstWhere(
      (a) => a.id == application.id,
      orElse: () => application,
    );

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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project Title
                    const Text(
                      'Project Title',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E95A0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeApp.projectTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Applicant Header Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFEEEEEE),
                          backgroundImage: (activeApp.applicantAvatar != null &&
                                  activeApp.applicantAvatar!.isNotEmpty)
                              ? NetworkImage(activeApp.applicantAvatar!)
                              : null,
                          child: (activeApp.applicantAvatar == null ||
                                  activeApp.applicantAvatar!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 22, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeApp.applicantName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF8E95A0),
                                  ),
                                  children: [
                                    const TextSpan(text: 'Applied, '),
                                    TextSpan(
                                      text: activeApp.appliedAt,
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
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Details List
                    _buildDetailItem('Contact Number', activeApp.contactNumber),
                    _buildDetailItem('Email', activeApp.contactEmail),
                    _buildDetailItem('Age', activeApp.age),
                    _buildDetailItem('Height', activeApp.height),
                    _buildDetailItem('Experience', activeApp.experience),
                    _buildDetailItem(
                      'Location',
                      activeApp.location,
                      isFlag: true,
                    ),
                    _buildDetailItem('Note', activeApp.note),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Bar: Wishlist + Reject + Accept
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
                child: Row(
                  children: [
                    // Wishlist Icon Button
                    InkWell(
                      onTap: () {
                        ref
                            .read(castingProvider.notifier)
                            .toggleWishlist(activeApp.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              activeApp.isWishlisted
                                  ? 'Removed from wishlist'
                                  : 'Added to wishlist',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: activeApp.isWishlisted
                              ? const Color(0xFF3899F3)
                              : const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF3899F3).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          activeApp.isWishlisted
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: activeApp.isWishlisted
                              ? Colors.white
                              : const Color(0xFF3899F3),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Reject Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: activeApp.isRejected
                              ? null
                              : () {
                                  ref
                                      .read(castingProvider.notifier)
                                      .updateApplicationStatus(
                                        activeApp.id,
                                        ApplicationStatus.rejected,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Application marked as rejected'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                          icon: const Icon(
                            Icons.block_flipped,
                            size: 18,
                            color: Color(0xFFE53935),
                          ),
                          label: Text(
                            activeApp.isRejected ? 'Rejected' : 'Reject',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE53935),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Accept Button
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: activeApp.isAccepted
                              ? null
                              : () {
                                  ref
                                      .read(castingProvider.notifier)
                                      .updateApplicationStatus(
                                        activeApp.id,
                                        ApplicationStatus.accepted,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Color(0xFF00C48C),
                                      content: Text('Application accepted! In-app notification sent.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                          icon: const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Color(0xFF00C48C),
                          ),
                          label: Text(
                            activeApp.isAccepted ? 'Accepted' : 'Accept',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00C48C),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8F8F3),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isFlag = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8E95A0),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (isFlag) ...[
                const Text('🇵🇰  ', style: TextStyle(fontSize: 15)),
              ],
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
