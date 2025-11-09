"""
Unit tests for PostgreSQL binary format encoders/decoders.

Tests round-trip encoding/decoding for all supported types:
- INT2, INT4, INT8
- FLOAT4, FLOAT8
- BOOLEAN
- TEXT
- TIMESTAMP, DATE, TIME

Run:
  mojo tests/unit/test_binary_format.mojo
"""

from testing import assert_equal, assert_true, assert_false


# ============================================================================
# INT2 Tests
# ============================================================================

fn test_int2_encode_decode_positive() raises:
    """Test INT2 encoding/decoding for positive values."""
    print("  Testing INT2 encode/decode (positive)...")

    from src.types.binary_format import encode_int2_binary, decode_int2_binary

    var value: Int16 = 42
    var encoded = encode_int2_binary(value)
    var decoded = decode_int2_binary(encoded)

    if decoded != value:
        raise Error("INT2 round-trip failed: expected " + String(value) + ", got " + String(decoded))

    print("    ✓ INT2 positive works")


fn test_int2_encode_decode_negative() raises:
    """Test INT2 encoding/decoding for negative values."""
    print("  Testing INT2 encode/decode (negative)...")

    from src.types.binary_format import encode_int2_binary, decode_int2_binary

    var value: Int16 = -100
    var encoded = encode_int2_binary(value)
    var decoded = decode_int2_binary(encoded)

    if decoded != value:
        raise Error("INT2 round-trip failed: expected " + String(value) + ", got " + String(decoded))

    print("    ✓ INT2 negative works")


fn test_int2_encode_decode_zero() raises:
    """Test INT2 encoding/decoding for zero."""
    print("  Testing INT2 encode/decode (zero)...")

    from src.types.binary_format import encode_int2_binary, decode_int2_binary

    var value: Int16 = 0
    var encoded = encode_int2_binary(value)
    var decoded = decode_int2_binary(encoded)

    if decoded != value:
        raise Error("INT2 round-trip failed")

    print("    ✓ INT2 zero works")


# ============================================================================
# INT4 Tests
# ============================================================================

fn test_int4_encode_decode_positive() raises:
    """Test INT4 encoding/decoding for positive values."""
    print("  Testing INT4 encode/decode (positive)...")

    from src.types.binary_format import encode_int4_binary, decode_int4_binary

    var value: Int32 = 123456
    var encoded = encode_int4_binary(value)
    var decoded = decode_int4_binary(encoded)

    if decoded != value:
        raise Error("INT4 round-trip failed")

    print("    ✓ INT4 positive works")


fn test_int4_encode_decode_negative() raises:
    """Test INT4 encoding/decoding for negative values."""
    print("  Testing INT4 encode/decode (negative)...")

    from src.types.binary_format import encode_int4_binary, decode_int4_binary

    var value: Int32 = -999999
    var encoded = encode_int4_binary(value)
    var decoded = decode_int4_binary(encoded)

    if decoded != value:
        raise Error("INT4 round-trip failed")

    print("    ✓ INT4 negative works")


# ============================================================================
# INT8 Tests
# ============================================================================

fn test_int8_encode_decode_positive() raises:
    """Test INT8 encoding/decoding for positive values."""
    print("  Testing INT8 encode/decode (positive)...")

    from src.types.binary_format import encode_int8_binary, decode_int8_binary

    var value: Int64 = 9876543210
    var encoded = encode_int8_binary(value)
    var decoded = decode_int8_binary(encoded)

    if decoded != value:
        raise Error("INT8 round-trip failed")

    print("    ✓ INT8 positive works")


fn test_int8_encode_decode_negative() raises:
    """Test INT8 encoding/decoding for negative values."""
    print("  Testing INT8 encode/decode (negative)...")

    from src.types.binary_format import encode_int8_binary, decode_int8_binary

    var value: Int64 = -123456789012
    var encoded = encode_int8_binary(value)
    var decoded = decode_int8_binary(encoded)

    if decoded != value:
        raise Error("INT8 round-trip failed")

    print("    ✓ INT8 negative works")


# ============================================================================
# FLOAT4 Tests
# ============================================================================

fn test_float4_encode_decode() raises:
    """Test FLOAT4 encoding/decoding."""
    print("  Testing FLOAT4 encode/decode...")

    from src.types.binary_format import encode_float4_binary, decode_float4_binary

    var value: Float32 = 3.14159
    var encoded = encode_float4_binary(value)
    var decoded = decode_float4_binary(encoded)

    # Allow small floating point error
    var diff = abs(decoded - value)
    if diff > 0.00001:
        raise Error("FLOAT4 round-trip failed")

    print("    ✓ FLOAT4 works")


# ============================================================================
# FLOAT8 Tests
# ============================================================================

fn test_float8_encode_decode() raises:
    """Test FLOAT8 encoding/decoding."""
    print("  Testing FLOAT8 encode/decode...")

    from src.types.binary_format import encode_float8_binary, decode_float8_binary

    var value: Float64 = 3.14159265358979
    var encoded = encode_float8_binary(value)
    var decoded = decode_float8_binary(encoded)

    # Allow small floating point error
    var diff = abs(decoded - value)
    if diff > 0.0000000001:
        raise Error("FLOAT8 round-trip failed")

    print("    ✓ FLOAT8 works")


# ============================================================================
# BOOLEAN Tests
# ============================================================================

fn test_boolean_encode_decode_true() raises:
    """Test BOOLEAN encoding/decoding for True."""
    print("  Testing BOOLEAN encode/decode (true)...")

    from src.types.binary_format import encode_boolean_binary, decode_boolean_binary

    var value = True
    var encoded = encode_boolean_binary(value)
    var decoded = decode_boolean_binary(encoded)

    if decoded != value:
        raise Error("BOOLEAN round-trip failed (true)")

    print("    ✓ BOOLEAN true works")


fn test_boolean_encode_decode_false() raises:
    """Test BOOLEAN encoding/decoding for False."""
    print("  Testing BOOLEAN encode/decode (false)...")

    from src.types.binary_format import encode_boolean_binary, decode_boolean_binary

    var value = False
    var encoded = encode_boolean_binary(value)
    var decoded = decode_boolean_binary(encoded)

    if decoded != value:
        raise Error("BOOLEAN round-trip failed (false)")

    print("    ✓ BOOLEAN false works")


# ============================================================================
# TEXT Tests
# ============================================================================

fn test_text_encode_decode() raises:
    """Test TEXT encoding/decoding."""
    print("  Testing TEXT encode/decode...")

    from src.types.binary_format import encode_text_binary, decode_text_binary

    var value = "Hello, World!"
    var encoded = encode_text_binary(value)
    var decoded = decode_text_binary(encoded)

    if decoded != value:
        raise Error("TEXT round-trip failed")

    print("    ✓ TEXT works")


fn test_text_encode_decode_empty() raises:
    """Test TEXT encoding/decoding for empty string."""
    print("  Testing TEXT encode/decode (empty)...")

    from src.types.binary_format import encode_text_binary, decode_text_binary

    var value = ""
    var encoded = encode_text_binary(value)
    var decoded = decode_text_binary(encoded)

    if decoded != value:
        raise Error("TEXT round-trip failed (empty)")

    print("    ✓ TEXT empty works")


# ============================================================================
# DATE Tests
# ============================================================================

fn test_date_encode_decode() raises:
    """Test DATE encoding/decoding."""
    print("  Testing DATE encode/decode...")

    from src.types.binary_format import encode_date_binary, decode_date_binary

    # Test date: 2024-01-15
    var encoded = encode_date_binary(2024, 1, 15)
    var decoded = decode_date_binary(encoded)

    if decoded.year != 2024:
        raise Error("DATE year mismatch")
    if decoded.month != 1:
        raise Error("DATE month mismatch")
    if decoded.day != 15:
        raise Error("DATE day mismatch")

    print("    ✓ DATE works")


fn test_date_encode_decode_epoch() raises:
    """Test DATE encoding/decoding for PostgreSQL epoch."""
    print("  Testing DATE encode/decode (epoch)...")

    from src.types.binary_format import encode_date_binary, decode_date_binary

    # PostgreSQL epoch: 2000-01-01
    var encoded = encode_date_binary(2000, 1, 1)
    var decoded = decode_date_binary(encoded)

    if decoded.year != 2000:
        raise Error("DATE epoch year mismatch")
    if decoded.month != 1:
        raise Error("DATE epoch month mismatch")
    if decoded.day != 1:
        raise Error("DATE epoch day mismatch")

    print("    ✓ DATE epoch works")


# ============================================================================
# TIME Tests
# ============================================================================

fn test_time_encode_decode() raises:
    """Test TIME encoding/decoding."""
    print("  Testing TIME encode/decode...")

    from src.types.binary_format import encode_time_binary, decode_time_binary

    # Test time: 10:30:45.123456
    var encoded = encode_time_binary(10, 30, 45, 123456)
    var decoded = decode_time_binary(encoded)

    if decoded.hour != 10:
        raise Error("TIME hour mismatch")
    if decoded.minute != 30:
        raise Error("TIME minute mismatch")
    if decoded.second != 45:
        raise Error("TIME second mismatch")
    if decoded.microsecond != 123456:
        raise Error("TIME microsecond mismatch")

    print("    ✓ TIME works")


fn test_time_encode_decode_midnight() raises:
    """Test TIME encoding/decoding for midnight."""
    print("  Testing TIME encode/decode (midnight)...")

    from src.types.binary_format import encode_time_binary, decode_time_binary

    # Midnight: 00:00:00
    var encoded = encode_time_binary(0, 0, 0, 0)
    var decoded = decode_time_binary(encoded)

    if decoded.hour != 0:
        raise Error("TIME midnight hour mismatch")
    if decoded.minute != 0:
        raise Error("TIME midnight minute mismatch")
    if decoded.second != 0:
        raise Error("TIME midnight second mismatch")
    if decoded.microsecond != 0:
        raise Error("TIME midnight microsecond mismatch")

    print("    ✓ TIME midnight works")


# ============================================================================
# TIMESTAMP Tests
# ============================================================================

fn test_timestamp_encode_decode() raises:
    """Test TIMESTAMP encoding/decoding."""
    print("  Testing TIMESTAMP encode/decode...")

    from src.types.binary_format import encode_timestamp_binary, decode_timestamp_binary

    # Test timestamp: 2024-01-15 10:30:45.123456
    var encoded = encode_timestamp_binary(2024, 1, 15, 10, 30, 45, 123456)
    var decoded = decode_timestamp_binary(encoded)

    if decoded.year != 2024:
        raise Error("TIMESTAMP year mismatch")
    if decoded.month != 1:
        raise Error("TIMESTAMP month mismatch")
    if decoded.day != 15:
        raise Error("TIMESTAMP day mismatch")
    if decoded.hour != 10:
        raise Error("TIMESTAMP hour mismatch")
    if decoded.minute != 30:
        raise Error("TIMESTAMP minute mismatch")
    if decoded.second != 45:
        raise Error("TIMESTAMP second mismatch")
    if decoded.microsecond != 123456:
        raise Error("TIMESTAMP microsecond mismatch")

    print("    ✓ TIMESTAMP works")


# ============================================================================
# Date Utility Tests
# ============================================================================

fn test_date_to_days_since_2000() raises:
    """Test date to days conversion."""
    print("  Testing date_to_days_since_2000...")

    from src.types.binary_format import date_to_days_since_2000

    # Epoch should be 0
    var days_epoch = date_to_days_since_2000(2000, 1, 1)
    if days_epoch != 0:
        raise Error("Epoch days should be 0, got " + String(days_epoch))

    # 2000-01-02 should be 1
    var days_next = date_to_days_since_2000(2000, 1, 2)
    if days_next != 1:
        raise Error("Next day should be 1, got " + String(days_next))

    print("    ✓ date_to_days_since_2000 works")


fn test_days_since_2000_to_date() raises:
    """Test days to date conversion."""
    print("  Testing days_since_2000_to_date...")

    from src.types.binary_format import days_since_2000_to_date

    # Day 0 should be 2000-01-01
    var date_epoch = days_since_2000_to_date(0)
    if date_epoch.year != 2000 or date_epoch.month != 1 or date_epoch.day != 1:
        raise Error("Epoch date mismatch")

    # Day 1 should be 2000-01-02
    var date_next = days_since_2000_to_date(1)
    if date_next.year != 2000 or date_next.month != 1 or date_next.day != 2:
        raise Error("Next day mismatch")

    print("    ✓ days_since_2000_to_date works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Unit Tests: Binary Format Encoders/Decoders")
    print("=" * 70)
    print("")

    print("INT2 Tests:")
    test_int2_encode_decode_positive()
    test_int2_encode_decode_negative()
    test_int2_encode_decode_zero()

    print("\nINT4 Tests:")
    test_int4_encode_decode_positive()
    test_int4_encode_decode_negative()

    print("\nINT8 Tests:")
    test_int8_encode_decode_positive()
    test_int8_encode_decode_negative()

    print("\nFLOAT4 Tests:")
    test_float4_encode_decode()

    print("\nFLOAT8 Tests:")
    test_float8_encode_decode()

    print("\nBOOLEAN Tests:")
    test_boolean_encode_decode_true()
    test_boolean_encode_decode_false()

    print("\nTEXT Tests:")
    test_text_encode_decode()
    test_text_encode_decode_empty()

    print("\nDATE Tests:")
    test_date_encode_decode()
    test_date_encode_decode_epoch()

    print("\nTIME Tests:")
    test_time_encode_decode()
    test_time_encode_decode_midnight()

    print("\nTIMESTAMP Tests:")
    test_timestamp_encode_decode()

    print("\nDate Utility Tests:")
    test_date_to_days_since_2000()
    test_days_since_2000_to_date()

    print("\n" + "=" * 70)
    print("✅ All unit tests passed!")
    print("=" * 70)
    print("")
    print("Test Summary:")
    print("  - INT2: 3 tests ✓")
    print("  - INT4: 2 tests ✓")
    print("  - INT8: 2 tests ✓")
    print("  - FLOAT4: 1 test ✓")
    print("  - FLOAT8: 1 test ✓")
    print("  - BOOLEAN: 2 tests ✓")
    print("  - TEXT: 2 tests ✓")
    print("  - DATE: 2 tests ✓")
    print("  - TIME: 2 tests ✓")
    print("  - TIMESTAMP: 1 test ✓")
    print("  - Date utilities: 2 tests ✓")
    print("")
    print("Total: 20 unit tests")
    print("")
    print("Binary format encoding/decoding is working! 🚀")
    print("Expected performance: 3-5x faster than text format")
    print("=" * 70)
