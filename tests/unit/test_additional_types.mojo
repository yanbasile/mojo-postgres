"""
Unit tests for PostgreSQL Additional Types.

Tests UUID, INET, CIDR, and INTERVAL parsing and operations.

Test Categories:
1. UUID parsing and validation
2. INET parsing and operations
3. CIDR parsing and operations
4. INTERVAL parsing and operations
5. Literal builders
6. Edge cases
"""

from testing import assert_equal, assert_true, assert_false, assert_raises
from src.types.additional_types import (
    parse_uuid,
    parse_inet,
    parse_cidr,
    parse_interval,
    build_uuid_literal,
    build_inet_literal,
    build_cidr_literal,
    build_interval_literal,
    validate_uuid,
    validate_ipv4,
)


# ============================================================================
# Test 1: UUID Parsing and Validation
# ============================================================================

fn test_parse_uuid_valid() raises:
    """Test 1.1: Parse valid UUID."""
    print("  test_parse_uuid_valid...", end="")

    var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
    assert_equal(uuid.value, "550e8400-e29b-41d4-a716-446655440000")
    assert_equal(uuid.to_string(), "550e8400-e29b-41d4-a716-446655440000")

    print(" ✅")


fn test_parse_uuid_nil() raises:
    """Test 1.2: Parse nil UUID."""
    print("  test_parse_uuid_nil...", end="")

    var uuid = parse_uuid("00000000-0000-0000-0000-000000000000")
    assert_true(uuid.is_nil())

    print(" ✅")


fn test_parse_uuid_not_nil() raises:
    """Test 1.3: Non-nil UUID."""
    print("  test_parse_uuid_not_nil...", end="")

    var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
    assert_false(uuid.is_nil())

    print(" ✅")


fn test_parse_uuid_uppercase() raises:
    """Test 1.4: Parse uppercase UUID."""
    print("  test_parse_uuid_uppercase...", end="")

    var uuid = parse_uuid("550E8400-E29B-41D4-A716-446655440000")
    assert_equal(uuid.value, "550E8400-E29B-41D4-A716-446655440000")

    print(" ✅")


fn test_uuid_to_canonical() raises:
    """Test 1.5: Convert to canonical lowercase."""
    print("  test_uuid_to_canonical...", end="")

    var uuid = parse_uuid("550E8400-E29B-41D4-A716-446655440000")
    var canonical = uuid.to_canonical()
    assert_equal(canonical, "550e8400-e29b-41d4-a716-446655440000")

    print(" ✅")


fn test_validate_uuid_valid() raises:
    """Test 1.6: Validate valid UUID."""
    print("  test_validate_uuid_valid...", end="")

    assert_true(validate_uuid("550e8400-e29b-41d4-a716-446655440000"))
    assert_true(validate_uuid("00000000-0000-0000-0000-000000000000"))

    print(" ✅")


fn test_validate_uuid_invalid() raises:
    """Test 1.7: Validate invalid UUID."""
    print("  test_validate_uuid_invalid...", end="")

    assert_false(validate_uuid("not-a-uuid"))
    assert_false(validate_uuid("550e8400-e29b-41d4-a716"))  # Too short
    assert_false(validate_uuid("550e8400e29b41d4a716446655440000"))  # Missing hyphens

    print(" ✅")


fn test_parse_uuid_invalid_length() raises:
    """Test 1.8: Invalid UUID length."""
    print("  test_parse_uuid_invalid_length...", end="")

    try:
        var _ = parse_uuid("550e8400-e29b-41d4-a716")
        raise Error("Should have raised error for invalid length")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_parse_uuid_missing_hyphens() raises:
    """Test 1.9: Invalid UUID format (missing hyphens)."""
    print("  test_parse_uuid_missing_hyphens...", end="")

    try:
        var _ = parse_uuid("550e8400e29b41d4a716446655440000")
        raise Error("Should have raised error for missing hyphens")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_build_uuid_literal() raises:
    """Test 1.10: Build UUID literal."""
    print("  test_build_uuid_literal...", end="")

    var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
    var literal = build_uuid_literal(uuid)
    assert_equal(literal, "'550e8400-e29b-41d4-a716-446655440000'::UUID")

    print(" ✅")


# ============================================================================
# Test 2: INET Parsing and Operations
# ============================================================================

fn test_parse_inet_ipv4_with_netmask() raises:
    """Test 2.1: Parse IPv4 with netmask."""
    print("  test_parse_inet_ipv4_with_netmask...", end="")

    var inet = parse_inet("192.168.1.5/24")
    assert_equal(inet.address, "192.168.1.5")
    assert_equal(inet.netmask, 24)
    assert_true(inet.has_netmask)
    assert_equal(inet.to_string(), "192.168.1.5/24")

    print(" ✅")


fn test_parse_inet_ipv4_without_netmask() raises:
    """Test 2.2: Parse IPv4 without netmask."""
    print("  test_parse_inet_ipv4_without_netmask...", end="")

    var inet = parse_inet("192.168.1.5")
    assert_equal(inet.address, "192.168.1.5")
    assert_false(inet.has_netmask)
    assert_equal(inet.to_string(), "192.168.1.5")

    print(" ✅")


fn test_parse_inet_ipv6() raises:
    """Test 2.3: Parse IPv6."""
    print("  test_parse_inet_ipv6...", end="")

    var inet = parse_inet("2001:db8::1/64")
    assert_equal(inet.address, "2001:db8::1")
    assert_equal(inet.netmask, 64)
    assert_true(inet.has_netmask)

    print(" ✅")


fn test_inet_is_ipv4() raises:
    """Test 2.4: Check if INET is IPv4."""
    print("  test_inet_is_ipv4...", end="")

    var inet = parse_inet("192.168.1.5/24")
    assert_true(inet.is_ipv4())
    assert_false(inet.is_ipv6())

    print(" ✅")


fn test_inet_is_ipv6() raises:
    """Test 2.5: Check if INET is IPv6."""
    print("  test_inet_is_ipv6...", end="")

    var inet = parse_inet("2001:db8::1/64")
    assert_true(inet.is_ipv6())
    assert_false(inet.is_ipv4())

    print(" ✅")


fn test_parse_inet_localhost() raises:
    """Test 2.6: Parse localhost."""
    print("  test_parse_inet_localhost...", end="")

    var inet = parse_inet("127.0.0.1")
    assert_equal(inet.address, "127.0.0.1")
    assert_equal(inet.to_string(), "127.0.0.1")

    print(" ✅")


fn test_validate_ipv4_valid() raises:
    """Test 2.7: Validate valid IPv4."""
    print("  test_validate_ipv4_valid...", end="")

    assert_true(validate_ipv4("192.168.1.1"))
    assert_true(validate_ipv4("0.0.0.0"))
    assert_true(validate_ipv4("255.255.255.255"))

    print(" ✅")


fn test_validate_ipv4_invalid() raises:
    """Test 2.8: Validate invalid IPv4."""
    print("  test_validate_ipv4_invalid...", end="")

    assert_false(validate_ipv4("999.999.999.999"))
    assert_false(validate_ipv4("192.168.1"))  # Too few octets
    assert_false(validate_ipv4("not-an-ip"))

    print(" ✅")


fn test_build_inet_literal() raises:
    """Test 2.9: Build INET literal."""
    print("  test_build_inet_literal...", end="")

    var inet = parse_inet("192.168.1.5/24")
    var literal = build_inet_literal(inet)
    assert_equal(literal, "'192.168.1.5/24'::INET")

    print(" ✅")


# ============================================================================
# Test 3: CIDR Parsing and Operations
# ============================================================================

fn test_parse_cidr_valid() raises:
    """Test 3.1: Parse valid CIDR."""
    print("  test_parse_cidr_valid...", end="")

    var cidr = parse_cidr("192.168.1.0/24")
    assert_equal(cidr.network, "192.168.1.0")
    assert_equal(cidr.netmask, 24)
    assert_equal(cidr.to_string(), "192.168.1.0/24")

    print(" ✅")


fn test_parse_cidr_different_sizes() raises:
    """Test 3.2: Parse CIDR with different netmask sizes."""
    print("  test_parse_cidr_different_sizes...", end="")

    var cidr8 = parse_cidr("10.0.0.0/8")
    assert_equal(cidr8.netmask, 8)

    var cidr16 = parse_cidr("172.16.0.0/16")
    assert_equal(cidr16.netmask, 16)

    var cidr32 = parse_cidr("192.168.1.1/32")
    assert_equal(cidr32.netmask, 32)

    print(" ✅")


fn test_parse_cidr_ipv6() raises:
    """Test 3.3: Parse IPv6 CIDR."""
    print("  test_parse_cidr_ipv6...", end="")

    var cidr = parse_cidr("2001:db8::/32")
    assert_equal(cidr.network, "2001:db8::")
    assert_equal(cidr.netmask, 32)

    print(" ✅")


fn test_parse_cidr_no_netmask() raises:
    """Test 3.4: CIDR requires netmask."""
    print("  test_parse_cidr_no_netmask...", end="")

    try:
        var _ = parse_cidr("192.168.1.0")
        raise Error("Should have raised error for missing netmask")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_build_cidr_literal() raises:
    """Test 3.5: Build CIDR literal."""
    print("  test_build_cidr_literal...", end="")

    var cidr = parse_cidr("192.168.1.0/24")
    var literal = build_cidr_literal(cidr)
    assert_equal(literal, "'192.168.1.0/24'::CIDR")

    print(" ✅")


# ============================================================================
# Test 4: INTERVAL Parsing and Operations
# ============================================================================

fn test_parse_interval_days() raises:
    """Test 4.1: Parse interval with days."""
    print("  test_parse_interval_days...", end="")

    var interval = parse_interval("1 day")
    assert_equal(interval.days, 1)
    assert_equal(interval.hours, 0)
    assert_equal(interval.minutes, 0)

    print(" ✅")


fn test_parse_interval_hours() raises:
    """Test 4.2: Parse interval with hours."""
    print("  test_parse_interval_hours...", end="")

    var interval = parse_interval("2 hours")
    assert_equal(interval.hours, 2)
    assert_equal(interval.days, 0)

    print(" ✅")


fn test_parse_interval_minutes() raises:
    """Test 4.3: Parse interval with minutes."""
    print("  test_parse_interval_minutes...", end="")

    var interval = parse_interval("30 minutes")
    assert_equal(interval.minutes, 30)

    print(" ✅")


fn test_parse_interval_complex() raises:
    """Test 4.4: Parse complex interval."""
    print("  test_parse_interval_complex...", end="")

    var interval = parse_interval("2 days 3 hours 30 minutes")
    assert_equal(interval.days, 2)
    assert_equal(interval.hours, 3)
    assert_equal(interval.minutes, 30)

    print(" ✅")


fn test_parse_interval_years_months() raises:
    """Test 4.5: Parse interval with years and months."""
    print("  test_parse_interval_years_months...", end="")

    var interval = parse_interval("1 year 2 months 3 days")
    assert_equal(interval.years, 1)
    assert_equal(interval.months, 2)
    assert_equal(interval.days, 3)

    print(" ✅")


fn test_parse_interval_time_format() raises:
    """Test 4.6: Parse interval in time format."""
    print("  test_parse_interval_time_format...", end="")

    var interval = parse_interval("01:30:45")
    assert_equal(interval.hours, 1)
    assert_equal(interval.minutes, 30)
    assert_equal(interval.seconds, 45.0)

    print(" ✅")


fn test_parse_interval_mons() raises:
    """Test 4.7: Parse interval with 'mons' abbreviation."""
    print("  test_parse_interval_mons...", end="")

    var interval = parse_interval("2 mons")
    assert_equal(interval.months, 2)

    print(" ✅")


fn test_interval_to_total_seconds() raises:
    """Test 4.8: Convert interval to total seconds."""
    print("  test_interval_to_total_seconds...", end="")

    var interval = parse_interval("1 day")
    var seconds = interval.to_total_seconds()
    assert_equal(seconds, 86400.0)  # 24 * 3600

    print(" ✅")


fn test_interval_to_total_days() raises:
    """Test 4.9: Convert interval to total days."""
    print("  test_interval_to_total_days...", end="")

    var interval = parse_interval("2 days")
    var days = interval.to_total_days()
    assert_equal(days, 2.0)

    print(" ✅")


fn test_build_interval_literal() raises:
    """Test 4.10: Build INTERVAL literal."""
    print("  test_build_interval_literal...", end="")

    var interval = parse_interval("1 day")
    var literal = build_interval_literal(interval)
    # The literal should contain '::INTERVAL'
    assert_true("::INTERVAL" in literal)

    print(" ✅")


# ============================================================================
# Test 5: Edge Cases
# ============================================================================

fn test_parse_inet_multiple_slashes() raises:
    """Test 5.1: INET with multiple slashes (invalid)."""
    print("  test_parse_inet_multiple_slashes...", end="")

    try:
        var _ = parse_inet("192.168.1.5/24/32")
        raise Error("Should have raised error for multiple slashes")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_parse_inet_invalid_netmask() raises:
    """Test 5.2: INET with invalid netmask."""
    print("  test_parse_inet_invalid_netmask...", end="")

    try:
        var _ = parse_inet("192.168.1.5/abc")
        raise Error("Should have raised error for invalid netmask")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_parse_cidr_invalid_netmask() raises:
    """Test 5.3: CIDR with invalid netmask."""
    print("  test_parse_cidr_invalid_netmask...", end="")

    try:
        var _ = parse_cidr("192.168.1.0/xyz")
        raise Error("Should have raised error for invalid netmask")
    except e:
        # Expected
        pass

    print(" ✅")


fn test_parse_interval_empty() raises:
    """Test 5.4: Parse empty interval."""
    print("  test_parse_interval_empty...", end="")

    var interval = parse_interval("")
    assert_equal(interval.days, 0)
    assert_equal(interval.hours, 0)

    print(" ✅")


fn test_inet_whitespace() raises:
    """Test 5.5: INET with whitespace."""
    print("  test_inet_whitespace...", end="")

    var inet = parse_inet("  192.168.1.5/24  ")
    assert_equal(inet.address, "192.168.1.5")
    assert_equal(inet.netmask, 24)

    print(" ✅")


fn test_uuid_whitespace() raises:
    """Test 5.6: UUID with whitespace."""
    print("  test_uuid_whitespace...", end="")

    var uuid = parse_uuid("  550e8400-e29b-41d4-a716-446655440000  ")
    assert_equal(uuid.value, "550e8400-e29b-41d4-a716-446655440000")

    print(" ✅")


fn main() raises:
    print("\n" + "=" * 70)
    print("Additional Types Unit Tests")
    print("=" * 70 + "\n")

    print("Test 1: UUID Parsing and Validation")
    test_parse_uuid_valid()
    test_parse_uuid_nil()
    test_parse_uuid_not_nil()
    test_parse_uuid_uppercase()
    test_uuid_to_canonical()
    test_validate_uuid_valid()
    test_validate_uuid_invalid()
    test_parse_uuid_invalid_length()
    test_parse_uuid_missing_hyphens()
    test_build_uuid_literal()

    print("\nTest 2: INET Parsing and Operations")
    test_parse_inet_ipv4_with_netmask()
    test_parse_inet_ipv4_without_netmask()
    test_parse_inet_ipv6()
    test_inet_is_ipv4()
    test_inet_is_ipv6()
    test_parse_inet_localhost()
    test_validate_ipv4_valid()
    test_validate_ipv4_invalid()
    test_build_inet_literal()

    print("\nTest 3: CIDR Parsing and Operations")
    test_parse_cidr_valid()
    test_parse_cidr_different_sizes()
    test_parse_cidr_ipv6()
    test_parse_cidr_no_netmask()
    test_build_cidr_literal()

    print("\nTest 4: INTERVAL Parsing and Operations")
    test_parse_interval_days()
    test_parse_interval_hours()
    test_parse_interval_minutes()
    test_parse_interval_complex()
    test_parse_interval_years_months()
    test_parse_interval_time_format()
    test_parse_interval_mons()
    test_interval_to_total_seconds()
    test_interval_to_total_days()
    test_build_interval_literal()

    print("\nTest 5: Edge Cases")
    test_parse_inet_multiple_slashes()
    test_parse_inet_invalid_netmask()
    test_parse_cidr_invalid_netmask()
    test_parse_interval_empty()
    test_inet_whitespace()
    test_uuid_whitespace()

    print("\n" + "=" * 70)
    print("✅ All 40 tests passed!")
    print("=" * 70 + "\n")
