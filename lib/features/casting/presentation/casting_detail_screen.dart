import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/casting/presentation/apply_casting_screen.dart';
import 'package:you_too_art/features/casting/providers/casting_provider.dart';

/// Casting Call details screen matching Figma Image 1 (middle screen).
class CastingDetailScreen extends ConsumerWidget {
  final CastingCallModel call;

  const CastingDetailScreen({
    super.key,
    required this.call,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch latest state to reflect application status dynamically
    final state = ref.watch(castingProvider);
    final activeCall = state.calls.firstWhere(
      (c) => c.id == call.id,
      orElse: () => call,
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
                    // Project Title Label & Value
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
                      activeCall.projectTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Author Row
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFEEEEEE),
                          backgroundImage: (activeCall.authorAvatar != null &&
                                  activeCall.authorAvatar!.isNotEmpty)
                              ? NetworkImage(activeCall.authorAvatar!)
                              : null,
                          child: (activeCall.authorAvatar == null ||
                                  activeCall.authorAvatar!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 20, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeCall.authorName,
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
                                  fontSize: 12.5,
                                  color: Color(0xFF8E95A0),
                                ),
                                children: [
                                  const TextSpan(text: 'Published on '),
                                  TextSpan(
                                    text: activeCall.publishedDateStr,
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                    const SizedBox(height: 16),

                    // Description
                    _buildSectionHeader('Description'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.description,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF333333),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Location
                    _buildSectionHeader('Location'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('🇵🇰  ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            activeCall.location,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                    const SizedBox(height: 16),

                    // Crew Required
                    _buildSectionHeader('Crew Required'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.crewRequired,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Shoot Details
                    _buildSectionHeader('Shoot Details'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.shootDetails.isNotEmpty
                          ? activeCall.shootDetails
                          : 'No additional shoot details provided.',
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF333333),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                    const SizedBox(height: 16),

                    // Budget
                    _buildSectionHeader('Budget'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.budget,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF0F0F0), thickness: 1),
                    const SizedBox(height: 16),

                    // Role Details
                    _buildSectionHeader('Position'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.position,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Age'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.ageRequired.isNotEmpty
                          ? (activeCall.ageRequired.toLowerCase().contains('year')
                              ? activeCall.ageRequired
                              : '${activeCall.ageRequired} Years')
                          : 'Any',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Height'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.heightRequired,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _buildSectionHeader('Gender'),
                    const SizedBox(height: 6),
                    Text(
                      activeCall.gender,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Button
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
                  height: 52,
                  child: activeCall.isApplied
                      ? Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F3),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF00C48C), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Applied',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00C48C),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ApplyCastingScreen(call: activeCall),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Now',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF8E95A0),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
