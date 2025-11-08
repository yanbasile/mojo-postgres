"""
PostgreSQL text and boolean type decoders.

Supports:
- BOOLEAN (decode 't'/'f' to Bool)
- TEXT (String validation)
- VARCHAR (String validation)
- CHAR (String with length validation)

PostgreSQL BOOLEAN representations:
- True: 't', 'T', 'true', 'TRUE', 'yes', 'YES', 'on', 'ON', '1'
- False: 'f', 'F', 'false', 'FALSE', 'no', 'NO', 'off', 'OFF', '0'

Reference:
https://www.postgresql.org/docs/current/datatype-boolean.html
https://www.postgresql.org/docs/current/datatype-character.html
"""


# ============================================================================
# Helper Functions
# ============================================================================

fn to_lowercase(s: String) -> String:
    """Convert string to lowercase for case-insensitive comparison."""
    # Simple ASCII lowercase conversion
    var result = String("")
    for i in range(len(s)):
        var c = s[i]
        if ord(c) >= ord('A') and ord(c) <= ord('Z'):
            result += chr(ord(c) + 32)
        else:
            result += c
    return result


fn trim_whitespace(s: String) -> String:
    """Trim leading and trailing whitespace from string."""
    if len(s) == 0:
        return s

    # Find first non-whitespace
    var start = 0
    while start < len(s):
        var c = s[start]
        if c != ' ' and c != '\t' and c != '\n' and c != '\r':
            break
        start += 1

    # All whitespace
    if start >= len(s):
        return ""

    # Find last non-whitespace
    var end = len(s) - 1
    while end >= start:
        var c = s[end]
        if c != ' ' and c != '\t' and c != '\n' and c != '\r':
            break
        end -= 1

    # Extract substring
    var result = String("")
    for i in range(start, end + 1):
        result += s[i]

    return result


# ============================================================================
# BOOLEAN Decoder
# ============================================================================

fn decode_boolean(value: String) raises -> Bool:
    """
    Decode PostgreSQL BOOLEAN from text format.

    PostgreSQL accepts many representations:
    - True: 't', 'true', 'yes', 'on', '1' (case-insensitive)
    - False: 'f', 'false', 'no', 'off', '0' (case-insensitive)

    Args:
        value: Text representation of boolean

    Returns:
        Bool value

    Raises:
        Error if value is not a valid boolean representation

    Examples:
        decode_boolean("t") → True
        decode_boolean("false") → False
        decode_boolean("yes") → True
        decode_boolean("0") → False
    """
    var trimmed = trim_whitespace(value)

    if len(trimmed) == 0:
        raise Error("Cannot decode empty string as BOOLEAN")

    # Convert to lowercase for case-insensitive comparison
    var lower = to_lowercase(trimmed)

    # Check true values
    if lower == "t" or lower == "true" or lower == "yes" or lower == "on" or lower == "1":
        return True

    # Check false values
    if lower == "f" or lower == "false" or lower == "no" or lower == "off" or lower == "0":
        return False

    # Invalid boolean value
    raise Error("Invalid BOOLEAN value: '" + value + "' (expected t/f, true/false, yes/no, on/off, 1/0)")


# ============================================================================
# TEXT Decoder
# ============================================================================

fn decode_text(value: String) -> String:
    """
    Decode PostgreSQL TEXT from text format.

    TEXT in PostgreSQL is already a string, so this is essentially a passthrough.
    However, it provides a consistent API for type decoding.

    PostgreSQL handles escaping during transmission, so we receive the raw string.

    Args:
        value: Text value from PostgreSQL

    Returns:
        String value (unchanged)

    Examples:
        decode_text("Hello") → "Hello"
        decode_text("Multi\\nLine") → "Multi\\nLine"
    """
    return value


# ============================================================================
# VARCHAR Decoder
# ============================================================================

fn decode_varchar(value: String) -> String:
    """
    Decode PostgreSQL VARCHAR from text format.

    VARCHAR is the same as TEXT in PostgreSQL (no length limit in storage).
    The length constraint (if specified) is enforced by PostgreSQL, not by the driver.

    Args:
        value: VARCHAR value from PostgreSQL

    Returns:
        String value (unchanged)

    Examples:
        decode_varchar("Sample") → "Sample"
    """
    return value


# ============================================================================
# CHAR Decoder
# ============================================================================

fn decode_char(value: String) -> String:
    """
    Decode PostgreSQL CHAR(n) from text format.

    CHAR(n) pads with spaces to the specified length in PostgreSQL.
    This decoder returns the value as-is (including trailing spaces).

    If you need the trimmed value, use decode_char_trimmed().

    Args:
        value: CHAR value from PostgreSQL (space-padded)

    Returns:
        String value (with trailing spaces)

    Examples:
        decode_char("abc  ") → "abc  "  (if CHAR(5))
    """
    return value


fn decode_char_trimmed(value: String) -> String:
    """
    Decode PostgreSQL CHAR(n) from text format with trailing space trimming.

    CHAR(n) pads with spaces to the specified length. This decoder removes
    trailing spaces for convenience.

    Args:
        value: CHAR value from PostgreSQL (space-padded)

    Returns:
        String value (trailing spaces removed)

    Examples:
        decode_char_trimmed("abc  ") → "abc"
    """
    # Only trim trailing spaces, preserve leading spaces
    if len(value) == 0:
        return value

    var end = len(value) - 1
    while end >= 0 and value[end] == ' ':
        end -= 1

    if end < 0:
        return ""  # All spaces

    var result = String("")
    for i in range(0, end + 1):
        result += value[i]

    return result


# ============================================================================
# Type Name Mapping
# ============================================================================

fn get_text_type_name(type_oid: Int) -> String:
    """
    Get human-readable name for text/boolean type OID.

    PostgreSQL type OIDs:
    - 16: BOOLEAN (bool)
    - 25: TEXT
    - 1042: CHAR(n) (bpchar)
    - 1043: VARCHAR(n)

    Args:
        type_oid: PostgreSQL type OID

    Returns:
        Type name string

    Examples:
        get_text_type_name(16) → "BOOLEAN"
        get_text_type_name(25) → "TEXT"
    """
    if type_oid == 16:
        return "BOOLEAN"
    elif type_oid == 25:
        return "TEXT"
    elif type_oid == 1042:
        return "CHAR"
    elif type_oid == 1043:
        return "VARCHAR"
    else:
        return "UNKNOWN_TEXT_TYPE(" + String(type_oid) + ")"


# ============================================================================
# Validation Helpers
# ============================================================================

fn validate_text_length(value: String, max_length: Int) raises:
    """
    Validate text length against maximum.

    Useful for VARCHAR(n) validation if you want to enforce length
    constraints on the client side.

    Args:
        value: Text value
        max_length: Maximum allowed length

    Raises:
        Error if value exceeds max_length
    """
    if len(value) > max_length:
        raise Error(
            "Text value exceeds maximum length of " + String(max_length) +
            " (got " + String(len(value)) + ")"
        )


fn is_ascii(value: String) -> Bool:
    """
    Check if string contains only ASCII characters (0-127).

    Useful for validation if you need pure ASCII.

    Args:
        value: String to check

    Returns:
        True if all characters are ASCII
    """
    for i in range(len(value)):
        if ord(value[i]) > 127:
            return False
    return True


fn contains_null_bytes(value: String) -> Bool:
    """
    Check if string contains NULL bytes (\\x00).

    PostgreSQL doesn't allow NULL bytes in TEXT/VARCHAR.
    This should never happen from PostgreSQL, but useful for validation.

    Args:
        value: String to check

    Returns:
        True if string contains NULL bytes
    """
    for i in range(len(value)):
        if ord(value[i]) == 0:
            return True
    return False
