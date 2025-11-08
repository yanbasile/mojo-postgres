"""
Integration tests for Additional Types with real PostgreSQL.

Prerequisites:
- PostgreSQL running on localhost:5432
- Database 'test' with user 'test' / password 'test'
- pgcrypto extension for UUID generation

Tests:
1. UUID operations
2. UUID as primary key
3. INET operations
4. CIDR operations
5. INTERVAL operations
6. Combined type operations
"""

from testing import assert_equal, assert_true, assert_false
from src.protocol.connection import PostgresConnection


fn test_uuid_generation() raises:
    """Test 1: UUID generation."""
    print("  test_uuid_generation...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Enable pgcrypto
    try:
        var _ = conn.query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    except:
        pass  # May already exist

    # Generate UUID
    var result = conn.query("SELECT gen_random_uuid()")
    var uuid = result.get_uuid(0, 0)

    # Should be 36 characters with hyphens
    assert_equal(len(uuid.value), 36)
    assert_false(uuid.is_nil())

    conn.close()

    print(" ✅")


fn test_uuid_parsing() raises:
    """Test 2: UUID parsing."""
    print("  test_uuid_parsing...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Parse specific UUID
    var result = conn.query("SELECT '550e8400-e29b-41d4-a716-446655440000'::UUID")
    var uuid = result.get_uuid(0, 0)

    assert_equal(uuid.value, "550e8400-e29b-41d4-a716-446655440000")
    assert_false(uuid.is_nil())

    conn.close()

    print(" ✅")


fn test_uuid_nil() raises:
    """Test 3: Nil UUID."""
    print("  test_uuid_nil...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '00000000-0000-0000-0000-000000000000'::UUID")
    var uuid = result.get_uuid(0, 0)

    assert_true(uuid.is_nil())

    conn.close()

    print(" ✅")


fn test_uuid_as_primary_key() raises:
    """Test 4: UUID as primary key."""
    print("  test_uuid_as_primary_key...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS test_uuid")
    var __ = conn.query("""
        CREATE TABLE test_uuid (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT
        )
    """)

    # Insert rows
    var ___ = conn.query("INSERT INTO test_uuid (name) VALUES ('Alice')")
    var ____ = conn.query("INSERT INTO test_uuid (name) VALUES ('Bob')")

    # Query
    var result = conn.query("SELECT id, name FROM test_uuid ORDER BY name")
    assert_equal(result.row_count(), 2)

    var uuid1 = result.get_uuid(0, 0)
    var uuid2 = result.get_uuid(1, 0)

    # UUIDs should be different
    assert_true(uuid1.value != uuid2.value)

    # Cleanup
    var _____ = conn.query("DROP TABLE test_uuid")

    conn.close()

    print(" ✅")


fn test_inet_ipv4() raises:
    """Test 5: INET IPv4."""
    print("  test_inet_ipv4...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # With netmask
    var result1 = conn.query("SELECT '192.168.1.5/24'::INET")
    var inet1 = result1.get_inet(0, 0)
    assert_equal(inet1.address, "192.168.1.5")
    assert_equal(inet1.netmask, 24)
    assert_true(inet1.has_netmask)

    # Without netmask
    var result2 = conn.query("SELECT '192.168.1.5'::INET")
    var inet2 = result2.get_inet(0, 0)
    assert_equal(inet2.address, "192.168.1.5")
    assert_false(inet2.has_netmask)

    conn.close()

    print(" ✅")


fn test_inet_ipv6() raises:
    """Test 6: INET IPv6."""
    print("  test_inet_ipv6...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '2001:db8::1/64'::INET")
    var inet = result.get_inet(0, 0)

    assert_equal(inet.address, "2001:db8::1")
    assert_equal(inet.netmask, 64)
    assert_true(inet.is_ipv6())

    conn.close()

    print(" ✅")


fn test_inet_operations() raises:
    """Test 7: INET operations."""
    print("  test_inet_operations...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Network contains
    var result1 = conn.query("SELECT '192.168.1.0/24'::INET >> '192.168.1.5'::INET")
    var contains = result1.get_bool(0, 0)
    assert_true(contains)

    # Broadcast address
    var result2 = conn.query("SELECT broadcast('192.168.1.0/24'::INET)")
    var broadcast = result2.get_inet(0, 0)
    assert_equal(broadcast.address, "192.168.1.255")

    # Network address
    var result3 = conn.query("SELECT network('192.168.1.5/24'::INET)")
    var network = result3.get_inet(0, 0)
    assert_equal(network.address, "192.168.1.0")

    conn.close()

    print(" ✅")


fn test_inet_in_table() raises:
    """Test 8: INET in table."""
    print("  test_inet_in_table...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS test_inet")
    var __ = conn.query("""
        CREATE TABLE test_inet (
            id SERIAL PRIMARY KEY,
            ip INET
        )
    """)

    # Insert IPs
    var ___ = conn.query("INSERT INTO test_inet (ip) VALUES ('192.168.1.5/24')")
    var ____ = conn.query("INSERT INTO test_inet (ip) VALUES ('10.0.0.1')")

    # Query
    var result = conn.query("SELECT ip FROM test_inet ORDER BY id")
    assert_equal(result.row_count(), 2)

    var ip1 = result.get_inet(0, 0)
    assert_equal(ip1.address, "192.168.1.5")
    assert_equal(ip1.netmask, 24)

    var ip2 = result.get_inet(1, 0)
    assert_equal(ip2.address, "10.0.0.1")
    assert_false(ip2.has_netmask)

    # Cleanup
    var _____ = conn.query("DROP TABLE test_inet")

    conn.close()

    print(" ✅")


fn test_cidr_basic() raises:
    """Test 9: Basic CIDR."""
    print("  test_cidr_basic...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT '192.168.1.0/24'::CIDR")
    var cidr = result.get_cidr(0, 0)

    assert_equal(cidr.network, "192.168.1.0")
    assert_equal(cidr.netmask, 24)

    conn.close()

    print(" ✅")


fn test_cidr_different_sizes() raises:
    """Test 10: CIDR different sizes."""
    print("  test_cidr_different_sizes...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # /8 network
    var result1 = conn.query("SELECT '10.0.0.0/8'::CIDR")
    var cidr1 = result1.get_cidr(0, 0)
    assert_equal(cidr1.netmask, 8)

    # /16 network
    var result2 = conn.query("SELECT '172.16.0.0/16'::CIDR")
    var cidr2 = result2.get_cidr(0, 0)
    assert_equal(cidr2.netmask, 16)

    # /32 (single host)
    var result3 = conn.query("SELECT '192.168.1.1/32'::CIDR")
    var cidr3 = result3.get_cidr(0, 0)
    assert_equal(cidr3.netmask, 32)

    conn.close()

    print(" ✅")


fn test_cidr_in_table() raises:
    """Test 11: CIDR in table."""
    print("  test_cidr_in_table...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS test_cidr")
    var __ = conn.query("""
        CREATE TABLE test_cidr (
            id SERIAL PRIMARY KEY,
            network CIDR
        )
    """)

    # Insert networks
    var ___ = conn.query("INSERT INTO test_cidr (network) VALUES ('192.168.1.0/24')")
    var ____ = conn.query("INSERT INTO test_cidr (network) VALUES ('10.0.0.0/8')")

    # Query
    var result = conn.query("SELECT network FROM test_cidr ORDER BY id")
    assert_equal(result.row_count(), 2)

    var net1 = result.get_cidr(0, 0)
    assert_equal(net1.network, "192.168.1.0")
    assert_equal(net1.netmask, 24)

    # Cleanup
    var _____ = conn.query("DROP TABLE test_cidr")

    conn.close()

    print(" ✅")


fn test_interval_simple() raises:
    """Test 12: Simple intervals."""
    print("  test_interval_simple...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # 1 day
    var result1 = conn.query("SELECT INTERVAL '1 day'")
    var interval1 = result1.get_interval(0, 0)
    assert_equal(interval1.days, 1)

    # 2 hours
    var result2 = conn.query("SELECT INTERVAL '2 hours'")
    var interval2 = result2.get_interval(0, 0)
    assert_equal(interval2.hours, 2)

    # 30 minutes
    var result3 = conn.query("SELECT INTERVAL '30 minutes'")
    var interval3 = result3.get_interval(0, 0)
    assert_equal(interval3.minutes, 30)

    conn.close()

    print(" ✅")


fn test_interval_complex() raises:
    """Test 13: Complex intervals."""
    print("  test_interval_complex...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Multiple components
    var result = conn.query("SELECT INTERVAL '1 year 2 months 3 days'")
    var interval = result.get_interval(0, 0)

    assert_equal(interval.years, 1)
    assert_equal(interval.months, 2)
    assert_equal(interval.days, 3)

    conn.close()

    print(" ✅")


fn test_interval_arithmetic() raises:
    """Test 14: INTERVAL arithmetic."""
    print("  test_interval_arithmetic...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Add interval to timestamp
    var result1 = conn.query("SELECT TIMESTAMP '2024-01-01 00:00:00' + INTERVAL '7 days'")
    var ts1 = result1.get_timestamp(0, 0)
    assert_equal(ts1.day, 8)

    # Subtract interval
    var result2 = conn.query("SELECT TIMESTAMP '2024-01-15 00:00:00' - INTERVAL '5 days'")
    var ts2 = result2.get_timestamp(0, 0)
    assert_equal(ts2.day, 10)

    conn.close()

    print(" ✅")


fn test_interval_comparison() raises:
    """Test 15: INTERVAL comparison."""
    print("  test_interval_comparison...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Less than
    var result1 = conn.query("SELECT INTERVAL '1 day' < INTERVAL '2 days'")
    var is_less = result1.get_bool(0, 0)
    assert_true(is_less)

    # Equal
    var result2 = conn.query("SELECT INTERVAL '24 hours' = INTERVAL '1 day'")
    var is_equal = result2.get_bool(0, 0)
    assert_true(is_equal)

    conn.close()

    print(" ✅")


fn test_interval_in_table() raises:
    """Test 16: INTERVAL in table."""
    print("  test_interval_in_table...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    var _ = conn.query("DROP TABLE IF EXISTS test_interval")
    var __ = conn.query("""
        CREATE TABLE test_interval (
            id SERIAL PRIMARY KEY,
            duration INTERVAL
        )
    """)

    # Insert intervals
    var ___ = conn.query("INSERT INTO test_interval (duration) VALUES (INTERVAL '1 day')")
    var ____ = conn.query("INSERT INTO test_interval (duration) VALUES (INTERVAL '2 hours')")

    # Query
    var result = conn.query("SELECT duration FROM test_interval ORDER BY id")
    assert_equal(result.row_count(), 2)

    var duration1 = result.get_interval(0, 0)
    assert_equal(duration1.days, 1)

    var duration2 = result.get_interval(1, 0)
    assert_equal(duration2.hours, 2)

    # Cleanup
    var _____ = conn.query("DROP TABLE test_interval")

    conn.close()

    print(" ✅")


fn test_combined_types_table() raises:
    """Test 17: Combined types in one table."""
    print("  test_combined_types_table...", end="")

    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Enable pgcrypto
    try:
        var _ = conn.query("CREATE EXTENSION IF NOT EXISTS pgcrypto")
    except:
        pass

    # Create table with all additional types
    var __ = conn.query("DROP TABLE IF EXISTS test_combined")
    var ___ = conn.query("""
        CREATE TABLE test_combined (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            ip_address INET,
            network CIDR,
            duration INTERVAL
        )
    """)

    # Insert data
    var ____ = conn.query("""
        INSERT INTO test_combined (ip_address, network, duration)
        VALUES (
            '192.168.1.100/24'::INET,
            '192.168.1.0/24'::CIDR,
            INTERVAL '30 days'
        )
    """)

    # Query
    var result = conn.query("SELECT id, ip_address, network, duration FROM test_combined")
    assert_equal(result.row_count(), 1)

    var uuid = result.get_uuid(0, 0)
    assert_false(uuid.is_nil())

    var ip = result.get_inet(0, 1)
    assert_equal(ip.address, "192.168.1.100")

    var net = result.get_cidr(0, 2)
    assert_equal(net.network, "192.168.1.0")

    var duration = result.get_interval(0, 3)
    assert_equal(duration.days, 30)

    # Cleanup
    var _____ = conn.query("DROP TABLE test_combined")

    conn.close()

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Additional Types Integration Tests")
    print("=" * 70 + "\n")

    print("UUID Tests:")
    test_uuid_generation()
    test_uuid_parsing()
    test_uuid_nil()
    test_uuid_as_primary_key()

    print("\nINET Tests:")
    test_inet_ipv4()
    test_inet_ipv6()
    test_inet_operations()
    test_inet_in_table()

    print("\nCIDR Tests:")
    test_cidr_basic()
    test_cidr_different_sizes()
    test_cidr_in_table()

    print("\nINTERVAL Tests:")
    test_interval_simple()
    test_interval_complex()
    test_interval_arithmetic()
    test_interval_comparison()
    test_interval_in_table()

    print("\nCombined Tests:")
    test_combined_types_table()

    print("\n" + "=" * 70)
    print("✅ All 17 tests passed!")
    print("=" * 70 + "\n")
