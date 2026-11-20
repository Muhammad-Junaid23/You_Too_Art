import 'package:you_too_art/features/casting/models/casting_call_model.dart';

/// Utility to match a user's registered artist categories with a casting call's required role.
class CastingRoleMatcher {
  /// Checks whether [userRolesString] matches the role required by [call].
  static bool canUserApply({
    required String userRolesString,
    required CastingCallModel call,
    required bool isProductionHouse,
  }) {
    // Production Houses can never apply to casting calls
    if (isProductionHouse) return false;

    final userRoles = userRolesString.toLowerCase();
    if (userRoles.isEmpty) return false;

    final crewReq = call.crewRequired.toLowerCase();
    final pos = call.position.toLowerCase();
    final roleTitle = (call.roleTitle ?? '').toLowerCase();
    final target = '$crewReq $pos $roleTitle'.trim();

    if (target.isEmpty) return true;

    // Generic crew calls permit any artist
    if (target.contains('1 crew member') ||
        target.contains('any crew') ||
        target.contains('general crew') ||
        target.contains('all crew')) {
      return true;
    }

    // Normalize user role tokens into a set for exact token matching
    final rolesSet = userRoles
        .split(RegExp(r'[,|/•]+'))
        .map((s) => s.trim().replaceAll(' ', '_'))
        .where((s) => s.isNotEmpty)
        .toSet();

    bool hasAnyUserRole(List<String> keys) {
      for (final k in keys) {
        final normalized = k.toLowerCase().replaceAll(' ', '_');
        if (rolesSet.contains(normalized) || userRoles.contains(k.toLowerCase())) {
          return true;
        }
      }
      return false;
    }

    // 1. Cinematographer / Camera (Director of Photography / DP)
    // NOTE: Must check BEFORE Director so "Director of Photography" is never treated as Film Director.
    final isCameraCall = target.contains('cinematograph') ||
        target.contains('director of photography') ||
        target.contains('dop') ||
        target.contains('camera') ||
        target.contains('photograph');
    if (isCameraCall) {
      return hasAnyUserRole([
        'cinematographer',
        'director_of_photography',
        'camera_operator',
        'photographer',
        'dop',
      ]);
    }

    // 2. Art Director / Production Designer
    // NOTE: Must check BEFORE Director so "Art Director" is never treated as Film Director.
    final isArtCall = target.contains('art director') ||
        target.contains('production design') ||
        target.contains('set design');
    if (isArtCall) {
      return hasAnyUserRole([
        'art_director',
        'production_designer',
        'set_designer',
      ]);
    }

    // 3. Stunt Director / Stunt Performer
    final isStuntCall = target.contains('stunt');
    if (isStuntCall) {
      return hasAnyUserRole([
        'stunt_director',
        'stunt_performer',
        'stunt',
      ]);
    }

    // 4. Film / Theatre Director (excluding Art, Stunt, and Photography)
    final isDirectorCall = target.contains('director') &&
        !target.contains('art director') &&
        !target.contains('stunt') &&
        !target.contains('photography') &&
        !target.contains('dop');
    if (isDirectorCall) {
      // Must not match if user only has art_director or stunt_director
      final hasRealDirector = rolesSet.contains('director') ||
          rolesSet.contains('assistant_director') ||
          (userRoles.contains('director') &&
              !userRoles.contains('art_director') &&
              !userRoles.contains('stunt_director'));
      if (hasRealDirector) return true;
    }

    // 5. Actor / Actress / Performing Talent
    final isActingCall = crewReq.contains('actor') ||
        crewReq.contains('actress') ||
        pos.contains('actor') ||
        pos.contains('actress') ||
        target.contains('lead antagonist') ||
        target.contains('lead protagonist') ||
        target.contains('lead male') ||
        target.contains('lead female') ||
        target.contains('supporting role') ||
        target.contains('extra') ||
        target.contains('model') ||
        target.contains('standup comedian');
    if (isActingCall) {
      return hasAnyUserRole([
        'actor',
        'actress',
        'anchor',
        'comedian',
        'dubbing',
        'model',
        'voice_over_artist',
      ]);
    }

    // 6. Writer / Screenwriter
    final isWriterCall = target.contains('writer') ||
        target.contains('screenwriter') ||
        target.contains('script');
    if (isWriterCall) {
      return hasAnyUserRole(['writer', 'screenwriter', 'scriptwriter']);
    }

    // 7. Producer / Line Producer / Executive Producer
    final isProducerCall = target.contains('producer') || target.contains('line producer');
    if (isProducerCall) {
      return hasAnyUserRole(['producer', 'line_producer', 'executive_producer']);
    }

    // 8. Editor
    final isEditorCall = target.contains('editor') || target.contains('editing') || target.contains('colorist');
    if (isEditorCall) {
      return hasAnyUserRole(['editor', 'colorist']);
    }

    // 9. Sound / Audio / Music
    final isSoundCall = target.contains('sound') ||
        target.contains('audio') ||
        target.contains('sound mixing') ||
        target.contains('sound designer') ||
        target.contains('music');
    if (isSoundCall) {
      return hasAnyUserRole(['sound', 'musician', 'sound_engineer', 'composer']);
    }

    // 10. Singer / Vocalist
    final isSingerCall = target.contains('singer') || target.contains('vocal');
    if (isSingerCall) {
      return hasAnyUserRole(['singer', 'vocalist', 'musician']);
    }

    // 11. Dancer / Choreographer
    final isDanceCall = target.contains('dance') || target.contains('choreograph');
    if (isDanceCall) {
      return hasAnyUserRole(['dancer', 'choreographer']);
    }

    // 12. VFX / Animator
    final isVfxCall = target.contains('vfx') || target.contains('visual effects') || target.contains('animat');
    if (isVfxCall) {
      return hasAnyUserRole(['vfx', 'animator', 'vfx_artist']);
    }

    // 13. Costume Designer / Wardrobe / Stylist
    final isCostumeCall = target.contains('costume') || target.contains('wardrobe') || target.contains('stylist');
    if (isCostumeCall) {
      return hasAnyUserRole(['costume', 'costume_designer', 'stylist', 'wardrobe']);
    }

    // 14. Makeup Artist
    final isMakeupCall = target.contains('makeup');
    if (isMakeupCall) {
      return hasAnyUserRole(['makeup', 'makeup_artist']);
    }

    return false;
  }

  /// Returns the human-readable target role required by the call.
  static String targetRoleName(CastingCallModel call) {
    if (call.crewRequired.isNotEmpty && call.crewRequired != '1' && call.crewRequired != '1 Crew Member') {
      return call.crewRequired;
    }
    if (call.position.isNotEmpty) {
      return call.position;
    }
    return 'required';
  }
}
