import 'package:you_too_art/core/providers/user_persona_provider.dart';
import 'package:you_too_art/core/services/app_persistence_service.dart';
import 'package:you_too_art/features/home/models/post_item.dart';
import 'package:you_too_art/features/talent/models/talent_model.dart';

/// Central directory of all talents and test accounts with valid RFC 4122 UUIDs.
/// Ensures consistent IDs across Talent, Network, Profiles, and Supabase Postgres.
class TalentDirectory {
  TalentDirectory._();

  static const String sophiaId = '22222222-2222-2222-2222-222222222222';
  static const String marcusId = '33333333-3333-3333-3333-333333333333';
  static const String elenaId = '44444444-4444-4444-4444-444444444444';
  static const String davidId = '55555555-5555-5555-5555-555555555555';
  static const String lucasId = '66666666-6666-6666-6666-666666666666';
  static const String jamesId = '77777777-7777-7777-7777-777777777777';
  static const String barbaraId = '88888888-8888-8888-8888-888888888888';
  static const String samuelId = '99999999-9999-9999-9999-999999999999';
  static const String dianaId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  static const String loisId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  static const String kadenId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  static const String wandaId = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
  static const String muhammadAliId = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  static const String ranveerSinghId = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

  // Sample posts for Sara Ahmed
  static final jeremiahPost = PostItem(
    id: 'post-sara-1',
    authorId: UserPersonaNotifier.jeremiahId,
    authorName: 'Sara Ahmed',
    authorRole: 'Cinematographer | DoP',
    authorAvatar:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    caption: 'New Camera Rigging Click!\n#Cinematography #SetLife #DoP',
    mediaUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    likeCount: 412,
    commentCount: 38,
  );

  static final jeremiahPost2 = PostItem(
    id: 'post-sara-2',
    authorId: UserPersonaNotifier.jeremiahId,
    authorName: 'Sara Ahmed',
    authorRole: 'Cinematographer | DoP',
    authorAvatar:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    caption:
        'Behind the scenes from yesterday\'s anamorphic camera tests. Atmospheric diffusion adds pure cinematic texture!\n#Cinematography #ArriMini #Lighting',
    mediaUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    likeCount: 620,
    commentCount: 45,
  );

  // Sample posts for SkyPulse Studios
  static final filmfarePost = PostItem(
    id: 'post-skypulse-1',
    authorId: UserPersonaNotifier.filmfareId,
    authorName: 'SkyPulse Studios',
    authorRole: 'Production House',
    authorAvatar:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    caption:
        'We have an announcement! SkyPulse Studios is opening casting for our new upcoming drama feature \'Echoes of Rawal\'. Apply now!\n#EchoesOfRawal #CastingCall #SkyPulse',
    mediaUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    likeCount: 2140,
    commentCount: 164,
  );

  static final filmfarePost2 = PostItem(
    id: 'post-skypulse-2',
    authorId: UserPersonaNotifier.filmfareId,
    authorName: 'SkyPulse Studios',
    authorRole: 'Production House',
    authorAvatar:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    caption:
        'Now Casting: Supporting roles for \'Midnight Sun\' psychological thriller short. Submit showreels through YouTooArt!\n#CastingCall #Audition #SkyPulseStudios',
    mediaUrl:
        'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    likeCount: 2890,
    commentCount: 215,
  );

  // Sample posts for Zaid Khan
  static final alexanderPost = PostItem(
    id: 'post-zaid-1',
    authorId: UserPersonaNotifier.alexanderId,
    authorName: 'Zaid Khan',
    authorRole: 'Director | Filmmaker',
    authorAvatar:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    caption:
        'Wrapping up location scouting for \'Lahore Tales\'. Huge thanks to the local art and architecture teams!\n#Director #SetLife #Cinema #LahoreTales',
    mediaUrl:
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    likeCount: 845,
    commentCount: 52,
  );

  static final alexanderPost2 = PostItem(
    id: 'post-zaid-2',
    authorId: UserPersonaNotifier.alexanderId,
    authorName: 'Zaid Khan',
    authorRole: 'Director | Filmmaker',
    authorAvatar:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    caption:
        'Pre-production rehearsals underway. Excited to direct this brilliant ensemble cast!\n#IndieFilm #DirectorLife #Cinema',
    mediaUrl:
        'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    likeCount: 960,
    commentCount: 71,
  );

  static final jeremiahGreen = TalentModel(
    id: UserPersonaNotifier.jeremiahId,
    name: 'Sara Ahmed',
    roles: 'Cinematographer | DoP',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    connectsCount: '84.2K',
    postsCount: '194',
    isProductionHouse: false,
    bio:
        'Cinematographer and camera operator specializing in Arri & RED camera workflows, anamorphic lighting design, and cinematic commercial aesthetics.',
    location: 'Karachi, Pakistan',
    email: 'crew@youtooart.com',
    posts: [jeremiahPost, jeremiahPost2],
    aboutInfo: const {
      'Category': 'Cinematography & Camera',
      'Experience': '6+ Years Experience',
      'Location': 'Karachi, Pakistan',
      'Email': 'crew@youtooart.com',
      'Specializations': 'Arri Alexa, Red Komodo, Anamorphic Primes',
    },
    workPortfolio: const [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=600&q=80',
    ],
  );

  static final filmfare = TalentModel(
    id: UserPersonaNotifier.filmfareId,
    name: 'SkyPulse Studios',
    roles: 'Production House',
    avatarUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    followersCount: '184.2K',
    postsCount: '312',
    isProductionHouse: true,
    bio:
        'Leading digital film studio producing groundbreaking feature films, digital web series, and high-impact commercial cinema. We connect bold emerging talent with top industry directors.',
    location: 'Islamabad, Pakistan',
    email: 'production@youtooart.com',
    posts: [filmfarePost, filmfarePost2],
    aboutInfo: const {
      'Category': 'Production House & Studio',
      'Established': '2019',
      'Incorporation': 'PK-REG-84920',
      'Address': 'Blue Area, Islamabad, Pakistan',
      'Email': 'production@youtooart.com',
      'Location': 'Islamabad, Pakistan',
      'Specializations': 'Feature Films, Dramatic Series, Commercial Cinema',
    },
  );

  static final alexanderCole = TalentModel(
    id: UserPersonaNotifier.alexanderId,
    name: 'Zaid Khan',
    roles: 'Director | Filmmaker',
    avatarUrl:
        'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=400&q=80',
    connectsCount: '98.4K',
    postsCount: '189',
    isProductionHouse: false,
    bio:
        'Award-winning independent filmmaker and commercial director with a passion for authentic storytelling, festival cinema, and discovering new talent.',
    location: 'Lahore, Pakistan',
    email: 'director@youtooart.com',
    posts: [alexanderPost, alexanderPost2],
    aboutInfo: const {
      'Category': 'Directing & Filmmaking',
      'Experience': '7+ Years Experience',
      'Location': 'Lahore, Pakistan',
      'Email': 'director@youtooart.com',
      'Languages': 'Urdu, English, Punjabi',
    },
    workPortfolio: const [
      'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=600&q=80',
    ],
  );

  static final sophiaVance = TalentModel(
    id: sophiaId,
    name: 'Sophia Vance',
    roles: 'Actress | Singer | Dancer',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    connectsCount: '89.2K',
    postsCount: '184',
    isProductionHouse: false,
    email: 'sophia.vance@youtooart.test',
    bio: 'Professional performing artist, singer, and musical theater dancer.',
    location: 'Chicago, IL',
    aboutInfo: const {
      'Category': 'Musical Theater & Vocal',
      'Experience': '5+ Years Experience',
      'Location': 'Chicago, IL',
      'Email': 'sophia.vance@youtooart.test',
    },
  );

  static final marcusChen = TalentModel(
    id: marcusId,
    name: 'Marcus Chen',
    roles: 'Director | Cinematographer',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    connectsCount: '45.1K',
    postsCount: '96',
    isProductionHouse: false,
    email: 'marcus.chen@youtooart.test',
    bio: 'Cinematographer and visual director specialized in dramatic lighting.',
    location: 'San Francisco, CA',
  );

  static final elenaRostova = TalentModel(
    id: elenaId,
    name: 'Elena Rostova',
    roles: 'Fashion Model | Voiceover',
    avatarUrl:
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=400&q=80',
    connectsCount: '112.5K',
    postsCount: '310',
    isProductionHouse: false,
    email: 'elena.rostova@youtooart.test',
    bio: 'International runway model and commercial voiceover talent.',
    location: 'Miami, FL',
  );

  static final davidKalu = TalentModel(
    id: davidId,
    name: 'David Kalu',
    roles: 'Actor | Screenwriter',
    avatarUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
    connectsCount: '63.8K',
    postsCount: '145',
    isProductionHouse: false,
    email: 'david.kalu@youtooart.test',
    bio: 'Film actor and screenwriter passionate about gripping narrative thrillers.',
    location: 'Atlanta, GA',
    aboutInfo: const {
      'Category': 'Screenwriting & Drama',
      'Experience': '4+ Years Experience',
      'Location': 'Atlanta, GA',
      'Email': 'david.kalu@youtooart.test',
    },
  );

  static final lucasScott = TalentModel(
    id: lucasId,
    name: 'Lucas Scott',
    roles: 'Actor | Director | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    connectsCount: '52.3K',
    postsCount: '112',
    isProductionHouse: false,
    email: 'lucas.scott@youtooart.test',
    bio: 'Independent director and theatre actor.',
    location: 'Austin, TX',
  );

  static final jamesPhillips = TalentModel(
    id: jamesId,
    name: 'James Phillips',
    roles: 'Actor | Voice Artist',
    avatarUrl:
        'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=400&q=80',
    email: 'james.phillips@youtooart.test',
  );

  static final barbaraGordon = TalentModel(
    id: barbaraId,
    name: 'Barbara Gordon',
    roles: 'Cinematographer',
    avatarUrl:
        'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
    email: 'barbara.gordon@youtooart.test',
  );

  static final samuelMoore = TalentModel(
    id: samuelId,
    name: 'Samuel Moore',
    roles: 'Screenwriter | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
    email: 'samuel.moore@youtooart.test',
  );

  static final dianaPrince = TalentModel(
    id: dianaId,
    name: 'Diana Prince',
    roles: 'Lead Actress | Stunt Performer',
    avatarUrl:
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
    email: 'diana.prince@youtooart.test',
  );

  static final loisLane = TalentModel(
    id: loisId,
    name: 'Lois Lane',
    roles: 'Journalist | Media Host',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    email: 'lois.lane@youtooart.test',
  );

  static final kadenFane = TalentModel(
    id: kadenId,
    name: 'Kaden Fane',
    roles: 'Actor | Commercial Model',
    avatarUrl:
        'https://images.unsplash.com/photo-1501196354995-cbb51c65aaea?auto=format&fit=crop&w=400&q=80',
    email: 'kaden.fane@youtooart.test',
  );

  static final wandaMaximoff = TalentModel(
    id: wandaId,
    name: 'Wanda Maximoff',
    roles: 'Director | Screenwriter',
    avatarUrl:
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=400&q=80',
    email: 'wanda.maximoff@youtooart.test',
  );

  static final muhammadAli = TalentModel(
    id: muhammadAliId,
    name: 'Muhammad Ali',
    roles: 'Actor | Director | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
    email: 'muhammad.ali@youtooart.test',
  );

  static final ranveerSingh = TalentModel(
    id: ranveerSinghId,
    name: 'Ranveer Singh',
    roles: 'Actor | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    email: 'ranveer.singh@youtooart.test',
  );

  static List<TalentModel> get allCuratedTalents => [
        findById(UserPersonaNotifier.jeremiahId) ?? jeremiahGreen,
        findById(UserPersonaNotifier.filmfareId) ?? filmfare,
        findById(UserPersonaNotifier.alexanderId) ?? alexanderCole,
        sophiaVance,
        marcusChen,
        elenaRostova,
        davidKalu,
        lucasScott,
        jamesPhillips,
        barbaraGordon,
        samuelMoore,
        dianaPrince,
        loisLane,
        kadenFane,
        wandaMaximoff,
        muhammadAli,
        ranveerSingh,
      ];

  static final Map<String, TalentModel> _byId = {
    for (final t in [
      jeremiahGreen,
      filmfare,
      alexanderCole,
      sophiaVance,
      marcusChen,
      elenaRostova,
      davidKalu,
      lucasScott,
      jamesPhillips,
      barbaraGordon,
      samuelMoore,
      dianaPrince,
      loisLane,
      kadenFane,
      wandaMaximoff,
      muhammadAli,
      ranveerSingh,
    ])
      t.id: t,
  };

  static TalentModel? findById(String id) {
    if (UserPersonaNotifier.isActorId(id)) {
      final persona = UserPersonaNotifier.getActorPersona();
      final portfolio = AppPersistenceService.instance.getPortfolio('actor');
      final photos = portfolio.photos.map((p) => p.mediaUrl).toList();
      return TalentModel.fromPersona(
        persona,
        connectsCount: '124.7K',
        postsCount: '${portfolio.videos.length + portfolio.photos.length}',
        workPortfolio: photos,
      );
    }
    if (UserPersonaNotifier.hasPersona(id)) {
      final persona = UserPersonaNotifier.getPersonaById(id);
      final base = _byId[id] ?? _byId[persona.id];
      final portfolio = AppPersistenceService.instance.getPortfolio(id);
      final photos = portfolio.photos.map((p) => p.mediaUrl).toList();
      return TalentModel.fromPersona(
        persona,
        connectsCount: base?.connectsCount ?? '124.7K',
        postsCount: '${portfolio.videos.length + portfolio.photos.length}',
        posts: base?.posts ?? [],
        aboutInfo: base?.aboutInfo,
        workPortfolio: photos,
      );
    }
    return _byId[id];
  }
}
