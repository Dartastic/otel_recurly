// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_recurly_suppression.dart';

const _tracerName = 'dartastic_otel_libs_recurly';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Wraps any Recurly v3 API call in a CLIENT span. The verb in
/// `resource.action` form (e.g. `subscriptions.create`,
/// `accounts.update`) feeds the span name and `recurly.operation`.
Future<T> tracedRecurly<T>({
  required String resource,
  required String action,
  required Future<T> Function() invoke,
  String? subscriptionId,
  String? accountId,
  String? invoiceId,
  String? subdomain,
}) async {
  if (recurlyInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'recurly.resource': resource,
    'recurly.action': action,
    'recurly.operation': '$resource.$action',
  };
  if (subscriptionId != null) m['recurly.subscription.id'] = subscriptionId;
  if (accountId != null) m['recurly.account.id'] = accountId;
  if (invoiceId != null) m['recurly.invoice.id'] = invoiceId;
  if (subdomain != null) m['recurly.subdomain'] = subdomain;

  final span = _tracer().startSpan(
    'recurly $resource.$action',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
