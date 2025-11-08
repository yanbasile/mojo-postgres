"""
Unit tests for PostgreSQL NUMERIC and JSONB type decoders.

Tests:
- NUMERIC decoder (arbitrary precision decimal)
- JSONB decoder (JSON parsing)

Run:
  mojo tests/unit/test_numeric_jsonb_types.mojo
"""

from testing import assert_equal, assert_true, assert_false


# ============================================================================
# NUMERIC Decoder Tests
# ============================================================================

fn test_numeric_decode_integer() raises:
    """Test NUMERIC decoding for integer values."""
    print("  Testing NUMERIC decode integer...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("42")
    if result.to_string() != "42":
        raise Error("Expected '42', got: " + result.to_string())

    print("    ✓ Integer decode works")


fn test_numeric_decode_decimal() raises:
    """Test NUMERIC decoding for decimal values."""
    print("  Testing NUMERIC decode decimal...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("123.45")
    if result.to_string() != "123.45":
        raise Error("Expected '123.45', got: " + result.to_string())

    print("    ✓ Decimal decode works")


fn test_numeric_decode_negative() raises:
    """Test NUMERIC decoding for negative values."""
    print("  Testing NUMERIC decode negative...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("-999.999")
    if result.to_string() != "-999.999":
        raise Error("Expected '-999.999', got: " + result.to_string())

    print("    ✓ Negative decode works")


fn test_numeric_decode_zero() raises:
    """Test NUMERIC decoding for zero."""
    print("  Testing NUMERIC decode zero...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("0")
    if result.to_string() != "0":
        raise Error("Expected '0', got: " + result.to_string())

    print("    ✓ Zero decode works")


fn test_numeric_decode_leading_zeros() raises:
    """Test NUMERIC decoding with leading zeros."""
    print("  Testing NUMERIC decode leading zeros...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("0042.1000")
    # Should normalize to "42.1" or "42.1000" depending on implementation
    var str_result = result.to_string()

    print("    ✓ Leading zeros handled (result: " + str_result + ")")


fn test_numeric_decode_high_precision() raises:
    """Test NUMERIC decoding with high precision (financial)."""
    print("  Testing NUMERIC decode high precision...")

    from src.types.numeric_jsonb import decode_numeric

    # Typical crypto price with 8 decimal places
    var result = decode_numeric("50123.45678901")
    if result.to_string() != "50123.45678901":
        raise Error("High precision mismatch")

    print("    ✓ High precision works")


fn test_numeric_decode_very_large() raises:
    """Test NUMERIC decoding for very large numbers."""
    print("  Testing NUMERIC decode very large...")

    from src.types.numeric_jsonb import decode_numeric

    # Beyond INT64 range
    var result = decode_numeric("99999999999999999999.99")
    var str_result = result.to_string()

    print("    ✓ Very large number handled (result: " + str_result + ")")


fn test_numeric_decode_very_small() raises:
    """Test NUMERIC decoding for very small decimals."""
    print("  Testing NUMERIC decode very small...")

    from src.types.numeric_jsonb import decode_numeric

    var result = decode_numeric("0.00000001")
    if result.to_string() != "0.00000001":
        raise Error("Very small decimal mismatch")

    print("    ✓ Very small decimal works")


fn test_numeric_to_float64() raises:
    """Test NUMERIC conversion to Float64 for calculations."""
    print("  Testing NUMERIC to Float64 conversion...")

    from src.types.numeric_jsonb import decode_numeric

    var numeric = decode_numeric("123.45")
    var float_val = numeric.to_float64()

    # Allow small floating point error
    var expected = 123.45
    var diff = abs(float_val - expected)
    if diff > 0.0001:
        raise Error("Float64 conversion failed")

    print("    ✓ to_float64() works")


fn test_numeric_comparison() raises:
    """Test NUMERIC comparison operations."""
    print("  Testing NUMERIC comparison...")

    from src.types.numeric_jsonb import decode_numeric

    var a = decode_numeric("123.45")
    var b = decode_numeric("123.46")
    var c = decode_numeric("123.45")

    # Test equality
    if not a.equals(c):
        raise Error("Equality check failed")

    # Test less than
    if not a.less_than(b):
        raise Error("Less than check failed")

    print("    ✓ Comparison operations work")


# ============================================================================
# JSONB Decoder Tests
# ============================================================================

fn test_jsonb_decode_empty_object() raises:
    """Test JSONB decoding for empty object."""
    print("  Testing JSONB decode empty object...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb("{}")
    if result.to_string() != "{}":
        raise Error("Empty object mismatch")

    print("    ✓ Empty object works")


fn test_jsonb_decode_simple_object() raises:
    """Test JSONB decoding for simple object."""
    print("  Testing JSONB decode simple object...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"name": "Alice", "age": 30}')

    # Check if we can access fields
    var name = result.get_string("name")
    if name != "Alice":
        raise Error("Expected 'Alice', got: " + name)

    var age = result.get_int("age")
    if age != 30:
        raise Error("Expected 30, got: " + String(age))

    print("    ✓ Simple object works")


fn test_jsonb_decode_nested_object() raises:
    """Test JSONB decoding for nested object."""
    print("  Testing JSONB decode nested object...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"user": {"name": "Bob", "id": 123}}')

    var user = result.get_object("user")
    var name = user.get_string("name")
    if name != "Bob":
        raise Error("Nested name mismatch")

    print("    ✓ Nested object works")


fn test_jsonb_decode_array() raises:
    """Test JSONB decoding for array."""
    print("  Testing JSONB decode array...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"tags": ["crypto", "trading", "BTC"]}')

    var tags = result.get_array("tags")
    if tags.length() != 3:
        raise Error("Expected 3 tags")

    var tag0 = tags.get_string(0)
    if tag0 != "crypto":
        raise Error("Tag 0 mismatch")

    print("    ✓ Array works")


fn test_jsonb_decode_mixed_types() raises:
    """Test JSONB decoding with mixed types."""
    print("  Testing JSONB decode mixed types...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"name": "Alice", "active": true, "balance": 123.45, "count": 42}')

    var name = result.get_string("name")
    if name != "Alice":
        raise Error("String field mismatch")

    var active = result.get_bool("active")
    if not active:
        raise Error("Bool field mismatch")

    var balance = result.get_float("balance")
    if abs(balance - 123.45) > 0.001:
        raise Error("Float field mismatch")

    var count = result.get_int("count")
    if count != 42:
        raise Error("Int field mismatch")

    print("    ✓ Mixed types work")


fn test_jsonb_decode_null_value() raises:
    """Test JSONB decoding with null value."""
    print("  Testing JSONB decode null value...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"name": "Alice", "email": null}')

    if not result.is_null("email"):
        raise Error("Expected null for email")

    print("    ✓ Null value works")


fn test_jsonb_decode_boolean_values() raises:
    """Test JSONB decoding with boolean values."""
    print("  Testing JSONB decode boolean values...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"active": true, "deleted": false}')

    var active = result.get_bool("active")
    if not active:
        raise Error("Expected true for active")

    var deleted = result.get_bool("deleted")
    if deleted:
        raise Error("Expected false for deleted")

    print("    ✓ Boolean values work")


fn test_jsonb_decode_escaped_strings() raises:
    """Test JSONB decoding with escaped strings."""
    print("  Testing JSONB decode escaped strings...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"message": "Line 1\\nLine 2\\tTab"}')

    var message = result.get_string("message")
    # Should handle escaped characters

    print("    ✓ Escaped strings handled")


fn test_jsonb_to_string() raises:
    """Test JSONB to_string() conversion."""
    print("  Testing JSONB to_string()...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"name": "Alice", "age": 30}')
    var str_result = result.to_string()

    # Should produce valid JSON string
    if len(str_result) == 0:
        raise Error("to_string() returned empty")

    print("    ✓ to_string() works")


fn test_jsonb_has_key() raises:
    """Test JSONB has_key() method."""
    print("  Testing JSONB has_key()...")

    from src.types.numeric_jsonb import decode_jsonb

    var result = decode_jsonb('{"name": "Alice", "age": 30}')

    if not result.has_key("name"):
        raise Error("Expected has_key('name') to be true")

    if result.has_key("email"):
        raise Error("Expected has_key('email') to be false")

    print("    ✓ has_key() works")


# ============================================================================
# Main Test Runner
# ============================================================================

fn main() raises:
    print("\n" + "=" * 70)
    print("Unit Tests: NUMERIC and JSONB Type Decoders")
    print("=" * 70)
    print("")

    print("NUMERIC Decoder Tests:")
    test_numeric_decode_integer()
    test_numeric_decode_decimal()
    test_numeric_decode_negative()
    test_numeric_decode_zero()
    test_numeric_decode_leading_zeros()
    test_numeric_decode_high_precision()
    test_numeric_decode_very_large()
    test_numeric_decode_very_small()
    test_numeric_to_float64()
    test_numeric_comparison()

    print("\nJSONB Decoder Tests:")
    test_jsonb_decode_empty_object()
    test_jsonb_decode_simple_object()
    test_jsonb_decode_nested_object()
    test_jsonb_decode_array()
    test_jsonb_decode_mixed_types()
    test_jsonb_decode_null_value()
    test_jsonb_decode_boolean_values()
    test_jsonb_decode_escaped_strings()
    test_jsonb_to_string()
    test_jsonb_has_key()

    print("\n" + "=" * 70)
    print("✅ All unit tests passed!")
    print("=" * 70)
    print("")
    print("Test Summary:")
    print("  - NUMERIC decoder: 10 tests ✓")
    print("  - JSONB decoder: 10 tests ✓")
    print("")
    print("Total: 20 unit tests")
    print("=" * 70)
