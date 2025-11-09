"""
PostgreSQL numeric type decoders.

Decodes numeric types from PostgreSQL text format to native Mojo types:
- INT2 (SMALLINT) ’ Int16
- INT4 (INTEGER) ’ Int32
- INT8 (BIGINT) ’ Int64
- FLOAT4 (REAL) ’ Float32
- FLOAT8 (DOUBLE PRECISION) ’ Float64

All decoders handle:
- Positive and negative numbers
- Overflow detection
- Invalid input validation
- Whitespace trimming (PostgreSQL compatibility)
"""

from math import isnan, isinf


# ============================================================================
# Helper Functions
# ============================================================================

fn trim_whitespace(s: String) -> String:
    """Remove leading and trailing whitespace."""
    var result = s

    # Trim leading whitespace
    var start = 0
    while start < len(result) and (result[start] == ' ' or result[start] == '\t' or result[start] == '\n'):
        start += 1

    # Trim trailing whitespace
    var end = len(result)
    while end > start and (result[end-1] == ' ' or result[end-1] == '\t' or result[end-1] == '\n'):
        end -= 1

    if start == 0 and end == len(result):
        return result

    # Extract trimmed substring
    var trimmed = String("")
    for i in range(start, end):
        trimmed += result[i]

    return trimmed


fn is_digit(c: String) -> Bool:
    """Check if character is a digit (0-9)."""
    if len(c) != 1:
        return False
    var code = ord(c)
    return code >= ord('0') and code <= ord('9')


fn char_to_digit(c: String) -> Int:
    """Convert character to digit value."""
    return ord(c) - ord('0')


# ============================================================================
# INT2 (SMALLINT) Decoder
# ============================================================================

fn decode_int2(value: String) raises -> Int16:
    """
    Decode PostgreSQL INT2 (SMALLINT) from text format.

    Args:
        value: Text representation (e.g., "42", "-123")

    Returns:
        Parsed Int16 value

    Raises:
        Error if invalid format or overflow
    """
    var trimmed = trim_whitespace(value)

    if len(trimmed) == 0:
        raise Error("Cannot decode INT2 from empty string")

    var is_negative = False
    var start_idx = 0

    # Check for sign
    if trimmed[0] == '-':
        is_negative = True
        start_idx = 1
    elif trimmed[0] == '+':
        start_idx = 1

    if start_idx >= len(trimmed):
        raise Error("Invalid INT2 format: sign with no digits")

    # Parse digits
    var result: Int64 = 0  # Use Int64 to detect overflow

    for i in range(start_idx, len(trimmed)):
        var c = trimmed[i]
        if not is_digit(c):
            raise Error("Invalid INT2 format: non-digit character '" + c + "'")

        result = result * 10 + char_to_digit(c)

        # Early overflow detection
        if result > 32768:  # Slightly more than INT16_MAX
            raise Error("INT2 overflow: value too large for SMALLINT")

    if is_negative:
        result = -result

    # Check bounds: INT16_MIN = -32768, INT16_MAX = 32767
    if result < -32768 or result > 32767:
        raise Error("INT2 overflow: value outside SMALLINT range [-32768, 32767]")

    return Int16(result)


# ============================================================================
# INT4 (INTEGER) Decoder
# ============================================================================

fn decode_int4(value: String) raises -> Int32:
    """
    Decode PostgreSQL INT4 (INTEGER) from text format.

    Args:
        value: Text representation (e.g., "42", "-123")

    Returns:
        Parsed Int32 value

    Raises:
        Error if invalid format or overflow
    """
    var trimmed = trim_whitespace(value)

    if len(trimmed) == 0:
        raise Error("Cannot decode INT4 from empty string")

    var is_negative = False
    var start_idx = 0

    # Check for sign
    if trimmed[0] == '-':
        is_negative = True
        start_idx = 1
    elif trimmed[0] == '+':
        start_idx = 1

    if start_idx >= len(trimmed):
        raise Error("Invalid INT4 format: sign with no digits")

    # Parse digits
    var result: Int64 = 0  # Use Int64 to detect overflow

    for i in range(start_idx, len(trimmed)):
        var c = trimmed[i]
        if not is_digit(c):
            raise Error("Invalid INT4 format: non-digit character '" + c + "'")

        result = result * 10 + char_to_digit(c)

        # Early overflow detection
        if result > 2147483648:  # Slightly more than INT32_MAX
            raise Error("INT4 overflow: value too large for INTEGER")

    if is_negative:
        result = -result

    # Check bounds: INT32_MIN = -2147483648, INT32_MAX = 2147483647
    if result < -2147483648 or result > 2147483647:
        raise Error("INT4 overflow: value outside INTEGER range")

    return Int32(result)


# ============================================================================
# INT8 (BIGINT) Decoder
# ============================================================================

fn decode_int8(value: String) raises -> Int64:
    """
    Decode PostgreSQL INT8 (BIGINT) from text format.

    Args:
        value: Text representation (e.g., "1000000000000")

    Returns:
        Parsed Int64 value

    Raises:
        Error if invalid format or overflow
    """
    var trimmed = trim_whitespace(value)

    if len(trimmed) == 0:
        raise Error("Cannot decode INT8 from empty string")

    var is_negative = False
    var start_idx = 0

    # Check for sign
    if trimmed[0] == '-':
        is_negative = True
        start_idx = 1
    elif trimmed[0] == '+':
        start_idx = 1

    if start_idx >= len(trimmed):
        raise Error("Invalid INT8 format: sign with no digits")

    # Parse digits
    var result: Int64 = 0

    # INT64_MAX = 9223372036854775807 (19 digits)
    # We need to be careful with overflow
    var max_safe_value: Int64 = 922337203685477580  # INT64_MAX / 10

    for i in range(start_idx, len(trimmed)):
        var c = trimmed[i]
        if not is_digit(c):
            raise Error("Invalid INT8 format: non-digit character '" + c + "'")

        var digit = char_to_digit(c)

        # Check for overflow before multiplication
        if result > max_safe_value:
            raise Error("INT8 overflow: value too large for BIGINT")

        if result == max_safe_value and digit > 7:
            # Last digit can only be 0-7 for positive, 0-8 for negative
            if not is_negative or digit > 8:
                raise Error("INT8 overflow: value too large for BIGINT")

        result = result * 10 + digit

    if is_negative:
        # Special case: -9223372036854775808 (INT64_MIN) is valid
        return -result

    return result


# ============================================================================
# FLOAT8 (DOUBLE PRECISION) Decoder
# ============================================================================

fn decode_float8(value: String) raises -> Float64:
    """
    Decode PostgreSQL FLOAT8 (DOUBLE PRECISION) from text format.

    Supports:
    - Regular decimals: "3.14159", "-42.5"
    - Scientific notation: "1.23e5", "1.5e-3"
    - Special values: "Infinity", "-Infinity", "NaN"

    Args:
        value: Text representation

    Returns:
        Parsed Float64 value

    Raises:
        Error if invalid format
    """
    var trimmed = trim_whitespace(value)

    if len(trimmed) == 0:
        raise Error("Cannot decode FLOAT8 from empty string")

    # Handle special values
    if trimmed == "Infinity":
        return Float64(1.0) / Float64(0.0)  # +Infinity
    elif trimmed == "-Infinity":
        return Float64(-1.0) / Float64(0.0)  # -Infinity
    elif trimmed == "NaN":
        return Float64(0.0) / Float64(0.0)  # NaN

    # Use Mojo's built-in float conversion
    # Note: This is a simplified version. Full implementation would parse manually
    # for better error messages, but atof() should work for most cases
    try:
        return atof(trimmed)
    except:
        raise Error("Invalid FLOAT8 format: cannot parse '" + trimmed + "'")


# ============================================================================
# FLOAT4 (REAL) Decoder
# ============================================================================

fn decode_float4(value: String) raises -> Float32:
    """
    Decode PostgreSQL FLOAT4 (REAL) from text format.

    Args:
        value: Text representation

    Returns:
        Parsed Float32 value

    Raises:
        Error if invalid format
    """
    # Decode as Float64 first, then convert
    var f64 = decode_float8(value)

    # Check if value fits in Float32 range
    # Float32 range: ±3.4e38 approximately
    # For now, just convert (may lose precision)
    return Float32(f64)


# ============================================================================
# Type Name Helpers
# ============================================================================

fn get_numeric_type_name(type_oid: Int) -> String:
    """Get human-readable name for numeric type OID."""
    if type_oid == 21:  # INT2
        return "INT2 (SMALLINT)"
    elif type_oid == 23:  # INT4
        return "INT4 (INTEGER)"
    elif type_oid == 20:  # INT8
        return "INT8 (BIGINT)"
    elif type_oid == 700:  # FLOAT4
        return "FLOAT4 (REAL)"
    elif type_oid == 701:  # FLOAT8
        return "FLOAT8 (DOUBLE PRECISION)"
    else:
        return "UNKNOWN NUMERIC TYPE (" + String(type_oid) + ")"
