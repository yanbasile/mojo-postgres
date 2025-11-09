"""
Master Stress Test Runner

Executes the comprehensive stress test suite for mojo-postgres.

Usage:
    python run_stress_tests.py --all              # Run all tests
    python run_stress_tests.py --quick            # Run quick versions (1hr instead of 24hr, etc.)
    python run_stress_tests.py --test 1           # Run specific test
    python run_stress_tests.py --test 1,2,3       # Run multiple specific tests
"""

import sys
import os
import argparse
from datetime import datetime

# Add current directory to path
sys.path.insert(0, os.path.dirname(__file__))

from stress_test_framework import StressTestSuite

# Import all test modules
from test_01_connection_limits import ConnectionLimitsTest
from test_02_memory_pressure import MemoryPressureTest
from test_03_long_running import LongRunningStabilityTest


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Mojo-Postgres Stress Test Suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all tests with production parameters (24hr, 7 days, etc.)
  python run_stress_tests.py --all

  # Run all tests with quick parameters (1hr, 1hr, 1hr for faster validation)
  python run_stress_tests.py --all --quick

  # Run specific test
  python run_stress_tests.py --test 1

  # Run multiple tests
  python run_stress_tests.py --test 1,2,3

  # Run with custom database
  POSTGRES_HOST=mydb.example.com python run_stress_tests.py --all

Environment Variables:
  POSTGRES_HOST      - Database host (default: localhost)
  POSTGRES_PORT      - Database port (default: 5432)
  POSTGRES_DB        - Database name (default: stress_test)
  POSTGRES_USER      - Database user (default: postgres)
  POSTGRES_PASSWORD  - Database password (default: postgres)
        """
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Run all stress tests"
    )

    parser.add_argument(
        "--quick",
        action="store_true",
        help="Use quick test parameters (1hr instead of 24hr, etc.) for faster validation"
    )

    parser.add_argument(
        "--test",
        type=str,
        help="Run specific test(s) by number (comma-separated, e.g., '1,2,3')"
    )

    parser.add_argument(
        "--output-dir",
        type=str,
        default="results",
        help="Directory to save test results (default: results)"
    )

    return parser.parse_args()


def create_suite(args):
    """Create test suite based on arguments."""
    suite = StressTestSuite("Mojo-Postgres Comprehensive Stress Tests")

    # Test configurations
    tests_config = {
        1: {
            "class": ConnectionLimitsTest,
            "name": "Connection Limits (1000+ concurrent)",
            "quick_params": {},
            "full_params": {}
        },
        2: {
            "class": MemoryPressureTest,
            "name": "Memory Pressure & Leak Detection",
            "quick_params": {"duration_hours": 1.0},
            "full_params": {"duration_hours": 24.0}
        },
        3: {
            "class": LongRunningStabilityTest,
            "name": "Long-Running Stability",
            "quick_params": {"duration_days": 0.042},  # ~1 hour
            "full_params": {"duration_days": 7.0}
        }
    }

    # Determine which tests to run
    if args.test:
        # Specific tests
        test_numbers = [int(n.strip()) for n in args.test.split(",")]
    else:
        # All tests
        test_numbers = list(tests_config.keys())

    # Add tests to suite
    for test_num in test_numbers:
        if test_num not in tests_config:
            print(f"⚠️  Warning: Test {test_num} not found, skipping")
            continue

        config = tests_config[test_num]

        # Use quick or full parameters
        params = config["quick_params"] if args.quick else config["full_params"]

        print(f"Adding Test {test_num}: {config['name']}")
        if args.quick and params:
            print(f"  Using quick parameters: {params}")

        test_instance = config["class"](**params)
        suite.add_test(test_instance)

    return suite


def main():
    """Main entry point."""
    args = parse_args()

    # Validate arguments
    if not args.all and not args.test:
        print("❌ Error: Must specify --all or --test")
        print("Run 'python run_stress_tests.py --help' for usage")
        sys.exit(1)

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    # Print configuration
    print("=" * 80)
    print("Mojo-Postgres Stress Test Suite")
    print("=" * 80)
    print(f"Mode: {'QUICK' if args.quick else 'FULL'}")
    print(f"Output Directory: {args.output_dir}")
    print(f"Database: {os.getenv('POSTGRES_HOST', 'localhost')}:{os.getenv('POSTGRES_PORT', '5432')}")
    print(f"Database Name: {os.getenv('POSTGRES_DB', 'stress_test')}")
    print("=" * 80)

    if not args.quick:
        print("\n⚠️  WARNING: Running in FULL mode. Some tests may take days to complete!")
        print("⚠️  Use --quick for faster validation during development.")
        print("\nPress Ctrl+C within 10 seconds to abort...")

        import time
        try:
            time.sleep(10)
        except KeyboardInterrupt:
            print("\n\n❌ Aborted by user")
            sys.exit(1)

    # Create and run test suite
    suite = create_suite(args)

    if len(suite.tests) == 0:
        print("\n❌ No tests to run!")
        sys.exit(1)

    print(f"\n🚀 Running {len(suite.tests)} test(s)...\n")

    # Execute all tests
    results = suite.run_all()

    # Save suite results
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = os.path.join(args.output_dir, f"stress_test_suite_{timestamp}.json")
    suite.save_suite_results(output_file)

    # Determine exit code
    all_passed = all(r.status.value == "passed" for r in results)
    exit_code = 0 if all_passed else 1

    if all_passed:
        print("\n✅ All tests PASSED!")
    else:
        print("\n❌ Some tests FAILED!")

    print(f"\nFull results saved to: {output_file}")

    sys.exit(exit_code)


if __name__ == "__main__":
    main()
