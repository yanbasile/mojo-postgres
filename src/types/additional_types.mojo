"""
PostgreSQL Additional Type Parsers and Structures.

Provides support for advanced PostgreSQL types:
- UUID (Universally Unique Identifier)
- INET/CIDR (IP addresses and networks)
- INTERVAL (time intervals)

Type Formats:
- UUID: 550e8400-e29b-41d4-a716-446655440000
- INET: 192.168.1.5 or 192.168.1.5/24
- CIDR: 192.168.1.0/24
- INTERVAL: '1 day', '2 months 3 days', '01:02:03'

Usage:
    from src.types.additional_types import parse_uuid, parse_inet, parse_interval

    var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
    var ip = parse_inet("192.168.1.5/24")
    var interval = parse_interval("2 days 3 hours")
"""

from collections import List


# ============================================================================
# UUID Type
# ============================================================================

@value
struct UUID:
    """
    PostgreSQL UUID (Universally Unique Identifier).

    Format: 550e8400-e29b-41d4-a716-446655440000

    Attributes:
        value: String representation of UUID

    Example:
        var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
        print(uuid.to_string())  # 550e8400-e29b-41d4-a716-446655440000
    """
    var value: String

    fn to_string(self) -> String:
        """Convert UUID to string."""
        return self.value

    fn to_canonical(self) -> String:
        """Convert to canonical lowercase format."""
        return self.value.lower()

    fn is_nil(self) -> Bool:
        """Check if UUID is nil (all zeros)."""
        return self.value == "00000000-0000-0000-0000-000000000000"


fn parse_uuid(text: String) raises -> UUID:
    """
    Parse PostgreSQL UUID from text format.

    Args:
        text: UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000")

    Returns:
        UUID struct

    Raises:
        Error if format is invalid

    Example:
        var uuid = parse_uuid("550e8400-e29b-41d4-a716-446655440000")
    """
    var trimmed = text.strip()

    # Validate format: 8-4-4-4-12 hex digits with hyphens
    if len(trimmed) != 36:
        raise Error("Invalid UUID length: " + String(len(trimmed)) + ", expected 36")

    if trimmed[8] != ord('-') or trimmed[13] != ord('-') or trimmed[18] != ord('-') or trimmed[23] != ord('-'):
        raise Error("Invalid UUID format: missing hyphens")

    return UUID(trimmed)


fn build_uuid_literal(uuid: UUID) -> String:
    """
    Build UUID literal for SQL queries.

    Args:
        uuid: UUID to convert

    Returns:
        SQL literal string

    Example:
        var literal = build_uuid_literal(uuid)  # Returns: '550e8400-e29b-41d4-a716-446655440000'::UUID
    """
    return "'" + uuid.value + "'::UUID"


fn generate_uuid_v4_sql() -> String:
    """
    Generate SQL for creating a new UUIDv4.

    Returns:
        SQL expression: gen_random_uuid()

    Note:
        Requires pgcrypto extension or PostgreSQL 13+

    Example:
        var sql = "INSERT INTO users (id, name) VALUES (" + generate_uuid_v4_sql() + ", 'John')"
    """
    return "gen_random_uuid()"


# ============================================================================
# INET Type (IP Address with optional netmask)
# ============================================================================

@value
struct INET:
    """
    PostgreSQL INET (IP address with optional network mask).

    Format: 192.168.1.5 or 192.168.1.5/24

    Attributes:
        address: IP address string
        netmask: Network mask bits (0-32 for IPv4, 0-128 for IPv6)
        has_netmask: Whether netmask was specified

    Example:
        var ip = parse_inet("192.168.1.5/24")
        print(ip.to_string())  # 192.168.1.5/24
        print(ip.address)      # 192.168.1.5
        print(ip.netmask)      # 24
    """
    var address: String
    var netmask: Int32
    var has_netmask: Bool

    fn to_string(self) -> String:
        """Convert INET to string."""
        if self.has_netmask:
            return self.address + "/" + String(self.netmask)
        return self.address

    fn is_ipv4(self) -> Bool:
        """Check if address is IPv4."""
        # Simple check: IPv4 contains dots, IPv6 contains colons
        return "." in self.address

    fn is_ipv6(self) -> Bool:
        """Check if address is IPv6."""
        return ":" in self.address


fn parse_inet(text: String) raises -> INET:
    """
    Parse PostgreSQL INET from text format.

    Args:
        text: INET string (e.g., "192.168.1.5/24" or "192.168.1.5")

    Returns:
        INET struct

    Example:
        var ip1 = parse_inet("192.168.1.5/24")
        var ip2 = parse_inet("192.168.1.5")
        var ip3 = parse_inet("2001:db8::1/64")
    """
    var trimmed = text.strip()

    # Check for netmask
    if "/" in trimmed:
        var parts = trimmed.split("/")
        if len(parts) != 2:
            raise Error("Invalid INET format: multiple slashes")

        var address = parts[0]
        var netmask_str = parts[1]

        try:
            var netmask = atol(netmask_str)
            return INET(address, Int32(netmask), True)
        except:
            raise Error("Invalid netmask: " + netmask_str)
    else:
        # No netmask specified
        return INET(trimmed, 0, False)


fn build_inet_literal(inet: INET) -> String:
    """
    Build INET literal for SQL queries.

    Args:
        inet: INET to convert

    Returns:
        SQL literal string

    Example:
        var literal = build_inet_literal(inet)  # Returns: '192.168.1.5/24'::INET
    """
    return "'" + inet.to_string() + "'::INET"


# ============================================================================
# CIDR Type (Network address)
# ============================================================================

@value
struct CIDR:
    """
    PostgreSQL CIDR (network address).

    Format: 192.168.1.0/24

    Similar to INET but represents a network rather than a host.

    Attributes:
        network: Network address
        netmask: Network mask bits

    Example:
        var net = parse_cidr("192.168.1.0/24")
        print(net.to_string())  # 192.168.1.0/24
    """
    var network: String
    var netmask: Int32

    fn to_string(self) -> String:
        """Convert CIDR to string."""
        return self.network + "/" + String(self.netmask)


fn parse_cidr(text: String) raises -> CIDR:
    """
    Parse PostgreSQL CIDR from text format.

    Args:
        text: CIDR string (e.g., "192.168.1.0/24")

    Returns:
        CIDR struct

    Example:
        var net = parse_cidr("192.168.1.0/24")
    """
    var trimmed = text.strip()

    if "/" not in trimmed:
        raise Error("CIDR requires netmask")

    var parts = trimmed.split("/")
    if len(parts) != 2:
        raise Error("Invalid CIDR format")

    var network = parts[0]
    var netmask_str = parts[1]

    try:
        var netmask = atol(netmask_str)
        return CIDR(network, Int32(netmask))
    except:
        raise Error("Invalid netmask: " + netmask_str)


fn build_cidr_literal(cidr: CIDR) -> String:
    """
    Build CIDR literal for SQL queries.

    Args:
        cidr: CIDR to convert

    Returns:
        SQL literal string

    Example:
        var literal = build_cidr_literal(cidr)  # Returns: '192.168.1.0/24'::CIDR
    """
    return "'" + cidr.to_string() + "'::CIDR"


# ============================================================================
# INTERVAL Type
# ============================================================================

@value
struct INTERVAL:
    """
    PostgreSQL INTERVAL (time interval).

    Formats:
        - '1 day'
        - '2 months 3 days'
        - '3 years 4 months 5 days'
        - '01:02:03' (hours:minutes:seconds)
        - '1 day 02:30:45'

    Attributes:
        years: Number of years
        months: Number of months
        days: Number of days
        hours: Number of hours
        minutes: Number of minutes
        seconds: Number of seconds (can be fractional)

    Example:
        var interval = parse_interval("2 days 3 hours")
        print(interval.to_string())
        print(interval.to_total_seconds())
    """
    var years: Int32
    var months: Int32
    var days: Int32
    var hours: Int32
    var minutes: Int32
    var seconds: Float64

    fn to_string(self) -> String:
        """Convert INTERVAL to PostgreSQL string format."""
        var result = String("")
        var parts = List[String]()

        if self.years != 0:
            parts.append(String(self.years) + " year" + ("s" if self.years != 1 else ""))
        if self.months != 0:
            parts.append(String(self.months) + " mon" + ("s" if self.months != 1 else ""))
        if self.days != 0:
            parts.append(String(self.days) + " day" + ("s" if self.days != 1 else ""))

        # Handle time components
        if self.hours != 0 or self.minutes != 0 or self.seconds != 0.0:
            var time_str = String("")
            if self.hours < 10:
                time_str += "0"
            time_str += String(self.hours) + ":"

            if self.minutes < 10:
                time_str += "0"
            time_str += String(self.minutes) + ":"

            if self.seconds < 10.0:
                time_str += "0"
            time_str += String(self.seconds)

            parts.append(time_str)

        if len(parts) == 0:
            return "00:00:00"

        result = parts[0]
        for i in range(1, len(parts)):
            result += " " + parts[i]

        return result

    fn to_total_seconds(self) -> Float64:
        """
        Convert interval to total seconds (approximate).

        Note: Uses 30 days per month, 365 days per year.
        """
        var total: Float64 = 0.0
        total += Float64(self.years) * 365.0 * 24.0 * 3600.0
        total += Float64(self.months) * 30.0 * 24.0 * 3600.0
        total += Float64(self.days) * 24.0 * 3600.0
        total += Float64(self.hours) * 3600.0
        total += Float64(self.minutes) * 60.0
        total += self.seconds
        return total

    fn to_total_days(self) -> Float64:
        """Convert interval to total days (approximate)."""
        return self.to_total_seconds() / (24.0 * 3600.0)


fn parse_interval(text: String) raises -> INTERVAL:
    """
    Parse PostgreSQL INTERVAL from text format.

    Args:
        text: INTERVAL string (various formats)

    Returns:
        INTERVAL struct

    Examples:
        var i1 = parse_interval("1 day")
        var i2 = parse_interval("2 mons 3 days")
        var i3 = parse_interval("01:02:03")
        var i4 = parse_interval("1 day 02:30:00")
    """
    var trimmed = text.strip()

    var years: Int32 = 0
    var months: Int32 = 0
    var days: Int32 = 0
    var hours: Int32 = 0
    var minutes: Int32 = 0
    var seconds: Float64 = 0.0

    # Split into tokens
    var tokens = trimmed.split(" ")

    var i = 0
    while i < len(tokens):
        var token = tokens[i].strip()

        if token == "":
            i += 1
            continue

        # Check if token is a time component (HH:MM:SS)
        if ":" in token:
            var time_parts = token.split(":")
            if len(time_parts) >= 2:
                try:
                    hours = Int32(atol(time_parts[0]))
                    minutes = Int32(atol(time_parts[1]))
                    if len(time_parts) >= 3:
                        seconds = atof(time_parts[2])
                except:
                    pass
            i += 1
            continue

        # Try to parse as number
        try:
            var value = atol(token)

            # Check next token for unit
            if i + 1 < len(tokens):
                var unit = tokens[i + 1].strip().lower()

                if unit.startswith("year"):
                    years = Int32(value)
                    i += 2
                    continue
                elif unit.startswith("mon"):
                    months = Int32(value)
                    i += 2
                    continue
                elif unit.startswith("day"):
                    days = Int32(value)
                    i += 2
                    continue
                elif unit.startswith("hour") or unit == "h":
                    hours = Int32(value)
                    i += 2
                    continue
                elif unit.startswith("min") or unit == "m":
                    minutes = Int32(value)
                    i += 2
                    continue
                elif unit.startswith("sec") or unit == "s":
                    seconds = Float64(value)
                    i += 2
                    continue
        except:
            pass

        i += 1

    return INTERVAL(years, months, days, hours, minutes, seconds)


fn build_interval_literal(interval: INTERVAL) -> String:
    """
    Build INTERVAL literal for SQL queries.

    Args:
        interval: INTERVAL to convert

    Returns:
        SQL literal string

    Example:
        var literal = build_interval_literal(interval)  # Returns: '2 days 3 hours'::INTERVAL
    """
    return "'" + interval.to_string() + "'::INTERVAL"


# ============================================================================
# Helper Functions
# ============================================================================

fn validate_uuid(text: String) -> Bool:
    """
    Validate UUID format without raising errors.

    Args:
        text: String to validate

    Returns:
        True if valid UUID format, False otherwise

    Example:
        if validate_uuid("550e8400-e29b-41d4-a716-446655440000"):
            print("Valid UUID")
    """
    var trimmed = text.strip()

    if len(trimmed) != 36:
        return False

    if trimmed[8] != ord('-') or trimmed[13] != ord('-') or trimmed[18] != ord('-') or trimmed[23] != ord('-'):
        return False

    return True


fn validate_ipv4(address: String) -> Bool:
    """
    Validate IPv4 address format.

    Args:
        address: String to validate

    Returns:
        True if valid IPv4, False otherwise

    Example:
        if validate_ipv4("192.168.1.1"):
            print("Valid IPv4")
    """
    var parts = address.split(".")
    if len(parts) != 4:
        return False

    for i in range(len(parts)):
        try:
            var num = atol(parts[i])
            if num < 0 or num > 255:
                return False
        except:
            return False

    return True
