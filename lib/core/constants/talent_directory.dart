import 'package:you_too_art/core/providers/user_persona_provider.dart';
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

  // Sample post for Jeremiah Green strictly matching Figma Image 1 & 2
  static final jeremiahPost = PostItem(
    id: 'post-jeremiah-1',
    authorId: UserPersonaNotifier.jeremiahId,
    authorName: 'Jeremiah Green',
    authorRole: 'Actor | Model | Director',
    authorAvatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    caption: 'New Click!\n#Poster #Click #Nature',
    mediaUrl:
        'https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    likeCount: 342,
    commentCount: 28,
  );

  // Sample post for FilmFare strictly matching Figma Image 3 & 4
  static final filmfarePost = PostItem(
    id: 'post-filmfare-1',
    authorId: UserPersonaNotifier.filmfareId,
    authorName: 'FilmFare',
    authorRole: 'Production House',
    authorAvatar:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    caption:
        'Guys! We have an announcement. We are going to launch Cast for our new upcoming short film soon.\n#Poster #Click #Nature',
    mediaUrl:
        'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    likeCount: 1420,
    commentCount: 114,
  );

  // Sample post for Alexander Cole
  static final alexanderPost = PostItem(
    id: 'post-alexander-1',
    authorId: UserPersonaNotifier.alexanderId,
    authorName: 'Alexander Cole',
    authorRole: 'Actor | Director | Producer',
    authorAvatar:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    caption:
        'Wrapping up the final shoot for our upcoming indie project. Huge thanks to the brilliant crew!\n#Director #SetLife #Cinema',
    mediaUrl:
        'https://images.unsplash.com/photo-1485846234645-a62644f84728?auto=format&fit=crop&w=1200&q=80',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    likeCount: 685,
    commentCount: 42,
  );

  static final jeremiahGreen = TalentModel(
    id: UserPersonaNotifier.jeremiahId,
    name: 'Jeremiah Green',
    roles: 'Actor | Model | Director',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    connectsCount: '124.7K',
    postsCount: '252',
    isProductionHouse: false,
    bio:
        'Passionate actor, runway model, and aspiring film director based in Los Angeles. Experienced in leading roles across independent cinema, international commercials, and theatrical performances.',
    location: 'Los Angeles, CA',
    email: 'jeremiah.green@youtooart.test',
    posts: [jeremiahPost],
    aboutInfo: const {
      'Category': 'Performing Arts & Modeling',
      'Experience': '6+ Years Experience',
      'Location': 'Los Angeles, California',
      'Email': 'jeremiah.green@youtooart.test',
      'Height': "6' 1\" (185 cm)",
      'Weight': '74 kg',
      'Hair Color': 'Dark Brown',
      'Eye Color': 'Hazel',
      'Languages': 'English, French, Spanish',
    },
    workPortfolio: const [
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=600&q=80',
      'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=600&q=80',
    ],
  );

  static final filmfare = TalentModel(
    id: UserPersonaNotifier.filmfareId,
    name: 'FilmFare',
    roles: 'Production House',
    avatarUrl:
        'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=400&q=80',
    followersCount: '124.7K',
    postsCount: '252',
    isProductionHouse: true,
    bio:
        'FilmFare is a premier entertainment studio producing groundbreaking feature films, digital web series, and high-impact commercial cinema. We connect bold emerging talent with top industry directors.',
    location: 'Hollywood, CA',
    email: 'filmfare.studio@youtooart.test',
    posts: [filmfarePost],
    aboutInfo: const {
      'Category': 'Production House & Studio',
      'Established': '2012',
      'Incorporation': 'FF-GLOBAL-77821',
      'Address': 'Hollywood Boulevard, Studio City, CA',
      'Email': 'filmfare.studio@youtooart.test',
      'Location': 'Los Angeles & Mumbai',
      'Specializations': 'Feature Films, Web Series, Commercials, Casting Calls',
    },
  );

  static final alexanderCole = TalentModel(
    id: UserPersonaNotifier.alexanderId,
    name: 'Alexander Cole',
    roles: 'Actor | Director | Producer',
    avatarUrl:
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    connectsCount: '98.4K',
    postsCount: '189',
    isProductionHouse: false,
    bio:
        'Award-winning actor and indie film director with extensive experience across feature drama, festival shorts, and modern theatrical storytelling.',
    location: 'New York, NY',
    email: 'alexander.cole@youtooart.test',
    posts: [alexanderPost],
    aboutInfo: const {
      'Category': 'Acting & Directing',
      'Experience': '8+ Years Experience',
      'Location': 'New York, NY',
      'Email': 'alexander.cole@youtooart.test',
      'Languages': 'English, Italian',
    },
    workPortfolio: const [
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=600&q=80',
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
        jeremiahGreen,
        filmfare,
        alexanderCole,
        sophiaVance,
        marcusChen,
        elenaRostova,
        davidKalu,
        lucasScott,
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

  static TalentModel? findById(String id) => _byId[id];
}
