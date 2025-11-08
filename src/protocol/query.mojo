"""
PostgreSQL Simple Query Protocol implementation.

Implements:
- Query message construction (Q message)
- RowDescription parsing (T message)
- DataRow parsing (D message)
- CommandComplete parsing (C message)
- QueryResult structure for holding results

Reference: https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-SIMPLE-QUERY
"""

from collections import List
from .connection import to_network_bytes_int32, from_network_bytes_int32, from_network_bytes_int16, extract_cstring
from ..types.temporal import Timestamp, TimestampTZ, Date, Time
from ..types.numeric_jsonb import Numeric, JsonValue


# ============================================================================
# Query Message Construction
# ============================================================================

fn build_query_message(query: String) -> List[UInt8]:
    """
    Build Simple Query message.

    Format: [Q:1][Length:4][Query:string][0x00]

    Args:
        query: SQL query string (e.g., "SELECT * FROM users")

    Returns:
        Query message bytes ready to send
    """
    var msg = List[UInt8]()

    # Message type: 'Q'
    msg.append(ord('Q'))

    # Length: 4 (length field) + query length + 1 (null terminator)
    var length = 4 + len(query) + 1
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # Query string
    for i in range(len(query)):
        msg.append(ord(query[i]))

    # Null terminator
    msg.append(0)

    return msg


# ============================================================================
# Field/Column Metadata
# ============================================================================

struct FieldDescription:
    """Description of a result column from RowDescription message."""
    var name: String
    var table_oid: Int
    var column_attr: Int
    var type_oid: Int  # PostgreSQL type OID (23=INT4, 25=TEXT, etc.)
    var type_size: Int  # -1 for variable length
    var type_modifier: Int
    var format_code: Int  # 0=text, 1=binary

    fn __init__(inout self):
        self.name = ""
        self.table_oid = 0
        self.column_attr = 0
        self.type_oid = 0
        self.type_size = 0
        self.type_modifier = 0
        self.format_code = 0

    fn __init__(inout self, name: String, type_oid: Int):
        self.name = name
        self.table_oid = 0
        self.column_attr = 0
        self.type_oid = type_oid
        self.type_size = 0
        self.type_modifier = 0
        self.format_code = 0


struct RowDescription:
    """RowDescription message (T) - describes columns in result set."""
    var field_count: Int
    var fields: List[FieldDescription]

    fn __init__(inout self):
        self.field_count = 0
        self.fields = List[FieldDescription]()


fn parse_row_description(msg: List[UInt8]) raises -> RowDescription:
    """
    Parse RowDescription message.

    Format: [T:1][Length:4][FieldCount:2][Fields...]
    Each field:
      - Name: null-terminated string
      - TableOID: 4 bytes
      - ColumnAttr: 2 bytes
      - TypeOID: 4 bytes
      - TypeSize: 2 bytes (signed)
      - TypeModifier: 4 bytes
      - FormatCode: 2 bytes
    """
    var row_desc = RowDescription()

    # Verify message type
    if msg[0] != ord('T'):
        raise Error("Expected RowDescription message (T), got: " + chr(Int(msg[0])))

    # Skip length (bytes 1-4)
    # Parse field count (bytes 5-6)
    row_desc.field_count = from_network_bytes_int16(msg, 5)

    var offset = 7  # Start of first field

    # Parse each field
    for i in range(row_desc.field_count):
        var field = FieldDescription()

        # Field name (null-terminated string)
        field.name = extract_cstring(msg, offset)
        offset += len(field.name) + 1  # +1 for null terminator

        # Table OID (4 bytes)
        field.table_oid = from_network_bytes_int32(msg, offset)
        offset += 4

        # Column attribute (2 bytes)
        field.column_attr = from_network_bytes_int16(msg, offset)
        offset += 2

        # Type OID (4 bytes)
        field.type_oid = from_network_bytes_int32(msg, offset)
        offset += 4

        # Type size (2 bytes, signed)
        field.type_size = from_network_bytes_int16(msg, offset)
        offset += 2

        # Type modifier (4 bytes)
        field.type_modifier = from_network_bytes_int32(msg, offset)
        offset += 4

        # Format code (2 bytes)
        field.format_code = from_network_bytes_int16(msg, offset)
        offset += 2

        row_desc.fields.append(field)

    return row_desc


# ============================================================================
# Data Row
# ============================================================================

struct FieldValue:
    """A single field value from a DataRow."""
    var is_null: Bool
    var value: String  # Text representation (for Simple Query Protocol)

    fn __init__(inout self):
        self.is_null = True
        self.value = ""

    fn __init__(inout self, value: String):
        self.is_null = False
        self.value = value


struct DataRow:
    """DataRow message (D) - one row of query results."""
    var field_count: Int
    var fields: List[FieldValue]

    fn __init__(inout self):
        self.field_count = 0
        self.fields = List[FieldValue]()


fn parse_data_row(msg: List[UInt8]) raises -> DataRow:
    """
    Parse DataRow message.

    Format: [D:1][Length:4][FieldCount:2][Fields...]
    Each field:
      - Length: 4 bytes (-1 = NULL, else value length)
      - Value: N bytes (if length > 0)
    """
    var data_row = DataRow()

    # Verify message type
    if msg[0] != ord('D'):
        raise Error("Expected DataRow message (D), got: " + chr(Int(msg[0])))

    # Skip length (bytes 1-4)
    # Parse field count (bytes 5-6)
    data_row.field_count = from_network_bytes_int16(msg, 5)

    var offset = 7  # Start of first field

    # Parse each field
    for i in range(data_row.field_count):
        # Field length (4 bytes)
        var field_length = from_network_bytes_int32(msg, offset)
        offset += 4

        if field_length == -1:
            # NULL value
            var field = FieldValue()
            field.is_null = True
            field.value = ""
            data_row.fields.append(field)
        else:
            # Extract value (field_length bytes)
            var value_bytes = List[UInt8]()
            for j in range(field_length):
                value_bytes.append(msg[offset + j])

            # Convert to string
            var value_str = String("")
            for j in range(len(value_bytes)):
                value_str += chr(Int(value_bytes[j]))

            var field = FieldValue(value_str)
            data_row.fields.append(field)

            offset += field_length

    return data_row


# ============================================================================
# Command Complete
# ============================================================================

struct CommandComplete:
    """CommandComplete message (C) - query execution result."""
    var tag: String  # Full tag (e.g., "SELECT 5", "INSERT 0 1")
    var command: String  # Command type (SELECT, INSERT, UPDATE, DELETE, etc.)
    var rows_affected: Int  # Number of rows affected/returned

    fn __init__(inout self):
        self.tag = ""
        self.command = ""
        self.rows_affected = 0


fn parse_command_complete(msg: List[UInt8]) raises -> CommandComplete:
    """
    Parse CommandComplete message.

    Format: [C:1][Length:4][Tag:string][0x00]

    Tag examples:
      - "SELECT 5" -> command=SELECT, rows=5
      - "INSERT 0 1" -> command=INSERT, rows=1
      - "UPDATE 3" -> command=UPDATE, rows=3
      - "DELETE 2" -> command=DELETE, rows=2
      - "CREATE TABLE" -> command=CREATE TABLE, rows=0
    """
    var cmd = CommandComplete()

    # Verify message type
    if msg[0] != ord('C'):
        raise Error("Expected CommandComplete message (C), got: " + chr(Int(msg[0])))

    # Skip length (bytes 1-4)
    # Extract tag (null-terminated string starting at byte 5)
    cmd.tag = extract_cstring(msg, 5)

    # Parse tag to extract command and rows
    # Format varies by command type
    var parts = List[String]()
    var current_part = String("")

    for i in range(len(cmd.tag)):
        var c = cmd.tag[i]
        if c == ' ':
            if len(current_part) > 0:
                parts.append(current_part)
                current_part = String("")
        else:
            current_part += c

    if len(current_part) > 0:
        parts.append(current_part)

    # First part is always the command
    if len(parts) > 0:
        cmd.command = parts[0]

    # Extract rows affected (last part, usually)
    if cmd.command == "SELECT" or cmd.command == "DELETE" or cmd.command == "UPDATE":
        # Last part is row count
        if len(parts) > 1:
            try:
                cmd.rows_affected = int(parts[len(parts) - 1])
            except:
                cmd.rows_affected = 0
    elif cmd.command == "INSERT":
        # Format: "INSERT oid count"
        if len(parts) > 2:
            try:
                cmd.rows_affected = int(parts[2])
            except:
                cmd.rows_affected = 0

    return cmd


# ============================================================================
# Query Result
# ============================================================================

struct QueryResult:
    """
    Complete query result with metadata and data.

    Holds:
    - Column descriptions (names, types)
    - Data rows
    - Command result (tag, rows affected)
    """
    var columns: List[FieldDescription]
    var rows: List[DataRow]
    var command_tag: String
    var rows_affected: Int

    fn __init__(inout self):
        self.columns = List[FieldDescription]()
        self.rows = List[DataRow]()
        self.command_tag = ""
        self.rows_affected = 0

    fn column_count(self) -> Int:
        """Get number of columns."""
        return len(self.columns)

    fn row_count(self) -> Int:
        """Get number of rows."""
        return len(self.rows)

    fn get_column_name(self, col_idx: Int) -> String:
        """Get column name by index."""
        return self.columns[col_idx].name

    fn get_column_type(self, col_idx: Int) -> Int:
        """Get column type OID by index."""
        return self.columns[col_idx].type_oid

    fn get_value(self, row_idx: Int, col_idx: Int) raises -> String:
        """
        Get field value as string.

        Raises:
            Error if field is NULL
        """
        var field = self.rows[row_idx].fields[col_idx]
        if field.is_null:
            raise Error("Field is NULL")
        return field.value

    fn is_null(self, row_idx: Int, col_idx: Int) -> Bool:
        """Check if field is NULL."""
        return self.rows[row_idx].fields[col_idx].is_null

    # ========================================================================
    # Typed Accessors - Numeric Types
    # ========================================================================

    fn get_int2(self, row_idx: Int, col_idx: Int) raises -> Int16:
        """
        Get field value as INT2 (SMALLINT).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Int16 value

        Raises:
            Error if field is NULL or cannot be decoded as INT2
        """
        from ..types.numeric import decode_int2

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get INT2 from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_int2(value_str)

    fn get_int4(self, row_idx: Int, col_idx: Int) raises -> Int32:
        """
        Get field value as INT4 (INTEGER).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Int32 value

        Raises:
            Error if field is NULL or cannot be decoded as INT4
        """
        from ..types.numeric import decode_int4

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get INT4 from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_int4(value_str)

    fn get_int8(self, row_idx: Int, col_idx: Int) raises -> Int64:
        """
        Get field value as INT8 (BIGINT).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Int64 value

        Raises:
            Error if field is NULL or cannot be decoded as INT8
        """
        from ..types.numeric import decode_int8

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get INT8 from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_int8(value_str)

    fn get_float8(self, row_idx: Int, col_idx: Int) raises -> Float64:
        """
        Get field value as FLOAT8 (DOUBLE PRECISION).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Float64 value

        Raises:
            Error if field is NULL or cannot be decoded as FLOAT8
        """
        from ..types.numeric import decode_float8

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get FLOAT8 from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_float8(value_str)

    fn get_float4(self, row_idx: Int, col_idx: Int) raises -> Float32:
        """
        Get field value as FLOAT4 (REAL).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Float32 value

        Raises:
            Error if field is NULL or cannot be decoded as FLOAT4
        """
        from ..types.numeric import decode_float4

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get FLOAT4 from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_float4(value_str)

    # ========================================================================
    # Typed Accessors - Boolean and Text Types
    # ========================================================================

    fn get_bool(self, row_idx: Int, col_idx: Int) raises -> Bool:
        """
        Get field value as BOOLEAN.

        PostgreSQL BOOLEAN accepts many representations:
        - True: 't', 'true', 'yes', 'on', '1' (case-insensitive)
        - False: 'f', 'false', 'no', 'off', '0' (case-insensitive)

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Parsed Bool value

        Raises:
            Error if field is NULL or cannot be decoded as BOOLEAN

        Example:
            var result = conn.query("SELECT active FROM users WHERE id = 1")
            var is_active = result.get_bool(0, 0)  # True or False
        """
        from ..types.text import decode_boolean

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get BOOLEAN from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_boolean(value_str)

    fn get_text(self, row_idx: Int, col_idx: Int) raises -> String:
        """
        Get field value as TEXT.

        This is equivalent to get_value() but provides a consistent API
        for type-safe access. TEXT values are already String in the protocol.

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            String value

        Raises:
            Error if field is NULL

        Example:
            var result = conn.query("SELECT name FROM users WHERE id = 1")
            var name = result.get_text(0, 0)  # String
        """
        from ..types.text import decode_text

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get TEXT from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_text(value_str)

    fn get_varchar(self, row_idx: Int, col_idx: Int) raises -> String:
        """
        Get field value as VARCHAR.

        VARCHAR is the same as TEXT in PostgreSQL. This accessor provides
        a convenient API for explicit VARCHAR columns.

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            String value

        Raises:
            Error if field is NULL

        Example:
            var result = conn.query("SELECT email FROM users WHERE id = 1")
            var email = result.get_varchar(0, 0)  # String
        """
        from ..types.text import decode_varchar

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get VARCHAR from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_varchar(value_str)

    # ========================================================================
    # Typed Accessors - Temporal Types
    # ========================================================================

    fn get_timestamp(self, row_idx: Int, col_idx: Int) raises -> owned Timestamp:
        """
        Get field value as TIMESTAMP (without timezone).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Timestamp structure

        Raises:
            Error if field is NULL or cannot be decoded as TIMESTAMP

        Example:
            var result = conn.query("SELECT created_at FROM events")
            var ts = result.get_timestamp(0, 0)
            print(ts.year, "-", ts.month, "-", ts.day)
        """
        from ..types.temporal import decode_timestamp

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get TIMESTAMP from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_timestamp(value_str)

    fn get_timestamptz(self, row_idx: Int, col_idx: Int) raises -> owned TimestampTZ:
        """
        Get field value as TIMESTAMPTZ (with timezone).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            TimestampTZ structure

        Raises:
            Error if field is NULL or cannot be decoded as TIMESTAMPTZ

        Example:
            var result = conn.query("SELECT recorded_at FROM sensor_data")
            var tstz = result.get_timestamptz(0, 0)
            print(tstz.year, "-", tstz.month, "-", tstz.day, " ", tstz.hour, ":", tstz.minute)
            print("Timezone offset:", tstz.timezone_offset_seconds, "seconds")
        """
        from ..types.temporal import decode_timestamptz

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get TIMESTAMPTZ from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_timestamptz(value_str)

    fn get_date(self, row_idx: Int, col_idx: Int) raises -> owned Date:
        """
        Get field value as DATE.

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Date structure

        Raises:
            Error if field is NULL or cannot be decoded as DATE

        Example:
            var result = conn.query("SELECT birth_date FROM users")
            var date = result.get_date(0, 0)
            print(date.year, "-", date.month, "-", date.day)
        """
        from ..types.temporal import decode_date

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get DATE from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_date(value_str)

    fn get_time(self, row_idx: Int, col_idx: Int) raises -> owned Time:
        """
        Get field value as TIME (without timezone).

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Time structure

        Raises:
            Error if field is NULL or cannot be decoded as TIME

        Example:
            var result = conn.query("SELECT opening_time FROM stores")
            var time = result.get_time(0, 0)
            print(time.hour, ":", time.minute, ":", time.second)
        """
        from ..types.temporal import decode_time

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get TIME from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_time(value_str)

    # ========================================================================
    # Typed Accessors - Financial & JSON Types
    # ========================================================================

    fn get_numeric(self, row_idx: Int, col_idx: Int) raises -> Numeric:
        """
        Get field value as NUMERIC (arbitrary precision decimal).

        NUMERIC provides exact decimal arithmetic, critical for financial calculations
        where floating point errors are unacceptable.

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            Numeric value preserving exact precision

        Raises:
            Error if field is NULL or cannot be decoded as NUMERIC

        Example:
            var result = conn.query("SELECT balance FROM accounts WHERE id = 1")
            var balance = result.get_numeric(0, 0)
            print("Balance: ", balance.to_string())
        """
        from ..types.numeric_jsonb import decode_numeric

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get NUMERIC from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_numeric(value_str)

    fn get_jsonb(self, row_idx: Int, col_idx: Int) raises -> JsonValue:
        """
        Get field value as JSONB (JSON binary storage).

        JSONB provides flexible schema-less storage for metadata, configurations,
        and semi-structured data.

        Args:
            row_idx: Row index
            col_idx: Column index

        Returns:
            JsonValue for accessing JSON fields

        Raises:
            Error if field is NULL or cannot be decoded as JSONB

        Example:
            var result = conn.query("SELECT metadata FROM trades WHERE id = 1")
            var metadata = result.get_jsonb(0, 0)
            var exchange = metadata.get_string("exchange")
        """
        from ..types.numeric_jsonb import decode_jsonb

        if self.is_null(row_idx, col_idx):
            raise Error("Cannot get JSONB from NULL field")

        var value_str = self.get_value(row_idx, col_idx)
        return decode_jsonb(value_str)


# ============================================================================
# PostgreSQL Type OIDs (for reference)
# ============================================================================

# Commonly used PostgreSQL type OIDs
alias PG_TYPE_BOOL = 16
alias PG_TYPE_BYTEA = 17
alias PG_TYPE_CHAR = 18
alias PG_TYPE_INT8 = 20  # bigint
alias PG_TYPE_INT2 = 21  # smallint
alias PG_TYPE_INT4 = 23  # integer
alias PG_TYPE_TEXT = 25
alias PG_TYPE_OID = 26
alias PG_TYPE_FLOAT4 = 700  # real
alias PG_TYPE_FLOAT8 = 701  # double precision
alias PG_TYPE_VARCHAR = 1043
alias PG_TYPE_DATE = 1082
alias PG_TYPE_TIME = 1083
alias PG_TYPE_TIMESTAMP = 1114
alias PG_TYPE_TIMESTAMPTZ = 1184
alias PG_TYPE_INTERVAL = 1186
alias PG_TYPE_NUMERIC = 1700
alias PG_TYPE_UUID = 2950
alias PG_TYPE_JSON = 114
alias PG_TYPE_JSONB = 3802


fn get_type_name(type_oid: Int) -> String:
    """Get human-readable type name from OID."""
    if type_oid == PG_TYPE_BOOL:
        return "BOOL"
    elif type_oid == PG_TYPE_INT2:
        return "INT2"
    elif type_oid == PG_TYPE_INT4:
        return "INT4"
    elif type_oid == PG_TYPE_INT8:
        return "INT8"
    elif type_oid == PG_TYPE_FLOAT4:
        return "FLOAT4"
    elif type_oid == PG_TYPE_FLOAT8:
        return "FLOAT8"
    elif type_oid == PG_TYPE_TEXT:
        return "TEXT"
    elif type_oid == PG_TYPE_VARCHAR:
        return "VARCHAR"
    elif type_oid == PG_TYPE_TIMESTAMP:
        return "TIMESTAMP"
    elif type_oid == PG_TYPE_TIMESTAMPTZ:
        return "TIMESTAMPTZ"
    elif type_oid == PG_TYPE_DATE:
        return "DATE"
    elif type_oid == PG_TYPE_NUMERIC:
        return "NUMERIC"
    elif type_oid == PG_TYPE_JSON:
        return "JSON"
    elif type_oid == PG_TYPE_JSONB:
        return "JSONB"
    elif type_oid == PG_TYPE_UUID:
        return "UUID"
    else:
        return "UNKNOWN(" + String(type_oid) + ")"
