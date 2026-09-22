import '../models/models.dart';

/// Devotional media for each deity, used when the API is unreachable or has
/// nothing published for a day yet.
///
/// Recordings are copyrighted even when the composition is centuries old, so
/// nothing here links to a specific upload we have not cleared. Each entry
/// opens a search on the platform where the recording is officially
/// published; the rights stay with the publisher and the app says so.
class SampleMedia {
  SampleMedia._();

  static const String _search = 'Search result · rights with the publisher';

  static DevotionalMedia _song(String title, String q, {String? artist, String? duration}) => DevotionalMedia(
        type: 'song',
        title: title,
        artist: artist,
        durationLabel: duration,
        sourceType: 'external',
        url: 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}',
        license: _search,
      );

  static DevotionalMedia _chant(String title, String q, {String? description}) => DevotionalMedia(
        type: 'chant',
        title: title,
        description: description,
        sourceType: 'external',
        url: 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}',
        license: _search,
      );

  static DevotionalMedia _video(String title, String q, {String? description}) => DevotionalMedia(
        type: 'video',
        title: title,
        description: description,
        sourceType: 'external',
        url: 'https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent(q)}',
        license: _search,
      );

  static final Map<String, List<DevotionalMedia>> _byDeity = {
    'shiva': [
      _chant('Om Namah Shivaya', 'Om Namah Shivaya chanting 108', description: 'The panchakshari mantra, 108 times.'),
      _chant('Shiva Tandava Stotram', 'Shiva Tandava Stotram', description: 'Ravana\'s hymn to the dancing Shiva.'),
      _song('Lingashtakam', 'Lingashtakam', artist: 'Traditional'),
      _song('Bho Shambho', 'Bho Shambho Shiva Shambho', artist: 'Traditional'),
      _video('Kashi Vishwanath Mangala Aarti', 'Kashi Vishwanath mangala aarti live', description: 'Pre-dawn aarti on the Ganga.'),
      _video('Mahakaleshwar Bhasma Aarti', 'Mahakaleshwar Bhasma Aarti Ujjain'),
    ],
    'hanuman': [
      _chant('Hanuman Chalisa', 'Hanuman Chalisa', description: 'Forty verses of Tulsidas.'),
      _chant('Bajrang Baan', 'Bajrang Baan'),
      _song('Sundarakanda Parayanam', 'Sundarakanda parayanam Telugu', artist: 'Traditional'),
      _video('Salasar Balaji Darshan', 'Salasar Balaji darshan aarti'),
      _video('Hanuman Garhi Ayodhya', 'Hanuman Garhi Ayodhya darshan'),
    ],
    'ganesha': [
      _chant('Ganapati Atharvashirsha', 'Ganapati Atharvashirsha'),
      _song('Sukhkarta Dukhharta', 'Sukhkarta Dukhharta aarti', artist: 'Traditional Marathi aarti'),
      _song('Vakratunda Mahakaya', 'Vakratunda Mahakaya shloka'),
      _video('Siddhivinayak Aarti', 'Siddhivinayak temple aarti Mumbai'),
    ],
    'krishna': [
      _chant('Hare Krishna Mahamantra', 'Hare Krishna maha mantra kirtan'),
      _song('Achyutam Keshavam', 'Achyutam Keshavam Krishna Damodaram'),
      _song('Madhurashtakam', 'Madhurashtakam Adharam Madhuram', artist: 'Vallabhacharya'),
      _song('Jagannath Ashtakam', 'Jagannathashtakam'),
      _video('Puri Rath Yatra', 'Puri Jagannath Rath Yatra', description: 'The chariot festival of Jagannath.'),
      _video('Dwarkadhish Mangala Aarti', 'Dwarkadhish temple mangala aarti'),
      _video('Guruvayur Seeveli', 'Guruvayur temple seeveli'),
    ],
    'vishnu': [
      _chant('Vishnu Sahasranamam', 'Vishnu Sahasranamam MS Subbulakshmi', description: 'The thousand names.'),
      _chant('Om Namo Narayanaya', 'Om Namo Narayanaya chanting'),
      _song('Shriman Narayana', 'Shriman Narayana Narayana Hari Hari', artist: 'Annamacharya'),
      _video('Badrinath Aarti', 'Badrinath temple evening aarti'),
    ],
    'venkateswara': [
      _chant('Venkateswara Suprabhatam', 'Venkateswara Suprabhatam MS Subbulakshmi', description: 'The morning awakening of the Lord of the Seven Hills.'),
      _song('Govinda Namalu', 'Srinivasa Govinda Sri Venkatesa Govinda'),
      _song('Brahma Kadigina Padamu', 'Brahma Kadigina Padamu Annamayya', artist: 'Annamacharya'),
      _video('Tirumala Darshan', 'Tirumala Tirupati darshan TTD'),
      _video('Brahmotsavam Vahana Seva', 'Tirumala Brahmotsavam vahana seva'),
    ],
    'narasimha': [
      _chant('Narasimha Kavacham', 'Narasimha Kavacham'),
      _song('Ugram Veeram Mahavishnum', 'Ugram Veeram Mahavishnum Narasimha mantra'),
      _video('Yadadri Darshan', 'Yadadri Lakshmi Narasimha temple darshan'),
    ],
    'rama': [
      _chant('Sri Rama Jaya Rama', 'Sri Rama Jaya Rama Jaya Jaya Rama chanting'),
      _song('Rama Rama Ratha Ratha', 'Bhadrachala Ramadasu keerthana', artist: 'Bhadrachala Ramadasu'),
      _song('Nagumomu', 'Nagumomu Ganaleni Tyagaraja', artist: 'Tyagaraja'),
      _video('Bhadrachalam Sri Rama Navami Kalyanam', 'Bhadrachalam Sita Rama Kalyanam'),
    ],
    'devi': [
      _chant('Lalita Sahasranamam', 'Lalita Sahasranamam', description: 'The thousand names of the Mother.'),
      _chant('Durga Saptashati', 'Durga Saptashati path'),
      _song('Aigiri Nandini', 'Aigiri Nandini Mahishasura Mardini stotram'),
      _song('Meenakshi Pancharatnam', 'Meenakshi Pancharatnam'),
      _video('Vaishno Devi Aarti', 'Vaishno Devi bhawan aarti'),
      _video('Kamakhya Ambubachi Mela', 'Kamakhya temple Ambubachi Mela'),
    ],
    'lakshmi': [
      _chant('Sri Suktam', 'Sri Suktam'),
      _song('Mahalakshmi Ashtakam', 'Mahalakshmi Ashtakam'),
      _song('Bhagyada Lakshmi Baramma', 'Bhagyada Lakshmi Baramma', artist: 'Purandara Dasa'),
      _video('Kolhapur Mahalakshmi Aarti', 'Kolhapur Mahalakshmi temple aarti'),
    ],
    'surya': [
      _chant('Aditya Hridayam', 'Aditya Hridayam stotram', description: 'Taught to Rama before the battle.'),
      _chant('Gayatri Mantra', 'Gayatri Mantra 108'),
      _song('Surya Ashtakam', 'Surya Ashtakam'),
      _video('Konark Sun Temple', 'Konark Sun Temple documentary'),
    ],
    'ayyappa': [
      _chant('Harivarasanam', 'Harivarasanam', description: 'The lullaby sung as the sanctum closes each night.'),
      _song('Swamiye Saranam Ayyappa', 'Swamiye Saranam Ayyappa bhajan'),
      _video('Sabarimala Makaravilakku', 'Sabarimala Makaravilakku'),
      _video('Pathinettam Padi', 'Sabarimala pathinettam padi 18 steps'),
    ],
  };

  static List<DevotionalMedia> forDeity(String? slug) => slug == null ? const [] : (_byDeity[slug] ?? const []);

  /// Media for a temple: its deity's catalogue, with the temple's own videos
  /// (matched by name) first.
  static List<DevotionalMedia> forTemple(String templeName, String? deitySlug) {
    final all = forDeity(deitySlug);
    final key = templeName.split(',').first.split(' ').where((w) => w.length > 4).map((w) => w.toLowerCase()).toList();
    bool mentions(DevotionalMedia m) => key.any((k) => m.title.toLowerCase().contains(k) || (m.description?.toLowerCase().contains(k) ?? false));
    return [...all.where(mentions), ...all.where((m) => !mentions(m))];
  }

  /// Sample galleries. Images are fetched from Wikimedia Commons by file
  /// name and shown with their attribution; if a file is renamed the tile
  /// falls back to the deity motif rather than a broken image.
  static Photo _commons(String file, String caption, {String category = 'exterior'}) {
    final base = 'https://commons.wikimedia.org/wiki/Special:FilePath/${Uri.encodeComponent(file)}';
    return Photo(
      category: category,
      caption: caption,
      original: base,
      medium: '$base?width=1200',
      thumbnail: '$base?width=400',
      credit: 'Wikimedia Commons contributors',
      license: 'CC BY-SA',
    );
  }

  static final Map<String, List<Photo>> _galleries = {
    'sri-venkateswara-swamy-temple-tirumala': [
      _commons('Tirumala Venkateswara Temple.jpg', 'The gopuram at Tirumala'),
      _commons('Tirumala Temple Entrance.jpg', 'Mahadwaram, the main entrance'),
    ],
    'kashi-vishwanath-temple': [
      _commons('Kashi Vishwanath Temple Varanasi.jpg', 'The golden spire'),
      _commons('Ganga Aarti Varanasi.jpg', 'Evening Ganga aarti at the ghats', category: 'ritual'),
    ],
    'somnath-temple': [
      _commons('Somnath Temple.jpg', 'Somnath on the Saurashtra coast'),
      _commons('Somnath temple at night.jpg', 'Lit at night'),
    ],
    'meenakshi-amman-temple': [
      _commons('Meenakshi Amman Temple Madurai.jpg', 'Painted gopurams of Madurai'),
      _commons('Meenakshi Temple Thousand Pillar Hall.jpg', 'The thousand-pillar hall', category: 'interior'),
    ],
    'jagannath-temple-puri': [_commons('Jagannath Temple Puri.jpg', 'The shrine at Puri')],
    'badrinath-temple': [_commons('Badrinath Temple.jpg', 'Badrinath on the Alaknanda')],
    'kedarnath-temple': [_commons('Kedarnath Temple.jpg', 'Kedarnath in the Himalaya')],
    'ramanathaswamy-temple-rameswaram': [_commons('Ramanathaswamy Temple corridor.jpg', 'The long corridor', category: 'interior')],
    'brihadeeswarar-temple-thanjavur': [_commons('Brihadeeswarar Temple Thanjavur.jpg', 'The Chola vimana')],
    'konark-sun-temple': [_commons('Konark Sun Temple.jpg', 'The stone chariot'), _commons('Konark Sun Temple wheel.jpg', 'A chariot wheel', category: 'detail')],
    'dwarkadhish-temple': [_commons('Dwarkadhish Temple.jpg', 'Dwarkadhish on the Gomti')],
    'lingaraj-temple-bhubaneswar': [_commons('Lingaraj Temple Bhubaneswar.jpg', 'Kalinga-style deul')],
    'kailasa-temple-ellora': [_commons('Kailasa Temple Ellora.jpg', 'Cut from a single rock')],
    'siddhivinayak-temple-mumbai': [_commons('Siddhivinayak Temple Mumbai.jpg', 'Prabhadevi')],
    'mahakaleshwar-temple-ujjain': [_commons('Mahakaleshwar Temple Ujjain.jpg', 'Mahakal')],
  };

  static List<Photo> galleryFor(String slug) => _galleries[slug] ?? const [];
}
