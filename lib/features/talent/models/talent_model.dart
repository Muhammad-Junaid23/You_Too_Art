import 'package:you_too_art/core/models/user_model.dart';
import 'package:you_too_art/features/home/models/post_item.dart';

enum ConnectionStatus {
  none,
  pending,
  connected,
}

class TalentModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String roles;
  final ConnectionStatus connectionStatus;
  final bool isFollowing;
  final bool isProductionHouse;
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
    this.isProductionHouse = false,
    this.connectsCount = '124.7K',
    this.postsCount = '252',
    this.followersCount = '124.7K',
    this.email,
    this.bio,
    this.location,
    this.posts = const [],
    this.aboutInfo = const {},
    this.workPortfolio = const [],
  });

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  bool get isPending => connectionStatus == ConnectionStatus.pending;

  factory TalentModel.fromUser(
    UserModel user, {
    ConnectionStatus connectionStatus = ConnectionStatus.none,
    bool isFollowing = false,
  }) {
    final isProd = user.role.toLowerCase().contains('production') ||
        (user.incorporationNumber != null &&
            user.incorporationNumber!.isNotEmpty);

    String rolesStr = isProd ? 'Production House' : 'Actor | Model | Director';
    if (user.role.isNotEmpty && user.role.toLowerCase() != 'unset') {
      rolesStr = user.role;
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
