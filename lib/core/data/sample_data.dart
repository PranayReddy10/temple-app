import '../models/models.dart';
import '../theme/day_theme.dart';
import 'sample_media.dart';

/// Bundled records so the app runs with no backend and stays usable with no
/// signal. Mirrors the backend seeders.
///
/// Every temple here is marked COMMUNITY level, exactly as the seeder does:
/// none of it has been checked against an official source, and section 20 of
/// the plan forbids dressing unverified information up as official.
class SampleData {
  SampleData._();

  static const List<DeityRef> deities = [
    DeityRef(slug: 'shiva', name: 'Shiva', alternateNames: ['Mahadeva', 'Shankara', 'Rudra', 'Eshwara']),
    DeityRef(slug: 'vishnu', name: 'Vishnu', alternateNames: ['Narayana', 'Hari', 'Perumal']),
    DeityRef(slug: 'venkateswara', name: 'Venkateswara', alternateNames: ['Balaji', 'Srinivasa', 'Govinda']),
    DeityRef(slug: 'krishna', name: 'Krishna', alternateNames: ['Govinda', 'Gopala', 'Jagannath', 'Vithoba']),
    DeityRef(slug: 'rama', name: 'Rama', alternateNames: ['Raghava', 'Ramachandra']),
    DeityRef(slug: 'narasimha', name: 'Narasimha', alternateNames: ['Nrisimha', 'Lakshmi Narasimha']),
    DeityRef(slug: 'devi', name: 'Devi', alternateNames: ['Durga', 'Parvati', 'Amman', 'Shakti']),
    DeityRef(slug: 'lakshmi', name: 'Lakshmi', alternateNames: ['Sri', 'Mahalakshmi']),
    DeityRef(slug: 'ganesha', name: 'Ganesha', alternateNames: ['Ganapati', 'Vinayaka', 'Pillaiyar']),
    DeityRef(slug: 'hanuman', name: 'Hanuman', alternateNames: ['Anjaneya', 'Maruti', 'Bajrangbali']),
    DeityRef(slug: 'surya', name: 'Surya', alternateNames: ['Aditya', 'Ravi']),
    DeityRef(slug: 'ayyappa', name: 'Ayyappa', alternateNames: ['Dharmasastha', 'Manikandan']),
  ];

  static const List<CategoryRef> categories = [
    CategoryRef(slug: 'jyotirlinga', name: 'Jyotirlinga', kind: 'circuit', description: 'The twelve shrines where Shiva appeared as a column of light.'),
    CategoryRef(slug: 'char-dham', name: 'Char Dham', kind: 'circuit', description: 'Badrinath, Dwarka, Puri and Rameswaram: the four abodes.'),
    CategoryRef(slug: 'chota-char-dham', name: 'Chota Char Dham', kind: 'circuit', description: 'Yamunotri, Gangotri, Kedarnath and Badrinath in the Himalaya.'),
    CategoryRef(slug: 'shakti-peetha', name: 'Shakti Peetha', kind: 'circuit', description: 'Seats of the goddess across the subcontinent.'),
    CategoryRef(slug: 'divya-desam', name: 'Divya Desam', kind: 'circuit', description: 'The 108 Vishnu temples sung by the Alvars.'),
    CategoryRef(slug: 'sapta-puri', name: 'Sapta Puri', kind: 'circuit', description: 'The seven holy cities that grant liberation.'),
    CategoryRef(slug: 'unesco-world-heritage', name: 'UNESCO World Heritage', kind: 'heritage'),
    CategoryRef(slug: 'hill-temple', name: 'Hill temple', kind: 'setting'),
    CategoryRef(slug: 'cave-temple', name: 'Cave temple', kind: 'setting'),
    CategoryRef(slug: 'coastal-temple', name: 'Coastal temple', kind: 'setting'),
    CategoryRef(slug: 'river-ghat-temple', name: 'River ghat temple', kind: 'setting'),
    CategoryRef(slug: 'forest-temple', name: 'Forest temple', kind: 'setting'),
    CategoryRef(slug: 'rock-cut-temple', name: 'Rock-cut temple', kind: 'architecture'),
  ];

  static const List<StateRef> states = [
    StateRef(slug: 'andhra-pradesh', name: 'Andhra Pradesh', code: 'AP'),
    StateRef(slug: 'assam', name: 'Assam', code: 'AS'),
    StateRef(slug: 'gujarat', name: 'Gujarat', code: 'GJ'),
    StateRef(slug: 'jammu-and-kashmir', name: 'Jammu and Kashmir', code: 'JK'),
    StateRef(slug: 'karnataka', name: 'Karnataka', code: 'KA'),
    StateRef(slug: 'kerala', name: 'Kerala', code: 'KL'),
    StateRef(slug: 'madhya-pradesh', name: 'Madhya Pradesh', code: 'MP'),
    StateRef(slug: 'maharashtra', name: 'Maharashtra', code: 'MH'),
    StateRef(slug: 'odisha', name: 'Odisha', code: 'OD'),
    StateRef(slug: 'tamil-nadu', name: 'Tamil Nadu', code: 'TN'),
    StateRef(slug: 'telangana', name: 'Telangana', code: 'TG'),
    StateRef(slug: 'uttar-pradesh', name: 'Uttar Pradesh', code: 'UP'),
    StateRef(slug: 'uttarakhand', name: 'Uttarakhand', code: 'UK'),
  ];

  static String? stateSlug(String? name) {
    if (name == null) return null;
    for (final s in states) {
      if (s.name == name) return s.slug;
    }
    return null;
  }

  static const Trust _community = Trust(level: TrustLevel.community, label: 'Community');

  static DeityRef _deity(String slug) => deities.firstWhere((d) => d.slug == slug);

  static TempleSummary _t(String slug, String name, String deity, String city, String state, double lat, double lng, String summary, List<String> cats) =>
      TempleSummary(
        slug: slug,
        name: name,
        shortDescription: summary,
        deity: _deity(deity),
        location: Location(city: city, state: state, latitude: lat, longitude: lng),
        trust: _community,
        categorySlugs: cats,
      );

  static final List<TempleSummary> temples = [
    _t('sri-venkateswara-swamy-temple-tirumala', 'Sri Venkateswara Swamy Temple, Tirumala', 'venkateswara', 'Tirumala', 'Andhra Pradesh', 13.6833, 79.3474,
        'Hill shrine of Venkateswara at Tirumala, among the most visited pilgrimage sites in India.', ['divya-desam', 'hill-temple']),
    _t('kashi-vishwanath-temple', 'Kashi Vishwanath Temple', 'shiva', 'Varanasi', 'Uttar Pradesh', 25.3109, 83.0107,
        'Jyotirlinga shrine on the western bank of the Ganga in Varanasi.', ['jyotirlinga', 'sapta-puri', 'river-ghat-temple']),
    _t('somnath-temple', 'Somnath Temple', 'shiva', 'Prabhas Patan', 'Gujarat', 20.8880, 70.4012,
        'First among the twelve Jyotirlingas, on the Arabian Sea coast of Saurashtra.', ['jyotirlinga', 'coastal-temple']),
    _t('mahakaleshwar-temple-ujjain', 'Mahakaleshwar Temple, Ujjain', 'shiva', 'Ujjain', 'Madhya Pradesh', 23.1828, 75.7682,
        'Jyotirlinga known for the Bhasma Aarti performed at dawn.', ['jyotirlinga', 'sapta-puri']),
    _t('meenakshi-amman-temple', 'Meenakshi Amman Temple', 'devi', 'Madurai', 'Tamil Nadu', 9.9195, 78.1193,
        'Twin shrines to Meenakshi and Sundareswarar, known for towering painted gopurams.', []),
    _t('jagannath-temple-puri', 'Jagannath Temple, Puri', 'krishna', 'Puri', 'Odisha', 19.8048, 85.8180,
        'Char Dham shrine to Jagannath, Balabhadra and Subhadra, home of the Rath Yatra.', ['char-dham', 'coastal-temple']),
    _t('badrinath-temple', 'Badrinath Temple', 'vishnu', 'Badrinath', 'Uttarakhand', 30.7433, 79.4938,
        'Himalayan Char Dham shrine on the bank of the Alaknanda, open roughly May to November.', ['char-dham', 'chota-char-dham', 'divya-desam', 'hill-temple']),
    _t('kedarnath-temple', 'Kedarnath Temple', 'shiva', 'Kedarnath', 'Uttarakhand', 30.7346, 79.0669,
        'Highest of the twelve Jyotirlingas, reached on foot from Gaurikund.', ['jyotirlinga', 'chota-char-dham', 'hill-temple']),
    _t('ramanathaswamy-temple-rameswaram', 'Ramanathaswamy Temple, Rameswaram', 'shiva', 'Rameswaram', 'Tamil Nadu', 9.2881, 79.3174,
        'Jyotirlinga and Char Dham site, known for the longest temple corridor in India.', ['jyotirlinga', 'char-dham', 'coastal-temple']),
    _t('dwarkadhish-temple', 'Dwarkadhish Temple', 'krishna', 'Dwarka', 'Gujarat', 22.2376, 68.9678,
        'Char Dham shrine to Krishna as king of Dwarka, on the Gomti creek.', ['char-dham', 'divya-desam', 'coastal-temple']),
    _t('vaishno-devi-temple-katra', 'Vaishno Devi Temple, Katra', 'devi', 'Katra', 'Jammu and Kashmir', 33.0308, 74.9497,
        'Cave shrine in the Trikuta hills, reached by a marked trek from Katra.', ['shakti-peetha', 'hill-temple', 'cave-temple']),
    _t('sabarimala-sree-dharmasastha-temple', 'Sabarimala Sree Dharmasastha Temple', 'ayyappa', 'Sabarimala', 'Kerala', 9.4360, 77.0811,
        'Forest hill shrine to Ayyappa, opened for the Mandala and Makaravilakku seasons.', ['hill-temple', 'forest-temple']),
    _t('brihadeeswarar-temple-thanjavur', 'Brihadeeswarar Temple, Thanjavur', 'shiva', 'Thanjavur', 'Tamil Nadu', 10.7828, 79.1318,
        'Chola temple completed around 1010 CE, part of the Great Living Chola Temples.', ['unesco-world-heritage']),
    _t('konark-sun-temple', 'Konark Sun Temple', 'surya', 'Konark', 'Odisha', 19.8876, 86.0945,
        "Thirteenth-century temple built as the sun god's chariot, a UNESCO World Heritage Site.", ['unesco-world-heritage', 'coastal-temple']),
    _t('siddhivinayak-temple-mumbai', 'Siddhivinayak Temple, Mumbai', 'ganesha', 'Mumbai', 'Maharashtra', 19.0170, 72.8302,
        'Ganesha temple at Prabhadevi, among the busiest shrines in Mumbai.', []),
    _t('mallikarjuna-jyotirlinga-temple-srisailam', 'Mallikarjuna Jyotirlinga Temple, Srisailam', 'shiva', 'Srisailam', 'Andhra Pradesh', 16.0733, 78.8683,
        'Rare site counted as both a Jyotirlinga and a Shakti Peetha, above the Krishna river.', ['jyotirlinga', 'shakti-peetha', 'hill-temple', 'forest-temple']),
    _t('kamakhya-temple-guwahati', 'Kamakhya Temple, Guwahati', 'devi', 'Guwahati', 'Assam', 26.1665, 91.7060,
        'Shakti Peetha on Nilachal Hill, known for the Ambubachi Mela.', ['shakti-peetha', 'hill-temple']),
    _t('lingaraj-temple-bhubaneswar', 'Lingaraj Temple, Bhubaneswar', 'shiva', 'Bhubaneswar', 'Odisha', 20.2385, 85.8338,
        'Eleventh-century Kalinga-style temple, the largest in Bhubaneswar.', []),
    _t('guruvayur-sri-krishna-temple', 'Guruvayur Sri Krishna Temple', 'krishna', 'Guruvayur', 'Kerala', 10.5949, 76.0411,
        'Krishna temple in Thrissur district, often called the Dwarka of the south.', []),
    _t('yadadri-lakshmi-narasimha-temple', 'Yadadri Lakshmi Narasimha Temple', 'narasimha', 'Yadagirigutta', 'Telangana', 17.6017, 78.9500,
        'Hill temple to Lakshmi Narasimha, rebuilt in Krishna Shila stone.', ['hill-temple']),
    _t('bhadrachalam-sita-ramachandraswamy-temple', 'Bhadrachalam Sita Ramachandraswamy Temple', 'rama', 'Bhadrachalam', 'Telangana', 17.6688, 80.8897,
        'Rama temple on the Godavari, known for Sri Rama Navami celebrations.', ['river-ghat-temple']),
    _t('kailasa-temple-ellora', 'Kailasa Temple, Ellora', 'shiva', 'Ellora', 'Maharashtra', 20.0268, 75.1779,
        'Monolithic temple carved downward from a single basalt cliff, Ellora Cave 16.', ['unesco-world-heritage', 'rock-cut-temple', 'cave-temple']),
    _t('salasar-balaji-temple', 'Salasar Balaji Temple', 'hanuman', 'Salasar', 'Rajasthan', 27.7333, 74.7333,
        'Hanuman shrine in Churu district, thronged on Tuesdays and Saturdays.', []),
    _t('hanuman-garhi-ayodhya', 'Hanuman Garhi, Ayodhya', 'hanuman', 'Ayodhya', 'Uttar Pradesh', 26.7960, 82.2000,
        'Hilltop Hanuman fort-temple reached by seventy-six steps.', ['sapta-puri']),
    _t('mahalakshmi-temple-kolhapur', 'Mahalakshmi Temple, Kolhapur', 'lakshmi', 'Kolhapur', 'Maharashtra', 16.6950, 74.2247,
        'Ambabai shrine and Shakti Peetha of the Deccan.', ['shakti-peetha']),
  ];

  static const Map<String, List<String>> _aliases = {
    'sri-venkateswara-swamy-temple-tirumala': ['Tirupati Balaji', 'Tirumala', 'తిరుమల'],
    'kashi-vishwanath-temple': ['Vishwanath', 'Kashi', 'काशी विश्वनाथ'],
    'meenakshi-amman-temple': ['Madurai Meenakshi', 'மீனாட்சி அம்மன்'],
    'jagannath-temple-puri': ['Puri', 'Jagannath Dham'],
    'vaishno-devi-temple-katra': ['Mata Rani', 'Vaishnodevi'],
    'yadadri-lakshmi-narasimha-temple': ['Yadagirigutta', 'యాదాద్రి'],
    'bhadrachalam-sita-ramachandraswamy-temple': ['Bhadradri', 'భద్రాచలం'],
  };

  static List<String> aliasesFor(String slug) => _aliases[slug] ?? const [];

  static TempleSummary? bySlug(String slug) => temples.where((t) => t.slug == slug).firstOrNull;

  static TempleDetail? detail(String slug) {
    final s = bySlug(slug);
    if (s == null) return null;
    final cats = s.categorySlugs.map((c) => categories.firstWhere((x) => x.slug == c, orElse: () => CategoryRef(slug: c, name: c))).toList();
    final photos = SampleMedia.galleryFor(slug);
    return TempleDetail(
      summary: photos.isEmpty
          ? s
          : TempleSummary(slug: s.slug, name: s.name, shortDescription: s.shortDescription, deity: s.deity, location: s.location, trust: s.trust, primaryPhoto: photos.first, categorySlugs: s.categorySlugs),
      photos: photos,
      alternateNames: aliasesFor(slug),
      categories: cats,
      history: s.shortDescription,
      significance: 'Community entry pending verification against an official source. Details shown here are approximate.',
      visitorRules: const {
        'dress_code': 'Traditional attire is respectful. Shoulders and knees covered.',
        'photography': 'Not permitted inside the sanctum.',
        'footwear': 'Remove footwear before the outer gate.',
        'mobile': 'Silent inside the temple.',
      },
      timings: const [
        Timing(kind: 'opening', label: 'Morning darshan', dayLabel: 'Every day', opensAt: '05:00', closesAt: '12:00', window: '05:00 – 12:00'),
        Timing(kind: 'opening', label: 'Evening darshan', dayLabel: 'Every day', opensAt: '16:00', closesAt: '21:00', window: '16:00 – 21:00'),
        Timing(kind: 'aarti', label: 'Evening aarti', dayLabel: 'Every day', opensAt: '18:30', closesAt: '19:00', window: '18:30 – 19:00'),
      ],
      pujas: const [
        Puja(
          name: 'Archana',
          description: 'Offering of the names of the deity with flowers, in the name of the devotee.',
          startsAt: '06:00',
          durationLabel: '15 min',
          fee: Fee(isFree: false, amount: null, label: 'No published price'),
          booking: Booking(url: null, isOfficial: false, label: 'Book at the temple counter'),
        ),
        Puja(
          name: 'Abhishekam',
          description: 'Ritual bathing of the deity with milk, honey and sandal paste.',
          startsAt: '07:30',
          durationLabel: '45 min',
          fee: Fee(isFree: false, amount: null, label: 'No published price'),
          booking: Booking(url: null, isOfficial: false, label: 'Book at the temple counter'),
        ),
      ],
      facilities: const [
        FacilityRef(slug: 'drinking-water', name: 'Drinking water', group: 'basics'),
        FacilityRef(slug: 'footwear-stand', name: 'Footwear stand', group: 'basics'),
        FacilityRef(slug: 'prasadam-counter', name: 'Prasadam counter', group: 'food'),
        FacilityRef(slug: 'wheelchair-access', name: 'Wheelchair access', group: 'accessibility'),
      ],
    );
  }

  static List<TempleEvent> get events {
    final now = DateTime.now();
    String d(int add) {
      final x = now.add(Duration(days: add));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    return [
      TempleEvent(type: 'festival', title: 'Brahmotsavam', description: 'Nine days of processions on the vahanams around the four mada streets.', startsOn: d(3), endsOn: d(12), dateLabel: 'In 3 days · 9 days', templeSlug: 'sri-venkateswara-swamy-temple-tirumala', templeName: 'Sri Venkateswara Swamy Temple', templeCity: 'Tirumala'),
      TempleEvent(type: 'program', title: 'Bhasma Aarti', description: 'Pre-dawn aarti with sacred ash. Register a day ahead.', startsOn: d(0), endsOn: d(0), dateLabel: 'Today', isHappeningToday: true, templeSlug: 'mahakaleshwar-temple-ujjain', templeName: 'Mahakaleshwar Temple', templeCity: 'Ujjain'),
      TempleEvent(type: 'festival', title: 'Chithirai Thiruvizha', description: 'The celestial wedding of Meenakshi and Sundareswarar.', startsOn: d(20), endsOn: d(32), dateLabel: 'In 3 weeks', templeSlug: 'meenakshi-amman-temple', templeName: 'Meenakshi Amman Temple', templeCity: 'Madurai'),
      TempleEvent(type: 'announcement', title: 'Mandala season opening', description: 'Sannidhanam opens for the forty-one day Mandala vratham.', startsOn: d(45), endsOn: d(86), dateLabel: 'In 6 weeks', templeSlug: 'sabarimala-sree-dharmasastha-temple', templeName: 'Sabarimala', templeCity: 'Sabarimala'),
    ];
  }

  static List<DevotionalDay> daysFor(int weekday) {
    final lead = DayTheme.all[weekday];
    final extras = DayTheme.extraDeities.where((d) => d.weekday == weekday && d.deitySlug != 'ayyappa' && d.deitySlug != 'narasimha' && d.deitySlug != 'rama');
    DevotionalDay build(DayTheme t) => DevotionalDay(
          weekday: t.weekday,
          weekdayName: t.dayName,
          title: '${t.sanskritDay} — ${t.deityName}',
          subtitle: t.greeting,
          significance: '${t.offering}. ${t.fastingNote}',
          mantra: t.mantra,
          mantraTransliteration: t.transliteration,
          accentColor: '#${t.accent.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
          deity: deities.where((d) => d.slug == t.deitySlug).firstOrNull ?? DeityRef(slug: t.deitySlug, name: t.deityName),
          media: SampleMedia.forDeity(t.deitySlug),
          temples: temples.where((x) => x.deity?.slug == t.deitySlug).take(10).toList(),
        );
    return [build(lead), ...extras.map(build)];
  }
}
