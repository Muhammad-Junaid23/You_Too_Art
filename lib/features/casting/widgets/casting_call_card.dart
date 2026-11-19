import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/casting/widgets/delete_casting_modal.dart';

/// Casting Call card widget strictly matching Figma Images 1 & 2.
class CastingCallCard extends StatelessWidget {
  final CastingCallModel call;
  final bool isMyCall;
  final bool isProductionHouse;
  final bool canApply;
  final VoidCallback onTap;
  final VoidCallback onApply;
  final VoidCallback? onViewApplications;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const CastingCallCard({
    super.key,
    required this.call,
    this.isMyCall = false,
    this.isProductionHouse = false,
    this.canApply = true,
    required this.onTap,
    required this.onApply,
    this.onViewApplications,
    this.onDelete,
    this.onEdit,
  });

  void _showOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(
                    text: 'https://youtooart.com/casting/${call.id}',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border_rounded),
                title: const Text('Save Casting Call'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Casting call saved!')),
                  );
                },
              ),
              if (isMyCall && onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF3899F3)),
                  title: const Text('Edit Casting Call'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit!();
                  },
                ),
              if (isMyCall && onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red),
                  title: const Text('Delete Call',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    DeleteCastingModal.show(
                      context,
                      call: call,
                      onConfirmDelete: onDelete!,
                    );
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: Colors.red),
                  title: const Text('Report Call',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thank you. We will review this call.'),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Title/Author + Action icons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFEEEEEE),
                      backgroundImage: (call.authorAvatar != null &&
                              call.authorAvatar!.isNotEmpty)
                          ? NetworkImage(call.authorAvatar!)
                          : null,
                      child: (call.authorAvatar == null ||
                              call.authorAvatar!.isEmpty)
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
                            call.projectTitle,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMyCall
                                ? 'Published, ${call.publishedDateStr}'
                                : call.authorName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E95A0),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Top Action Icons (Decongested)
                    if (isMyCall && onEdit != null) ...[
                      // Edit Icon
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F2FD),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: Color(0xFF3899F3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // More Options Icon (opens complete options sheet with Delete, Copy Link/Share, Save)
                    InkWell(
                      onTap: () => _showOptionsModal(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFEAEAEA), width: 0.8),
                        ),
                        child: const Icon(
                          Icons.more_vert_rounded,
                          size: 17,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Responsive Metadata Grid (2x2 on narrow viewports < 380px, 4-column on wider)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final shootText = (call.shootDuration.isNotEmpty && call.shootDuration != 'TBD')
                        ? call.shootDuration
                        : (call.shootDetails.isNotEmpty ? call.shootDetails : 'TBD');

                    if (constraints.maxWidth < 360) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              _buildMetaColumn('Location', call.locationDisplay),
                              const SizedBox(width: 12),
                              _buildMetaColumn('Type', call.type),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildMetaColumn('Shoot', shootText),
                              const SizedBox(width: 12),
                              _buildMetaColumn('Budget', call.budget),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        _buildMetaColumn('Location', call.locationDisplay),
                        const SizedBox(width: 8),
                        _buildMetaColumn('Type', call.type),
                        const SizedBox(width: 8),
                        _buildMetaColumn('Shoot', shootText),
                        const SizedBox(width: 8),
                        _buildMetaColumn('Budget', call.budget),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // Bottom Content
                if (isMyCall) ...[
                  // Blue Applicants Banner for My Casting Calls
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Applicants',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF757575),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${call.applicantsCount}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3899F3),
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: InkWell(
                            onTap: onViewApplications,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'View Applications',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3899F3),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Color(0xFF3899F3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Normal Tab: Either Applied Badge or Black "Apply Now" Button
                  if (call.isApplied)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: Color(0xFF00C48C),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Applied, ${call.appliedAt ?? '2 Days Ago'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00C48C),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!isProductionHouse && canApply)
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Apply Now',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildMetaColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E95A0),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
