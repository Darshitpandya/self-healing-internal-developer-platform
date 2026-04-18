"""OpenTelemetry tracing helper for self-healing actions.

Emits a trace span for each self-healing action — used for audit trail
and SLO measurement.

Usage in GitHub Actions:
  python -c "from otel.tracing import trace_action; trace_action('golden_path_upgrade', 'payments-svc', 'allow', 'https://github.com/...')"
"""

import os

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor, ConsoleSpanExporter
from opentelemetry.sdk.resources import Resource


def _init_tracer() -> trace.Tracer:
    resource = Resource.create({"service.name": "self-healing-platform"})
    provider = TracerProvider(resource=resource)
    provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))

    otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if otlp_endpoint:
        try:
            from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
            provider.add_span_processor(SimpleSpanProcessor(OTLPSpanExporter(endpoint=otlp_endpoint)))
        except ImportError:
            pass

    trace.set_tracer_provider(provider)
    return trace.get_tracer("self-healing-agent")


def trace_action(action_type: str, service: str, policy_decision: str, pr_url: str = ""):
    """Emit a trace span for a self-healing action."""
    tracer = _init_tracer()
    with tracer.start_as_current_span("self-heal-action") as span:
        span.set_attribute("action.type", action_type)
        span.set_attribute("service.name", service)
        span.set_attribute("policy.decision", policy_decision)
        span.set_attribute("remediation.pr_url", pr_url)
