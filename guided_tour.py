#!/usr/bin/env python3
"""
🚀 mojo-postgres Guided Tour

Interactive tour of the mojo-postgres driver showcasing all features with
step-by-step examples and explanations.

Requirements:
- Python 3.8+
- PostgreSQL running (docker-compose up)
- Mojo 24.5+ installed

Usage:
    python guided_tour.py
"""

import os
import sys
import subprocess
from typing import List, Tuple, Optional
from pathlib import Path

# ANSI color codes
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


class GuidedTour:
    def __init__(self):
        self.root_dir = Path(__file__).parent
        self.examples_dir = self.root_dir / "examples"
        self.tests_dir = self.root_dir / "tests"
        self.benchmarks_dir = self.root_dir / "benchmarks"

    def print_header(self, text: str):
        """Print a formatted header."""
        print(f"\n{Colors.HEADER}{Colors.BOLD}{'='*80}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}{text:^80}{Colors.ENDC}")
        print(f"{Colors.HEADER}{Colors.BOLD}{'='*80}{Colors.ENDC}\n")

    def print_section(self, text: str):
        """Print a section title."""
        print(f"\n{Colors.OKCYAN}{Colors.BOLD}▶ {text}{Colors.ENDC}\n")

    def print_success(self, text: str):
        """Print success message."""
        print(f"{Colors.OKGREEN}✓ {text}{Colors.ENDC}")

    def print_info(self, text: str):
        """Print info message."""
        print(f"{Colors.OKBLUE}ℹ {text}{Colors.ENDC}")

    def print_warning(self, text: str):
        """Print warning message."""
        print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")

    def print_error(self, text: str):
        """Print error message."""
        print(f"{Colors.FAIL}✗ {text}{Colors.ENDC}")

    def check_prerequisites(self) -> bool:
        """Check if all prerequisites are met."""
        self.print_section("Checking Prerequisites")

        all_ok = True

        # Check Mojo
        try:
            result = subprocess.run(['mojo', '--version'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                version = result.stdout.strip()
                self.print_success(f"Mojo installed: {version}")
            else:
                self.print_error("Mojo not found or not working")
                all_ok = False
        except (FileNotFoundError, subprocess.TimeoutExpired):
            self.print_error("Mojo not installed. Visit: https://docs.modular.com/mojo/")
            all_ok = False

        # Check Docker (for PostgreSQL)
        try:
            result = subprocess.run(['docker', '--version'],
                                  capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                self.print_success("Docker installed")
            else:
                self.print_warning("Docker not found (optional for local PostgreSQL)")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            self.print_warning("Docker not installed (you can use external PostgreSQL)")

        # Check if PostgreSQL is running
        try:
            result = subprocess.run(['docker', 'ps'],
                                  capture_output=True, text=True, timeout=5)
            if 'postgres' in result.stdout.lower():
                self.print_success("PostgreSQL container running")
            else:
                self.print_warning("PostgreSQL container not found")
                self.print_info("Start with: docker-compose up -d")
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

        return all_ok

    def show_menu(self) -> str:
        """Display the main menu and get user choice."""
        self.print_header("🔥 mojo-postgres Guided Tour")

        print(f"{Colors.BOLD}Choose a tour section:{Colors.ENDC}\n")

        sections = [
            ("1", "🚀 Quick Start - Your First Connection", "simple_connection.mojo"),
            ("2", "📊 Core Types - Working with Data Types", "numeric_types.mojo"),
            ("3", "⚡ Performance - Prepared Statements & Pooling", "prepared_statements.mojo"),
            ("4", "🔄 Transactions - ACID Guarantees", "transactions_advanced.mojo"),
            ("5", "📦 Bulk Operations - COPY Protocol", "copy_protocol.mojo"),
            ("6", "🔔 Real-time - LISTEN/NOTIFY", "listen_notify.mojo"),
            ("7", "🛡️ Resilience - Error Handling & Retry", "resilience_example.mojo"),
            ("8", "🏪 Production Demo - E-commerce Application", "demo_ecommerce.mojo"),
            ("9", "⏱️ TimescaleDB - Time-Series Data", "timescaledb_complete.mojo"),
            ("10", "📈 Benchmarks - Performance Testing", None),
            ("11", "🧪 Tests - Run Test Suite", None),
            ("12", "📚 Documentation - Browse Guides", None),
            ("", ""),
            ("s", "📋 Show Project Statistics", None),
            ("h", "❓ Help & Resources", None),
            ("q", "🚪 Quit", None),
        ]

        for num, desc, _ in sections:
            if num:
                print(f"  {Colors.OKCYAN}{num:>3}{Colors.ENDC}. {desc}")
            else:
                print()

        choice = input(f"\n{Colors.BOLD}Enter your choice: {Colors.ENDC}").strip().lower()

        for num, desc, example in sections:
            if choice == num:
                return choice, example

        return choice, None

    def run_example(self, example_file: str):
        """Run a Mojo example file."""
        example_path = self.examples_dir / example_file

        if not example_path.exists():
            self.print_error(f"Example not found: {example_file}")
            return

        self.print_section(f"Running: {example_file}")

        # Show the file contents first
        print(f"{Colors.BOLD}Example Code:{Colors.ENDC}")
        print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}")

        with open(example_path, 'r') as f:
            lines = f.readlines()[:50]  # Show first 50 lines
            for i, line in enumerate(lines, 1):
                print(f"{i:3d} | {line}", end='')

        if len(lines) == 50:
            print(f"\n{Colors.WARNING}... (showing first 50 lines){Colors.ENDC}")

        print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}\n")

        # Ask if user wants to run it
        response = input(f"{Colors.BOLD}Run this example? (y/n): {Colors.ENDC}").strip().lower()

        if response != 'y':
            self.print_info("Skipped")
            return

        self.print_info("Executing example...")
        print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}")

        try:
            result = subprocess.run(['mojo', str(example_path)],
                                  cwd=self.root_dir,
                                  timeout=30)
            print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}")

            if result.returncode == 0:
                self.print_success("Example completed successfully!")
            else:
                self.print_warning(f"Example exited with code {result.returncode}")

        except subprocess.TimeoutExpired:
            self.print_error("Example timed out (30s limit)")
        except KeyboardInterrupt:
            self.print_warning("\nExample interrupted by user")
        except Exception as e:
            self.print_error(f"Error running example: {e}")

    def show_statistics(self):
        """Show project statistics."""
        self.print_section("📋 Project Statistics")

        # Count files
        mojo_files = list(self.root_dir.glob('**/*.mojo'))
        src_files = list((self.root_dir / 'src').glob('**/*.mojo'))
        test_files = list(self.tests_dir.glob('**/*.mojo'))
        example_files = list(self.examples_dir.glob('**/*.mojo'))
        benchmark_files = list(self.benchmarks_dir.glob('**/*.mojo'))

        # Count lines of code
        def count_lines(files):
            total = 0
            for f in files:
                try:
                    with open(f, 'r') as file:
                        total += len(file.readlines())
                except:
                    pass
            return total

        src_lines = count_lines(src_files)
        test_lines = count_lines(test_files)
        example_lines = count_lines(example_files)
        benchmark_lines = count_lines(benchmark_files)

        print(f"{Colors.BOLD}Code Statistics:{Colors.ENDC}")
        print(f"  Source files:       {len(src_files):4d} files ({src_lines:,} lines)")
        print(f"  Test files:         {len(test_files):4d} files ({test_lines:,} lines)")
        print(f"  Example files:      {len(example_files):4d} files ({example_lines:,} lines)")
        print(f"  Benchmark files:    {len(benchmark_files):4d} files ({benchmark_lines:,} lines)")
        print(f"  {Colors.OKGREEN}Total:              {len(mojo_files):4d} files ({src_lines + test_lines + example_lines + benchmark_lines:,} lines){Colors.ENDC}")

        print(f"\n{Colors.BOLD}Features Implemented:{Colors.ENDC}")
        features = [
            ("✅", "14 PostgreSQL types (INT, FLOAT, TEXT, TIMESTAMP, NUMERIC, JSONB, etc.)"),
            ("✅", "Extended query protocol (5-10x faster)"),
            ("✅", "Prepared statements with caching"),
            ("✅", "Connection pooling (100x faster reuse)"),
            ("✅", "Transaction management with savepoints"),
            ("✅", "COPY protocol (10-100x faster bulk operations)"),
            ("✅", "LISTEN/NOTIFY for real-time notifications"),
            ("✅", "Array types (INT[], TEXT[], etc.)"),
            ("✅", "SSL/TLS encrypted connections"),
            ("✅", "Retry logic with exponential backoff"),
            ("✅", "Circuit breaker pattern"),
            ("✅", "Health monitoring & metrics"),
            ("✅", "TimescaleDB optimizations"),
            ("✅", "Comprehensive benchmarks"),
        ]

        for icon, feature in features:
            print(f"  {icon} {feature}")

    def show_help(self):
        """Show help and resources."""
        self.print_section("❓ Help & Resources")

        print(f"{Colors.BOLD}Documentation:{Colors.ENDC}")
        print(f"  📖 README.md           - Project overview and quick start")
        print(f"  📘 GETTING_STARTED.md  - Detailed getting started guide")
        print(f"  🚀 TOUR.md             - Complete feature tour")
        print(f"  🗺️  ROADMAP.md          - Project roadmap and status")
        print(f"  🛡️  docs/RESILIENCE_GUIDE.md - Enterprise resilience patterns")
        print(f"  🔐 docs/SSL_SUPPORT.md - SSL/TLS setup guide")

        print(f"\n{Colors.BOLD}Quick Commands:{Colors.ENDC}")
        print(f"  Start PostgreSQL:   docker-compose up -d")
        print(f"  Stop PostgreSQL:    docker-compose down")
        print(f"  Run example:        mojo examples/simple_connection.mojo")
        print(f"  Run tests:          mojo tests/unit/test_connection.mojo")
        print(f"  Run benchmarks:     mojo benchmarks/run_all_benchmarks.mojo")

        print(f"\n{Colors.BOLD}External Resources:{Colors.ENDC}")
        print(f"  Mojo Docs:          https://docs.modular.com/mojo/")
        print(f"  PostgreSQL Docs:    https://www.postgresql.org/docs/")
        print(f"  Project GitHub:     https://github.com/yanbasile/mojo-postgres")

    def run_benchmarks(self):
        """Run benchmark suite."""
        self.print_section("📈 Running Benchmarks")

        benchmarks = [
            ("bench_connection.mojo", "Connection performance"),
            ("bench_prepared_statements.mojo", "Prepared statements"),
            ("bench_connection_pool.mojo", "Connection pooling"),
            ("bench_query.mojo", "Query execution"),
        ]

        print(f"{Colors.BOLD}Available benchmarks:{Colors.ENDC}\n")
        for i, (bench, desc) in enumerate(benchmarks, 1):
            print(f"  {i}. {desc} ({bench})")

        print(f"\n  0. Run all benchmarks")

        choice = input(f"\n{Colors.BOLD}Select benchmark (0-{len(benchmarks)}): {Colors.ENDC}").strip()

        if choice == '0':
            bench_file = "run_all_benchmarks.mojo"
        elif choice.isdigit() and 1 <= int(choice) <= len(benchmarks):
            bench_file = benchmarks[int(choice)-1][0]
        else:
            self.print_error("Invalid choice")
            return

        bench_path = self.benchmarks_dir / bench_file

        if not bench_path.exists():
            self.print_error(f"Benchmark not found: {bench_file}")
            return

        self.print_info(f"Running: {bench_file}")
        print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}")

        try:
            subprocess.run(['mojo', str(bench_path)], cwd=self.root_dir, timeout=120)
            print(f"{Colors.OKBLUE}{'─'*80}{Colors.ENDC}")
            self.print_success("Benchmark completed!")
        except subprocess.TimeoutExpired:
            self.print_error("Benchmark timed out")
        except KeyboardInterrupt:
            self.print_warning("\nBenchmark interrupted")
        except Exception as e:
            self.print_error(f"Error: {e}")

    def run_tests(self):
        """Run test suite."""
        self.print_section("🧪 Running Tests")

        print(f"{Colors.BOLD}Test suites:{Colors.ENDC}\n")
        print(f"  1. Unit tests")
        print(f"  2. Integration tests")
        print(f"  3. All tests")

        choice = input(f"\n{Colors.BOLD}Select test suite (1-3): {Colors.ENDC}").strip()

        if choice == '1':
            test_dir = self.tests_dir / 'unit'
        elif choice == '2':
            test_dir = self.tests_dir / 'integration'
        elif choice == '3':
            test_dir = self.tests_dir
        else:
            self.print_error("Invalid choice")
            return

        test_files = list(test_dir.glob('test_*.mojo'))

        if not test_files:
            self.print_error("No test files found")
            return

        self.print_info(f"Found {len(test_files)} test files")

        passed = 0
        failed = 0

        for test_file in test_files:
            print(f"\n{Colors.BOLD}Running: {test_file.name}{Colors.ENDC}")
            try:
                result = subprocess.run(['mojo', str(test_file)],
                                      cwd=self.root_dir,
                                      capture_output=True,
                                      timeout=30)
                if result.returncode == 0:
                    self.print_success(f"{test_file.name}")
                    passed += 1
                else:
                    self.print_error(f"{test_file.name}")
                    failed += 1
            except Exception as e:
                self.print_error(f"{test_file.name}: {e}")
                failed += 1

        print(f"\n{Colors.BOLD}Results:{Colors.ENDC}")
        print(f"  {Colors.OKGREEN}Passed: {passed}{Colors.ENDC}")
        if failed > 0:
            print(f"  {Colors.FAIL}Failed: {failed}{Colors.ENDC}")

    def browse_documentation(self):
        """Browse documentation files."""
        self.print_section("📚 Documentation")

        docs = [
            ("README.md", "Project overview"),
            ("GETTING_STARTED.md", "Getting started guide"),
            ("TOUR.md", "Complete feature tour"),
            ("ROADMAP.md", "Project roadmap"),
            ("docs/RESILIENCE_GUIDE.md", "Resilience patterns"),
            ("docs/SSL_SUPPORT.md", "SSL/TLS setup"),
            ("docs/ACCOMPLISHMENTS.md", "What we've built"),
        ]

        print(f"{Colors.BOLD}Available documentation:{Colors.ENDC}\n")
        for i, (file, desc) in enumerate(docs, 1):
            print(f"  {i}. {desc} ({file})")

        choice = input(f"\n{Colors.BOLD}Select document (1-{len(docs)}): {Colors.ENDC}").strip()

        if not choice.isdigit() or not (1 <= int(choice) <= len(docs)):
            self.print_error("Invalid choice")
            return

        doc_file = self.root_dir / docs[int(choice)-1][0]

        if not doc_file.exists():
            self.print_error(f"Documentation not found: {doc_file}")
            return

        # Try to open with less/more, fallback to cat
        try:
            subprocess.run(['less', str(doc_file)])
        except FileNotFoundError:
            try:
                subprocess.run(['more', str(doc_file)])
            except FileNotFoundError:
                with open(doc_file, 'r') as f:
                    print(f.read())

    def run(self):
        """Main tour loop."""
        if not self.check_prerequisites():
            self.print_warning("\nSome prerequisites are missing, but you can continue the tour")
            input(f"{Colors.BOLD}Press Enter to continue...{Colors.ENDC}")

        while True:
            try:
                choice, example = self.show_menu()

                if choice == 'q':
                    self.print_success("Thanks for touring mojo-postgres! 🚀")
                    break
                elif choice == 's':
                    self.show_statistics()
                elif choice == 'h':
                    self.show_help()
                elif choice == '10':
                    self.run_benchmarks()
                elif choice == '11':
                    self.run_tests()
                elif choice == '12':
                    self.browse_documentation()
                elif example:
                    self.run_example(example)
                else:
                    self.print_error("Invalid choice")

                input(f"\n{Colors.BOLD}Press Enter to continue...{Colors.ENDC}")

            except KeyboardInterrupt:
                print(f"\n{Colors.WARNING}Tour interrupted{Colors.ENDC}")
                break
            except Exception as e:
                self.print_error(f"Unexpected error: {e}")
                import traceback
                traceback.print_exc()


if __name__ == "__main__":
    tour = GuidedTour()
    tour.run()
