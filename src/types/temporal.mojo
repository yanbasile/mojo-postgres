"""
PostgreSQL temporal type decoders.

Supports:
- TIMESTAMP (date and time without timezone)
- TIMESTAMPTZ (date and time with timezone)
- DATE (date only)
- TIME (time only)
- INTERVAL (duration)

PostgreSQL temporal format:
- TIMESTAMP: "2024-01-15 10:30:45.123456"
- TIMESTAMPTZ: "2024-01-15 10:30:45.123456+00"
- DATE: "2024-01-15"
- TIME: "10:30:45.123456"
- INTERVAL: "1 day 02:30:45"

Reference:
https://www.postgresql.org/docs/current/datatype-datetime.html
"""


# ============================================================================
# Temporal Structures
# ============================================================================

@value
struct Timestamp:
    """
    Represents a PostgreSQL TIMESTAMP (without timezone).
    
    Stores: year, month, day, hour, minute, second, microsecond
    """
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var microsecond: Int

    fn __init__(inout self, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, microsecond: Int):
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.microsecond = microsecond


@value
struct TimestampTZ:
    """
    Represents a PostgreSQL TIMESTAMPTZ (with timezone).
    
    Stores: year, month, day, hour, minute, second, microsecond, timezone_offset_seconds
    
    Timezone offset is in seconds (e.g., +05:30 = 19800, -05:00 = -18000)
    """
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var microsecond: Int
    var timezone_offset_seconds: Int

    fn __init__(inout self, year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, microsecond: Int, timezone_offset_seconds: Int):
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.microsecond = microsecond
        self.timezone_offset_seconds = timezone_offset_seconds


@value
struct Date:
    """
    Represents a PostgreSQL DATE.
    
    Stores: year, month, day
    """
    var year: Int
    var month: Int
    var day: Int

    fn __init__(inout self, year: Int, month: Int, day: Int):
        self.year = year
        self.month = month
        self.day = day


@value
struct Time:
    """
    Represents a PostgreSQL TIME (without timezone).
    
    Stores: hour, minute, second, microsecond
    """
    var hour: Int
    var minute: Int
    var second: Int
    var microsecond: Int

    fn __init__(inout self, hour: Int, minute: Int, second: Int, microsecond: Int):
        self.hour = hour
        self.minute = minute
        self.second = second
        self.microsecond = microsecond


# ============================================================================
# Helper Functions
# ============================================================================

fn is_digit(c: String) -> Bool:
    """Check if character is a digit."""
    if len(c) != 1:
        return False
    var char_code = ord(c)
    return char_code >= ord('0') and char_code <= ord('9')


fn parse_int(s: String) raises -> Int:
    """Parse string to integer."""
    if len(s) == 0:
        raise Error("Cannot parse empty string as integer")
    
    var result = 0
    var is_negative = False
    var start_idx = 0
    
    if s[0] == '-':
        is_negative = True
        start_idx = 1
    elif s[0] == '+':
        start_idx = 1
    
    for i in range(start_idx, len(s)):
        var c = s[i]
        if not is_digit(c):
            raise Error("Invalid character in integer: " + c)
        result = result * 10 + (ord(c) - ord('0'))
    
    if is_negative:
        return -result
    return result


fn parse_microseconds(s: String) raises -> Int:
    """
    Parse fractional seconds to microseconds.
    
    Handles variable precision (1-6 digits after decimal point).
    Examples:
      ".1" → 100000
      ".12" → 120000
      ".123456" → 123456
    """
    if len(s) == 0:
        return 0
    
    var result = 0
    var multiplier = 100000  # Start with 10^5
    
    for i in range(len(s)):
        var c = s[i]
        if not is_digit(c):
            raise Error("Invalid character in microseconds: " + c)
        result += (ord(c) - ord('0')) * multiplier
        multiplier = multiplier // 10
        if multiplier == 0:
            break  # Already have 6 digits
    
    return result


# ============================================================================
# TIMESTAMP Decoder
# ============================================================================

fn decode_timestamp(value: String) raises -> Timestamp:
    """
    Decode PostgreSQL TIMESTAMP from text format.
    
    Format: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD HH:MM:SS.microseconds"
    
    Args:
        value: Text representation (e.g., "2024-01-15 10:30:45.123456")
    
    Returns:
        Timestamp structure
    
    Raises:
        Error if invalid format
    
    Examples:
        decode_timestamp("2024-01-15 10:30:45") → Timestamp(2024, 1, 15, 10, 30, 45, 0)
        decode_timestamp("2024-01-15 10:30:45.123456") → Timestamp(..., 123456)
    """
    # Expected format: "YYYY-MM-DD HH:MM:SS.microseconds"
    # Minimum length: "YYYY-MM-DD HH:MM:SS" = 19 chars
    
    if len(value) < 19:
        raise Error("TIMESTAMP too short: " + value)
    
    # Parse date part (YYYY-MM-DD)
    var year_str = value[0:4]
    var month_str = value[5:7]
    var day_str = value[8:10]
    
    var year = parse_int(year_str)
    var month = parse_int(month_str)
    var day = parse_int(day_str)
    
    # Parse time part (HH:MM:SS)
    var hour_str = value[11:13]
    var minute_str = value[14:16]
    var second_str = value[17:19]
    
    var hour = parse_int(hour_str)
    var minute = parse_int(minute_str)
    var second = parse_int(second_str)
    
    # Parse microseconds if present
    var microsecond = 0
    if len(value) > 19 and value[19] == '.':
        var micro_str = value[20:]
        microsecond = parse_microseconds(micro_str)
    
    return Timestamp(year, month, day, hour, minute, second, microsecond)


# ============================================================================
# TIMESTAMPTZ Decoder
# ============================================================================

fn decode_timestamptz(value: String) raises -> TimestampTZ:
    """
    Decode PostgreSQL TIMESTAMPTZ from text format.
    
    Format: "YYYY-MM-DD HH:MM:SS+TZ" or "YYYY-MM-DD HH:MM:SS.microseconds+TZ"
    Timezone: +HH:MM, +HH, -HH:MM, -HH, or +00 for UTC
    
    Args:
        value: Text representation (e.g., "2024-01-15 10:30:45.123456+00")
    
    Returns:
        TimestampTZ structure
    
    Raises:
        Error if invalid format
    
    Examples:
        decode_timestamptz("2024-01-15 10:30:45+00") → TimestampTZ(..., 0)
        decode_timestamptz("2024-01-15 10:30:45-05") → TimestampTZ(..., -18000)
    """
    # Find timezone separator (+ or -)
    var tz_pos = -1
    var tz_sign = 1
    
    # Scan from right to find timezone
    for i in range(len(value) - 1, 18, -1):  # Start after minimum timestamp
        var c = value[i]
        if c == '+':
            tz_pos = i
            tz_sign = 1
            break
        elif c == '-':
            tz_pos = i
            tz_sign = -1
            break
    
    if tz_pos == -1:
        raise Error("TIMESTAMPTZ missing timezone: " + value)
    
    # Parse timestamp part (before timezone)
    var timestamp_str = value[0:tz_pos]
    var ts = decode_timestamp(timestamp_str)
    
    # Parse timezone part
    var tz_str = value[tz_pos + 1:]
    
    # Parse timezone offset
    var tz_offset_seconds = 0
    
    if ":" in tz_str:
        # Format: HH:MM
        var colon_pos = tz_str.find(":")
        var tz_hours = parse_int(tz_str[0:colon_pos])
        var tz_minutes = parse_int(tz_str[colon_pos + 1:])
        tz_offset_seconds = (tz_hours * 3600 + tz_minutes * 60) * tz_sign
    else:
        # Format: HH
        var tz_hours = parse_int(tz_str)
        tz_offset_seconds = (tz_hours * 3600) * tz_sign
    
    return TimestampTZ(
        ts.year, ts.month, ts.day,
        ts.hour, ts.minute, ts.second, ts.microsecond,
        tz_offset_seconds
    )


# ============================================================================
# DATE Decoder
# ============================================================================

fn decode_date(value: String) raises -> Date:
    """
    Decode PostgreSQL DATE from text format.
    
    Format: "YYYY-MM-DD"
    
    Args:
        value: Text representation (e.g., "2024-01-15")
    
    Returns:
        Date structure
    
    Raises:
        Error if invalid format
    
    Examples:
        decode_date("2024-01-15") → Date(2024, 1, 15)
        decode_date("2024-12-31") → Date(2024, 12, 31)
    """
    if len(value) != 10:
        raise Error("DATE must be 10 characters (YYYY-MM-DD): " + value)
    
    var year_str = value[0:4]
    var month_str = value[5:7]
    var day_str = value[8:10]
    
    var year = parse_int(year_str)
    var month = parse_int(month_str)
    var day = parse_int(day_str)
    
    # Basic validation
    if month < 1 or month > 12:
        raise Error("Invalid month: " + String(month))
    if day < 1 or day > 31:
        raise Error("Invalid day: " + String(day))
    
    return Date(year, month, day)


# ============================================================================
# TIME Decoder
# ============================================================================

fn decode_time(value: String) raises -> Time:
    """
    Decode PostgreSQL TIME from text format.
    
    Format: "HH:MM:SS" or "HH:MM:SS.microseconds"
    
    Args:
        value: Text representation (e.g., "10:30:45.123456")
    
    Returns:
        Time structure
    
    Raises:
        Error if invalid format
    
    Examples:
        decode_time("10:30:45") → Time(10, 30, 45, 0)
        decode_time("10:30:45.123456") → Time(10, 30, 45, 123456)
    """
    # Minimum length: "HH:MM:SS" = 8 chars
    if len(value) < 8:
        raise Error("TIME too short: " + value)
    
    var hour_str = value[0:2]
    var minute_str = value[3:5]
    var second_str = value[6:8]
    
    var hour = parse_int(hour_str)
    var minute = parse_int(minute_str)
    var second = parse_int(second_str)
    
    # Basic validation
    if hour < 0 or hour > 23:
        raise Error("Invalid hour: " + String(hour))
    if minute < 0 or minute > 59:
        raise Error("Invalid minute: " + String(minute))
    if second < 0 or second > 59:
        raise Error("Invalid second: " + String(second))
    
    # Parse microseconds if present
    var microsecond = 0
    if len(value) > 8 and value[8] == '.':
        var micro_str = value[9:]
        microsecond = parse_microseconds(micro_str)
    
    return Time(hour, minute, second, microsecond)


# ============================================================================
# Type Name Mapping
# ============================================================================

fn get_temporal_type_name(type_oid: Int) -> String:
    """
    Get human-readable name for temporal type OID.
    
    PostgreSQL type OIDs:
    - 1082: DATE
    - 1083: TIME
    - 1114: TIMESTAMP
    - 1184: TIMESTAMPTZ
    - 1186: INTERVAL
    
    Args:
        type_oid: PostgreSQL type OID
    
    Returns:
        Type name string
    """
    if type_oid == 1082:
        return "DATE"
    elif type_oid == 1083:
        return "TIME"
    elif type_oid == 1114:
        return "TIMESTAMP"
    elif type_oid == 1184:
        return "TIMESTAMPTZ"
    elif type_oid == 1186:
        return "INTERVAL"
    else:
        return "UNKNOWN_TEMPORAL_TYPE(" + String(type_oid) + ")"
