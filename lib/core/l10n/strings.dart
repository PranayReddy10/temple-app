import 'package:flutter/widgets.dart';

/// Interface strings in English, Telugu and Hindi.
///
/// Kept as a plain map rather than ARB files so a string can be added in one
/// place. Temple content itself is localised by the backend (alternate names
/// and spellings); this covers the app chrome.
class S {
  const S(this.code);

  final String code;

  static S of(BuildContext context) => S(Localizations.localeOf(context).languageCode);

  String call(String key) => _table[key]?[code] ?? _table[key]?['en'] ?? key;

  static const Map<String, Map<String, String>> _table = {
    'home': {'en': 'Home', 'te': 'హోమ్', 'hi': 'होम'},
    'explore': {'en': 'Explore', 'te': 'అన్వేషణ', 'hi': 'खोजें'},
    'passport': {'en': 'Passport', 'te': 'పాస్‌పోర్ట్', 'hi': 'पासपोर्ट'},
    'yatra': {'en': 'Yatra', 'te': 'యాత్ర', 'hi': 'यात्रा'},
    'profile': {'en': 'Profile', 'te': 'ప్రొఫైల్', 'hi': 'प्रोफ़ाइल'},
    'search_hint': {'en': 'Search temples, deities, cities', 'te': 'ఆలయాలు, దేవతలు, నగరాలు వెతకండి', 'hi': 'मंदिर, देवता, शहर खोजें'},
    'today': {'en': 'Today', 'te': 'ఈ రోజు', 'hi': 'आज'},
    'nearby': {'en': 'Near you', 'te': 'మీ దగ్గర', 'hi': 'आपके पास'},
    'popular': {'en': 'Popular temples', 'te': 'ప్రసిద్ధ ఆలయాలు', 'hi': 'लोकप्रिय मंदिर'},
    'festivals': {'en': 'Festivals & events', 'te': 'పండుగలు & కార్యక్రమాలు', 'hi': 'त्योहार और कार्यक्रम'},
    'week': {'en': 'The week of devotion', 'te': 'భక్తి వారం', 'hi': 'भक्ति का सप्ताह'},
    'temples_of': {'en': 'Temples of', 'te': 'ఆలయాలు:', 'hi': 'मंदिर:'},
    'see_all': {'en': 'See all', 'te': 'అన్నీ చూడండి', 'hi': 'सभी देखें'},
    'categories': {'en': 'Pilgrimage circuits', 'te': 'తీర్థయాత్ర మార్గాలు', 'hi': 'तीर्थ परिक्रमाएँ'},
    'by_deity': {'en': 'By deity', 'te': 'దేవత వారీగా', 'hi': 'देवता के अनुसार'},
    'by_state': {'en': 'By state', 'te': 'రాష్ట్రం వారీగా', 'hi': 'राज्य के अनुसार'},
    'map': {'en': 'Map', 'te': 'పటం', 'hi': 'मानचित्र'},
    'filters': {'en': 'Filters', 'te': 'వడపోతలు', 'hi': 'फ़िल्टर'},
    'verified_only': {'en': 'Verified only', 'te': 'ధృవీకరించినవి మాత్రమే', 'hi': 'केवल सत्यापित'},
    'no_results': {'en': 'No temples match. Try a different name or city.', 'te': 'ఆలయాలు కనబడలేదు. వేరే పేరు ప్రయత్నించండి.', 'hi': 'कोई मंदिर नहीं मिला। दूसरा नाम आज़माएँ।'},
    'offline_note': {'en': 'Showing bundled records. Connect to see live data.', 'te': 'నిల్వ చేసిన రికార్డులు చూపుతున్నాం. ప్రత్యక్ష డేటా కోసం కనెక్ట్ అవ్వండి.', 'hi': 'संग्रहीत रिकॉर्ड दिखा रहे हैं। लाइव डेटा के लिए कनेक्ट करें।'},
    'timings': {'en': 'Darshan timings', 'te': 'దర్శన సమయాలు', 'hi': 'दर्शन समय'},
    'pujas': {'en': 'Puja & seva', 'te': 'పూజ & సేవ', 'hi': 'पूजा और सेवा'},
    'facilities': {'en': 'Facilities', 'te': 'సౌకర్యాలు', 'hi': 'सुविधाएँ'},
    'visitor_rules': {'en': 'Visitor rules', 'te': 'సందర్శకుల నియమాలు', 'hi': 'दर्शनार्थी नियम'},
    'about': {'en': 'About', 'te': 'గురించి', 'hi': 'परिचय'},
    'contact': {'en': 'Contact', 'te': 'సంప్రదించండి', 'hi': 'संपर्क'},
    'check_in': {'en': 'Check in', 'te': 'చెక్-ఇన్', 'hi': 'चेक-इन'},
    'visited': {'en': 'Visited', 'te': 'సందర్శించారు', 'hi': 'दर्शन किया'},
    'save': {'en': 'Save', 'te': 'సేవ్', 'hi': 'सहेजें'},
    'saved': {'en': 'Saved', 'te': 'సేవ్ అయింది', 'hi': 'सहेजा गया'},
    'add_to_yatra': {'en': 'Add to yatra', 'te': 'యాత్రకు జోడించు', 'hi': 'यात्रा में जोड़ें'},
    'closed_today': {'en': 'Closed today', 'te': 'ఈ రోజు మూసివేయబడింది', 'hi': 'आज बंद'},
    'stamps': {'en': 'Stamps', 'te': 'ముద్రలు', 'hi': 'मुहरें'},
    'visits': {'en': 'Visits', 'te': 'సందర్శనలు', 'hi': 'दर्शन'},
    'collections': {'en': 'Collections', 'te': 'సేకరణలు', 'hi': 'संग्रह'},
    'achievements': {'en': 'Achievements', 'te': 'విజయాలు', 'hi': 'उपलब्धियाँ'},
    'no_stamps': {'en': 'Your passport is waiting for its first stamp. Check in at a temple to begin.', 'te': 'మీ పాస్‌పోర్ట్ మొదటి ముద్ర కోసం వేచి ఉంది. ఆలయంలో చెక్-ఇన్ చేయండి.', 'hi': 'आपका पासपोर्ट पहली मुहर की प्रतीक्षा में है। किसी मंदिर में चेक-इन करें।'},
    'my_yatras': {'en': 'My yatras', 'te': 'నా యాత్రలు', 'hi': 'मेरी यात्राएँ'},
    'new_yatra': {'en': 'Plan a yatra', 'te': 'యాత్ర ప్రణాళిక', 'hi': 'यात्रा की योजना'},
    'yatra_mode': {'en': 'Yatra mode', 'te': 'యాత్ర మోడ్', 'hi': 'यात्रा मोड'},
    'no_yatras': {'en': 'No yatra planned yet. Every pilgrimage begins with one temple.', 'te': 'ఇంకా యాత్ర ప్రణాళిక లేదు. ప్రతి తీర్థయాత్ర ఒక ఆలయంతో మొదలవుతుంది.', 'hi': 'अभी कोई यात्रा नहीं। हर तीर्थ एक मंदिर से शुरू होता है।'},
    'memories': {'en': 'Memories', 'te': 'జ్ఞాపకాలు', 'hi': 'यादें'},
    'settings': {'en': 'Settings', 'te': 'సెట్టింగ్‌లు', 'hi': 'सेटिंग्स'},
    'language': {'en': 'Language', 'te': 'భాష', 'hi': 'भाषा'},
    'appearance': {'en': 'Appearance', 'te': 'రూపం', 'hi': 'रूप'},
    'sign_in': {'en': 'Sign in', 'te': 'సైన్ ఇన్', 'hi': 'साइन इन'},
    'sign_out': {'en': 'Sign out', 'te': 'సైన్ అవుట్', 'hi': 'साइन आउट'},
    'create_account': {'en': 'Create account', 'te': 'ఖాతా సృష్టించండి', 'hi': 'खाता बनाएँ'},
    'guest': {'en': 'Devotee', 'te': 'భక్తుడు', 'hi': 'भक्त'},
    'mantra_of_day': {'en': 'Mantra of the day', 'te': 'ఈ రోజు మంత్రం', 'hi': 'आज का मंत्र'},
    'offering': {'en': 'Offering', 'te': 'నైవేద్యం', 'hi': 'अर्पण'},
    'fasting': {'en': 'Vrat', 'te': 'వ్రతం', 'hi': 'व्रत'},
    'photo_stamp': {'en': 'Photo stamp', 'te': 'ఫోటో ముద్ర', 'hi': 'फ़ोटो मुहर'},
    'share': {'en': 'Share', 'te': 'పంచుకోండి', 'hi': 'साझा करें'},
    'enter': {'en': 'Enter the temple', 'te': 'ఆలయంలోకి ప్రవేశించండి', 'hi': 'मंदिर में प्रवेश करें'},
    'trust_note': {'en': 'Only official and verified records are checked against a primary source.', 'te': 'అధికారిక మరియు ధృవీకరించిన రికార్డులు మాత్రమే ప్రాథమిక మూలంతో సరిపోల్చబడతాయి.', 'hi': 'केवल आधिकारिक और सत्यापित रिकॉर्ड प्राथमिक स्रोत से जाँचे जाते हैं।'},
  };
}
