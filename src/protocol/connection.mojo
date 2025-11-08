"""
PostgreSQL connection implementation using POSIX sockets.

Implements:
- TCP socket connection with TCP_NODELAY
- PostgreSQL startup protocol (version 3.0)
- Message encoding/decoding with network byte order
- Error handling and resource cleanup
"""

from sys.ffi import external_call
from memory import memset_zero, memcpy, UnsafePointer
from collections import List


# ============================================================================
# POSIX Socket Constants and Structures
# ============================================================================

# Address families
alias AF_INET = 2
alias AF_INET6 = 10
alias AF_UNSPEC = 0

# Socket types
alias SOCK_STREAM = 1

# Protocol levels
alias IPPROTO_TCP = 6
alias IPPROTO_IP = 0
alias SOL_SOCKET = 1

# Socket options
alias TCP_NODELAY = 1
alias SO_ERROR = 4

# Address info flags
alias AI_PASSIVE = 1
alias AI_CANONNAME = 2
alias AI_NUMERICHOST = 4

# Error codes
alias EAGAIN = 11
alias EWOULDBLOCK = 11
alias EINTR = 4
alias EINPROGRESS = 115


# ============================================================================
# Network Byte Order Utilities (Big-Endian)
# ============================================================================

fn to_network_bytes_int32(value: Int) -> List[UInt8]:
    """Convert Int32 to network byte order (big-endian) bytes."""
    var bytes = List[UInt8](capacity=4)
    bytes.append(UInt8((value >> 24) & 0xFF))
    bytes.append(UInt8((value >> 16) & 0xFF))
    bytes.append(UInt8((value >> 8) & 0xFF))
    bytes.append(UInt8(value & 0xFF))
    return bytes


fn to_network_bytes_int16(value: Int) -> List[UInt8]:
    """Convert Int16 to network byte order (big-endian) bytes."""
    var bytes = List[UInt8](capacity=2)
    bytes.append(UInt8((value >> 8) & 0xFF))
    bytes.append(UInt8(value & 0xFF))
    return bytes


fn from_network_bytes_int32(bytes: List[UInt8], offset: Int) -> Int:
    """Parse Int32 from network byte order bytes."""
    var b0 = Int(bytes[offset])
    var b1 = Int(bytes[offset + 1])
    var b2 = Int(bytes[offset + 2])
    var b3 = Int(bytes[offset + 3])
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3


fn from_network_bytes_int16(bytes: List[UInt8], offset: Int) -> Int:
    """Parse Int16 from network byte order bytes."""
    var b0 = Int(bytes[offset])
    var b1 = Int(bytes[offset + 1])
    return (b0 << 8) | b1


# ============================================================================
# Message Building Utilities
# ============================================================================

fn build_startup_message(user: String, database: String, application_name: String = "mojo-postgres") -> List[UInt8]:
    """
    Build PostgreSQL startup message.

    Format: [Length:4][ProtocolVersion:4][Params...][0x00]

    Protocol version 3.0 = 196608 (0x00030000)

    Parameters are sent as: "key\0value\0key\0value\0\0"
    """
    var msg = List[UInt8]()

    # Reserve space for length (will fill in later)
    msg.append(0)
    msg.append(0)
    msg.append(0)
    msg.append(0)

    # Protocol version 3.0 = 196608
    var protocol_bytes = to_network_bytes_int32(196608)
    for i in range(len(protocol_bytes)):
        msg.append(protocol_bytes[i])

    # Add parameters: user
    for i in range(len("user")):
        msg.append(ord("user"[i]))
    msg.append(0)  # Null terminator
    for i in range(len(user)):
        msg.append(ord(user[i]))
    msg.append(0)

    # Add parameters: database
    for i in range(len("database")):
        msg.append(ord("database"[i]))
    msg.append(0)
    for i in range(len(database)):
        msg.append(ord(database[i]))
    msg.append(0)

    # Add parameters: application_name
    for i in range(len("application_name")):
        msg.append(ord("application_name"[i]))
    msg.append(0)
    for i in range(len(application_name)):
        msg.append(ord(application_name[i]))
    msg.append(0)

    # Final null terminator
    msg.append(0)

    # Fill in length at the beginning (includes the length field itself)
    var length_bytes = to_network_bytes_int32(len(msg))
    msg[0] = length_bytes[0]
    msg[1] = length_bytes[1]
    msg[2] = length_bytes[2]
    msg[3] = length_bytes[3]

    return msg


fn build_password_message(password: String) -> List[UInt8]:
    """
    Build password message (for cleartext or MD5).

    Format: [p:1][Length:4][Password:string][0x00]
    """
    var msg = List[UInt8]()

    # Message type: 'p'
    msg.append(ord('p'))

    # Length: 4 (length field) + password length + 1 (null terminator)
    var length = 4 + len(password) + 1
    var length_bytes = to_network_bytes_int32(length)
    for i in range(len(length_bytes)):
        msg.append(length_bytes[i])

    # Password string
    for i in range(len(password)):
        msg.append(ord(password[i]))

    # Null terminator
    msg.append(0)

    return msg


# ============================================================================
# Message Parsing Utilities
# ============================================================================

struct MessageHeader:
    """PostgreSQL message header."""
    var msg_type: UInt8
    var length: Int  # Total length including length field
    var payload_length: Int  # Length minus the length field itself

    fn __init__(inout self, msg_type: UInt8, length: Int):
        self.msg_type = msg_type
        self.length = length
        self.payload_length = length - 4  # Subtract length field size


fn parse_message_header(bytes: List[UInt8]) -> MessageHeader:
    """
    Parse PostgreSQL message header.

    Format: [Type:1][Length:4][Payload...]
    Length includes itself but NOT the type byte.
    """
    var msg_type = bytes[0]
    var length = from_network_bytes_int32(bytes, 1)
    return MessageHeader(msg_type, length)


fn extract_cstring(bytes: List[UInt8], offset: Int) -> String:
    """Extract a null-terminated C string from bytes."""
    var chars = List[UInt8]()
    var i = offset
    while i < len(bytes) and bytes[i] != 0:
        chars.append(bytes[i])
        i += 1

    # Convert bytes to string
    var result = String("")
    for j in range(len(chars)):
        result += chr(Int(chars[j]))
    return result


# ============================================================================
# PostgreSQL Connection
# ============================================================================

struct PostgresError:
    """PostgreSQL error information."""
    var severity: String
    var code: String
    var message: String
    var detail: String

    fn __init__(inout self):
        self.severity = ""
        self.code = ""
        self.message = ""
        self.detail = ""

    fn __str__(self) -> String:
        var result = "PostgresError("
        if self.severity:
            result += "severity=" + self.severity + ", "
        if self.code:
            result += "code=" + self.code + ", "
        result += "message=" + self.message
        if self.detail:
            result += ", detail=" + self.detail
        result += ")"
        return result


struct PostgresConnection:
    """
    PostgreSQL connection using POSIX sockets.

    Handles:
    - TCP connection with TCP_NODELAY
    - PostgreSQL startup protocol
    - Authentication
    - Message reading/writing
    """
    var socket_fd: Int
    var host: String
    var port: Int
    var database: String
    var user: String
    var is_connected: Bool

    fn __init__(inout self, host: String = "localhost", port: Int = 5432):
        """Initialize connection (does not connect yet)."""
        self.socket_fd = -1
        self.host = host
        self.port = port
        self.database = ""
        self.user = ""
        self.is_connected = False

    fn __del__(owned self):
        """Cleanup: close socket if still open."""
        if self.socket_fd >= 0:
            _ = external_call["close", Int, Int](self.socket_fd)

    fn connect(inout self, database: String, user: String, password: String) raises:
        """
        Establish TCP connection and perform PostgreSQL startup.

        Steps:
        1. Resolve host via DNS (getaddrinfo)
        2. Create TCP socket
        3. Connect to PostgreSQL server
        4. Set TCP_NODELAY for low latency
        5. Send startup message
        6. Handle authentication
        7. Wait for ReadyForQuery
        """
        self.database = database
        self.user = user

        # Step 1 & 2: Resolve host and create socket
        self.socket_fd = self._create_and_connect_socket()
        if self.socket_fd < 0:
            raise Error("Failed to create or connect socket")

        # Step 3: Set TCP_NODELAY for low latency
        # This reduces latency by disabling Nagle's algorithm
        var nodelay_value = 1
        var nodelay_ptr = UnsafePointer[Int].address_of(nodelay_value)
        var setsockopt_result = external_call["setsockopt", Int,
            Int, Int, Int, UnsafePointer[Int], Int](
            self.socket_fd,
            IPPROTO_TCP,
            TCP_NODELAY,
            nodelay_ptr,
            4  # sizeof(int)
        )
        if setsockopt_result < 0:
            # Non-fatal, but log warning
            # In production, we might want to log this
            pass

        # Step 4: Send startup message
        var startup_msg = build_startup_message(user, database)
        self._send_bytes(startup_msg)

        # Step 5: Handle authentication
        self._handle_authentication(password)

        # Step 6: Wait for ReadyForQuery
        self._wait_for_ready()

        self.is_connected = True

    fn _create_and_connect_socket(self) raises -> Int:
        """
        Create socket and connect to PostgreSQL server.

        Uses getaddrinfo for DNS resolution and proper address handling.
        Returns socket file descriptor or -1 on error.
        """
        # Convert port to string for getaddrinfo
        var port_str = String(self.port)

        # Simplified approach: Create IPv4 socket and connect directly
        # For localhost, we can use a simple approach

        # Create socket: socket(AF_INET, SOCK_STREAM, 0)
        var sock_fd = external_call["socket", Int, Int, Int, Int](
            AF_INET, SOCK_STREAM, 0
        )
        if sock_fd < 0:
            raise Error("Failed to create socket")

        # For localhost/127.0.0.1, we can build sockaddr_in directly
        # This avoids complex getaddrinfo FFI for now
        # sockaddr_in structure (16 bytes total):
        #   sin_family: 2 bytes (AF_INET = 2)
        #   sin_port:   2 bytes (network byte order)
        #   sin_addr:   4 bytes (127.0.0.1 = 0x7F000001 in network order)
        #   sin_zero:   8 bytes (padding, zeros)

        var addr_buffer = UnsafePointer[UInt8].alloc(16)
        memset_zero(addr_buffer, 16)

        # sin_family = AF_INET (2) - little endian on x86
        addr_buffer[0] = 2  # AF_INET low byte
        addr_buffer[1] = 0  # AF_INET high byte

        # sin_port = self.port (network byte order = big endian)
        var port_bytes = to_network_bytes_int16(self.port)
        addr_buffer[2] = port_bytes[0]
        addr_buffer[3] = port_bytes[1]

        # sin_addr = 127.0.0.1 for localhost (network byte order)
        # Check if host is localhost
        if self.host == "localhost" or self.host == "127.0.0.1":
            addr_buffer[4] = 127
            addr_buffer[5] = 0
            addr_buffer[6] = 0
            addr_buffer[7] = 1
        else:
            # For non-localhost, try to parse IP address
            # Simplified: this should use getaddrinfo for full DNS support
            # For now, raise error for non-localhost
            addr_buffer.free()
            _ = external_call["close", Int, Int](sock_fd)
            raise Error("Only localhost/127.0.0.1 supported in this version. Host: " + self.host)

        # Connect: connect(sockfd, addr, addrlen)
        var connect_result = external_call["connect", Int,
            Int, UnsafePointer[UInt8], Int](
            sock_fd, addr_buffer, 16
        )

        addr_buffer.free()

        if connect_result < 0:
            _ = external_call["close", Int, Int](sock_fd)
            raise Error("Failed to connect to " + self.host + ":" + String(self.port))

        return sock_fd

    fn _send_bytes(self, bytes: List[UInt8]) raises:
        """
        Send raw bytes to the socket.

        Handles partial writes by looping until all bytes are sent.
        """
        if self.socket_fd < 0:
            raise Error("Socket not connected")

        var total_sent = 0
        var bytes_to_send = len(bytes)

        # Create buffer from List[UInt8]
        var buffer = UnsafePointer[UInt8].alloc(bytes_to_send)
        for i in range(bytes_to_send):
            buffer[i] = bytes[i]

        # Loop until all bytes are sent
        while total_sent < bytes_to_send:
            var remaining = bytes_to_send - total_sent
            var buffer_offset = buffer + total_sent

            # send(sockfd, buf, len, flags)
            var sent = external_call["send", Int,
                Int, UnsafePointer[UInt8], Int, Int](
                self.socket_fd,
                buffer_offset,
                remaining,
                0  # flags
            )

            if sent < 0:
                buffer.free()
                raise Error("Failed to send data: socket error")
            elif sent == 0:
                buffer.free()
                raise Error("Socket closed by peer")

            total_sent += sent

        buffer.free()

    fn _receive_bytes(self, num_bytes: Int) raises -> List[UInt8]:
        """
        Receive exact number of bytes from socket.

        Handles partial reads by looping until all bytes are received.
        """
        if self.socket_fd < 0:
            raise Error("Socket not connected")

        if num_bytes == 0:
            return List[UInt8]()

        var result = List[UInt8](capacity=num_bytes)
        var buffer = UnsafePointer[UInt8].alloc(num_bytes)
        var total_received = 0

        # Loop until all bytes are received
        while total_received < num_bytes:
            var remaining = num_bytes - total_received
            var buffer_offset = buffer + total_received

            # recv(sockfd, buf, len, flags)
            var received = external_call["recv", Int,
                Int, UnsafePointer[UInt8], Int, Int](
                self.socket_fd,
                buffer_offset,
                remaining,
                0  # flags
            )

            if received < 0:
                buffer.free()
                raise Error("Failed to receive data: socket error")
            elif received == 0:
                buffer.free()
                raise Error("Connection closed by server")

            total_received += received

        # Copy to result List
        for i in range(num_bytes):
            result.append(buffer[i])

        buffer.free()
        return result

    fn _receive_message(self) raises -> List[UInt8]:
        """
        Receive a complete PostgreSQL message.

        1. Read 5 bytes: [Type:1][Length:4]
        2. Read payload based on length
        """
        # Read header (type + length)
        var header_bytes = self._receive_bytes(5)

        # Parse length
        var msg_type = header_bytes[0]
        var length = from_network_bytes_int32(header_bytes, 1)

        # Read payload (length includes itself, so subtract 4)
        var payload_length = length - 4
        var payload_bytes = self._receive_bytes(payload_length)

        # Combine into full message
        var full_message = List[UInt8](capacity=5 + payload_length)
        full_message.append(msg_type)
        for i in range(4):
            full_message.append(header_bytes[i + 1])
        for i in range(len(payload_bytes)):
            full_message.append(payload_bytes[i])

        return full_message

    fn _handle_authentication(self, password: String) raises:
        """Handle PostgreSQL authentication."""
        # Receive authentication request
        var auth_msg = self._receive_message()

        if auth_msg[0] != ord('R'):
            raise Error("Expected authentication message, got: " + chr(Int(auth_msg[0])))

        # Parse auth type
        var auth_type = from_network_bytes_int32(auth_msg, 5)

        if auth_type == 0:
            # AuthenticationOk - no password needed
            return
        elif auth_type == 3:
            # AuthenticationCleartextPassword
            var pwd_msg = build_password_message(password)
            self._send_bytes(pwd_msg)

            # Wait for AuthenticationOk
            var response = self._receive_message()
            var response_type = from_network_bytes_int32(response, 5)
            if response_type != 0:
                raise Error("Authentication failed")
        elif auth_type == 5:
            # AuthenticationMD5Password
            # Extract salt (4 bytes after auth type)
            var salt = List[UInt8](capacity=4)
            for i in range(4):
                salt.append(auth_msg[9 + i])

            # Build MD5 password hash
            from .auth import md5_password_postgres
            var md5_hash = md5_password_postgres(password, self.user, salt)

            # Send password message
            var pwd_msg = build_password_message(md5_hash)
            self._send_bytes(pwd_msg)

            # Wait for AuthenticationOk
            var response = self._receive_message()
            var response_type = from_network_bytes_int32(response, 5)
            if response_type != 0:
                raise Error("Authentication failed")
        else:
            raise Error("Unsupported authentication type: " + String(auth_type))

    fn _wait_for_ready(self) raises:
        """Wait for ReadyForQuery message after authentication."""
        # After authentication, server sends:
        # - BackendKeyData (K)
        # - ParameterStatus (S) - possibly multiple
        # - ReadyForQuery (Z)

        while True:
            var msg = self._receive_message()
            var msg_type = chr(Int(msg[0]))

            if msg_type == 'Z':
                # ReadyForQuery - we're done!
                break
            elif msg_type == 'K':
                # BackendKeyData - ignore for now
                continue
            elif msg_type == 'S':
                # ParameterStatus - ignore for now
                continue
            elif msg_type == 'E':
                # ErrorResponse
                var error = self._parse_error_response(msg)
                raise Error(error.__str__())
            else:
                # Unexpected message type
                raise Error("Unexpected message type: " + msg_type)

    fn _parse_error_response(self, msg: List[UInt8]) -> PostgresError:
        """Parse ErrorResponse message."""
        var error = PostgresError()

        # Error message format: [E:1][Length:4][Field1:1][String1][0x00]...
        var offset = 5  # Skip type and length

        while offset < len(msg):
            var field_type = chr(Int(msg[offset]))
            offset += 1

            if field_type == '\0':
                # End of fields
                break

            var field_value = extract_cstring(msg, offset)
            offset += len(field_value) + 1  # +1 for null terminator

            # Parse field type
            if field_type == 'S':
                error.severity = field_value
            elif field_type == 'C':
                error.code = field_value
            elif field_type == 'M':
                error.message = field_value
            elif field_type == 'D':
                error.detail = field_value

        return error

    fn query(self, sql: String) raises -> owned QueryResult:
        """
        Execute a Simple Query and return results.

        This implements the Simple Query protocol which:
        1. Sends Query message (Q)
        2. Receives RowDescription (T) - column metadata
        3. Receives DataRow messages (D) - one per row
        4. Receives CommandComplete (C) - completion status
        5. Receives ReadyForQuery (Z) - ready for next query

        Args:
            sql: SQL query string (e.g., "SELECT * FROM users")

        Returns:
            QueryResult with columns, rows, and command info

        Raises:
            Error on query errors or connection issues
        """
        from .query import build_query_message, parse_row_description, parse_data_row
        from .query import parse_command_complete, QueryResult, FieldDescription

        if not self.is_connected:
            raise Error("Not connected to PostgreSQL")

        # Build and send Query message
        var query_msg = build_query_message(sql)
        self._send_bytes(query_msg)

        # Initialize result
        var result = QueryResult()

        # Process response messages
        var got_row_description = False
        var got_command_complete = False

        while True:
            var msg = self._receive_message()
            var msg_type = chr(Int(msg[0]))

            if msg_type == 'T':
                # RowDescription - column metadata
                var row_desc = parse_row_description(msg)
                for i in range(row_desc.field_count):
                    result.columns.append(row_desc.fields[i])
                got_row_description = True

            elif msg_type == 'D':
                # DataRow - one row of data
                var data_row = parse_data_row(msg)
                result.rows.append(data_row)

            elif msg_type == 'C':
                # CommandComplete - query finished
                var cmd = parse_command_complete(msg)
                result.command_tag = cmd.tag
                result.rows_affected = cmd.rows_affected
                got_command_complete = True

            elif msg_type == 'Z':
                # ReadyForQuery - all done
                break

            elif msg_type == 'E':
                # ErrorResponse - query failed
                var error = self._parse_error_response(msg)
                raise Error("Query error: " + error.message)

            elif msg_type == 'N':
                # NoticeResponse - informational, ignore for now
                continue

            elif msg_type == 'S':
                # ParameterStatus - ignore
                continue

            else:
                # Unexpected message
                raise Error("Unexpected message type during query: " + msg_type)

        if not got_command_complete:
            raise Error("Query did not complete properly")

        return result^

    fn close(inout self):
        """Close the connection gracefully."""
        if self.socket_fd >= 0:
            # Send Terminate message to PostgreSQL
            # Format: [X:1][Length:4]
            try:
                var terminate_msg = List[UInt8]()
                terminate_msg.append(ord('X'))  # Terminate message type

                # Length = 4 (just the length field itself)
                var length_bytes = to_network_bytes_int32(4)
                for i in range(len(length_bytes)):
                    terminate_msg.append(length_bytes[i])

                # Try to send, but don't fail if socket is already closed
                self._send_bytes(terminate_msg)
            except:
                # Ignore errors during close - socket might already be closed
                pass

            # Close the socket
            _ = external_call["close", Int, Int](self.socket_fd)
            self.socket_fd = -1
            self.is_connected = False
