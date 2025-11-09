"""
Benchmark: PostgreSQL MD5 Password Hashing

Measures the time to compute PostgreSQL MD5 password hash:
"md5" + md5(md5(password + username) + salt)

This is done once per connection with MD5 authentication.
Target: <50μs (should be negligible overhead)
"""

from benchmarks.harness import benchmark, BenchmarkResult, Timer
from src.protocol.auth import md5_password_postgres, md5_hash
from collections import List


# Configuration
alias ITERATIONS = 10000  # More iterations since this is fast


fn hash_password_once() raises:
    """Compute PostgreSQL MD5 hash once."""
    var password = "test_password_123"
    var username = "testuser"
    var salt = List[UInt8](capacity=4)
    salt.append(0xAB)
    salt.append(0xCD)
    salt.append(0xEF)
    salt.append(0x12)

    var hash = md5_password_postgres(password, username, salt)
    # Force evaluation
    _ = len(hash)


fn hash_md5_basic() raises:
    """Benchmark basic MD5 hashing."""
    var input = "hello world this is a test string"
    var hash = md5_hash(input)
    _ = len(hash)


fn main() raises:
    print("\n" + "=" * 70)
    print("BENCHMARK: PostgreSQL MD5 Authentication")
    print("=" * 70)

    # Benchmark PostgreSQL MD5 password hashing
    var result_postgres = benchmark[hash_password_once]("PostgreSQL MD5 Password Hash", ITERATIONS)
    result_postgres.print_report()

    # Benchmark basic MD5 for comparison
    print("\n")
    var result_basic = benchmark[hash_md5_basic]("Basic MD5 Hash", ITERATIONS)
    result_basic.print_report()

    # Analysis
    print("\n" + "=" * 70)
    print("ANALYSIS")
    print("=" * 70)

    var postgres_md5_us = result_postgres.mean_ns / 1000.0
    var basic_md5_us = result_basic.mean_ns / 1000.0
    var overhead_us = postgres_md5_us - (2.0 * basic_md5_us)  # PostgreSQL does 2 MD5 hashes

    print("PostgreSQL MD5:     ", String(postgres_md5_us), "μs")
    print("Basic MD5:          ", String(basic_md5_us), "μs")
    print("Expected (2x MD5):  ", String(2.0 * basic_md5_us), "μs")
    print("Actual overhead:    ", String(overhead_us), "μs")

    print("\nConnection Impact:")
    print("  Auth adds ~", String(postgres_md5_us / 1000.0), "ms to connection time")

    if postgres_md5_us < 50.0:
        print("  Status: ✅ EXCELLENT - negligible overhead")
    elif postgres_md5_us < 100.0:
        print("  Status: ✅ GOOD - acceptable overhead")
    elif postgres_md5_us < 200.0:
        print("  Status: ⚠️  OK - noticeable overhead")
    else:
        print("  Status: ❌ SLOW - investigate OpenSSL integration")

    print("\n" + "=" * 70)
    print("Notes:")
    print("  - MD5 is computed once per connection")
    print("  - For cleartext auth, this overhead is zero")
    print("  - MD5 is considered weak; PostgreSQL 14+ supports SCRAM-SHA-256")
    print("  - SCRAM support planned for Phase 2")
    print("=" * 70)
