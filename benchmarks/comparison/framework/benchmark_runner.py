"""
Benchmark Framework - Core Runner

Orchestrates benchmark execution across all use cases and drivers.
"""

import json
import time
from dataclasses import dataclass, asdict
from typing import List, Dict, Any, Optional
from datetime import datetime
import subprocess
import sys


@dataclass
class BenchmarkConfig:
    """Configuration for a single benchmark run."""
    use_case: str
    driver: str  # 'psycopg2', 'asyncpg', 'mojo-postgres'
    scenario: str  # 'bulk_insert', 'copy', 'time_range_query', 'aggregation', 'mixed', 'compression'
    dataset_size: str  # 'small', 'medium', 'large'
    database: str
    host: str = "localhost"
    port: int = 5432
    user: str = "postgres"
    password: str = "postgres"


@dataclass
class BenchmarkResult:
    """Results from a single benchmark run."""
    config: BenchmarkConfig
    duration_seconds: float
    throughput_ops_per_sec: float
    latency_p50_ms: float
    latency_p95_ms: float
    latency_p99_ms: float
    memory_mb: float
    cpu_percent: float
    rows_processed: int
    errors: int
    timestamp: str
    metadata: Dict[str, Any]


class BenchmarkRunner:
    """Orchestrates benchmark execution."""

    def __init__(self, output_dir: str = "benchmarks/comparison/results/raw"):
        self.output_dir = output_dir
        self.results: List[BenchmarkResult] = []

    def run_benchmark(self, config: BenchmarkConfig) -> BenchmarkResult:
        """Execute a single benchmark."""
        print(f"\n{'='*80}")
        print(f"Running: {config.use_case} - {config.driver} - {config.scenario} - {config.dataset_size}")
        print(f"{'='*80}")

        start_time = time.time()

        # Determine which implementation to run
        if config.driver == "psycopg2":
            result = self._run_psycopg2_benchmark(config)
        elif config.driver == "asyncpg":
            result = self._run_asyncpg_benchmark(config)
        elif config.driver == "mojo-postgres":
            result = self._run_mojo_benchmark(config)
        else:
            raise ValueError(f"Unknown driver: {config.driver}")

        elapsed = time.time() - start_time

        # Add timing metadata
        result.metadata["total_elapsed"] = elapsed
        result.timestamp = datetime.now().isoformat()

        self.results.append(result)

        # Save result immediately
        self._save_result(result)

        print(f"✅ Completed in {elapsed:.2f}s")
        print(f"   Throughput: {result.throughput_ops_per_sec:.0f} ops/sec")
        print(f"   Latency p95: {result.latency_p95_ms:.2f}ms")

        return result

    def _run_psycopg2_benchmark(self, config: BenchmarkConfig) -> BenchmarkResult:
        """Run psycopg2 implementation."""
        script_path = f"benchmarks/comparison/python/psycopg2_impl/{config.use_case}_bench.py"

        cmd = [
            sys.executable,
            script_path,
            "--scenario", config.scenario,
            "--dataset-size", config.dataset_size,
            "--database", config.database,
            "--host", config.host,
            "--port", str(config.port),
            "--user", config.user,
            "--password", config.password
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"psycopg2 benchmark failed: {result.stderr}")

        # Parse JSON output
        output = json.loads(result.stdout)

        return BenchmarkResult(
            config=config,
            duration_seconds=output["duration_seconds"],
            throughput_ops_per_sec=output["throughput_ops_per_sec"],
            latency_p50_ms=output["latency_p50_ms"],
            latency_p95_ms=output["latency_p95_ms"],
            latency_p99_ms=output["latency_p99_ms"],
            memory_mb=output["memory_mb"],
            cpu_percent=output["cpu_percent"],
            rows_processed=output["rows_processed"],
            errors=output.get("errors", 0),
            timestamp="",
            metadata=output.get("metadata", {})
        )

    def _run_asyncpg_benchmark(self, config: BenchmarkConfig) -> BenchmarkResult:
        """Run asyncpg implementation."""
        script_path = f"benchmarks/comparison/python/asyncpg_impl/{config.use_case}_bench.py"

        cmd = [
            sys.executable,
            script_path,
            "--scenario", config.scenario,
            "--dataset-size", config.dataset_size,
            "--database", config.database,
            "--host", config.host,
            "--port", str(config.port),
            "--user", config.user,
            "--password", config.password
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"asyncpg benchmark failed: {result.stderr}")

        output = json.loads(result.stdout)

        return BenchmarkResult(
            config=config,
            duration_seconds=output["duration_seconds"],
            throughput_ops_per_sec=output["throughput_ops_per_sec"],
            latency_p50_ms=output["latency_p50_ms"],
            latency_p95_ms=output["latency_p95_ms"],
            latency_p99_ms=output["latency_p99_ms"],
            memory_mb=output["memory_mb"],
            cpu_percent=output["cpu_percent"],
            rows_processed=output["rows_processed"],
            errors=output.get("errors", 0),
            timestamp="",
            metadata=output.get("metadata", {})
        )

    def _run_mojo_benchmark(self, config: BenchmarkConfig) -> BenchmarkResult:
        """Run mojo-postgres implementation."""
        script_path = f"benchmarks/comparison/mojo/{config.use_case}_bench.mojo"

        cmd = [
            "mojo",
            script_path,
            "--scenario", config.scenario,
            "--dataset-size", config.dataset_size,
            "--database", config.database,
            "--host", config.host,
            "--port", str(config.port),
            "--user", config.user,
            "--password", config.password
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode != 0:
            raise RuntimeError(f"mojo-postgres benchmark failed: {result.stderr}")

        output = json.loads(result.stdout)

        return BenchmarkResult(
            config=config,
            duration_seconds=output["duration_seconds"],
            throughput_ops_per_sec=output["throughput_ops_per_sec"],
            latency_p50_ms=output["latency_p50_ms"],
            latency_p95_ms=output["latency_p95_ms"],
            latency_p99_ms=output["latency_p99_ms"],
            memory_mb=output["memory_mb"],
            cpu_percent=output["cpu_percent"],
            rows_processed=output["rows_processed"],
            errors=output.get("errors", 0),
            timestamp="",
            metadata=output.get("metadata", {})
        )

    def _save_result(self, result: BenchmarkResult):
        """Save result to JSON file."""
        filename = f"{result.config.use_case}_{result.config.driver}_{result.config.scenario}_{result.config.dataset_size}_{result.timestamp.replace(':', '-')}.json"
        filepath = f"{self.output_dir}/{filename}"

        with open(filepath, 'w') as f:
            json.dump(asdict(result), f, indent=2)

    def run_all_benchmarks(self, use_cases: List[str], drivers: List[str],
                          scenarios: List[str], dataset_sizes: List[str]):
        """Run all combinations of benchmarks."""
        total = len(use_cases) * len(drivers) * len(scenarios) * len(dataset_sizes)
        current = 0

        print(f"\n🚀 Starting benchmark suite: {total} total benchmarks")
        print(f"   Use cases: {len(use_cases)}")
        print(f"   Drivers: {len(drivers)}")
        print(f"   Scenarios: {len(scenarios)}")
        print(f"   Dataset sizes: {len(dataset_sizes)}")
        print()

        for use_case in use_cases:
            for driver in drivers:
                # Determine database name
                database = f"bench_{driver.replace('-', '_')}"

                for scenario in scenarios:
                    for dataset_size in dataset_sizes:
                        current += 1

                        print(f"\n[{current}/{total}] Progress: {current/total*100:.1f}%")

                        config = BenchmarkConfig(
                            use_case=use_case,
                            driver=driver,
                            scenario=scenario,
                            dataset_size=dataset_size,
                            database=database
                        )

                        try:
                            self.run_benchmark(config)
                        except Exception as e:
                            print(f"❌ Error: {e}")
                            # Continue with next benchmark

                        # Small delay between benchmarks
                        time.sleep(2)

        print(f"\n✅ Benchmark suite complete! {len(self.results)} results collected")

    def generate_summary(self) -> Dict[str, Any]:
        """Generate summary statistics."""
        if not self.results:
            return {}

        summary = {
            "total_benchmarks": len(self.results),
            "by_driver": {},
            "by_use_case": {},
            "by_scenario": {}
        }

        # Group by driver
        for driver in ["psycopg2", "asyncpg", "mojo-postgres"]:
            driver_results = [r for r in self.results if r.config.driver == driver]
            if driver_results:
                summary["by_driver"][driver] = {
                    "count": len(driver_results),
                    "avg_throughput": sum(r.throughput_ops_per_sec for r in driver_results) / len(driver_results),
                    "avg_latency_p95": sum(r.latency_p95_ms for r in driver_results) / len(driver_results)
                }

        return summary


def main():
    """Example usage."""
    runner = BenchmarkRunner()

    # Define benchmark matrix
    use_cases = [
        "crypto_trading",
        "market_data",
        # "defi_monitoring",
        # ... add more as implemented
    ]

    drivers = [
        "psycopg2",
        "asyncpg",
        "mojo-postgres"
    ]

    scenarios = [
        "bulk_insert",
        "copy",
        "time_range_query",
        "aggregation",
        "mixed",
        "compression"
    ]

    dataset_sizes = [
        "small",    # 1M rows
        "medium",   # 100M rows
        # "large"   # 1B rows (takes hours)
    ]

    # Run benchmarks
    runner.run_all_benchmarks(use_cases, drivers, scenarios, dataset_sizes)

    # Generate summary
    summary = runner.generate_summary()
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
