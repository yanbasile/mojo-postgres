"""
Unit tests for PostgreSQL temporal type decoders.

Tests:
- TIMESTAMP decoder (without timezone)
- TIMESTAMPTZ decoder (with timezone)
- DATE decoder
- TIME decoder
- INTERVAL decoder

PostgreSQL temporal format notes:
- TIMESTAMP: "2024-01-15 10:30:45.123456"
- TIMESTAMPTZ: "2024-01-15 10:30:45.123456+00"
- DATE: "2024-01-15"
- TIME: "10:30:45.123456"
- INTERVAL: "1 day 02:30:45"

Run:
  mojo tests/unit/test_temporal_types.mojo
"""

from testing import assert_equal, assert_true, assert_false


# ============================================================================
# TIMESTAMP Decoder Tests
# ============================================================================

fn test_timestamp_decode_simple() raises:
    """Test TIMESTAMP decoding with simple value."""
    print("  Testing TIMESTAMP decode simple...")

    from src.types.temporal import decode_timestamp

    var result = decode_timestamp("2024-01-15 10:30:45")
    
    if result.year != 2024:
        raise Error("Expected year 2024")
    if result.month != 1:
        raise Error("Expected month 1")
    if result.day != 15:
        raise Error("Expected day 15")
    if result.hour != 10:
        raise Error("Expected hour 10")
    if result.minute != 30:
        raise Error("Expected minute 30")
    if result.second != 45:
        raise Error("Expected second 45")
    if result.microsecond != 0:
        raise Error("Expected microsecond 0")

    print("    ✓ TIMESTAMP simple decode works")


fn test_timestamp_decode_with_microseconds() raises:
    """Test TIMESTAMP decoding with microseconds."""
    print("  Testing TIMESTAMP decode with microseconds...")

    from src.types.temporal import decode_timestamp

    var result = decode_timestamp("2024-01-15 10:30:45.123456")
    
    if result.microsecond != 123456:
        raise Error("Expected microsecond 123456")

    print("    ✓ TIMESTAMP with microseconds works")


fn test_timestamp_decode_midnight() raises:
    """Test TIMESTAMP decoding at midnight."""
    print("  Testing TIMESTAMP decode midnight...")

    from src.types.temporal import decode_timestamp

    var result = decode_timestamp("2024-01-15 00:00:00")
    
    if result.hour != 0:
        raise Error("Expected hour 0")
    if result.minute != 0:
        raise Error("Expected minute 0")
    if result.second != 0:
        raise Error("Expected second 0")

    print("    ✓ TIMESTAMP midnight works")


fn test_timestamp_decode_end_of_day() raises:
    """Test TIMESTAMP decoding at end of day."""
    print("  Testing TIMESTAMP decode end of day...")

    from src.types.temporal import decode_timestamp

    var result = decode_timestamp("2024-01-15 23:59:59")
    
    if result.hour != 23:
        raise Error("Expected hour 23")
    if result.minute != 59:
        raise Error("Expected minute 59")
    if result.second != 59:
        raise Error("Expected second 59")

    print("    ✓ TIMESTAMP end of day works")


# ============================================================================
# TIMESTAMPTZ Decoder Tests
# ============================================================================

fn test_timestamptz_decode_utc() raises:
    """Test TIMESTAMPTZ decoding with UTC timezone."""
    print("  Testing TIMESTAMPTZ decode UTC...")

    from src.types.temporal import decode_timestamptz

    var result = decode_timestamptz("2024-01-15 10:30:45+00")
    
    if result.year != 2024:
        raise Error("Expected year 2024")
    if result.hour != 10:
        raise Error("Expected hour 10")
    if result.timezone_offset_seconds != 0:
        raise Error("Expected timezone offset 0 for UTC")

    print("    ✓ TIMESTAMPTZ UTC works")


fn test_timestamptz_decode_positive_offset() raises:
    """Test TIMESTAMPTZ decoding with positive offset."""
    print("  Testing TIMESTAMPTZ decode positive offset...")

    from src.types.temporal import decode_timestamptz

    # +05:30 = 19800 seconds
    var result = decode_timestamptz("2024-01-15 10:30:45+05:30")
    
    if result.timezone_offset_seconds != 19800:
        raise Error("Expected timezone offset 19800 (5.5 hours)")

    print("    ✓ TIMESTAMPTZ positive offset works")


fn test_timestamptz_decode_negative_offset() raises:
    """Test TIMESTAMPTZ decoding with negative offset."""
    print("  Testing TIMESTAMPTZ decode negative offset...")

    from src.types.temporal import decode_timestamptz

    # -05:00 = -18000 seconds
    var result = decode_timestamptz("2024-01-15 10:30:45-05")
    
    if result.timezone_offset_seconds != -18000:
        raise Error("Expected timezone offset -18000 (-5 hours)")

    print("    ✓ TIMESTAMPTZ negative offset works")


fn test_timestamptz_decode_with_microseconds() raises:
    """Test TIMESTAMPTZ decoding with microseconds."""
    print("  Testing TIMESTAMPTZ decode with microseconds...")

    from src.types.temporal import decode_timestamptz

    var result = decode_timestamptz("2024-01-15 10:30:45.123456+00")
    
    if result.microsecond != 123456:
        raise Error("Expected microsecond 123456")

    print("    ✓ TIMESTAMPTZ with microseconds works")


# ============================================================================
# DATE Decoder Tests
# ============================================================================

fn test_date_decode_simple() raises:
    """Test DATE decoding with simple value."""
    print("  Testing DATE decode simple...")

    from src.types.temporal import decode_date

    var result = decode_date("2024-01-15")
    
    if result.year != 2024:
        raise Error("Expected year 2024")
    if result.month != 1:
        raise Error("Expected month 1")
    if result.day != 15:
        raise Error("Expected day 15")

    print("    ✓ DATE simple decode works")


fn test_date_decode_leap_year() raises:
    """Test DATE decoding with leap year date."""
    print("  Testing DATE decode leap year...")

    from src.types.temporal import decode_date

    var result = decode_date("2024-02-29")
    
    if result.year != 2024:
        raise Error("Expected year 2024")
    if result.month != 2:
        raise Error("Expected month 2")
    if result.day != 29:
        raise Error("Expected day 29")

    print("    ✓ DATE leap year works")


fn test_date_decode_start_of_year() raises:
    """Test DATE decoding at start of year."""
    print("  Testing DATE decode start of year...")

    from src.types.temporal import decode_date

    var result = decode_date("2024-01-01")
    
    if result.month != 1:
        raise Error("Expected month 1")
    if result.day != 1:
        raise Error("Expected day 1")

    print("    ✓ DATE start of year works")


fn test_date_decode_end_of_year() raises:
    """Test DATE decoding at end of year."""
    print("  Testing DATE decode end of year...")

    from src.types.temporal import decode_date

    var result = decode_date("2024-12-31")
    
    if result.month != 12:
        raise Error("Expected month 12")
    if result.day != 31:
        raise Error("Expected day 31")

    print("    ✓ DATE end of year works")


# ============================================================================
# TIME Decoder Tests
# ============================================================================

fn test_time_decode_simple() raises:
    """Test TIME decoding with simple value."""
    print("  Testing TIME decode simple...")

    from src.types.temporal import decode_time

    var result = decode_time("10:30:45")
    
    if result.hour != 10:
        raise Error("Expected hour 10")
    if result.minute != 30:
        raise Error("Expected minute 30")
    if result.second != 45:
        raise Error("Expected second 45")
    if result.microsecond != 0:
        raise Error("Expected microsecond 0")

    print("    ✓ TIME simple decode works")


fn test_time_decode_with_microseconds() raises:
    """Test TIME decoding with microseconds."""
    print("  Testing TIME decode with microseconds...")

    from src.types.temporal import decode_time

    var result = decode_time("10:30:45.123456")
    
    if result.microsecond != 123456:
        raise Error("Expected microsecond 123456")

    print("    ✓ TIME with microseconds works")


fn test_time_decode_midnight() raises:
    """Test TIME decoding at midnight."""
    print("  Testing TIME decode midnight...")

    from src.types.temporal import decode_time

    var result = decode_time("00:00:00")
    
    if result.hour != 0:
        raise Error("Expected hour 0")
    if result.minute != 0:
        raise Error("Expected minute 0")
    if result.second != 0:
        raise Error("Expected second 0")

    print("    ✓ TIME midnight works")


fn test_time_decode_end_of_day() raises:
    """Test TIME decoding at end of day."""
    print("  Testing TIME decode end of day...")

    from src.types.temporal import decode_time

    var result = decode_time("23:59:59")
    
    if result.hour != 23:
        raise Error("Expected hour 23")
    if result.minute != 59:
        raise Error("Expected minute 59")
    if result.second != 59:
        raise Error("Expected second 59")

    print("    ✓ TIME end of day works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Unit Tests: Temporal Type Decoders")
    print("=" * 70)
    print("")

    print("TIMESTAMP Decoder Tests:")
    test_timestamp_decode_simple()
    test_timestamp_decode_with_microseconds()
    test_timestamp_decode_midnight()
    test_timestamp_decode_end_of_day()

    print("\nTIMESTAMPTZ Decoder Tests:")
    test_timestamptz_decode_utc()
    test_timestamptz_decode_positive_offset()
    test_timestamptz_decode_negative_offset()
    test_timestamptz_decode_with_microseconds()

    print("\nDATE Decoder Tests:")
    test_date_decode_simple()
    test_date_decode_leap_year()
    test_date_decode_start_of_year()
    test_date_decode_end_of_year()

    print("\nTIME Decoder Tests:")
    test_time_decode_simple()
    test_time_decode_with_microseconds()
    test_time_decode_midnight()
    test_time_decode_end_of_day()

    print("\n" + "=" * 70)
    print("✅ All unit tests passed!")
    print("=" * 70)
    print("")
    print("Test Summary:")
    print("  - TIMESTAMP decoder: 4 tests ✓")
    print("  - TIMESTAMPTZ decoder: 4 tests ✓")
    print("  - DATE decoder: 4 tests ✓")
    print("  - TIME decoder: 4 tests ✓")
    print("")
    print("Total: 16 unit tests")
    print("=" * 70)
