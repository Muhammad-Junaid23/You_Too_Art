import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

enum ConnectionStatus {
  none,
  pendingOutgoing,
  pendingIncoming,
  connected,
}

class TalentModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String roles;
  final ConnectionStatus connectionStatus;
  final bool isFollowing;
  final bool _isProductionHouse;
  bool get isProductionHouse =>
      _isProductionHouse ||
      roles.toLowerCase().contains('production') ||
      roles.toLowerCase().contains('studio') ||
      roles.toLowerCase().contains('house') ||
      name.toLowerCase().contains('studio') ||
      name.toLowerCase().contains('production');

  final String connectsCount;
  final String postsCount;
  final String followersCount;
  final String? email;
  final String? bio;
  final String? location;
  final List<PostItem> posts;
  final Map<String, String> aboutInfo;
  final List<String> workPortfolio;

  const TalentModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.roles,
    this.connectionStatus = ConnectionStatus.none,
    this.isFollowing = false,
    bool? isProductionHouse,
    this.connectsCount = '0',
    this.postsCount = '0',
    this.followersCount = '0',
    this.email,
    this.bio,
    this.location,
    this.posts = const [],
    this.aboutInfo = const {},
    this.workPortfolio = const [],
  }) : _isProductionHouse = isProductionHouse ?? false;

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  bool get isPending =>
      connectionStatus == ConnectionStatus.pendingOutgoing ||
      connectionStatus == ConnectionStatus.pendingIncoming;
  bool get isPendingOutgoing =>
      connectionStatus == ConnectionStatus.pendingOutgoing;
  bool get isPendingIncoming =>
      connectionStatus == ConnectionStatus.pendingIncoming;

  factory TalentModel.fromPersona(
    UserPersona persona, {
    ConnectionStatus connectionStatus = ConnectionStatus.none,
    bool isFollowing = false,
    String connectsCount = '0',
    String? postsCount,
    String followersCount = '0',
    List<PostItem> posts = const [],
    Map<String, String>? aboutInfo,
    List<String>? workPortfolio,
  }) {
    final portfolio = AppPersistenceService.instance.getPortfolio(persona.id);
    final photos = workPortfolio ?? portfolio.photos.map((p) => p.mediaUrl).toList();
    final calculatedPosts = postsCount ?? '${portfolio.videos.length + portfolio.photos.length}';

    final mergedAbout = Map<String, String>.from(aboutInfo ?? {});
    if (persona.website.isNotEmpty) {
      mergedAbout['Personal Website'] = persona.website;
    }
    if (persona.experience.isNotEmpty) {
      mergedAbout['Experience'] = persona.experience;
    }
    if (persona.location.isNotEmpty) {
      mergedAbout['Location'] = persona.location;
    }
    if (persona.email.isNotEmpty) mergedAbout['Email'] = persona.email;
    if (persona.role.isNotEmpty && !mergedAbout.containsKey('Category')) {
      mergedAbout['Category'] = persona.role;
    }
    if (persona.bio.isNotEmpty && !mergedAbout.containsKey('Bio')) {
      mergedAbout['Bio'] = persona.bio;
    }

    return TalentModel(
      id: persona.id,
      name: persona.name,
      avatarUrl: persona.avatarUrl,
      roles: persona.role,
      connectionStatus: connectionStatus,
      isFollowing: isFollowing,
      isProductionHouse: persona.isProductionHouse,
      connectsCount: connectsCount,
      postsCount: calculatedPosts,
      followersCount: followersCount,
      email: persona.email,
      bio: persona.bio,
      location: persona.location,
      posts: posts,
      aboutInfo: mergedAbout,
      workPortfolio: photos,
    );
  }

  factory TalentModel.fromUser(
    UserModel user, {
    ConnectionStatus connectionStatus = ConnectionStatus.none,
    bool isFollowing = false,
  }) {
    final roleLower = user.role.toLowerCase();
    final isProd = roleLower.contains('production') ||
        roleLower.contains('house') ||
        roleLower.contains('studio') ||
        user.name.toLowerCase().contains('studio') ||
        (user.incorporationNumber != null &&
            user.incorporationNumber!.isNotEmpty);

    String rolesStr = isProd ? 'Production House' : 'Actor | Model | Director';
    if (user.role.isNotEmpty && user.role.toLowerCase() != 'unset') {
      rolesStr = user.role.split('_').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
    }
    if (user.bio != null &&
        user.bio!.trim().isNotEmpty &&
        rolesStr == 'Actor | Model | Director') {
      rolesStr = user.bio!.trim();
    }

    return TalentModel(
      id: user.id,
      name: user.name.isNotEmpty ? user.name : (isProd ? 'Film Studio' : 'Artist'),
      avatarUrl: user.profileImagePath,
      roles: rolesStr,
      connectionStatus: connectionStatus,
      isFollowing: isFollowing,
      isProductionHouse: isProd,
      connectsCount: isProd ? '0' : '0',
      followersCount: '0',
      email: user.email,
      bio: user.bio ?? (isProd
          ? 'Official Production House profile on You Too Art.'
          : 'Passionate artist and creator on You Too Art.'),
      location: user.location ?? (user.address ?? 'Los Angeles, CA'),
      aboutInfo: {
        'Category': isProd ? 'Production House' : 'Performing Arts',
        if (user.email.isNotEmpty) 'Email': user.email,
        if (user.location != null && user.location!.isNotEmpty)
          'Location': user.location!,
        if (user.address != null && user.address!.isNotEmpty)
          'Address': user.address!,
        if (user.establishedYear != null)
          'Established': '${user.establishedYear}',
        if (user.incorporationNumber != null &&
            user.incorporationNumber!.isNotEmpty)
          'Incorporation': user.incorporationNumber!,
      },
    );
  }

  factory TalentModel.fromJson(
    Map<String, dynamic> json, {
    ConnectionStatus connectionStatus = ConnectionStatus.none,
    bool isFollowing = false,
  }) {
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    final rawName = '$firstName $lastName'.trim();
    final name =
        rawName.isNotEmpty ? rawName : (json['name'] as String? ?? 'Artist');

    final role = json['role'] as String? ?? '';
    final isProd = role.toLowerCase().contains('production') ||
        role.toLowerCase().contains('studio') ||
        role.toLowerCase().contains('house') ||
        name.toLowerCase().contains('studio') ||
        name.toLowerCase().contains('production') ||
        json['incorporation_number'] != null;

    final rolesStr = (role.isNotEmpty && role.toLowerCase() != 'unset')
        ? role
        : (isProd ? 'Production House' : 'Actor | Model | Director');

    return TalentModel(
      id: json['id'] as String? ?? '',
      name: name,
      avatarUrl: (json['profile_image_path'] ?? json['avatar_url']) as String?,
      roles: rolesStr,
      connectionStatus: connectionStatus,
      isFollowing: isFollowing,
      isProductionHouse: isProd,
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
    );
  }

  TalentModel copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? roles,
    ConnectionStatus? connectionStatus,
    bool? isFollowing,
    bool? isProductionHouse,
    String? connectsCount,
    String? postsCount,
    String? followersCount,
    String? email,
    String? bio,
    String? location,
    List<PostItem>? posts,
    Map<String, String>? aboutInfo,
    List<String>? workPortfolio,
  }) {
    return TalentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      roles: roles ?? this.roles,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isFollowing: isFollowing ?? this.isFollowing,
      isProductionHouse: isProductionHouse ?? this.isProductionHouse,
      connectsCount: connectsCount ?? this.connectsCount,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      posts: posts ?? this.posts,
      aboutInfo: aboutInfo ?? this.aboutInfo,
      workPortfolio: workPortfolio ?? this.workPortfolio,
    );
  }
}
