// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_recurly/otel_recurly.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_recurly-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('subscriptions.create records CLIENT span', () async {
    await tracedRecurly<String>(
      resource: 'subscriptions',
      action: 'create',
      accountId: 'acct-1',
      subdomain: 'acme',
      invoke: () async => 'sub-1',
    );
    final a = attrsOf(spans.findSpanByName('recurly subscriptions.create')!);
    expect(a['recurly.resource'], 'subscriptions');
    expect(a['recurly.action'], 'create');
    expect(a['recurly.operation'], 'subscriptions.create');
    expect(a['recurly.account.id'], 'acct-1');
    expect(a['recurly.subdomain'], 'acme');
  });

  test('records exception', () async {
    await expectLater(
      tracedRecurly<String>(
        resource: 'subscriptions',
        action: 'create',
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      spans.findSpanByName('recurly subscriptions.create')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutRecurlyInstrumentationAsync(() async {
      await tracedRecurly<String>(
        resource: 'subscriptions',
        action: 'create',
        invoke: () async => 'sub-2',
      );
    });
    expect(spans.findSpansStartingWith('recurly '), isEmpty);
  });
}
