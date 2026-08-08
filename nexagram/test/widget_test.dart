// Minimal smoke test: verifies the app boots without throwing.
//
// A deeper widget test would need a fake Supabase client and seeded auth
// state (the previous placeholder here was flutter create's counter-app
// template and didn't actually exercise NexaGramApp), so this intentionally
// stays a light "does it construct" check rather than asserting on screen
// content that depends on backend state.
//
// Supabase.initialize() only builds a local client — it does not make a
// network call — so a dummy URL/key is enough to satisfy the services'
// `Supabase.instance.client` lookups during the test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nexagram/main.dart';

void main() {
  testWidgets('NexaGramApp builds without throwing', (WidgetTester tester) async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );

    await tester.pumpWidget(const NexaGramApp());
    await tester.pump();

    // The app should have built a MaterialApp-backed widget tree.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
