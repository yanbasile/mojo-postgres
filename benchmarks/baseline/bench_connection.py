#!/usr/bin/env python3
"""
Python Baseline: psycopg2 Connection Benchmark

Measures connection establishment time for comparison with mojo-postgres.
"""

import psycopg2
import time
import statistics


# Configuration
HOST = "localhost"
PORT = 5432
DATABASE = "benchdb"
USER = "benchuser"
PASSWORD = "benchpass"
ITERATIONS = 1000


def connect_once():
    """Connect to PostgreSQL and immediately disconnect."""
    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        database=DATABASE,
        user=USER,
        password=PASSWORD
    )
    conn.close()


def benchmark_connection():
    """Benchmark connection establishment."""
    print("=" * 70)
    print("BENCHMARK: psycopg2 Connection Establishment")
    print("=" * 70)
    print(f"Configuration:")
    print(f"  Host:       {HOST}")
    print(f"  Port:       {PORT}")
    print(f"  Database:   {DATABASE}")
    print(f"  User:       {USER}")
    print(f"  Iterations: {ITERATIONS}")
    print("=" * 70)

    # Warmup
    print("\nWarming up...")
    for _ in range(10):
        connect_once()

    # Benchmark
    print("Running benchmark...")
    timings = []

    for i in range(ITERATIONS):
        start = time.perf_counter_ns()
        connect_once()
        end = time.perf_counter_ns()
        timings.append(end - start)

        if (i + 1) % 100 == 0:
            print(f"  Progress: {i + 1}/{ITERATIONS}")

    # Calculate statistics
    total_ns = sum(timings)
    mean_ns = statistics.mean(timings)
    median_ns = statistics.median(timings)
    min_ns = min(timings)
    max_ns = max(timings)
    p95_ns = statistics.quantiles(timings, n=20)[18]  # 95th percentile
    p99_ns = statistics.quantiles(timings, n=100)[98]  # 99th percentile

    # Print results
    print("\n" + "=" * 70)
    print("RESULTS")
    print("=" * 70)
    print(f"Iterations:      {ITERATIONS}")
    print(f"Total Time:      {total_ns / 1_000_000:.2f} ms")
    print(f"Mean:            {mean_ns / 1_000_000:.3f} ms ({mean_ns / 1_000:.1f} μs)")
    print(f"Median:          {median_ns / 1_000_000:.3f} ms")
    print(f"Min:             {min_ns / 1_000_000:.3f} ms")
    print(f"Max:             {max_ns / 1_000_000:.3f} ms")
    print(f"P95:             {p95_ns / 1_000_000:.3f} ms")
    print(f"P99:             {p99_ns / 1_000_000:.3f} ms")
    print(f"Throughput:      {ITERATIONS / (total_ns / 1_000_000_000):.0f} ops/sec")
    print("=" * 70)

    # Save results for comparison
    with open("results_psycopg2.txt", "w") as f:
        f.write(f"mean_ns={mean_ns}\n")
        f.write(f"median_ns={median_ns}\n")
        f.write(f"p95_ns={p95_ns}\n")
        f.write(f"p99_ns={p99_ns}\n")

    print("\nResults saved to: results_psycopg2.txt")
    print("Use these values to compare with mojo-postgres benchmark")

    return mean_ns


if __name__ == "__main__":
    try:
        mean_ns = benchmark_connection()

        print("\n" + "=" * 70)
        print("COMPARISON TARGET")
        print("=" * 70)
        print(f"psycopg2 mean:          {mean_ns / 1_000_000:.3f} ms")
        print(f"Target (4x faster):     {mean_ns / 4_000_000:.3f} ms")
        print(f"Aggressive (10x faster): {mean_ns / 10_000_000:.3f} ms")
        print("=" * 70)

    except psycopg2.Error as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure PostgreSQL is running:")
        print("  docker run -d -p 5432:5432 \\")
        print("    -e POSTGRES_PASSWORD=benchpass \\")
        print("    -e POSTGRES_USER=benchuser \\")
        print("    -e POSTGRES_DB=benchdb \\")
        print("    postgres:16")
