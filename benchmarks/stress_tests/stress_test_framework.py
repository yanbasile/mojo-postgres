"""
Stress Test Framework for mojo-postgres

Provides base classes and utilities for stress testing the mojo-postgres driver.
"""

import time
import psutil
import threading
import multiprocessing
from datetime import datetime, timedelta
from typing import List, Dict, Callable, Optional, Any
from dataclasses import dataclass
from enum import Enum
import json


class TestStatus(Enum):
    """Test execution status."""
    PENDING = "pending"
    RUNNING = "running"
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class TestResult:
    """Result of a stress test."""
    test_name: str
    status: TestStatus
    duration_seconds: float
    start_time: datetime
    end_time: datetime
    metrics: Dict[str, Any]
    errors: List[str]
    warnings: List[str]
    pass_criteria: Dict[str, bool]


class StressTestBase:
    """
    Base class for all stress tests.

    Provides common functionality:
    - Timing and metrics collection
    - Resource monitoring
    - Result reporting
    - Pass/fail criteria checking
    """

    def __init__(self, name: str, description: str):
        """Initialize stress test."""
        self.name = name
        self.description = description
        self.start_time = None
        self.end_time = None
        self.metrics = {}
        self.errors = []
        self.warnings = []
        self.pass_criteria = {}

        # Resource monitoring
        self.process = psutil.Process()
        self.initial_memory = 0
        self.peak_memory = 0
        self.monitoring = False
        self.monitor_thread = None

    def setup(self):
        """Override: Setup before test execution."""
        pass

    def teardown(self):
        """Override: Cleanup after test execution."""
        pass

    def run_test(self) -> Dict[str, Any]:
        """Override: Main test logic. Return metrics dict."""
        raise NotImplementedError("Subclasses must implement run_test()")

    def check_pass_criteria(self) -> Dict[str, bool]:
        """Override: Define pass/fail criteria. Return dict of checks."""
        return {}

    def start_resource_monitoring(self):
        """Start background resource monitoring."""
        self.monitoring = True
        self.initial_memory = self.process.memory_info().rss / 1024 / 1024  # MB
        self.peak_memory = self.initial_memory

        def monitor():
            while self.monitoring:
                current_memory = self.process.memory_info().rss / 1024 / 1024
                self.peak_memory = max(self.peak_memory, current_memory)
                time.sleep(1)

        self.monitor_thread = threading.Thread(target=monitor, daemon=True)
        self.monitor_thread.start()

    def stop_resource_monitoring(self):
        """Stop resource monitoring."""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=2)

        final_memory = self.process.memory_info().rss / 1024 / 1024
        memory_growth = final_memory - self.initial_memory

        self.metrics.update({
            "initial_memory_mb": round(self.initial_memory, 2),
            "peak_memory_mb": round(self.peak_memory, 2),
            "final_memory_mb": round(final_memory, 2),
            "memory_growth_mb": round(memory_growth, 2)
        })

    def execute(self) -> TestResult:
        """Execute the stress test."""
        print(f"\n{'='*80}")
        print(f"Stress Test: {self.name}")
        print(f"Description: {self.description}")
        print(f"{'='*80}\n")

        self.start_time = datetime.now()
        status = TestStatus.RUNNING

        try:
            # Setup
            print("Setting up test...")
            self.setup()

            # Start monitoring
            self.start_resource_monitoring()

            # Run test
            print(f"Running test (started at {self.start_time.strftime('%Y-%m-%d %H:%M:%S')})...")
            test_metrics = self.run_test()
            self.metrics.update(test_metrics)

            # Stop monitoring
            self.stop_resource_monitoring()

            # Check pass criteria
            print("\nChecking pass criteria...")
            self.pass_criteria = self.check_pass_criteria()

            # Determine status
            if all(self.pass_criteria.values()):
                status = TestStatus.PASSED
                print("✅ TEST PASSED")
            else:
                status = TestStatus.FAILED
                print("❌ TEST FAILED")

        except Exception as e:
            status = TestStatus.FAILED
            self.errors.append(f"Test execution error: {str(e)}")
            print(f"❌ TEST FAILED: {str(e)}")

        finally:
            # Teardown
            try:
                print("\nTearing down test...")
                self.teardown()
            except Exception as e:
                self.warnings.append(f"Teardown error: {str(e)}")

            self.end_time = datetime.now()

        # Calculate duration
        duration = (self.end_time - self.start_time).total_seconds()

        # Create result
        result = TestResult(
            test_name=self.name,
            status=status,
            duration_seconds=duration,
            start_time=self.start_time,
            end_time=self.end_time,
            metrics=self.metrics,
            errors=self.errors,
            warnings=self.warnings,
            pass_criteria=self.pass_criteria
        )

        # Print summary
        self.print_summary(result)

        return result

    def print_summary(self, result: TestResult):
        """Print test result summary."""
        print(f"\n{'='*80}")
        print(f"Test Summary: {result.test_name}")
        print(f"{'='*80}")
        print(f"Status: {result.status.value.upper()}")
        print(f"Duration: {result.duration_seconds:.2f} seconds ({result.duration_seconds/3600:.2f} hours)")
        print(f"Start: {result.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"End: {result.end_time.strftime('%Y-%m-%d %H:%M:%S')}")

        print(f"\nMetrics:")
        for key, value in result.metrics.items():
            print(f"  {key}: {value}")

        print(f"\nPass Criteria:")
        for criterion, passed in result.pass_criteria.items():
            status = "✅" if passed else "❌"
            print(f"  {status} {criterion}")

        if result.errors:
            print(f"\nErrors ({len(result.errors)}):")
            for error in result.errors:
                print(f"  ❌ {error}")

        if result.warnings:
            print(f"\nWarnings ({len(result.warnings)}):")
            for warning in result.warnings:
                print(f"  ⚠️  {warning}")

        print(f"{'='*80}\n")

    def save_result(self, result: TestResult, output_file: str):
        """Save test result to JSON file."""
        result_dict = {
            "test_name": result.test_name,
            "status": result.status.value,
            "duration_seconds": result.duration_seconds,
            "start_time": result.start_time.isoformat(),
            "end_time": result.end_time.isoformat(),
            "metrics": result.metrics,
            "errors": result.errors,
            "warnings": result.warnings,
            "pass_criteria": result.pass_criteria
        }

        with open(output_file, 'w') as f:
            json.dump(result_dict, f, indent=2)

        print(f"Results saved to: {output_file}")


class StressTestSuite:
    """
    Collection of stress tests to execute.
    """

    def __init__(self, name: str):
        """Initialize test suite."""
        self.name = name
        self.tests = []
        self.results = []

    def add_test(self, test: StressTestBase):
        """Add a test to the suite."""
        self.tests.append(test)

    def run_all(self) -> List[TestResult]:
        """Execute all tests in the suite."""
        print(f"\n{'#'*80}")
        print(f"# Stress Test Suite: {self.name}")
        print(f"# Total Tests: {len(self.tests)}")
        print(f"{'#'*80}\n")

        self.results = []

        for i, test in enumerate(self.tests, 1):
            print(f"\n[{i}/{len(self.tests)}] Running: {test.name}")
            result = test.execute()
            self.results.append(result)

        self.print_suite_summary()

        return self.results

    def print_suite_summary(self):
        """Print overall suite summary."""
        print(f"\n{'#'*80}")
        print(f"# Suite Summary: {self.name}")
        print(f"{'#'*80}\n")

        passed = sum(1 for r in self.results if r.status == TestStatus.PASSED)
        failed = sum(1 for r in self.results if r.status == TestStatus.FAILED)

        print(f"Total Tests: {len(self.results)}")
        print(f"Passed: {passed} ✅")
        print(f"Failed: {failed} ❌")
        print(f"Success Rate: {passed/len(self.results)*100:.1f}%")

        total_duration = sum(r.duration_seconds for r in self.results)
        print(f"\nTotal Duration: {total_duration:.2f} seconds ({total_duration/3600:.2f} hours)")

        print(f"\nTest Results:")
        for result in self.results:
            status_icon = "✅" if result.status == TestStatus.PASSED else "❌"
            print(f"  {status_icon} {result.test_name} ({result.duration_seconds:.2f}s)")

        print(f"\n{'#'*80}\n")

    def save_suite_results(self, output_file: str):
        """Save all results to JSON file."""
        suite_data = {
            "suite_name": self.name,
            "total_tests": len(self.results),
            "passed": sum(1 for r in self.results if r.status == TestStatus.PASSED),
            "failed": sum(1 for r in self.results if r.status == TestStatus.FAILED),
            "results": [
                {
                    "test_name": r.test_name,
                    "status": r.status.value,
                    "duration_seconds": r.duration_seconds,
                    "start_time": r.start_time.isoformat(),
                    "end_time": r.end_time.isoformat(),
                    "metrics": r.metrics,
                    "errors": r.errors,
                    "warnings": r.warnings,
                    "pass_criteria": r.pass_criteria
                }
                for r in self.results
            ]
        }

        with open(output_file, 'w') as f:
            json.dump(suite_data, f, indent=2)

        print(f"Suite results saved to: {output_file}")


def run_concurrent_workers(worker_func: Callable, num_workers: int,
                          duration_seconds: int, *args, **kwargs) -> Dict[str, Any]:
    """
    Run multiple worker threads/processes concurrently.

    Args:
        worker_func: Function to execute in each worker
        num_workers: Number of concurrent workers
        duration_seconds: How long to run
        *args, **kwargs: Arguments to pass to worker_func

    Returns:
        Metrics dict with results
    """
    import queue

    results_queue = queue.Queue()
    workers = []
    start_time = time.time()
    end_time = start_time + duration_seconds

    def worker_wrapper(worker_id):
        """Wrapper that runs worker_func until time expires."""
        operations = 0
        errors = 0

        while time.time() < end_time:
            try:
                worker_func(worker_id, *args, **kwargs)
                operations += 1
            except Exception as e:
                errors += 1

        results_queue.put({
            "worker_id": worker_id,
            "operations": operations,
            "errors": errors
        })

    # Start workers
    for i in range(num_workers):
        worker = threading.Thread(target=worker_wrapper, args=(i,))
        worker.start()
        workers.append(worker)

    # Wait for completion
    for worker in workers:
        worker.join()

    # Collect results
    total_operations = 0
    total_errors = 0

    while not results_queue.empty():
        result = results_queue.get()
        total_operations += result["operations"]
        total_errors += result["errors"]

    actual_duration = time.time() - start_time
    throughput = total_operations / actual_duration

    return {
        "total_operations": total_operations,
        "total_errors": total_errors,
        "duration_seconds": round(actual_duration, 2),
        "throughput_ops_per_sec": round(throughput, 2),
        "error_rate": round(total_errors / total_operations * 100, 2) if total_operations > 0 else 0
    }


if __name__ == "__main__":
    print("Stress Test Framework for mojo-postgres")
    print("This module provides base classes for stress testing.")
    print("\nUsage:")
    print("  from stress_test_framework import StressTestBase, StressTestSuite")
    print("  class MyTest(StressTestBase):")
    print("      def run_test(self):")
    print("          # Test implementation")
    print("          return {'metric': value}")
