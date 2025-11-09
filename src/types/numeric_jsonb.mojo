"""
PostgreSQL NUMERIC and JSONB type decoders.

Supports:
- NUMERIC (arbitrary precision decimal)
- JSONB (JSON binary storage)

NUMERIC is critical for financial calculations where floating point errors
are unacceptable (e.g., currency, prices, balances).

JSONB provides flexible schema-less storage for metadata, configurations,
and semi-structured data.

Reference:
https://www.postgresql.org/docs/current/datatype-numeric.html
https://www.postgresql.org/docs/current/datatype-json.html
"""


# ============================================================================
# NUMERIC Type
# ============================================================================

@value
struct Numeric:
    """
    PostgreSQL NUMERIC type (arbitrary precision decimal).

    Stores the numeric value as a string internally to preserve exact precision.
    This avoids floating point rounding errors for financial calculations.

    Examples:
        var price = Numeric("50123.45")
        var small = Numeric("0.00000001")
        var large = Numeric("99999999999999999999.99")
    """
    var value_str: String

    fn to_string(self) -> String:
        """Return string representation of the numeric value."""
        return self.value_str

    fn to_float64(self) raises -> Float64:
        """
        Convert to Float64 for calculations.

        Warning: This may lose precision for very large or very precise numbers.
        Use only when floating point precision is acceptable.

        Returns:
            Float64 approximation

        Raises:
            Error if conversion fails
        """
        return atof(self.value_str)

    fn to_int(self) raises -> Int:
        """
        Convert to Int (truncates decimal part).

        Returns:
            Integer part only

        Raises:
            Error if conversion fails or value is too large
        """
        # Find decimal point
        var decimal_pos = -1
        for i in range(len(self.value_str)):
            if self.value_str[i] == '.':
                decimal_pos = i
                break

        # Extract integer part
        var int_part: String
        if decimal_pos >= 0:
            int_part = String("")
            for i in range(decimal_pos):
                int_part += self.value_str[i]
        else:
            int_part = self.value_str

        return atol(int_part)

    fn equals(self, other: Numeric) -> Bool:
        """Check if two NUMERIC values are equal."""
        # Simple string comparison (works for normalized values)
        return self.value_str == other.value_str

    fn less_than(self, other: Numeric) raises -> Bool:
        """
        Check if this NUMERIC is less than another.

        Note: This uses Float64 comparison, which may have precision limits.
        For exact comparison, use string-based decimal comparison.
        """
        var self_float = self.to_float64()
        var other_float = other.to_float64()
        return self_float < other_float


fn decode_numeric(value: String) raises -> Numeric:
    """
    Decode PostgreSQL NUMERIC from text format.

    NUMERIC supports arbitrary precision and scale:
    - Precision: total number of digits
    - Scale: number of digits after decimal point

    PostgreSQL sends NUMERIC in text format like:
    - "123.45"
    - "-999.999"
    - "0.00000001"
    - "99999999999999999999.99"

    Args:
        value: Text representation of numeric value

    Returns:
        Numeric struct preserving exact precision

    Raises:
        Error if value is not a valid numeric format

    Examples:
        decode_numeric("123.45") → Numeric("123.45")
        decode_numeric("-0.01") → Numeric("-0.01")
    """
    if len(value) == 0:
        raise Error("Cannot decode empty string as NUMERIC")

    # Validate format: [+-]?[0-9]+(\.[0-9]+)?
    var has_digit = False
    var has_decimal = False
    var decimal_count = 0

    for i in range(len(value)):
        var c = value[i]

        if c == '+' or c == '-':
            # Sign must be at start
            if i != 0:
                raise Error("Invalid NUMERIC: sign not at start")
        elif c == '.':
            # Only one decimal point allowed
            if has_decimal:
                raise Error("Invalid NUMERIC: multiple decimal points")
            has_decimal = True
            decimal_count += 1
        elif ord(c) >= ord('0') and ord(c) <= ord('9'):
            has_digit = True
        else:
            raise Error("Invalid NUMERIC: invalid character '" + c + "'")

    if not has_digit:
        raise Error("Invalid NUMERIC: no digits found")

    # Return as-is (preserve exact representation from PostgreSQL)
    return Numeric(value)


# ============================================================================
# JSONB Type
# ============================================================================

@value
struct JsonArray:
    """JSON array value."""
    var items: List[String]  # Store items as strings for simplicity

    fn length(self) -> Int:
        """Return number of items in array."""
        return len(self.items)

    fn get_string(self, index: Int) -> String:
        """Get array item as string."""
        return self.items[index]


@value
struct JsonValue:
    """
    PostgreSQL JSONB value.

    Represents a JSON object with key-value pairs.
    This is a simplified implementation that stores the JSON as a string
    and provides methods to access values.

    For production use, consider using a full JSON parser library.
    """
    var json_str: String

    fn to_string(self) -> String:
        """Return JSON string representation."""
        return self.json_str

    fn has_key(self, key: String) -> Bool:
        """Check if JSON object has a key."""
        var search = '"' + key + '":'
        return self.json_str.find(search) >= 0

    fn get_string(self, key: String) raises -> String:
        """
        Get string value for key.

        This is a simplified implementation that extracts values using
        basic string parsing. For production, use a proper JSON parser.
        """
        var search = '"' + key + '": "'
        var start_pos = self.json_str.find(search)

        if start_pos < 0:
            raise Error("Key not found: " + key)

        # Find start of value (after ": ")
        var value_start = start_pos + len(search)

        # Find end of string (next ")
        var value_end = value_start
        while value_end < len(self.json_str):
            if self.json_str[value_end] == '"':
                # Check if it's escaped
                if value_end > 0 and self.json_str[value_end - 1] == '\\':
                    value_end += 1
                    continue
                break
            value_end += 1

        # Extract value
        var result = String("")
        for i in range(value_start, value_end):
            result += self.json_str[i]

        return result

    fn get_int(self, key: String) raises -> Int:
        """Get integer value for key."""
        var search = '"' + key + '": '
        var start_pos = self.json_str.find(search)

        if start_pos < 0:
            raise Error("Key not found: " + key)

        var value_start = start_pos + len(search)

        # Find end of number (comma, brace, or end)
        var value_end = value_start
        while value_end < len(self.json_str):
            var c = self.json_str[value_end]
            if c == ',' or c == '}' or c == ' ' or c == '\n':
                break
            value_end += 1

        # Extract value
        var num_str = String("")
        for i in range(value_start, value_end):
            num_str += self.json_str[i]

        return atol(num_str)

    fn get_float(self, key: String) raises -> Float64:
        """Get float value for key."""
        var search = '"' + key + '": '
        var start_pos = self.json_str.find(search)

        if start_pos < 0:
            raise Error("Key not found: " + key)

        var value_start = start_pos + len(search)

        # Find end of number
        var value_end = value_start
        while value_end < len(self.json_str):
            var c = self.json_str[value_end]
            if c == ',' or c == '}' or c == ' ' or c == '\n':
                break
            value_end += 1

        # Extract value
        var num_str = String("")
        for i in range(value_start, value_end):
            num_str += self.json_str[i]

        return atof(num_str)

    fn get_bool(self, key: String) raises -> Bool:
        """Get boolean value for key."""
        var search_true = '"' + key + '": true'
        var search_false = '"' + key + '": false'

        if self.json_str.find(search_true) >= 0:
            return True
        elif self.json_str.find(search_false) >= 0:
            return False
        else:
            raise Error("Boolean key not found: " + key)

    fn is_null(self, key: String) -> Bool:
        """Check if value is null."""
        var search = '"' + key + '": null'
        return self.json_str.find(search) >= 0

    fn get_object(self, key: String) raises -> JsonValue:
        """Get nested object value for key."""
        var search = '"' + key + '": {'
        var start_pos = self.json_str.find(search)

        if start_pos < 0:
            raise Error("Object key not found: " + key)

        # Find matching closing brace
        var brace_start = start_pos + len(search) - 1
        var depth = 1
        var brace_end = brace_start + 1

        while brace_end < len(self.json_str) and depth > 0:
            if self.json_str[brace_end] == '{':
                depth += 1
            elif self.json_str[brace_end] == '}':
                depth -= 1
            brace_end += 1

        # Extract nested object
        var nested_json = String("")
        for i in range(brace_start, brace_end):
            nested_json += self.json_str[i]

        return JsonValue(nested_json)

    fn get_array(self, key: String) raises -> JsonArray:
        """Get array value for key."""
        var search = '"' + key + '": ['
        var start_pos = self.json_str.find(search)

        if start_pos < 0:
            raise Error("Array key not found: " + key)

        # Find matching closing bracket
        var bracket_start = start_pos + len(search) - 1
        var depth = 1
        var bracket_end = bracket_start + 1

        while bracket_end < len(self.json_str) and depth > 0:
            if self.json_str[bracket_end] == '[':
                depth += 1
            elif self.json_str[bracket_end] == ']':
                depth -= 1
            bracket_end += 1

        # Extract array contents (simplified: split by comma)
        var array_str = String("")
        for i in range(bracket_start + 1, bracket_end - 1):
            array_str += self.json_str[i]

        # Parse array items (simplified)
        var items = List[String]()
        var current_item = String("")
        var in_string = False

        for i in range(len(array_str)):
            var c = array_str[i]

            if c == '"':
                in_string = not in_string
            elif c == ',' and not in_string:
                # End of item
                var trimmed = current_item.strip()
                if len(trimmed) > 0:
                    # Remove quotes if present
                    if trimmed[0] == '"':
                        var unquoted = String("")
                        for j in range(1, len(trimmed) - 1):
                            unquoted += trimmed[j]
                        items.append(unquoted)
                    else:
                        items.append(trimmed)
                current_item = String("")
                continue

            current_item += c

        # Add last item
        var trimmed = current_item.strip()
        if len(trimmed) > 0:
            if trimmed[0] == '"':
                var unquoted = String("")
                for j in range(1, len(trimmed) - 1):
                    unquoted += trimmed[j]
                items.append(unquoted)
            else:
                items.append(trimmed)

        return JsonArray(items)


fn decode_jsonb(value: String) raises -> JsonValue:
    """
    Decode PostgreSQL JSONB from text format.

    JSONB is PostgreSQL's binary JSON storage format.
    When transmitted in text format, it's regular JSON.

    This is a simplified JSON parser for basic use cases.
    For production, consider using a full-featured JSON library.

    Args:
        value: JSON string from PostgreSQL

    Returns:
        JsonValue object for accessing fields

    Raises:
        Error if JSON is invalid

    Examples:
        decode_jsonb('{"name": "Alice"}')
        decode_jsonb('{"balance": 123.45, "active": true}')
    """
    if len(value) == 0:
        raise Error("Cannot decode empty string as JSONB")

    # Basic validation: should start with { or [
    var first_char = value[0]
    if first_char != '{' and first_char != '[':
        raise Error("Invalid JSONB: must start with { or [")

    return JsonValue(value)


# ============================================================================
# Type Name Mapping
# ============================================================================

fn get_numeric_jsonb_type_name(type_oid: Int) -> String:
    """
    Get human-readable name for numeric/jsonb type OID.

    PostgreSQL type OIDs:
    - 1700: NUMERIC
    - 3802: JSONB

    Args:
        type_oid: PostgreSQL type OID

    Returns:
        Type name string
    """
    if type_oid == 1700:
        return "NUMERIC"
    elif type_oid == 3802:
        return "JSONB"
    else:
        return "UNKNOWN_TYPE(" + String(type_oid) + ")"
