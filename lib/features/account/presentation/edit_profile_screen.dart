import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/auth/providers/auth_provider.dart';
import 'package:you_too_art/features/home/providers/home_feed_provider.dart';
import 'package:you_too_art/features/network/providers/network_provider.dart';
import 'package:you_too_art/features/profile/widgets/profile_avatar_picker.dart';
import 'package:you_too_art/features/talent/providers/talent_provider.dart';

/// Edit Profile screen — lets the user update their real profile on Supabase.
/// Supports both Individual Artist and Production House profile attributes.
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
  late TextEditingController _incorporationController;
  late TextEditingController _establishedYearController;
  late TextEditingController _addressController;

  String? _avatarUrl;
  String? _selectedCountry;
  String? _selectedCity;
  bool _isSaving = false;
  bool _isProd = false;

  @override
  void initState() {
    super.initState();
    final persona = ref.read(userPersonaProvider);
    final user = ref.read(currentUserProfileProvider).value;

    _isProd = (user?.role.toLowerCase().contains('production') ?? false) ||
        (user?.incorporationNumber != null &&
            user!.incorporationNumber!.isNotEmpty) ||
        persona.isProductionHouse;

    final initialName = user?.name.isNotEmpty == true
        ? user!.name
        : (user?.firstName.isNotEmpty == true
            ? '${user!.firstName} ${user.lastName}'.trim()
            : persona.name);

    _nameController = TextEditingController(text: initialName);
    _roleController = TextEditingController(
      text: user?.role != null && user!.role != 'unset'
          ? user.role
          : persona.role,
    );
    _bioController = TextEditingController(text: user?.bio ?? persona.bio);
    _emailController = TextEditingController(text: user?.email ?? persona.email);
    _websiteController = TextEditingController(text: persona.website);
    _experienceController = TextEditingController(text: persona.experience);
    _incorporationController =
        TextEditingController(text: user?.incorporationNumber ?? '');
    _establishedYearController = TextEditingController(
      text: user?.establishedYear != null ? '${user!.establishedYear}' : '',
    );
    _addressController = TextEditingController(text: user?.address ?? '');
    _avatarUrl = user?.profileImagePath ?? persona.avatarUrl;

    // Parse location if present
    final loc = user?.location ?? persona.location;
    if (loc.contains(',')) {
      final parts = loc.split(',');
      if (parts.length >= 2) {
        _selectedCity = parts[0].trim();
        _selectedCountry = parts[1].trim();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _experienceController.dispose();
    _incorporationController.dispose();
    _establishedYearController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
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

      final uid = ref.read(currentUidProvider);

      final updates = <String, dynamic>{
        'bio': _bioController.text.trim(),
        'location': locationStr,
        if (_avatarUrl != null) 'profile_image_path': _avatarUrl,
      };

      if (_isProd) {
        updates['first_name'] = _nameController.text.trim();
        updates['name'] = _nameController.text.trim();
        updates['address'] = _addressController.text.trim();
        updates['incorporation_number'] =
            _incorporationController.text.trim();
        final est = int.tryParse(_establishedYearController.text.trim());
        if (est != null) updates['established_year'] = est;
      } else {
        final rawName = _nameController.text.trim();
        updates['name'] = rawName;
        updates['first_name'] =
            rawName.contains(' ') ? rawName.split(' ').first : rawName;
        updates['last_name'] =
            rawName.contains(' ') ? rawName.split(' ').sublist(1).join(' ') : '';
        if (_roleController.text.trim().isNotEmpty) {
          updates['role'] = _roleController.text.trim();
        }
      }

      // 1. Sync to Supabase PostgREST
      if (uid != null) {
        try {
          await ref
              .read(userRepositoryProvider)
              .updateProfile(uid: uid, updates: updates);
        } catch (_) {}
      }

      // 2. Update local persistent persona
      final updatedPersona = persona.copyWith(
        id: uid ?? persona.id,
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : persona.name,
        role: _roleController.text.trim().isNotEmpty
            ? _roleController.text.trim()
            : persona.role,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : persona.email,
        bio: _bioController.text.trim(),
        website: _websiteController.text.trim(),
        experience: _experienceController.text.trim(),
        location: locationStr.isNotEmpty ? locationStr : persona.location,
        avatarUrl: _avatarUrl ?? persona.avatarUrl,
        isProductionHouse: _isProd,
      );

      AppPersistenceService.instance.savePersona(updatedPersona);
      await ref.read(userPersonaProvider.notifier).updateProfile(updatedPersona);

      // 3. Refresh feeds and directories
      ref.invalidate(currentUserProfileProvider);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final countriesAsync = ref.watch(countriesProvider);

    // If _selectedCountry is a name rather than code, resolve to code
    if (_selectedCountry != null && countriesAsync.hasValue) {
      final list = countriesAsync.value!;
      final match = list.where((c) {
        final code = c['code'] as String?;
        final name = c['name'] as String?;
        return code?.toLowerCase() == _selectedCountry!.toLowerCase() ||
            name?.toLowerCase() == _selectedCountry!.toLowerCase();
      }).firstOrNull;
      if (match != null && _selectedCountry != match['code']) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCountry = match['code'] as String);
        });
      }
    }

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
        title: Text(
          _isProd ? 'Edit Production Profile' : 'Edit Profile',
          style: const TextStyle(
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

            // ─── Name / Company Name ─────────────────────────
            _buildLabel(_isProd ? 'Company Name' : 'Full Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _nameController,
              hint: _isProd ? 'Enter studio/production name' : 'Enter full name',
              prefixIcon: _isProd ? Icons.business : Icons.person_outline,
            ),
            const SizedBox(height: 20),

            if (!_isProd) ...[
              // ─── Role / Specialization (Individual) ────────
              _buildLabel('Role / Specialization'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _roleController,
                hint: 'e.g. Actor | Director | Producer',
                prefixIcon: Icons.work_outline,
              ),
              const SizedBox(height: 20),
            ],

            if (_isProd) ...[
              // ─── Incorporation Number ──────────────────────
              _buildLabel('Incorporation Number'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _incorporationController,
                hint: 'e.g. INC-12345678',
                prefixIcon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 20),

              // ─── Established Year ──────────────────────────
              _buildLabel('Established Year'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _establishedYearController,
                hint: 'e.g. 2018',
                prefixIcon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // ─── Office Address ────────────────────────────
              _buildLabel('Office / Studio Address'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _addressController,
                hint: 'e.g. Suite 400, Film City Road',
                prefixIcon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 20),
            ],

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

            // ─── Bio / Description ───────────────────────────
            _buildLabel(_isProd ? 'About Company' : 'Bio'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _bioController,
              hint: _isProd
                  ? 'Describe your production house and film projects...'
                  : 'Tell us about your background and skills...',
              prefixIcon: Icons.edit_note,
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // ─── Website ─────────────────────────────────────
            _buildLabel(_isProd ? 'Official Website' : 'Personal Website'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _websiteController,
              hint: 'e.g. www.studiofilms.com',
              prefixIcon: Icons.language,
            ),
            const SizedBox(height: 20),

            if (!_isProd) ...[
              // ─── Experience ──────────────────────────────────
              _buildLabel('Experience'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _experienceController,
                hint: 'e.g. 5+ Years',
                prefixIcon: Icons.star_outline_rounded,
              ),
              const SizedBox(height: 40),
            ] else ...[
              const SizedBox(height: 40),
            ],
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
    // Safety guard against Flutter DropdownButton assertion errors when value
    // is not present in the current items list.
    final effectiveValue =
        (value != null && items.any((i) => i.value == value)) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E7E8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
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
