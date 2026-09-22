import 'package:flutter/material.dart';

import '../motifs/motif.dart';
import 'palette.dart';

/// The visual identity of one weekday.
///
/// The traditional weekday-to-deity associations are the backbone of the app:
/// every screen tints itself with the day's colour, shows the day's motif and
/// greets the devotee with the day's mantra. The backend serves the same
/// mapping from its `devotional_days` table; these are the offline defaults
/// and the extra visual data (motif, texture, greeting) that a colour alone
/// cannot carry.
class DayTheme {
  const DayTheme({
    required this.weekday,
    required this.dayName,
    required this.sanskritDay,
    required this.deitySlug,
    required this.deityName,
    required this.epithet,
    required this.accent,
    required this.secondary,
    required this.lightTint,
    required this.darkTint,
    required this.motif,
    required this.mantra,
    required this.transliteration,
    required this.greeting,
    required this.offering,
    required this.fastingNote,
  });

  /// 0 = Sunday … 6 = Saturday, matching `DateTime.weekday % 7` and the API.
  final int weekday;
  final String dayName;
  final String sanskritDay;
  final String deitySlug;
  final String deityName;
  final String epithet;
  final Color accent;
  final Color secondary;
  final Color lightTint;
  final Color darkTint;
  final Motif motif;
  final String mantra;
  final String transliteration;
  final String greeting;
  final String offering;
  final String fastingNote;

  Color tint(Brightness b) => b == Brightness.dark ? darkTint : lightTint;

  Color onAccent() =>
      ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : Palette.ebony;

  /// Returns a copy with an accent taken from the server.
  DayTheme withAccent(Color color) => DayTheme(
        weekday: weekday,
        dayName: dayName,
        sanskritDay: sanskritDay,
        deitySlug: deitySlug,
        deityName: deityName,
        epithet: epithet,
        accent: color,
        secondary: secondary,
        lightTint: Color.lerp(Palette.sandal, color, 0.10)!,
        darkTint: Color.lerp(Palette.ebony, color, 0.18)!,
        motif: motif,
        mantra: mantra,
        transliteration: transliteration,
        greeting: greeting,
        offering: offering,
        fastingNote: fastingNote,
      );

  static DayTheme forDate(DateTime date) => all[date.weekday % 7];

  static DayTheme today() => forDate(DateTime.now());

  static DayTheme forDeity(String? slug) {
    if (slug == null) return today();
    return all.firstWhere(
      (d) => d.deitySlug == slug,
      orElse: () => extraDeities.firstWhere(
        (d) => d.deitySlug == slug,
        orElse: today,
      ),
    );
  }

  /// Indexed by weekday, Sunday first.
  static const List<DayTheme> all = [
    DayTheme(
      weekday: 0,
      dayName: 'Sunday',
      sanskritDay: 'Ravivara',
      deitySlug: 'surya',
      deityName: 'Surya',
      epithet: 'The Radiant One',
      accent: Color(0xFFE07A1F),
      secondary: Color(0xFFF2B632),
      lightTint: Color(0xFFFFF1DF),
      darkTint: Color(0xFF2E1A0C),
      motif: Motif.sun,
      mantra: 'ॐ सूर्याय नमः',
      transliteration: 'Om Suryaya Namaha',
      greeting: 'Rise with the sun, and let its light guide your path.',
      offering: 'Arghya of water to the rising sun, red flowers, wheat',
      fastingNote: 'Ravivara vrat: a single meal before sunset, without salt.',
    ),
    DayTheme(
      weekday: 1,
      dayName: 'Monday',
      sanskritDay: 'Somavara',
      deitySlug: 'shiva',
      deityName: 'Shiva',
      epithet: 'Mahadeva, Lord of the Moon',
      accent: Color(0xFF6B7FA8),
      secondary: Color(0xFFC9D3E8),
      lightTint: Color(0xFFEEF1F7),
      darkTint: Color(0xFF161C2A),
      motif: Motif.trishul,
      mantra: 'ॐ नमः शिवाय',
      transliteration: 'Om Namah Shivaya',
      greeting: 'Monday belongs to Mahadeva. Let stillness be your offering.',
      offering: 'Bilva leaves, water and milk abhishekam, white flowers, vibhuti',
      fastingNote: 'Somavara vrat: fruits and milk until evening aarti.',
    ),
    DayTheme(
      weekday: 2,
      dayName: 'Tuesday',
      sanskritDay: 'Mangalavara',
      deitySlug: 'hanuman',
      deityName: 'Hanuman',
      epithet: 'Sankat Mochan, Son of the Wind',
      accent: Color(0xFFC1440E),
      secondary: Color(0xFFF2B632),
      lightTint: Color(0xFFFCE9DF),
      darkTint: Color(0xFF2C130A),
      motif: Motif.gada,
      mantra: 'ॐ हं हनुमते नमः',
      transliteration: 'Om Ham Hanumate Namaha',
      greeting: 'Tuesday for strength and protection. Recite the Chalisa.',
      offering: 'Sindoor, jasmine oil, betel leaves, boondi laddu',
      fastingNote: 'Mangalavara vrat: one meal, avoiding salt, for courage.',
    ),
    DayTheme(
      weekday: 3,
      dayName: 'Wednesday',
      sanskritDay: 'Budhavara',
      deitySlug: 'krishna',
      deityName: 'Krishna',
      epithet: 'Govinda, the Flute Bearer',
      accent: Color(0xFF2E7D55),
      secondary: Color(0xFF1F5F8B),
      lightTint: Color(0xFFE6F2EA),
      darkTint: Color(0xFF0F2318),
      motif: Motif.peacock,
      mantra: 'ॐ नमो भगवते वासुदेवाय',
      transliteration: 'Om Namo Bhagavate Vasudevaya',
      greeting: 'Wednesday for Govinda. Sing, and the day sings back.',
      offering: 'Tulsi leaves, butter, makhan-mishri, green moong',
      fastingNote: 'Budhavara vrat: green foods and a single evening meal.',
    ),
    DayTheme(
      weekday: 4,
      dayName: 'Thursday',
      sanskritDay: 'Guruvara',
      deitySlug: 'vishnu',
      deityName: 'Vishnu',
      epithet: 'Narayana, the Preserver',
      accent: Color(0xFFC9A227),
      secondary: Color(0xFF9B1B30),
      lightTint: Color(0xFFFBF3D9),
      darkTint: Color(0xFF2A2108),
      motif: Motif.shankhaChakra,
      mantra: 'ॐ नमो नारायणाय',
      transliteration: 'Om Namo Narayanaya',
      greeting: 'Thursday for the preserver and the guru. Wear yellow.',
      offering: 'Yellow flowers, chana dal, turmeric, jaggery, banana',
      fastingNote: 'Guruvara vrat: yellow foods, no salt, for wisdom.',
    ),
    DayTheme(
      weekday: 5,
      dayName: 'Friday',
      sanskritDay: 'Shukravara',
      deitySlug: 'devi',
      deityName: 'Devi',
      epithet: 'Shakti, the Mother',
      accent: Color(0xFF9B1B30),
      secondary: Color(0xFFC9A227),
      lightTint: Color(0xFFF9E4E7),
      darkTint: Color(0xFF2A0A10),
      motif: Motif.lotus,
      mantra: 'ॐ ऐं ह्रीं क्लीं चामुण्डायै विच्चे',
      transliteration: 'Om Aim Hreem Kleem Chamundayai Vichche',
      greeting: 'Friday for the mother goddess. Light the lamp at dusk.',
      offering: 'Red flowers, kumkum, bangles, kheer, coconut',
      fastingNote: 'Shukravara vrat: white sweets at sunset, for grace.',
    ),
    DayTheme(
      weekday: 6,
      dayName: 'Saturday',
      sanskritDay: 'Shanivara',
      deitySlug: 'venkateswara',
      deityName: 'Venkateswara',
      epithet: 'Lord of the Seven Hills',
      accent: Color(0xFF3E2723),
      secondary: Color(0xFFC9A227),
      lightTint: Color(0xFFEFE6E2),
      darkTint: Color(0xFF15100E),
      motif: Motif.namam,
      mantra: 'ॐ नमो वेंकटेशाय',
      transliteration: 'Om Namo Venkatesaya',
      greeting: 'Saturday at Tirumala. Govinda, Govinda.',
      offering: 'Tulsi garland, laddu, sesame oil lamp, black gram',
      fastingNote: 'Shanivara vrat: sesame and black gram, lamp of sesame oil.',
    ),
  ];

  /// Deities that are not the lead of a weekday but still get an identity.
  static const List<DayTheme> extraDeities = [
    DayTheme(
      weekday: 2,
      dayName: 'Tuesday',
      sanskritDay: 'Mangalavara',
      deitySlug: 'ganesha',
      deityName: 'Ganesha',
      epithet: 'Vighnaharta, Remover of Obstacles',
      accent: Color(0xFFD9541E),
      secondary: Color(0xFFF2B632),
      lightTint: Color(0xFFFDEBDF),
      darkTint: Color(0xFF2C150A),
      motif: Motif.om,
      mantra: 'ॐ गं गणपतये नमः',
      transliteration: 'Om Gam Ganapataye Namaha',
      greeting: 'Begin with Ganesha and every path clears.',
      offering: 'Modak, durva grass, red hibiscus',
      fastingNote: 'Sankashti Chaturthi: fast until moonrise.',
    ),
    DayTheme(
      weekday: 5,
      dayName: 'Friday',
      sanskritDay: 'Shukravara',
      deitySlug: 'lakshmi',
      deityName: 'Lakshmi',
      epithet: 'Goddess of Prosperity',
      accent: Color(0xFFB8261E),
      secondary: Color(0xFFF2B632),
      lightTint: Color(0xFFFBE7E1),
      darkTint: Color(0xFF2C0E0A),
      motif: Motif.lotus,
      mantra: 'ॐ श्रीं महालक्ष्म्यै नमः',
      transliteration: 'Om Shreem Mahalakshmyai Namaha',
      greeting: 'Friday for prosperity and well-being.',
      offering: 'Lotus, rice, coins, kheer',
      fastingNote: 'Vaibhav Lakshmi vrat on Fridays.',
    ),
    DayTheme(
      weekday: 6,
      dayName: 'Saturday',
      sanskritDay: 'Shanivara',
      deitySlug: 'ayyappa',
      deityName: 'Ayyappa',
      epithet: 'Hariharaputra, Lord of Sabarimala',
      accent: Color(0xFF1B1B1B),
      secondary: Color(0xFFC9A227),
      lightTint: Color(0xFFEDEAE6),
      darkTint: Color(0xFF111111),
      motif: Motif.namam,
      mantra: 'स्वामिये शरणम् अय्यप्पा',
      transliteration: 'Swamiye Saranam Ayyappa',
      greeting: 'Forty-one days of vratham, one climb to the eighteen steps.',
      offering: 'Ghee-filled coconut, irumudi',
      fastingNote: 'Mandala vratham: black attire, vegetarian food, austerity.',
    ),
    DayTheme(
      weekday: 4,
      dayName: 'Thursday',
      sanskritDay: 'Guruvara',
      deitySlug: 'narasimha',
      deityName: 'Narasimha',
      epithet: 'The Lion Avatar',
      accent: Color(0xFFB8860B),
      secondary: Color(0xFF9B1B30),
      lightTint: Color(0xFFFAF0D7),
      darkTint: Color(0xFF291E07),
      motif: Motif.shankhaChakra,
      mantra: 'ॐ नरसिंहाय नमः',
      transliteration: 'Om Narasimhaya Namaha',
      greeting: 'Fierce protector of the devoted.',
      offering: 'Panakam, jaggery water, tulsi',
      fastingNote: 'Narasimha Jayanti fast until dusk.',
    ),
    DayTheme(
      weekday: 4,
      dayName: 'Thursday',
      sanskritDay: 'Guruvara',
      deitySlug: 'rama',
      deityName: 'Rama',
      epithet: 'Maryada Purushottama',
      accent: Color(0xFF1F5F8B),
      secondary: Color(0xFFC9A227),
      lightTint: Color(0xFFE3EEF6),
      darkTint: Color(0xFF0C1C28),
      motif: Motif.shankhaChakra,
      mantra: 'श्री राम जय राम जय जय राम',
      transliteration: 'Sri Rama Jaya Rama Jaya Jaya Rama',
      greeting: 'Walk the path of dharma.',
      offering: 'Tulsi, panakam, vadapappu',
      fastingNote: 'Sri Rama Navami fast.',
    ),
  ];
}
