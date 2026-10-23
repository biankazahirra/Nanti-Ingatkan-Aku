import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// DEC-02: the Indonesian ARB is the only shipped copy deck. These tests keep
/// the domain's message keys and the deck from drifting apart.
void main() {
  final arbFile = File('lib/l10n/app_id.arb');
  final messagesFile = File('lib/l10n/messages.dart');

  Map<String, Object?> readArb() =>
      jsonDecode(arbFile.readAsStringSync()) as Map<String, Object?>;

  Set<String> arbKeys() =>
      readArb().keys.where((key) => !key.startsWith('@')).toSet();

  /// gen-l10n only accepts Dart identifiers, so a dotted domain key such as
  /// `error.title_empty` is spelled `errorTitleEmpty` in the deck.
  String identifierFor(String key) {
    final words = key
        .split(RegExp('[._]'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .toList();
    return words.first +
        words.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
  }

  /// Keys the domain hands to the presentation layer, e.g. `'error.title_empty'`.
  Set<String> messageKeys() =>
      RegExp(r"^\s*'([a-zA-Z0-9_.]+)'\s*=>", multiLine: true)
          .allMatches(messagesFile.readAsStringSync())
          .map((match) => match.group(1)!)
          .toSet();

  test('the copy deck and the message mapper both exist', () {
    expect(arbFile.existsSync(), isTrue, reason: arbFile.path);
    expect(messagesFile.existsSync(), isTrue, reason: messagesFile.path);
  });

  test('only Indonesian is declared as a locale', () {
    expect(readArb()['@@locale'], 'id');
    expect(
      Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .map((file) => file.uri.pathSegments.last),
      ['app_id.arb'],
    );
  });

  test('every key is a Dart identifier gen-l10n can generate', () {
    // Regression guard: dotted keys are rejected by the generator with
    // `Invalid ARB resource name`, which breaks the whole build.
    // A dotted domain key such as `error.title_empty` is not a Dart
    // identifier, so this catches any key the generator would reject.
    final invalid = arbKeys().where((key) => !key.isValidDartName);
    expect(invalid, isEmpty, reason: 'invalid ARB keys: $invalid');
  });

  test('every copy value is non-empty and is not a leftover placeholder', () {
    final entries = readArb().entries.where((e) => !e.key.startsWith('@'));
    expect(entries, isNotEmpty);
    for (final entry in entries) {
      final value = entry.value;
      expect(value, isA<String>(), reason: entry.key);
      final text = value! as String;
      expect(text.trim(), isNotEmpty, reason: entry.key);
      expect(text, isNot(equals(entry.key)), reason: entry.key);
      // A template that never got translated keeps the key as its own text.
      expect(text.contains('TODO'), isFalse, reason: entry.key);
    }
  });

  test('every message key the domain can emit exists in the copy deck', () {
    final missing = messageKeys()
        .map(identifierFor)
        .toSet()
        .difference(arbKeys());
    expect(missing, isEmpty, reason: 'ARB keys missing: $missing');
  });

  test('placeholders referenced in copy are declared', () {
    final arb = readArb();
    for (final entry in arb.entries.where((e) => !e.key.startsWith('@'))) {
      final placeholders = RegExp(r'\{(\w+)\}')
          .allMatches(entry.value! as String);
      if (placeholders.isEmpty) continue;
      final meta = arb['@${entry.key}'];
      final declared = meta is Map
          ? (meta['placeholders'] as Map?)?.keys.toSet() ?? const <String>{}
          : const <String>{};
      expect(
        placeholders.map((m) => m.group(1)!).toSet(),
        declared,
        reason: entry.key,
      );
    }
  });

  test('the business limits in the copy match the code', () {
    final arb = readArb();
    expect(arb['errorTitleTooLong'], contains('120'));
    expect(arb['errorBodyTooLong'], contains('10.000'));
    expect(arb['errorPersonTooLong'], contains('80'));
    expect(arb['errorItemTooLong'], contains('120'));
  });
}

extension on String {
  /// `gen_l10n` accepts camelCase identifiers only.
  bool get isValidDartName => RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(this);
}
