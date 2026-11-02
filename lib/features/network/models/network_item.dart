import 'package:you_too_art/features/talent/models/talent_model.dart';

class ConnectionItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String roles;
  final String connectedTimeAgo;
  final TalentModel talentModel;

  const ConnectionItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.roles,
    required this.connectedTimeAgo,
    required this.talentModel,
  });
}

class ConnectionRequestItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String roles;
  final TalentModel talentModel;

  const ConnectionRequestItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.roles,
    required this.talentModel,
  });
}

class NetworkSuggestionItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final String roles;
  final bool isRequested;
  final bool isFollowing;
  final TalentModel talentModel;

  const NetworkSuggestionItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.roles,
    this.isRequested = false,
    this.isFollowing = false,
    required this.talentModel,
  });

  bool get isProductionHouse =>
      talentModel.isProductionHouse ||
      roles.toLowerCase().contains('production') ||
      roles.toLowerCase().contains('studio') ||
      name.toLowerCase().contains('studio');

  NetworkSuggestionItem copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? roles,
    bool? isRequested,
    bool? isFollowing,
    TalentModel? talentModel,
  }) {
    return NetworkSuggestionItem(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      isRequested: isRequested ?? this.isRequested,
      isFollowing: isFollowing ?? this.isFollowing,
      talentModel: talentModel ?? this.talentModel,
    );
  }
}
