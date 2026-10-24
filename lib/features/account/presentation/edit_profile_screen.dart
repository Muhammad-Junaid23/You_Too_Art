import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/profile/widgets/profile_avatar_picker.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

/// Edit Profile screen — lets the active persona update their
/// name, bio, location, and avatar.
///
/// Since this is an internship project with multi-persona testing,
/// changes are applied to the local [UserPersona] state only
/// (no Supabase write for mock personas).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _experienceController;
  String? _avatarUrl;
  String? _selectedCountry;
  String? _selectedCity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final persona = ref.read(userPersonaProvider);
    _nameController = TextEditingController(text: persona.name);
    _roleController = TextEditingController(text: persona.role);
    _bioController = TextEditingController(text: persona.bio);
    _emailController = TextEditingController(text: persona.email);
    _websiteController = TextEditingController(text: persona.website);
    _experienceController = TextEditingController(text: persona.experience);
    _avatarUrl = persona.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    // Simulate a brief save delay for realism
    await Future.delayed(const Duration(milliseconds: 500));

    final persona = ref.read(userPersonaProvider);
    final countries = ref.read(countriesProvider).value ?? [];
    String? countryName = _selectedCountry;
    if (_selectedCountry != null) {
      final match =
          countries.where((c) => c['code'] == _selectedCountry).firstOrNull;
      if (match != null) {
        countryName = match['name'] as String?;
      }
    }

    final locationStr = (_selectedCity != null && countryName != null)
        ? '$_selectedCity, $countryName'
        : (countryName ?? persona.location);

    final updatedPersona = persona.copyWith(
      name: _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : persona.name,
      role: _roleController.text.trim().isNotEmpty
          ? _roleController.text.trim()
          : persona.role,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : persona.email,
      bio: _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : persona.bio,
      website: _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : persona.website,
      experience: _experienceController.text.trim().isNotEmpty
          ? _experienceController.text.trim()
          : persona.experience,
      location: locationStr.isNotEmpty ? locationStr : persona.location,
      avatarUrl: _avatarUrl ?? persona.avatarUrl,
    );

    await ref.read(userPersonaProvider.notifier).updateProfile(updatedPersona);
    ref.read(talentListProvider.notifier).fetchTalents();
    ref.read(networkProvider.notifier).refresh();

    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Profile updated successfully'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF00C48C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(countriesProvider);
    final citiesAsync = _selectedCountry == null
        ? const AsyncValue.data(<Map<String, dynamic>>[])
        : ref.watch(citiesProvider(_selectedCountry!));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3899F3),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF3899F3),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Avatar ──────────────────────────────────────
            Center(
              child: ProfileAvatarPicker(
                currentUrl: _avatarUrl,
                onUploaded: (url) => setState(() => _avatarUrl = url),
              ),
            ),
            const SizedBox(height: 28),

            // ─── Full Name ───────────────────────────────────
            _buildLabel('Full Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your full name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            // ─── Role / Specialization ───────────────────────
            _buildLabel('Role / Specialization'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _roleController,
              hint: 'e.g. Actor | Director | Producer',
              prefixIcon: Icons.work_outline,
            ),
            const SizedBox(height: 20),

            // ─── Email ───────────────────────────────────────
            _buildLabel('Email'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _emailController,
              hint: 'your.email@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            // ─── Location ────────────────────────────────────
            _buildLabel('Country'),
            const SizedBox(height: 6),
            _buildDropdown(
              value: _selectedCountry,
              hint: 'Select Country',
              items: countriesAsync.when(
                data: (list) => list
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['code'] as String,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                loading: () => const [],
                error: (e, st) => const [],
              ),
              onChanged: (v) {
                setState(() {
                  _selectedCountry = v;
                  _selectedCity = null;
                });
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('City'),
            const SizedBox(height: 6),
            _buildDropdown(
              value: _selectedCity,
              hint: 'Select City',
              items: citiesAsync.when(
                data: (list) => list
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['name'] as String,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                loading: () => const [],
                error: (e, st) => const [],
              ),
              onChanged: (v) => setState(() => _selectedCity = v),
            ),
            const SizedBox(height: 20),

            // ─── Bio ─────────────────────────────────────────
            _buildLabel('Bio'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _bioController,
              hint: 'Tell us about yourself...',
              prefixIcon: Icons.edit_note,
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // ─── Personal Website ─────────────────────────────
            _buildLabel('Personal Website'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _websiteController,
              hint: 'e.g. www.be.net/WajahatUIUX',
              prefixIcon: Icons.language,
            ),
            const SizedBox(height: 20),

            // ─── Experience ───────────────────────────────────
            _buildLabel('Experience'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _experienceController,
              hint: 'e.g. 5+ Years',
              prefixIcon: Icons.star_outline_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF616161),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFBDBDBD),
          fontSize: 14,
        ),
        prefixIcon: maxLines == 1
            ? Icon(prefixIcon, color: const Color(0xFF9E9E9E), size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E7E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE6E7E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF3899F3),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E7E8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF9E9E9E),
          ),
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
