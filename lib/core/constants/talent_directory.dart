import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// Central directory resolver.
/// Dynamically resolves real platform talents without dummy seed data.
class TalentDirectory {
  TalentDirectory._();

  static List<TalentModel> get allCuratedTalents => const [];

  static TalentModel? findById(String id) {
    if (id.isEmpty) return null;
    if (UserPersonaNotifier.hasPersona(id)) {
      final persona = UserPersonaNotifier.getPersonaById(id);
      final portfolio = AppPersistenceService.instance.getPortfolio(persona.id);
      final photos = portfolio.photos.map((p) => p.mediaUrl).toList();
      return TalentModel.fromPersona(
        persona,
        connectsCount: '0',
        postsCount: '${portfolio.videos.length + portfolio.photos.length}',
        workPortfolio: photos,
      );
    }
    return null;
  }
}
