import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:you_too_art/core/constants/geo_data.dart';
import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/geo_providers.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/core/utils/role_formatter.dart';
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
  bool _populated = false; // guard: only populate fields once

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _roleController = TextEditingController();
    _bioController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _experienceController = TextEditingController();
    _incorporationController = TextEditingController();
    _establishedYearController = TextEditingController();
    _addressController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Try the already-cached stream value first
      final cached = ref.read(currentUserProfileProvider).value;
      if (cached != null) {
        _populateFromUser(cached);
        return;
      }
      // Otherwise fetch directly from Supabase
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      try {
        final user =
            await ref.read(userRepositoryProvider).getById(uid);
        if (user != null && mounted) _populateFromUser(user);
      } catch (_) {}
    });
  }

  /// Fills all form fields from [user] (Supabase UserModel).
  /// Called once when the async profile resolves.
  void _populateFromUser(UserModel user) {
    if (_populated) return;
    _populated = true;

    final currentPersona = ref.read(userPersonaProvider);
    final isMatchingPersona = currentPersona.id == user.id;
    final persona = isMatchingPersona
        ? currentPersona
        : UserPersona(
            id: user.id,
            name: '',
            email: user.email,
            role: '',
            avatarUrl: '',
          );

    _isProd = user.role.toLowerCase().contains('production') ||
        (user.incorporationNumber != null &&
            user.incorporationNumber!.isNotEmpty) ||
        persona.isProductionHouse;

    final fullName = user.name.isNotEmpty
        ? user.name
        : (user.firstName.isNotEmpty
            ? '${user.firstName} ${user.lastName}'.trim()
            : persona.name);

    final clientUser = Supabase.instance.client.auth.currentUser;
    final isClientCurrentUser = clientUser != null && clientUser.id == user.id;
    final meta = isClientCurrentUser ? (clientUser.userMetadata ?? {}) : const <String, dynamic>{};
    final metaWebsite = meta['website'] as String? ?? '';
    final metaExp = meta['experience'] as String? ?? '';

    _nameController.text = fullName;
    final rawRole = (user.role.isNotEmpty && user.role != 'unset') ? user.role : persona.role;
    _roleController.text = _isProd ? 'Production House' : RoleFormatter.format(rawRole);
    _bioController.text = user.bio?.isNotEmpty == true ? user.bio! : persona.bio;
    _emailController.text =
        user.email.isNotEmpty ? user.email : persona.email;
    final initialWeb = (user.website != null && user.website!.isNotEmpty)
        ? user.website!
        : (metaWebsite.isNotEmpty
            ? metaWebsite
            : persona.website);
    final initialExp = (user.experience != null && user.experience!.isNotEmpty)
        ? user.experience!
        : (metaExp.isNotEmpty
            ? metaExp
            : persona.experience);

    bool isWebLike(String s) {
      final l = s.toLowerCase().trim();
      return l.startsWith('http://') ||
          l.startsWith('https://') ||
          l.startsWith('www.') ||
          l.contains('.com') ||
          l.contains('.org') ||
          l.contains('.net') ||
          l.contains('.pk') ||
          l.contains('.io') ||
          l.contains('.co');
    }

    bool isExpLike(String s) {
      final l = s.toLowerCase().trim();
      return l.contains('year') ||
          l.contains('yr') ||
          l.contains('exp') ||
          RegExp(r'^\d+\+?\s*(years?|yrs?)?', caseSensitive: false).hasMatch(l);
    }

    if (isWebLike(initialExp) && (isExpLike(initialWeb) || !isWebLike(initialWeb))) {
      _websiteController.text = initialExp;
      _experienceController.text = initialWeb;
    } else {
      _websiteController.text = initialWeb;
      _experienceController.text = initialExp;
    }
    _incorporationController.text = user.incorporationNumber ?? '';
    _establishedYearController.text =
        user.establishedYear != null ? '${user.establishedYear}' : '';
    _addressController.text = user.address ?? '';
    _avatarUrl = user.profileImagePath?.isNotEmpty == true
        ? user.profileImagePath
        : (persona.avatarUrl.isNotEmpty ? persona.avatarUrl : null);

    // Parse location: stored as "City, CountryName" or "City, CountryCode"
    final loc = user.location?.isNotEmpty == true ? user.location! : persona.location;
    if (loc.contains(',')) {
      final parts = loc.split(',');
      if (parts.length >= 2) {
        _selectedCity = parts[0].trim();
        final rawCountry = parts[1].trim();
        final allCountries = getCountries();
        final match = allCountries.where((c) {
          final code = c['code']?.toLowerCase();
          final name = c['name']?.toLowerCase();
          return code == rawCountry.toLowerCase() || name == rawCountry.toLowerCase();
        }).firstOrNull;
        _selectedCountry = match != null ? match['code'] : rawCountry;
      }
    }

    if (mounted) setState(() {});
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
      final currentPersona = ref.read(userPersonaProvider);
      final uid = ref.read(currentUidProvider);
      final clientUser = Supabase.instance.client.auth.currentUser;
      final isMatchingPersona = currentPersona.id == uid;
      final persona = isMatchingPersona
          ? currentPersona
          : UserPersona(
              id: uid ?? '',
              name: '',
              email: clientUser?.email ?? '',
              role: '',
              avatarUrl: '',
            );

      // Always fetch the latest DB row so we never overwrite existing data
      // with an empty form field that wasn't populated yet.
      UserModel? dbUser = ref.read(currentUserProfileProvider).value;
      if (dbUser == null && uid != null) {
        dbUser = await ref.read(userRepositoryProvider).getById(uid);
      }

      final countries = ref.read(countriesProvider).value ?? [];
      String? countryName = _selectedCountry;
      if (_selectedCountry != null) {
        final match =
            countries.where((c) => c['code'] == _selectedCountry).firstOrNull;
        if (match != null) countryName = match['name'] as String?;
      }

      // Keep existing location when user didn't touch the dropdowns.
      final existingLocation = dbUser?.location ?? persona.location;
      final locationStr = (_selectedCity != null && countryName != null)
          ? '$_selectedCity, $countryName'
          : (countryName ??
              (existingLocation.isNotEmpty ? existingLocation : ''));

      // Helper: use form value only if non-empty, else keep DB / persona value.
      String pick(String formVal, String? dbVal, [String fallback = '']) {
        if (formVal.isNotEmpty) return formVal;
        if (dbVal != null && dbVal.isNotEmpty) return dbVal;
        return fallback;
      }

      final isClientCurrentUser = clientUser != null && clientUser.id == uid;
      final meta = isClientCurrentUser ? (clientUser.userMetadata ?? {}) : const <String, dynamic>{};
      final metaWebsite = meta['website'] as String? ?? '';
      final metaExp = meta['experience'] as String? ?? '';

      final nameVal = pick(_nameController.text.trim(), dbUser?.name, persona.name);
      final bioVal = pick(_bioController.text.trim(), dbUser?.bio, persona.bio);
      final rawWeb = _websiteController.text.trim().isNotEmpty
          ? _websiteController.text.trim()
          : (dbUser?.website?.isNotEmpty == true
              ? dbUser!.website!
              : (metaWebsite.isNotEmpty ? metaWebsite : persona.website));
      final rawExp = _experienceController.text.trim().isNotEmpty
          ? _experienceController.text.trim()
          : (dbUser?.experience?.isNotEmpty == true
              ? dbUser!.experience!
              : (metaExp.isNotEmpty ? metaExp : persona.experience));

      String websiteVal = rawWeb;
      String expVal = rawExp;
      bool isWeb(String s) {
        final l = s.toLowerCase().trim();
        return l.startsWith('http://') ||
            l.startsWith('https://') ||
            l.startsWith('www.') ||
            l.contains('.com') ||
            l.contains('.org') ||
            l.contains('.net') ||
            l.contains('.pk') ||
            l.contains('.io') ||
            l.contains('.co');
      }
      bool isExp(String s) {
        final l = s.toLowerCase().trim();
        return l.contains('year') ||
            l.contains('yr') ||
            l.contains('exp') ||
            RegExp(r'^\d+\+?\s*(years?|yrs?)?', caseSensitive: false).hasMatch(l);
      }
      if (isWeb(expVal) && (isExp(websiteVal) || !isWeb(websiteVal))) {
        final temp = websiteVal;
        websiteVal = expVal;
        expVal = temp;
      }

      final updates = <String, dynamic>{
        if (bioVal.isNotEmpty) 'bio': bioVal,
        if (locationStr.isNotEmpty) 'location': locationStr,
        if (_avatarUrl != null) 'profile_image_path': _avatarUrl,
        if (websiteVal.isNotEmpty) 'website': websiteVal,
        if (expVal.isNotEmpty) 'experience': expVal,
      };

      if (_isProd) {
        if (nameVal.isNotEmpty) {
          updates['first_name'] = nameVal;
          updates['name'] = nameVal;
        }
        final addrVal = pick(_addressController.text.trim(), dbUser?.address, persona.location);
        if (addrVal.isNotEmpty) updates['address'] = addrVal;
        final incVal = pick(
            _incorporationController.text.trim(), dbUser?.incorporationNumber);
        if (incVal.isNotEmpty) updates['incorporation_number'] = incVal;
        final est = int.tryParse(_establishedYearController.text.trim());
        final existingEst = dbUser?.establishedYear;
        if (est != null || existingEst != null) {
          updates['established_year'] = est ?? existingEst;
        }
      } else {
        if (nameVal.isNotEmpty) {
          updates['name'] = nameVal;
          updates['first_name'] =
              nameVal.contains(' ') ? nameVal.split(' ').first : nameVal;
          updates['last_name'] = nameVal.contains(' ')
              ? nameVal.split(' ').sublist(1).join(' ')
              : '';
        }
        final roleVal = pick(_roleController.text.trim(), dbUser?.role == 'unset' ? '' : dbUser?.role, persona.role);
        if (roleVal.isNotEmpty) updates['role'] = RoleFormatter.format(roleVal);
      }

      // 1. Sync to Supabase PostgREST (public.users table)
      if (uid != null) {
        try {
          await ref
              .read(userRepositoryProvider)
              .updateProfile(uid: uid, updates: updates);
        } catch (_) {}
      }

      // 2. Sync to Supabase Auth user_metadata (preserves website, experience across devices & sessions)
      if (clientUser != null) {
        try {
          final authData = <String, dynamic>{
            if (nameVal.isNotEmpty) 'name': nameVal,
            if (bioVal.isNotEmpty) 'bio': bioVal,
            if (locationStr.isNotEmpty) 'location': locationStr,
            if (websiteVal.isNotEmpty) 'website': websiteVal,
            if (expVal.isNotEmpty) 'experience': expVal,
            if (_avatarUrl != null) 'avatar_url': _avatarUrl,
          };
          if (authData.isNotEmpty) {
            await Supabase.instance.client.auth.updateUser(UserAttributes(data: authData));
          }
        } catch (_) {}
      }

      // 3. Update local persistent persona
      final updatedPersona = persona.copyWith(
        id: uid ?? persona.id,
        name: nameVal.isNotEmpty ? nameVal : persona.name,
        role: _roleController.text.trim().isNotEmpty
            ? _roleController.text.trim()
            : persona.role,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : persona.email,
        bio: bioVal,
        website: websiteVal,
        experience: expVal,
        location: locationStr.isNotEmpty ? locationStr : persona.location,
        avatarUrl: _avatarUrl ?? persona.avatarUrl,
        isProductionHouse: _isProd,
      );

      AppPersistenceService.instance.savePersona(updatedPersona);
      await ref.read(userPersonaProvider.notifier).updateProfile(updatedPersona);

      // 4. Refresh feeds and directories
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

    // Populate fields whenever the stream delivers a user (handles fresh login
    // where the stream emits after initState has already run).
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (prev, next) {
      final user = next.value;
      if (user != null && !_populated) _populateFromUser(user);
    });

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
