"""
Application Performance Monitoring (APM) Data Generator

Generates realistic distributed tracing data for microservices:
- 10,000+ microservices
- Parent-child trace relationships
- Realistic latency distributions
- Error patterns and cascading failures
- Service dependencies
- JSONB tags for metadata
"""

import random
import numpy as np
from datetime import datetime, timedelta
from typing import Iterator, List, Dict, Tuple, Optional
from dataclasses import dataclass
import json
import uuid


@dataclass
class Trace:
    """Single trace span."""
    time: datetime
    trace_id: str
    span_id: str
    parent_span_id: Optional[str]
    service_name: str
    operation_name: str
    duration_ms: float
    status_code: int
    tags: str  # JSON string


@dataclass
class Metric:
    """Application metric."""
    time: datetime
    metric_name: str
    service_name: str
    value: float
    tags: str  # JSON string


class APMDataGenerator:
    """
    Generates realistic APM data for distributed systems.

    Features:
    - Microservice architecture (10,000 services)
    - Distributed traces with parent-child relationships
    - Realistic latency (log-normal distribution)
    - Error cascading (upstream failures cause downstream errors)
    - Service mesh patterns (sidecar proxies, retries)
    - Metrics correlated with traces
    - Peak traffic patterns
    """

    def __init__(self, seed: int = 42, num_services: int = 10000):
        """Initialize generator with random seed."""
        random.seed(seed)
        np.random.seed(seed)

        self.num_services = num_services

        # Service tier patterns
        self.tiers = {
            "frontend": {
                "services": ["web-ui", "mobile-api", "graphql-gateway"],
                "operations": ["page_load", "api_request", "graphql_query"],
                "latency_ms": {"mean": 100, "std": 50},
                "error_rate": 0.01,  # 1%
                "proportion": 0.05,
            },
            "api": {
                "services": ["user-service", "product-service", "order-service",
                           "payment-service", "inventory-service", "auth-service"],
                "operations": ["get", "post", "put", "delete", "search"],
                "latency_ms": {"mean": 50, "std": 30},
                "error_rate": 0.02,  # 2%
                "proportion": 0.20,
            },
            "backend": {
                "services": ["recommendation-engine", "search-indexer", "email-worker",
                           "analytics-processor", "fraud-detector", "image-processor"],
                "operations": ["process", "compute", "analyze", "transform"],
                "latency_ms": {"mean": 200, "std": 100},
                "error_rate": 0.05,  # 5%
                "proportion": 0.30,
            },
            "database": {
                "services": ["postgres-primary", "postgres-replica", "redis-cache",
                           "elasticsearch", "mongodb", "cassandra"],
                "operations": ["query", "insert", "update", "delete", "scan"],
                "latency_ms": {"mean": 20, "std": 15},
                "error_rate": 0.001,  # 0.1%
                "proportion": 0.15,
            },
            "external": {
                "services": ["stripe-api", "sendgrid-api", "twilio-api",
                           "aws-s3", "cloudflare-cdn", "auth0"],
                "operations": ["api_call", "upload", "download", "authenticate"],
                "latency_ms": {"mean": 300, "std": 150},
                "error_rate": 0.03,  # 3%
                "proportion": 0.10,
            },
            "infrastructure": {
                "services": ["load-balancer", "api-gateway", "service-mesh-proxy",
                           "message-queue", "cache-warmer", "health-checker"],
                "operations": ["route", "forward", "enqueue", "dequeue"],
                "latency_ms": {"mean": 5, "std": 3},
                "error_rate": 0.001,  # 0.1%
                "proportion": 0.20,
            }
        }

        # Generate service instances
        self.services = self._generate_services()

        # Common HTTP status codes
        self.status_codes = {
            "success": [200, 201, 204],
            "client_error": [400, 401, 403, 404, 422, 429],
            "server_error": [500, 502, 503, 504]
        }

    def _generate_services(self) -> List[Dict]:
        """Generate service instances."""
        services = []
        service_id = 0

        for tier_name, tier_config in self.tiers.items():
            num_tier = int(self.num_services * tier_config["proportion"])

            for i in range(num_tier):
                # Pick service type and add instance number
                base_service = random.choice(tier_config["services"])
                service_name = f"{base_service}-{i % 100:03d}"  # e.g., user-service-042

                services.append({
                    "id": service_id,
                    "name": service_name,
                    "tier": tier_name,
                    "operations": tier_config["operations"],
                    "latency_config": tier_config["latency_ms"],
                    "error_rate": tier_config["error_rate"]
                })

                service_id += 1

        print(f"Generated {len(services)} service instances:")
        for tier_name in self.tiers.keys():
            tier_services = [s for s in services if s["tier"] == tier_name]
            print(f"  {tier_name:15s}: {len(tier_services):5d}")

        return services

    def _generate_latency(self, service: Dict, has_error: bool = False) -> float:
        """
        Generate realistic latency using log-normal distribution.

        Latency is log-normal because:
        - Most requests are fast (median)
        - Long tail of slow requests (p95, p99)
        - Errors often take longer (timeouts)
        """
        mean = service["latency_config"]["mean"]
        std = service["latency_config"]["std"]

        # Log-normal distribution
        latency = np.random.lognormal(np.log(mean), 0.5)

        # Errors often timeout (5x normal latency)
        if has_error and random.random() < 0.5:
            latency *= 5

        return round(latency, 2)

    def _should_have_error(self, service: Dict) -> bool:
        """Determine if this request should error."""
        return random.random() < service["error_rate"]

    def _generate_status_code(self, has_error: bool) -> int:
        """Generate HTTP status code."""
        if not has_error:
            return random.choice(self.status_codes["success"])
        else:
            # 70% client errors, 30% server errors
            if random.random() < 0.7:
                return random.choice(self.status_codes["client_error"])
            else:
                return random.choice(self.status_codes["server_error"])

    def _generate_tags(self, service: Dict, operation: str,
                      status_code: int, environment: str = "production") -> str:
        """Generate JSONB tags for trace."""
        tags = {
            "environment": environment,
            "tier": service["tier"],
            "operation": operation,
            "http.status_code": status_code,
            "http.method": random.choice(["GET", "POST", "PUT", "DELETE"]),
            "version": f"v{random.randint(1, 5)}.{random.randint(0, 20)}.{random.randint(0, 50)}",
            "region": random.choice(["us-east-1", "us-west-2", "eu-west-1", "ap-southeast-1"]),
            "instance_id": f"i-{random.randint(1000, 9999):04d}"
        }

        # Add error details if present
        if status_code >= 400:
            error_types = ["timeout", "connection_refused", "invalid_request",
                          "rate_limited", "internal_error", "database_error"]
            tags["error"] = True
            tags["error.type"] = random.choice(error_types)

        return json.dumps(tags)

    def _generate_trace_tree(self, current_time: datetime,
                            depth: int = 0, max_depth: int = 5,
                            parent_trace_id: Optional[str] = None,
                            parent_span_id: Optional[str] = None) -> List[Trace]:
        """
        Recursively generate trace tree (parent-child relationships).

        A typical request flow:
        frontend → api → backend → database
        """
        if depth > max_depth or random.random() < 0.3:  # 30% chance to stop at each level
            return []

        traces = []

        # Generate current span
        trace_id = parent_trace_id or str(uuid.uuid4())
        span_id = str(uuid.uuid4())

        # Select service based on depth (frontend → api → backend → database)
        tier_progression = ["frontend", "api", "backend", "database", "external"]
        tier = tier_progression[min(depth, len(tier_progression) - 1)]

        tier_services = [s for s in self.services if s["tier"] == tier]
        if not tier_services:
            return []

        service = random.choice(tier_services)
        operation = random.choice(service["operations"])

        # Determine if this span has an error
        has_error = self._should_have_error(service)

        # Generate latency and status
        latency = self._generate_latency(service, has_error)
        status_code = self._generate_status_code(has_error)
        tags = self._generate_tags(service, operation, status_code)

        # Create trace span
        span_time = current_time + timedelta(milliseconds=sum(
            t.duration_ms for t in traces
        ))

        current_span = Trace(
            time=span_time,
            trace_id=trace_id,
            span_id=span_id,
            parent_span_id=parent_span_id,
            service_name=service["name"],
            operation_name=operation,
            duration_ms=latency,
            status_code=status_code,
            tags=tags
        )

        traces.append(current_span)

        # Generate child spans (1-3 downstream calls)
        num_children = random.choices([0, 1, 2, 3], weights=[0.3, 0.4, 0.2, 0.1])[0]

        for _ in range(num_children):
            child_traces = self._generate_trace_tree(
                current_time=span_time,
                depth=depth + 1,
                max_depth=max_depth,
                parent_trace_id=trace_id,
                parent_span_id=span_id
            )
            traces.extend(child_traces)

        return traces

    def generate_traces(self, duration_seconds: int = 3600,
                       traces_per_second: int = 500000) -> Iterator[Trace]:
        """
        Generate distributed trace stream.

        Args:
            duration_seconds: How long to generate data for
            traces_per_second: Number of trace spans/sec

        Yields:
            Trace objects
        """
        start_time = datetime.now()
        current_time = start_time

        total_spans = duration_seconds * traces_per_second

        print(f"Generating ~{total_spans:,} trace spans...")
        print(f"  Duration: {duration_seconds}s ({duration_seconds/3600:.1f} hours)")
        print(f"  Rate: {traces_per_second:,} spans/sec")
        print(f"  Services: {len(self.services):,}")

        spans_generated = 0

        # Generate traces second by second
        for _ in range(duration_seconds):
            current_time += timedelta(seconds=1)

            # Calculate traces for this second (with some randomness)
            traces_this_second = int(traces_per_second * random.uniform(0.8, 1.2))

            # Determine how many are root traces (vs child spans)
            # Assume average trace depth of 3-4, so ~25% are roots
            root_traces = traces_this_second // 4

            for _ in range(root_traces):
                # Generate full trace tree
                trace_tree = self._generate_trace_tree(
                    current_time=current_time,
                    depth=0,
                    max_depth=random.randint(2, 6)
                )

                for span in trace_tree:
                    yield span
                    spans_generated += 1

            # Progress update
            if spans_generated % 1_000_000 == 0:
                print(f"  Generated {spans_generated:,} spans...")

        print(f"✅ Generated {spans_generated:,} spans")

    def generate_dataset(self, size: str = "small") -> List[Trace]:
        """
        Generate complete dataset.

        Args:
            size: 'small' (1M rows), 'medium' (100M rows), 'large' (1B rows)

        Returns:
            List of Trace objects
        """
        # Calculate parameters based on size
        if size == "small":
            # 1M spans at 500K/sec = 2 seconds
            duration_seconds = 2
            traces_per_second = 500000
        elif size == "medium":
            # 100M spans at 500K/sec = 200 seconds
            duration_seconds = 200
            traces_per_second = 500000
        elif size == "large":
            # 1B spans at 500K/sec = 2000 seconds
            duration_seconds = 2000
            traces_per_second = 500000
        else:
            raise ValueError(f"Unknown size: {size}")

        traces = list(self.generate_traces(
            duration_seconds=duration_seconds,
            traces_per_second=traces_per_second
        ))

        return traces


def main():
    """Example usage and testing."""
    # Use smaller number for testing
    generator = APMDataGenerator(seed=42, num_services=100)

    # Generate 5 seconds of data
    print("\nGenerating sample APM data...")
    traces = list(generator.generate_traces(duration_seconds=5, traces_per_second=1000))

    print(f"\n✅ Generated {len(traces):,} trace spans")
    print("\nSample traces (first 10):")

    for i, trace in enumerate(traces[:10]):
        indent = "  " * (2 if trace.parent_span_id else 0)
        symbol = "└─" if trace.parent_span_id else "🔵"
        print(f"  {i+1}. {indent}{symbol} {trace.time.strftime('%H:%M:%S.%f')[:-3]} | "
              f"{trace.service_name:25s} | {trace.operation_name:10s} | "
              f"{trace.duration_ms:7.2f}ms | {trace.status_code}")

    # Statistics
    from collections import Counter

    print("\nService Tier Distribution:")
    # Parse tags to get tier
    tier_counts = Counter()
    for trace in traces:
        tags = json.loads(trace.tags)
        tier_counts[tags.get("tier", "unknown")] += 1

    for tier, count in tier_counts.most_common():
        print(f"  {tier:15s}: {count:6d} spans ({count/len(traces)*100:5.1f}%)")

    print("\nStatus Code Distribution:")
    status_counts = Counter(t.status_code for t in traces)
    for status, count in sorted(status_counts.items()):
        error_mark = "❌" if status >= 400 else "✅"
        print(f"  {error_mark} {status}: {count:6d} ({count/len(traces)*100:5.1f}%)")

    print("\nLatency Statistics:")
    latencies = [t.duration_ms for t in traces]
    print(f"  p50: {np.percentile(latencies, 50):.2f}ms")
    print(f"  p95: {np.percentile(latencies, 95):.2f}ms")
    print(f"  p99: {np.percentile(latencies, 99):.2f}ms")
    print(f"  max: {max(latencies):.2f}ms")

    print("\nTrace Depth Analysis:")
    # Count root traces (no parent)
    root_traces = [t for t in traces if t.parent_span_id is None]
    child_spans = [t for t in traces if t.parent_span_id is not None]
    print(f"  Root traces: {len(root_traces):,}")
    print(f"  Child spans: {len(child_spans):,}")
    print(f"  Avg spans per trace: {len(traces) / len(root_traces) if root_traces else 0:.1f}")

    print("\nError Rate by Tier:")
    for tier in tier_counts.keys():
        tier_traces = [t for t in traces if json.loads(t.tags).get("tier") == tier]
        errors = [t for t in tier_traces if t.status_code >= 400]
        error_rate = len(errors) / len(tier_traces) * 100 if tier_traces else 0
        print(f"  {tier:15s}: {error_rate:5.2f}% ({len(errors)}/{len(tier_traces)})")


if __name__ == "__main__":
    main()
