import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/casting/providers/casting_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';

/// Create Casting Call screen strictly matching Figma Image 3.
class CreateCastingCallScreen extends ConsumerStatefulWidget {
  final CastingCallModel? callToEdit;

  const CreateCastingCallScreen({super.key, this.callToEdit});

  @override
  ConsumerState<CreateCastingCallScreen> createState() =>
      _CreateCastingCallScreenState();
}

class _CreateCastingCallScreenState
    extends ConsumerState<CreateCastingCallScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _cityController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleTitleController = TextEditingController();
  final _roleDescController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _shootDetailsController = TextEditingController();
  final _budgetController = TextEditingController();

  String? _selectedCrewType;
  String _selectedGender = 'Male Only';
  bool _isSubmitting = false;

  final List<String> _crewOptions = [
    'Actor',
    'Actress',
    'Director',
    'Cinematographer',
    'Screenwriter',
    'Producer',
    'Sound Designer',
    'Video Editor',
    'Art Director',
    '1 Crew Member',
  ];

  final List<String> _genderOptions = [
    'Male Only',
    'Female Only',
    'Any Gender',
    'Non-Binary / Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.callToEdit != null) {
      final c = widget.callToEdit!;
      _titleController.text = c.projectTitle;
      _descController.text = c.description;
      _cityController.text = c.locationDisplay;
      _emailController.text = c.contactEmail ?? '';
      _phoneController.text = c.contactNumber ?? '';
      _roleTitleController.text = c.roleTitle ?? '';
      _roleDescController.text = c.roleDescription ?? '';
      _ageController.text = c.ageRequired.replaceAll(' Years', '');
      _heightController.text = c.heightRequired.replaceAll(' Feet', '');
      _shootDetailsController.text = c.shootDetails;
      _budgetController.text = c.budget;
      _selectedCrewType = c.crewRequired.isNotEmpty ? c.crewRequired : null;
      _selectedGender = c.gender.isNotEmpty ? c.gender : 'Male Only';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _roleTitleController.dispose();
    _roleDescController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _shootDetailsController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _submitCastingCall() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final activeUser = ref.read(userPersonaProvider);
      final currentUser = ref.read(currentUserProfileProvider).value;
      final roleLower = '${activeUser.role} ${currentUser?.role ?? ''}'.toLowerCase();
      final isProductionHouse = activeUser.isProductionHouse ||
          roleLower.contains('production') ||
          roleLower.contains('studio') ||
          (currentUser?.incorporationNumber != null &&
              currentUser!.incorporationNumber!.isNotEmpty);
      final isFilmDirector = roleLower.contains('director') &&
          !roleLower.contains('art director') &&
          !roleLower.contains('stunt');
      final canCreateCasting = isProductionHouse ||
          isFilmDirector ||
          roleLower.contains('producer');

      if (widget.callToEdit == null && !canCreateCasting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Only Production Houses, Directors, and Producers can create casting calls.',
            ),
          ),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final now = DateTime.now();

      final cityText = _cityController.text.trim();
      final budgetText = _budgetController.text.trim();
      final shootDetailsText = _shootDetailsController.text.trim();
      final roleTitleText = _roleTitleController.text.trim();
      final ageText = _ageController.text.trim();
      final heightText = _heightController.text.trim();
      final emailText = _emailController.text.trim();
      final phoneText = _phoneController.text.trim();
      final roleDescText = _roleDescController.text.trim();

      final newCall = CastingCallModel(
        id: 'call_${now.millisecondsSinceEpoch}',
        projectTitle: _titleController.text.trim(),
        authorId: activeUser.id.isNotEmpty ? activeUser.id : 'current_user',
        authorName: activeUser.name.isNotEmpty ? activeUser.name : 'FilmFare',
        authorAvatar: activeUser.avatarUrl.isNotEmpty
            ? activeUser.avatarUrl
            : 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
        publishedDateStr: 'Just Now',
        publishedAt: now,
        description: _descController.text.trim(),
        location: cityText.isNotEmpty ? '$cityText, Pakistan' : 'Unspecified',
        locationDisplay: cityText.isNotEmpty ? cityText : 'Unspecified',
        type: _selectedCrewType ?? 'Short Film',
        shootDuration: shootDetailsText.isNotEmpty ? shootDetailsText : 'TBD',
        budget: budgetText.isNotEmpty ? budgetText : 'Negotiable',
        budgetFull: budgetText.isNotEmpty ? budgetText : 'Negotiable',
        crewRequired: _selectedCrewType ?? '1',
        shootDetails: shootDetailsText,
        position: roleTitleText.isNotEmpty
            ? roleTitleText
            : (_selectedCrewType ?? 'Actor'),
        ageRequired: ageText.isNotEmpty ? '$ageText Years' : 'Any',
        heightRequired: heightText.isNotEmpty ? '$heightText Feet' : 'Any',
        gender: _selectedGender,
        contactEmail: emailText.isNotEmpty ? emailText : null,
        contactNumber: phoneText.isNotEmpty ? phoneText : null,
        roleDescription: roleDescText.isNotEmpty ? roleDescText : null,
        applicantsCount: 0,
      );

      if (widget.callToEdit != null) {
        final updatedCall = widget.callToEdit!.copyWith(
          projectTitle: _titleController.text.trim(),
          description: _descController.text.trim(),
          location: cityText.isNotEmpty ? '$cityText, Pakistan' : 'Unspecified',
          locationDisplay: cityText.isNotEmpty ? cityText : 'Unspecified',
          type: _selectedCrewType ?? widget.callToEdit!.type,
          crewRequired: _selectedCrewType ?? '1 Crew Member',
          shootDuration: shootDetailsText.isNotEmpty ? shootDetailsText : widget.callToEdit!.shootDuration,
          shootDetails: shootDetailsText,
          budget: budgetText.isNotEmpty ? budgetText : 'Paid',
          budgetFull: budgetText.isNotEmpty ? budgetText : widget.callToEdit!.budgetFull,
          roleTitle: roleTitleText,
          ageRequired: ageText.isNotEmpty ? '$ageText Years' : 'Any',
          heightRequired: heightText.isNotEmpty ? '$heightText Feet' : 'Any',
          gender: _selectedGender,
          contactEmail: emailText.isNotEmpty ? emailText : null,
          contactNumber: phoneText.isNotEmpty ? phoneText : null,
          roleDescription: roleDescText.isNotEmpty ? roleDescText : null,
        );
        await ref.read(castingProvider.notifier).updateCastingCall(updatedCall);
      } else {
        await ref.read(castingProvider.notifier).createCastingCall(newCall);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00C48C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.callToEdit != null
                        ? 'Casting Call updated successfully!'
                        : 'Casting Call created successfully!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error creating casting call: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screen Title
                      Text(
                        widget.callToEdit != null ? 'Edit Casting Call' : 'Create Casting Call',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Project Title *
                      _buildLabel('Project Title', isRequired: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: _inputDecoration('Enter Project Title'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Project Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 2. Short Description *
                      _buildLabel('Short Description', isRequired: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: _inputDecoration('Enter short description'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Short Description is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 3. Crew Required *
                      _buildLabel('Crew Required', isRequired: true),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCrewType,
                        hint: const Text(
                          'Crew Type',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB0B7C3),
                          ),
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF1A1A2E),
                        ),
                        decoration: _inputDecoration('Crew Type'),
                        items: _crewOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt,
                            child: Text(
                              opt,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCrewType = val),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please select crew required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 4. City Name *
                      _buildLabel('City Name', isRequired: true),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _cityController,
                        decoration: _inputDecoration('Enter City Name'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'City Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 5. Contact Email
                      _buildLabel('Contact Email'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration('Enter Contact Email'),
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isNotEmpty &&
                              !RegExp(r'^[\w\.\-]+@[\w\.\-]+\.[a-zA-Z]{2,}$').hasMatch(trimmed)) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 6. Contact Number
                      _buildLabel('Contact Number'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d\s+\-()]')),
                          LengthLimitingTextInputFormatter(18),
                        ],
                        decoration: _inputDecoration('Enter Contact Number (e.g. +92 300 1234567)'),
                        validator: (val) {
                          final trimmed = val?.trim() ?? '';
                          if (trimmed.isNotEmpty) {
                            final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
                            if (digitsOnly.length < 7) {
                              return 'Contact number must be at least 7 digits';
                            }
                            if (digitsOnly.length > 15) {
                              return 'Contact number cannot exceed 15 digits';
                            }
                            if (!RegExp(r'^\+?[\d\s\-()]{7,18}$').hasMatch(trimmed)) {
                              return 'Please enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // 7. Role Title (Optional)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: _buildLabel('Role Title')),
                          const Text(
                            '(Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8E95A0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _roleTitleController,
                        decoration: _inputDecoration('Role Title'),
                      ),
                      const SizedBox(height: 18),

                      // 8. Role Description
                      _buildLabel('Role Description'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _roleDescController,
                        maxLines: 3,
                        decoration: _inputDecoration('Role Description'),
                      ),
                      const SizedBox(height: 18),

                      // 9. Age Required
                      _buildLabel('Age Required'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('23'),
                      ),
                      const SizedBox(height: 18),

                      // 10. Height Required (in Feet)
                      _buildLabel('Height Required (in Feet)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('5.9'),
                      ),
                      const SizedBox(height: 18),

                      // 11. Gender *
                      _buildLabel('Gender', isRequired: true),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGender,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF1A1A2E),
                        ),
                        decoration: _inputDecoration('Gender'),
                        items: _genderOptions.map((gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(
                              gender,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGender = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      // 12. Shoot Details
                      _buildLabel('Shoot Details'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _shootDetailsController,
                        maxLines: 3,
                        decoration: _inputDecoration('Enter Shoot Details'),
                      ),
                      const SizedBox(height: 18),

                      // 13. Budget / Remuneration
                      _buildLabel('Budget / Remuneration'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _budgetController,
                        decoration: _inputDecoration('Enter Your Budget'),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Buttons (Cancel & Submit)
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
                    // Cancel Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFEBEE),
                            foregroundColor: const Color(0xFFE53935),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Submit Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitCastingCall,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    widget.callToEdit != null ? 'Save Changes' : 'Submit',
                                    style: const TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        children: [
          TextSpan(text: text),
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFFB0B7C3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3899F3), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
