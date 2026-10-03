import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/services/deep_links.dart';
import 'package:temple_app/features/temple/temple_screen.dart';

void main() {
  test('a shared temple page opens that temple', () {
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/temples/sri-rama-bhadrachalam')), const DeepLink('sri-rama-bhadrachalam'));
    expect(DeepLink.parse(Uri.parse('https://www.darshansaathi.com/temples/sri-rama-bhadrachalam/')), const DeepLink('sri-rama-bhadrachalam'));
  });

  test('the website buttons open the temple, and Book goes to its sevas', () {
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/?temple=sri-rama-bhadrachalam')), const DeepLink('sri-rama-bhadrachalam'));
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/?temple=sri-rama-bhadrachalam&action=book')), const DeepLink('sri-rama-bhadrachalam', book: true));
  });

  test('anything else is not a temple', () {
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/')), isNull);
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/temples')), isNull);
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/?temple=../../etc')), isNull);
    expect(DeepLink.parse(Uri.parse('https://darshansaathi.com/privacy-policy')), isNull);
  });

  test('sharing a temple sends its page, which opens the same temple', () {
    expect(templeShareText('Sri Rama Temple', 'Bhadrachalam', 'sri-rama-bhadrachalam'), 'Sri Rama Temple, Bhadrachalam\nhttps://darshansaathi.com/temples/sri-rama-bhadrachalam');
    expect(templeShareText('Sri Rama Temple', null, 'sri-rama'), 'Sri Rama Temple\nhttps://darshansaathi.com/temples/sri-rama');
  });
}
