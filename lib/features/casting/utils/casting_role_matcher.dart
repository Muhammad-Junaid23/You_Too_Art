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

    // 1. Actor / Actress / Performing Talent
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
      if (userRoles.contains('actor') ||
          userRoles.contains('actress') ||
          userRoles.contains('anchor') ||
          userRoles.contains('comedian') ||
          userRoles.contains('dubbing')) {
        return true;
      }
    }

    // 2. Director (excluding Art Director and Stunt Director)
    final isDirectorCall = (crewReq.contains('director') &&
            !crewReq.contains('art') &&
            !crewReq.contains('stunt')) ||
        (pos.contains('director') &&
            !pos.contains('art') &&
            !pos.contains('stunt') &&
            !pos.contains('photography'));
    if (isDirectorCall) {
      if (userRoles.contains('director') &&
          !userRoles.contains('art_director') &&
          !userRoles.contains('stunt_director')) {
        return true;
      }
    }

    // 3. Writer / Screenwriter
    final isWriterCall = target.contains('writer') ||
        target.contains('screenwriter') ||
        target.contains('script');
    if (isWriterCall && userRoles.contains('writer')) {
      return true;
    }

    // 4. Producer
    final isProducerCall = target.contains('producer') || target.contains('line producer');
    if (isProducerCall && userRoles.contains('producer')) {
      return true;
    }

    // 5. Cinematographer / Camera
    final isCameraCall = target.contains('cinematograph') ||
        target.contains('director of photography') ||
        target.contains('dop') ||
        target.contains('camera') ||
        target.contains('photograph');
    if (isCameraCall &&
        (userRoles.contains('cinematographer') ||
            userRoles.contains('photographer'))) {
      return true;
    }

    // 6. Editor
    final isEditorCall = target.contains('editor') || target.contains('editing');
    if (isEditorCall && userRoles.contains('editor')) {
      return true;
    }

    // 7. Sound / Audio / Music
    final isSoundCall = target.contains('sound') ||
        target.contains('audio') ||
        target.contains('sound mixing') ||
        target.contains('sound designer');
    if (isSoundCall &&
        (userRoles.contains('sound') ||
            userRoles.contains('musician') ||
            userRoles.contains('singer'))) {
      return true;
    }

    // 8. Singer
    final isSingerCall = target.contains('singer') || target.contains('vocal');
    if (isSingerCall &&
        (userRoles.contains('singer') || userRoles.contains('musician'))) {
      return true;
    }

    // 9. Dancer / Choreographer
    final isDanceCall = target.contains('dance') || target.contains('choreograph');
    if (isDanceCall &&
        (userRoles.contains('dancer') || userRoles.contains('choreographer'))) {
      return true;
    }

    // 10. VFX / Animator
    final isVfxCall = target.contains('vfx') || target.contains('visual effects');
    if (isVfxCall && userRoles.contains('vfx')) {
      return true;
    }

    // 11. Art Director / Set Design
    final isArtCall = target.contains('art director') || target.contains('production design');
    if (isArtCall && userRoles.contains('art_director')) {
      return true;
    }

    // 12. Costume Designer / Wardrobe
    final isCostumeCall = target.contains('costume') || target.contains('wardrobe') || target.contains('stylist');
    if (isCostumeCall && userRoles.contains('costume')) {
      return true;
    }

    // 13. Makeup Artist
    final isMakeupCall = target.contains('makeup');
    if (isMakeupCall && userRoles.contains('makeup')) {
      return true;
    }

    // 14. Stunt Director
    final isStuntCall = target.contains('stunt');
    if (isStuntCall && userRoles.contains('stunt')) {
      return true;
    }

    // Fallback: check each role token against target
    final userTokens = userRoles
        .split(RegExp(r'[,|/_ ]+'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.length > 2);
    for (final token in userTokens) {
      if (crewReq.contains(token) || pos.contains(token)) {
        return true;
      }
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
