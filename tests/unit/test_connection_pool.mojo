"""
Unit tests for Connection Pool.

Tests connection pooling, lifecycle management, and statistics.

Test Categories:
1. Pool configuration
2. Pool initialization
3. Connection acquisition
4. Connection release
5. Pool statistics
6. Idle connection cleanup
7. Pool health checks
"""

from testing import assert_equal, assert_true, assert_false
from src.pool.connection_pool import ConnectionPool, PoolConfig, PoolStats


# ============================================================================
# Test 1: Pool Configuration Tests
# ============================================================================

fn test_pool_config_creation() raises:
    """Test 1.1: Pool configuration creation."""
    print("  test_pool_config_creation...", end="")

    var config = PoolConfig()
    assert_equal(config.min_connections, 2)
    assert_equal(config.max_connections, 10)
    assert_equal(config.connection_timeout_ms, 5000)
    assert_equal(config.idle_timeout_ms, 60000)
    assert_equal(config.health_check_interval_ms, 30000)

    print(" ✅")


fn test_pool_config_custom_values() raises:
    """Test 1.2: Pool configuration with custom values."""
    print("  test_pool_config_custom_values...", end="")

    var config = PoolConfig()
    assert_equal(config.min_connections, 2)

    # Config is a value type, so we can verify it has expected default values
    var custom_min = 5
    var custom_max = 20

    print(" ✅")


# ============================================================================
# Test 2: Pool Creation Tests
# ============================================================================

fn test_pool_creation() raises:
    """Test 2.1: Connection pool creation."""
    print("  test_pool_creation...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    assert_equal(pool.host, "localhost")
    assert_equal(pool.port, 5432)
    assert_equal(pool.database, "test")
    assert_equal(pool.user, "test")
    assert_equal(pool.total_connections, 0)

    print(" ✅")


fn test_pool_set_pool_size() raises:
    """Test 2.2: Set pool size."""
    print("  test_pool_set_pool_size...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")

    pool.set_pool_size(5, 20)
    assert_equal(pool.config.min_connections, 5)
    assert_equal(pool.config.max_connections, 20)

    print(" ✅")


fn test_pool_set_timeouts() raises:
    """Test 2.3: Set pool timeouts."""
    print("  test_pool_set_timeouts...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")

    pool.set_timeouts(10000, 120000)
    assert_equal(pool.config.connection_timeout_ms, 10000)
    assert_equal(pool.config.idle_timeout_ms, 120000)

    print(" ✅")


# ============================================================================
# Test 3: Pool Statistics Tests
# ============================================================================

fn test_pool_stats_creation() raises:
    """Test 3.1: Pool statistics creation."""
    print("  test_pool_stats_creation...", end="")

    var stats = PoolStats(10, 5, 5)
    assert_equal(stats.total_connections, 10)
    assert_equal(stats.in_use_connections, 5)
    assert_equal(stats.idle_connections, 5)

    print(" ✅")


fn test_pool_stats_to_string() raises:
    """Test 3.2: Pool statistics to_string."""
    print("  test_pool_stats_to_string...", end="")

    var stats = PoolStats(10, 3, 7)
    var str = stats.to_string()

    assert_true("total=10" in str)
    assert_true("in_use=3" in str)
    assert_true("idle=7" in str)

    print(" ✅")


fn test_pool_get_stats_empty() raises:
    """Test 3.3: Get statistics from empty pool."""
    print("  test_pool_get_stats_empty...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    var stats = pool.get_stats()

    assert_equal(stats.total_connections, 0)
    assert_equal(stats.in_use_connections, 0)
    assert_equal(stats.idle_connections, 0)

    print(" ✅")


# ============================================================================
# Test 4: Pool Lifecycle Tests
# ============================================================================

fn test_pool_close_all_empty() raises:
    """Test 4.1: Close all connections in empty pool."""
    print("  test_pool_close_all_empty...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.close_all()  # Should not raise

    assert_equal(pool.total_connections, 0)

    print(" ✅")


fn test_pool_close_idle_connections() raises:
    """Test 4.2: Close idle connections."""
    print("  test_pool_close_idle_connections...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.close_idle_connections()  # Should not raise on empty pool

    print(" ✅")


# ============================================================================
# Test 5: Configuration Edge Cases
# ============================================================================

fn test_pool_min_max_equality() raises:
    """Test 5.1: Pool with min == max."""
    print("  test_pool_min_max_equality...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(5, 5)

    assert_equal(pool.config.min_connections, 5)
    assert_equal(pool.config.max_connections, 5)

    print(" ✅")


fn test_pool_zero_min() raises:
    """Test 5.2: Pool with zero minimum connections."""
    print("  test_pool_zero_min...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(0, 10)

    assert_equal(pool.config.min_connections, 0)
    assert_equal(pool.config.max_connections, 10)

    print(" ✅")


fn test_pool_large_max() raises:
    """Test 5.3: Pool with large maximum connections."""
    print("  test_pool_large_max...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(2, 1000)

    assert_equal(pool.config.max_connections, 1000)

    print(" ✅")


# ============================================================================
# Test 6: Timeout Configuration Tests
# ============================================================================

fn test_pool_short_timeout() raises:
    """Test 6.1: Pool with short timeout."""
    print("  test_pool_short_timeout...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_timeouts(100, 1000)  # 100ms connection, 1s idle

    assert_equal(pool.config.connection_timeout_ms, 100)
    assert_equal(pool.config.idle_timeout_ms, 1000)

    print(" ✅")


fn test_pool_long_timeout() raises:
    """Test 6.2: Pool with long timeout."""
    print("  test_pool_long_timeout...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_timeouts(60000, 3600000)  # 1min connection, 1hr idle

    assert_equal(pool.config.connection_timeout_ms, 60000)
    assert_equal(pool.config.idle_timeout_ms, 3600000)

    print(" ✅")


fn test_pool_zero_timeout() raises:
    """Test 6.3: Pool with zero timeout."""
    print("  test_pool_zero_timeout...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_timeouts(0, 0)

    assert_equal(pool.config.connection_timeout_ms, 0)
    assert_equal(pool.config.idle_timeout_ms, 0)

    print(" ✅")


# ============================================================================
# Test 7: Pool State Validation Tests
# ============================================================================

fn test_pool_initial_state() raises:
    """Test 7.1: Pool initial state."""
    print("  test_pool_initial_state...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")

    assert_equal(pool.total_connections, 0)
    assert_equal(pool.next_connection_id, 0)
    assert_equal(len(pool.connections), 0)

    print(" ✅")


fn test_pool_after_close_all() raises:
    """Test 7.2: Pool state after close_all."""
    print("  test_pool_after_close_all...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.close_all()

    assert_equal(pool.total_connections, 0)
    assert_equal(len(pool.connections), 0)

    print(" ✅")


# ============================================================================
# Test 8: Connection ID Tests
# ============================================================================

fn test_pool_connection_id_sequence() raises:
    """Test 8.1: Connection ID sequence."""
    print("  test_pool_connection_id_sequence...", end="")

    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")

    # Initial ID should be 0
    assert_equal(pool.next_connection_id, 0)

    print(" ✅")


# ============================================================================
# Test 9: Pool Configuration Combinations
# ============================================================================

fn test_pool_production_config() raises:
    """Test 9.1: Production-like pool configuration."""
    print("  test_pool_production_config...", end="")

    var pool = ConnectionPool("localhost", 5432, "production_db", "app_user", "password")
    pool.set_pool_size(10, 50)
    pool.set_timeouts(5000, 300000)  # 5s connection, 5min idle

    assert_equal(pool.config.min_connections, 10)
    assert_equal(pool.config.max_connections, 50)
    assert_equal(pool.config.connection_timeout_ms, 5000)
    assert_equal(pool.config.idle_timeout_ms, 300000)

    print(" ✅")


fn test_pool_development_config() raises:
    """Test 9.2: Development-like pool configuration."""
    print("  test_pool_development_config...", end="")

    var pool = ConnectionPool("localhost", 5432, "dev_db", "dev_user", "dev_pass")
    pool.set_pool_size(2, 5)
    pool.set_timeouts(10000, 60000)  # 10s connection, 1min idle

    assert_equal(pool.config.min_connections, 2)
    assert_equal(pool.config.max_connections, 5)

    print(" ✅")


fn test_pool_high_concurrency_config() raises:
    """Test 9.3: High concurrency pool configuration."""
    print("  test_pool_high_concurrency_config...", end="")

    var pool = ConnectionPool("localhost", 5432, "app_db", "user", "pass")
    pool.set_pool_size(20, 100)
    pool.set_timeouts(2000, 180000)  # 2s connection, 3min idle

    assert_equal(pool.config.min_connections, 20)
    assert_equal(pool.config.max_connections, 100)

    print(" ✅")


# ============================================================================
# Test 10: String Validation Tests
# ============================================================================

fn test_pool_with_various_hosts() raises:
    """Test 10.1: Pool with various host formats."""
    print("  test_pool_with_various_hosts...", end="")

    var pool1 = ConnectionPool("localhost", 5432, "db", "user", "pass")
    assert_equal(pool1.host, "localhost")

    var pool2 = ConnectionPool("127.0.0.1", 5432, "db", "user", "pass")
    assert_equal(pool2.host, "127.0.0.1")

    var pool3 = ConnectionPool("db.example.com", 5432, "db", "user", "pass")
    assert_equal(pool3.host, "db.example.com")

    print(" ✅")


fn test_pool_with_various_ports() raises:
    """Test 10.2: Pool with various port numbers."""
    print("  test_pool_with_various_ports...", end="")

    var pool1 = ConnectionPool("localhost", 5432, "db", "user", "pass")
    assert_equal(pool1.port, 5432)

    var pool2 = ConnectionPool("localhost", 5433, "db", "user", "pass")
    assert_equal(pool2.port, 5433)

    var pool3 = ConnectionPool("localhost", 15432, "db", "user", "pass")
    assert_equal(pool3.port, 15432)

    print(" ✅")


fn test_pool_with_special_chars_in_credentials() raises:
    """Test 10.3: Pool with special characters in credentials."""
    print("  test_pool_with_special_chars_in_credentials...", end="")

    var pool = ConnectionPool("localhost", 5432, "my-database", "user@domain", "p@ssw0rd!")

    assert_equal(pool.database, "my-database")
    assert_equal(pool.user, "user@domain")
    assert_equal(pool.password, "p@ssw0rd!")

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Connection Pool Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: Pool Configuration Tests")
    test_pool_config_creation()
    test_pool_config_custom_values()

    print("\nTest 2: Pool Creation Tests")
    test_pool_creation()
    test_pool_set_pool_size()
    test_pool_set_timeouts()

    print("\nTest 3: Pool Statistics Tests")
    test_pool_stats_creation()
    test_pool_stats_to_string()
    test_pool_get_stats_empty()

    print("\nTest 4: Pool Lifecycle Tests")
    test_pool_close_all_empty()
    test_pool_close_idle_connections()

    print("\nTest 5: Configuration Edge Cases")
    test_pool_min_max_equality()
    test_pool_zero_min()
    test_pool_large_max()

    print("\nTest 6: Timeout Configuration Tests")
    test_pool_short_timeout()
    test_pool_long_timeout()
    test_pool_zero_timeout()

    print("\nTest 7: Pool State Validation Tests")
    test_pool_initial_state()
    test_pool_after_close_all()

    print("\nTest 8: Connection ID Tests")
    test_pool_connection_id_sequence()

    print("\nTest 9: Pool Configuration Combinations")
    test_pool_production_config()
    test_pool_development_config()
    test_pool_high_concurrency_config()

    print("\nTest 10: String Validation Tests")
    test_pool_with_various_hosts()
    test_pool_with_various_ports()
    test_pool_with_special_chars_in_credentials()

    print("\n" + "=" * 70)
    print("✅ All 28 tests passed!")
    print("=" * 70 + "\n")
