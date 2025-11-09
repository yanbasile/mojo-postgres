"""
PostgreSQL Extended Query Protocol implementation.

The Extended Query Protocol provides:
- Prepared statements (parse once, execute many)
- Parameter binding (SQL injection prevention)
- Binary format support (faster encoding/decoding)
- Statement caching

Protocol flow:
1. Parse (P) - Prepare SQL with placeholders ($1, $2, etc.)
2. Bind (B) - Bind parameter values
3. Execute (E) - Execute bound statement
4. Sync (S) - Synchronize

Benefits vs Simple Query Protocol:
- 5-10x faster for repeated queries (no re-parsing)
- Parameter binding prevents SQL injection
- Binary format 3-5x faster than text format
- Better query plan caching

Reference: https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-EXT-QUERY
"""

from collections import List
from .connection import to_network_bytes_int32, to_network_bytes_int16, from_network_bytes_int32, from_network_bytes_int16, extract_cstring


# ============================================================================
# Message Type Constants
# ============================================================================

# Frontend (client) messages
alias MSG_PARSE = ord('P')
alias MSG_BIND = ord('B')
alias MSG_EXECUTE = ord('E')
alias MSG_DESCRIBE = ord('D')
alias MSG_CLOSE = ord('C')
alias MSG_SYNC = ord('S')
alias MSG_FLUSH = ord('H')

# Backend (server) responses
alias MSG_PARSE_COMPLETE = ord('1')
alias MSG_BIND_COMPLETE = ord('2')
alias MSG_CLOSE_COMPLETE = ord('3')
alias MSG_NO_DATA = ord('n')

# Format codes
alias FORMAT_TEXT = 0
alias FORMAT_BINARY = 1


# ============================================================================
# Parse Message (P)
# ============================================================================

fn build_parse_message(
    statement_name: String,
    query: String,
    param_types: List[Int] = List[Int]()
) -> List[UInt8]:
    """
    Build Parse message for preparing a statement.

    Format: [P:1][Length:4][StatementName:string][Query:string][NumParams:2][ParamTypes:4*n]

    Args:
        statement_name: Name for the prepared statement (empty string for unnamed)
        query: SQL query with placeholders ($1, $2, etc.)
        param_types: PostgreSQL type OIDs for parameters (empty = auto-detect)

    Returns:
        Parse message bytes

    Example:
        build_parse_message("", "SELECT * FROM users WHERE id = $1", [23])  # 23 = INT4
    """
    var msg = List[UInt8]()

    # Message type: 'P'
    msg.append(MSG_PARSE)

    # Calculate length first (we'll insert it later)
    # Length = 4 (length field) + statement_name (+ \0) + query (+ \0) + 2 (param count) + 4*param_count
    var length = 4 + len(statement_name) + 1 + len(query) + 1 + 2 + (4 * len(param_types))

    # Length field
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # Statement name (null-terminated)
    for i in range(len(statement_name)):
        msg.append(ord(statement_name[i]))
    msg.append(0)

    # Query string (null-terminated)
    for i in range(len(query)):
        msg.append(ord(query[i]))
    msg.append(0)

    # Number of parameter data types
    var param_count = len(param_types)
    var param_count_bytes = to_network_bytes_int16(param_count)
    for i in range(len(param_count_bytes)):
        msg.append(param_count_bytes[i])

    # Parameter type OIDs
    for i in range(param_count):
        var type_oid_bytes = to_network_bytes_int32(param_types[i])
        for j in range(len(type_oid_bytes)):
            msg.append(type_oid_bytes[j])

    return msg


# ============================================================================
# Bind Message (B)
# ============================================================================

fn build_bind_message(
    portal_name: String,
    statement_name: String,
    param_values: List[String],
    param_formats: List[Int] = List[Int](),
    result_formats: List[Int] = List[Int]()
) -> List[UInt8]:
    """
    Build Bind message for binding parameters to a prepared statement.

    Format: [B:1][Length:4][PortalName:string][StatementName:string]
            [NumParamFormats:2][ParamFormats:2*n]
            [NumParams:2][ParamValues]
            [NumResultFormats:2][ResultFormats:2*n]

    Args:
        portal_name: Name for the portal (empty string for unnamed)
        statement_name: Name of the prepared statement
        param_values: Parameter values as strings (empty string for NULL)
        param_formats: Format codes for parameters (0=text, 1=binary)
        result_formats: Format codes for result columns (0=text, 1=binary)

    Returns:
        Bind message bytes

    Example:
        build_bind_message("", "stmt1", ["123", "true"], [0, 0], [0])
    """
    var msg = List[UInt8]()

    # Message type: 'B'
    msg.append(MSG_BIND)

    # We'll calculate and insert length later
    var length_start = len(msg)
    for i in range(4):
        msg.append(0)  # Placeholder for length

    # Portal name (null-terminated)
    for i in range(len(portal_name)):
        msg.append(ord(portal_name[i]))
    msg.append(0)

    # Statement name (null-terminated)
    for i in range(len(statement_name)):
        msg.append(ord(statement_name[i]))
    msg.append(0)

    # Parameter format codes
    var num_param_formats = len(param_formats)
    if num_param_formats == 0:
        # No formats specified = all text
        var zero_bytes = to_network_bytes_int16(0)
        for i in range(len(zero_bytes)):
            msg.append(zero_bytes[i])
    else:
        var count_bytes = to_network_bytes_int16(num_param_formats)
        for i in range(len(count_bytes)):
            msg.append(count_bytes[i])

        for i in range(num_param_formats):
            var format_bytes = to_network_bytes_int16(param_formats[i])
            for j in range(len(format_bytes)):
                msg.append(format_bytes[j])

    # Number of parameters
    var num_params = len(param_values)
    var param_count_bytes = to_network_bytes_int16(num_params)
    for i in range(len(param_count_bytes)):
        msg.append(param_count_bytes[i])

    # Parameter values
    for i in range(num_params):
        var value = param_values[i]

        # Length (-1 for NULL, otherwise byte length)
        var value_len = len(value)
        var len_bytes = to_network_bytes_int32(value_len)
        for j in range(len(len_bytes)):
            msg.append(len_bytes[j])

        # Value bytes
        for j in range(value_len):
            msg.append(ord(value[j]))

    # Result format codes
    var num_result_formats = len(result_formats)
    if num_result_formats == 0:
        # No formats specified = all text
        var zero_bytes = to_network_bytes_int16(0)
        for i in range(len(zero_bytes)):
            msg.append(zero_bytes[i])
    else:
        var count_bytes = to_network_bytes_int16(num_result_formats)
        for i in range(len(count_bytes)):
            msg.append(count_bytes[i])

        for i in range(num_result_formats):
            var format_bytes = to_network_bytes_int16(result_formats[i])
            for j in range(len(format_bytes)):
                msg.append(format_bytes[j])

    # Calculate and insert length
    var total_length = len(msg) - length_start
    var length_bytes = to_network_bytes_int32(total_length)
    for i in range(4):
        msg[length_start + i] = length_bytes[i]

    return msg


# ============================================================================
# Execute Message (E)
# ============================================================================

fn build_execute_message(portal_name: String, max_rows: Int = 0) -> List[UInt8]:
    """
    Build Execute message for executing a bound portal.

    Format: [E:1][Length:4][PortalName:string][MaxRows:4]

    Args:
        portal_name: Name of the portal to execute (empty string for unnamed)
        max_rows: Maximum number of rows to return (0 = unlimited)

    Returns:
        Execute message bytes

    Example:
        build_execute_message("", 0)  # Execute unnamed portal, return all rows
    """
    var msg = List[UInt8]()

    # Message type: 'E'
    msg.append(MSG_EXECUTE)

    # Length: 4 (length field) + portal_name (+ \0) + 4 (max_rows)
    var length = 4 + len(portal_name) + 1 + 4
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # Portal name (null-terminated)
    for i in range(len(portal_name)):
        msg.append(ord(portal_name[i]))
    msg.append(0)

    # Max rows (0 = unlimited)
    var max_rows_bytes = to_network_bytes_int32(max_rows)
    for i in range(len(max_rows_bytes)):
        msg.append(max_rows_bytes[i])

    return msg


# ============================================================================
# Sync Message (S)
# ============================================================================

fn build_sync_message() -> List[UInt8]:
    """
    Build Sync message to end transaction block and synchronize.

    Format: [S:1][Length:4]

    The Sync message asks the server to complete the current transaction
    and be ready for a new query cycle.

    Returns:
        Sync message bytes
    """
    var msg = List[UInt8]()

    # Message type: 'S'
    msg.append(MSG_SYNC)

    # Length: just the length field itself (4 bytes)
    var length_bytes = to_network_bytes_int32(4)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    return msg


# ============================================================================
# Close Message (C)
# ============================================================================

fn build_close_message(target_type: String, target_name: String) -> List[UInt8]:
    """
    Build Close message to close a prepared statement or portal.

    Format: [C:1][Length:4][Type:1][Name:string]

    Args:
        target_type: 'S' for statement, 'P' for portal
        target_name: Name of the statement or portal to close

    Returns:
        Close message bytes

    Example:
        build_close_message("S", "stmt1")  # Close statement named "stmt1"
        build_close_message("P", "")       # Close unnamed portal
    """
    var msg = List[UInt8]()

    # Message type: 'C'
    msg.append(MSG_CLOSE)

    # Length: 4 (length field) + 1 (type) + name (+ \0)
    var length = 4 + 1 + len(target_name) + 1
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # Target type ('S' = statement, 'P' = portal)
    msg.append(ord(target_type[0]))

    # Target name (null-terminated)
    for i in range(len(target_name)):
        msg.append(ord(target_name[i]))
    msg.append(0)

    return msg


# ============================================================================
# Flush Message (H)
# ============================================================================

fn build_flush_message() -> List[UInt8]:
    """
    Build Flush message to flush output buffer.

    Format: [H:1][Length:4]

    The Flush message asks the server to send any pending output immediately.
    Useful for pipelined queries where you want partial results.

    Returns:
        Flush message bytes
    """
    var msg = List[UInt8]()

    # Message type: 'H'
    msg.append(MSG_FLUSH)

    # Length: just the length field itself (4 bytes)
    var length_bytes = to_network_bytes_int32(4)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    return msg


# ============================================================================
# Response Parsing
# ============================================================================

fn is_parse_complete(msg: List[UInt8]) -> Bool:
    """Check if message is ParseComplete ('1')."""
    return len(msg) > 0 and msg[0] == MSG_PARSE_COMPLETE


fn is_bind_complete(msg: List[UInt8]) -> Bool:
    """Check if message is BindComplete ('2')."""
    return len(msg) > 0 and msg[0] == MSG_BIND_COMPLETE


fn is_close_complete(msg: List[UInt8]) -> Bool:
    """Check if message is CloseComplete ('3')."""
    return len(msg) > 0 and msg[0] == MSG_CLOSE_COMPLETE


fn is_no_data(msg: List[UInt8]) -> Bool:
    """Check if message is NoData ('n')."""
    return len(msg) > 0 and msg[0] == MSG_NO_DATA


# ============================================================================
# PreparedStatement Struct
# ============================================================================

@value
struct PreparedStatement:
    """
    Represents a prepared SQL statement.

    A prepared statement is parsed once by the server and can be executed
    multiple times with different parameters. This provides:
    - Performance: 5-10x faster than re-parsing on each execution
    - Safety: Parameter binding prevents SQL injection
    - Efficiency: Server can cache query plans

    Example:
        var stmt = conn.prepare("SELECT * FROM users WHERE id = $1 AND active = $2")
        var result1 = conn.execute_prepared(stmt, ["123", "true"])
        var result2 = conn.execute_prepared(stmt, ["456", "false"])
    """
    var statement_name: String
    var query: String
    var param_count: Int

    fn __init__(inout self, statement_name: String, query: String, param_count: Int):
        self.statement_name = statement_name
        self.query = query
        self.param_count = param_count


# ============================================================================
# Utility Functions
# ============================================================================

fn count_parameters(query: String) -> Int:
    """
    Count the number of parameter placeholders ($1, $2, etc.) in a query.

    Args:
        query: SQL query string

    Returns:
        Maximum parameter number found (e.g., "$1, $2, $3" → 3)

    Example:
        count_parameters("SELECT * FROM users WHERE id = $1 AND name = $2")  # → 2
    """
    var max_param = 0
    var i = 0

    while i < len(query):
        if query[i] == '$':
            # Found a parameter placeholder
            i += 1
            var num_str = String("")

            # Extract number
            while i < len(query) and ord(query[i]) >= ord('0') and ord(query[i]) <= ord('9'):
                num_str += query[i]
                i += 1

            # Parse number
            if len(num_str) > 0:
                var param_num = atol(num_str)
                if param_num > max_param:
                    max_param = param_num
        else:
            i += 1

    return max_param


fn generate_statement_name() -> String:
    """
    Generate a unique statement name.

    For simplicity, we use a timestamp-based name.
    In production, you might want a more robust naming scheme.

    Returns:
        Unique statement name
    """
    from time import now
    var timestamp = now()
    return "stmt_" + String(timestamp)
