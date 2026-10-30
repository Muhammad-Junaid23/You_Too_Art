import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/casting/models/casting_call_model.dart';
import 'package:you_too_art/features/casting/presentation/apply_casting_screen.dart';
import 'package:you_too_art/features/casting/presentation/casting_applications_screen.dart';
import 'package:you_too_art/features/casting/presentation/casting_detail_screen.dart';
import 'package:you_too_art/features/casting/presentation/create_casting_call_screen.dart';
import 'package:you_too_art/features/casting/providers/casting_provider.dart';
import 'package:you_too_art/features/casting/widgets/casting_call_card.dart';

/// Main Casting Calls screen with full-stack sync, search, filters,
/// and reactive multi-persona workflows matching Figma Images 1 & 2.
class CastingScreen extends ConsumerStatefulWidget {
  const CastingScreen({super.key});

  @override
  ConsumerState<CastingScreen> createState() => _CastingScreenState();
}

class _CastingScreenState extends ConsumerState<CastingScreen> {
  int _selectedTabIndex = 0; // 0: Casting Calls, 1: Applied, 2: My Casting Calls

  // Search & Filter State
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCity = 'All';
  String _selectedType = 'All';
  bool _showFilters = false;

  final List<String> _cities = ['All', 'Islamabad', 'Lahore', 'Karachi', 'Rawalpindi'];
  final List<String> _types = ['All', 'Short Film', 'Feature Film', 'Commercial', 'Web Series'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final castingState = ref.watch(castingProvider);
    final userPersona = ref.watch(userPersonaProvider);

    final castingNotifier = ref.read(castingProvider.notifier);

    // Calculate feed calls with search and filter applied,
    // dynamically enriched with user-specific application status!
    final rawFilteredCalls = castingNotifier.searchAndFilterCalls(
          query: _searchQuery,
          selectedCity: _selectedCity,
          selectedType: _selectedType,
        );

    final filteredCalls = rawFilteredCalls.map((call) {
      final isApplied = castingNotifier.isCallAppliedBy(call.id, userPersona.id);
      final appliedAt = castingNotifier.getAppliedAt(call.id, userPersona.id);
      return call.copyWith(
        isApplied: isApplied,
        appliedAt: appliedAt,
      );
    }).toList();

    final appliedCalls = castingNotifier.getAppliedCalls(userPersona.id);
    final myCalls = castingNotifier.getMyCalls(userPersona.id);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Tab Pills
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Casting Calls',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (castingState.isSyncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3899F3),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3 Tab Pills: Casting Calls, Applied, My Casting Calls
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabPill(
                          index: 0,
                          icon: Icons.auto_awesome_outlined,
                          label: 'Casting Calls',
                        ),
                        const SizedBox(width: 8),
                        _buildTabPill(
                          index: 1,
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Applied (${appliedCalls.length})',
                        ),
                        const SizedBox(width: 8),
                        _buildTabPill(
                          index: 2,
                          icon: Icons.auto_awesome_outlined,
                          label: 'My Casting Calls (${myCalls.length})',
                        ),
                      ],
                    ),
                  ),

                  // Search & Filter bar (for main Casting Calls feed)
                  if (_selectedTabIndex == 0) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F6F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search by title, role or city...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8E95A0),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF8E95A0),
                                  size: 19,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear,
                                          size: 16,
                                          color: Color(0xFF8E95A0),
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              setState(() => _showFilters = !_showFilters),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: _hasActiveFilters
                                  ? const Color(0xFF3899F3)
                                  : const Color(0xFFF5F6F8),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              size: 19,
                              color: _hasActiveFilters
                                  ? Colors.white
                                  : const Color(0xFF555555),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Filter Chips expandable row
                    if (_showFilters) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'City: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E95A0),
                              ),
                            ),
                            ..._cities.map((city) {
                              final isSelected = _selectedCity == city;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(city),
                                  selected: isSelected,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  selectedColor: const Color(0xFF3899F3),
                                  backgroundColor: const Color(0xFFF0F0F0),
                                  onSelected: (_) =>
                                      setState(() => _selectedCity = city),
                                ),
                              );
                            }),
                            const SizedBox(width: 8),
                            const Text(
                              'Type: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF8E95A0),
                              ),
                            ),
                            ..._types.map((type) {
                              final isSelected = _selectedType == type;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(type),
                                  selected: isSelected,
                                  labelStyle: TextStyle(
                                    fontSize: 11.5,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1A1A2E),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  selectedColor: const Color(0xFF3899F3),
                                  backgroundColor: const Color(0xFFF0F0F0),
                                  onSelected: (_) =>
                                      setState(() => _selectedType = type),
                                ),
                              );
                            }),
                            if (_hasActiveFilters) ...[
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCity = 'All';
                                    _selectedType = 'All';
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

            // Content List based on selected tab
            Expanded(
              child: _buildTabContent(
                filteredCalls: filteredCalls,
                appliedCalls: appliedCalls,
                myCalls: myCalls,
                userPersonaId: userPersona.id,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedCity != 'All' || _selectedType != 'All' || _searchQuery.isNotEmpty;

  Widget _buildTabPill({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3899F3) : const Color(0xFFE0E0E0),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildTabContent({
    required List<CastingCallModel> filteredCalls,
    required List<CastingCallModel> appliedCalls,
    required List<CastingCallModel> myCalls,
    required String userPersonaId,
  }) {
    if (_selectedTabIndex == 0) {
      // ─── TAB 0: All Casting Calls Feed (Search & Filtered) ───
      if (filteredCalls.isEmpty) {
        return _buildEmptyState(
          _hasActiveFilters
              ? 'No casting calls match your search and filter criteria.'
              : 'No casting calls available right now.',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: filteredCalls.length,
        itemBuilder: (ctx, idx) {
          final call = filteredCalls[idx];
          final isMyCall = call.authorId == userPersonaId ||
              AppPersistenceService.instance.isSamePersona(call.authorId, userPersonaId);
          return CastingCallCard(
            call: call,
            isMyCall: isMyCall,
            onTap: () => _openDetail(call),
            onApply: () => _openApply(call),
            onViewApplications: isMyCall ? () => _openApplications(call) : null,
          );
        },
      );
    } else if (_selectedTabIndex == 1) {
      // ─── TAB 1: Applied Calls ────────────────────────────────
      if (appliedCalls.isEmpty) {
        return _buildEmptyState(
          'You haven\'t applied to any casting calls yet.\nBrowse the feed and apply to exciting opportunities!',
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: appliedCalls.length,
        itemBuilder: (ctx, idx) {
          final call = appliedCalls[idx];
          return CastingCallCard(
            call: call,
            onTap: () => _openDetail(call),
            onApply: () => _openApply(call),
          );
        },
      );
    } else {
      // ─── TAB 2: My Casting Calls ─────────────────────────────
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          // "+ Create Casting Call" Button (Auto-switches here upon creation)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _openCreateCall,
              icon: const Icon(Icons.add, color: Colors.white, size: 20),
              label: const Text(
                'Create Casting Call',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (myCalls.isEmpty)
            _buildEmptyState('You haven\'t created any casting calls yet.')
          else
            ...myCalls.map(
              (call) => CastingCallCard(
                call: call,
                isMyCall: true,
                onTap: () => _openDetail(call),
                onApply: () => _openApply(call),
                onViewApplications: () => _openApplications(call),
                onEdit: () => _openEditCall(call),
                onDelete: () {
                  ref
                      .read(castingProvider.notifier)
                      .deleteCastingCall(call.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Casting Call deleted'),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    }
  }

  Future<void> _openCreateCall() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateCastingCallScreen(),
      ),
    );

    // Auto-switch to "My Casting Calls" tab upon creating a new call!
    if (created == true && mounted) {
      setState(() => _selectedTabIndex = 2);
    }
  }

  Future<void> _openDetail(CastingCallModel call) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CastingDetailScreen(call: call),
      ),
    );
  }

  Future<void> _openApply(CastingCallModel call) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApplyCastingScreen(call: call),
      ),
    );
  }

  Future<void> _openApplications(CastingCallModel call) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CastingApplicationsScreen(call: call),
      ),
    );
  }

  Future<void> _openEditCall(CastingCallModel call) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCastingCallScreen(callToEdit: call),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.campaign_outlined,
              size: 54,
              color: Color(0xFFB0B7C3),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF8E95A0),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
