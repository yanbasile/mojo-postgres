# Mojo-Postgres Architecture

## Overview

Mojo-postgres is a pure Mojo implementation of the PostgreSQL client protocol. It prioritizes:

1. **Zero-copy operations** - Direct memory manipulation
2. **Type safety** - Compile-time guarantees
3. **Performance** - SIMD, no GC, predictable latency
4. **Correctness** - Comprehensive testing

## Layer Architecture
```
┌─────────────────────────────────────┐
│     Application Code                │
├─────────────────────────────────────┤
│  Client API (client.mojo)           │  ← High-level interface
│  - connect(), query(), execute()    │
├─────────────────────────────────────┤
│  Connection Pool (pool/)            │  ← Resource management
│  - Connection lifecycle             │
│  - Health checks                    │
├─────────────────────────────────────┤
│  Protocol Layer (protocol/)         │  ← Wire protocol
│  - Message framing                  │
│  - Authentication                   │
│  - Query/Response handling          │
├─────────────────────────────────────┤
│  Type System (types/)               │  ← Encoding/Decoding
│  - Binary format                    │
│  - Text format                      │
│  - Type registry                    │
├─────────────────────────────────────┤
│  Transport Layer                    │  ← Raw I/O
│  - TCP sockets                      │
│  - SSL/TLS (future)                 │
└─────────────────────────────────────┘
```

## Component Details

### 1. Transport Layer

**File**: `src/protocol/connection.mojo`

Handles raw TCP socket communication:
- Socket creation and management
- Network byte order conversion
- Buffer management
- Error handling
```mojo
struct PostgresConnection:
    var socket_fd: Int
    var read_buffer: DynamicVector[UInt8]
    var write_buffer: DynamicVector[UInt8]
    
    fn connect(host: String, port: Int) -> Self: ...
    fn send(data: DynamicVector[UInt8]): ...
    fn receive() -> DynamicVector[UInt8]: ...
    fn close(): ...
```

### 2. Protocol Layer

**Files**: 
- `src/protocol/messages.mojo` - Message parsing
- `src/protocol/auth.mojo` - Authentication

Implements PostgreSQL Frontend/Backend Protocol:

#### Message Format
```
[Type:1byte][Length:4bytes][Payload:N bytes]
```

#### Key Message Types
- `'Q'` - Simple Query
- `'D'` - Data Row
- `'T'` - Row Description
- `'Z'` - Ready For Query
- `'E'` - Error Response
- `'C'` - Command Complete

#### Authentication Flow
```
Client                          Server
  |                               |
  |--- Startup Message --------->|
  |                               |
  |<-- Authentication Request ---|
  |                               |
  |--- Password Response ------->|
  |                               |
  |<-- Authentication OK ---------|
  |                               |
  |<-- Ready For Query -----------|
```

### 3. Type System

**Files**: `src/types/*.mojo`

Each type handler provides:
- **Binary encoding**: Mojo type → PostgreSQL binary format
- **Binary decoding**: PostgreSQL binary format → Mojo type
- **Text encoding**: Mojo type → SQL text representation
- **Text decoding**: SQL text → Mojo type

Example: INT4 (INTEGER)
```mojo
struct Int4Handler:
    alias OID: Int = 23
    
    @staticmethod
    fn encode_binary(value: Int32) -> DynamicVector[UInt8]:
        # Convert to 4-byte big-endian
        var buffer = DynamicVector[UInt8](4)
        buffer[0] = (value >> 24) & 0xFF
        buffer[1] = (value >> 16) & 0xFF
        buffer[2] = (value >> 8) & 0xFF
        buffer[3] = value & 0xFF
        return buffer
    
    @staticmethod
    fn decode_binary(data: DynamicVector[UInt8]) -> Int32:
        # Parse 4-byte big-endian
        return (data[0] << 24) | (data[1] << 16) | 
               (data[2] << 8) | data[3]
```

#### Type Registry

Maps PostgreSQL OIDs to handlers:
```mojo
struct TypeRegistry:
    var handlers: Dict[Int, TypeHandler]
    
    fn register[T: TypeHandler]():
        handlers[T.OID] = T
    
    fn encode(oid: Int, value: Any) -> DynamicVector[UInt8]:
        return handlers[oid].encode_binary(value)
```

### 4. Client API

**File**: `src/client.mojo`

High-level interface for applications:
```mojo
struct PostgresClient:
    var connection: PostgresConnection
    var type_registry: TypeRegistry
    
    @staticmethod
    fn connect(
        host: String,
        port: Int,
        database: String,
        user: String,
        password: String
    ) -> Self:
        # Connection establishment
        # Authentication
        # Type registry initialization
    
    fn query(sql: String) -> QueryResult:
        # Send simple query
        # Parse result rows
        # Decode values using type registry
    
    fn execute(sql: String, *params: Any) -> Int:
        # Send parameterized query
        # Return affected rows
    
    fn close():
        # Graceful connection shutdown
```

### 5. Connection Pool

**File**: `src/pool/connection_pool.mojo` (Phase 2)

Manages multiple connections:
```mojo
struct ConnectionPool:
    var max_connections: Int
    var idle_connections: List[PostgresConnection]
    var active_connections: Set[PostgresConnection]
    
    fn acquire() -> PostgresConnection:
        # Get connection from pool or create new
    
    fn release(conn: PostgresConnection):
        # Return connection to pool
    
    fn health_check():
        # Ping idle connections
        # Remove dead connections
```

## Data Flow

### Query Execution Flow
```
1. Application
   ↓ query("SELECT * FROM users WHERE id = 1")
2. Client API
   ↓ Build 'Q' message with SQL
3. Protocol Layer
   ↓ Frame message: ['Q'][length][sql]
4. Transport Layer
   ↓ Send bytes over TCP socket
5. PostgreSQL Server
   ↓ Execute query
6. Transport Layer
   ↑ Receive response bytes
7. Protocol Layer
   ↑ Parse messages: ['T'=RowDesc, 'D'=DataRow, 'C'=Complete]
8. Type System
   ↑ Decode column values using type handlers
9. Client API
   ↑ Build QueryResult object
10. Application
   ↑ Iterate rows
```

### Binary vs Text Format

#### Text Format (Simple Query Protocol)
- **Pros**: Simpler to implement, human-readable
- **Cons**: Slower, more parsing overhead
- **Use**: Development, debugging, SQL commands

#### Binary Format (Extended Query Protocol)
- **Pros**: Faster, less CPU, exact precision
- **Cons**: More complex, harder to debug
- **Use**: Production, high-frequency operations

## Performance Optimizations

### 1. Zero-Copy Buffer Management
```mojo
# BAD: Multiple copies
fn receive_message() -> String:
    var bytes = socket.read()  # Copy 1
    var string = String(bytes)  # Copy 2
    return string  # Copy 3

# GOOD: Zero-copy
fn receive_message() -> DTypePointer[DType.uint8]:
    return socket.read_into_buffer()  # Direct pointer
```

### 2. SIMD Type Encoding
```mojo
fn encode_float8_array(values: List[Float64]) -> DynamicVector[UInt8]:
    # Use SIMD to encode multiple values in parallel
    var buffer = DynamicVector[UInt8](values.len * 8)
    
    @parameter
    fn encode_simd[width: Int](i: Int):
        var simd_vals = values.load[width=width](i)
        # Vectorized byte swapping for network order
        var encoded = simd_vals.to_bytes_be()
        buffer.store[width=width*8](i*8, encoded)
    
    vectorize[encode_simd, 4](values.len)
    return buffer
```

### 3. Connection Pooling

Reduces connection overhead:
- Reuse existing connections
- Amortize authentication cost
- Maintain warm connections

### 4. Prepared Statement Caching

Parse query once, execute many times:
- Server-side query plan caching
- Reduced network traffic
- Better performance

## Error Handling

### Error Categories

1. **Connection Errors**
   - Network failure
   - Authentication failed
   - Connection timeout

2. **Protocol Errors**
   - Invalid message format
   - Unexpected message type
   - Version mismatch

3. **Query Errors**
   - Syntax error
   - Constraint violation
   - Type mismatch

4. **Type Errors**
   - Decode failure
   - Unsupported type
   - Value out of range

### Error Propagation
```mojo
struct PostgresError:
    var code: String  # SQLSTATE
    var message: String
    var detail: String?
    var hint: String?

# Return type for operations that can fail
alias Result[T] = Variant[T, PostgresError]

fn query(sql: String) -> Result[QueryResult]:
    try:
        # Execute query
        return Ok(result)
    except e:
        return Err(PostgresError(e))
```

## Testing Strategy

### 1. Unit Tests
- Each type handler independently
- Protocol message parsing
- Buffer management
- Error conditions

### 2. Integration Tests
- Real PostgreSQL connection
- Full query lifecycle
- Transaction handling
- Connection pooling

### 3. Performance Tests
- Benchmark vs psycopg2
- Latency measurements
- Memory usage profiling
- Throughput testing

### 4. Stress Tests
- Many concurrent connections
- High query rate
- Large result sets
- Long-running queries

## Security Considerations

### Authentication
- MD5 (legacy, less secure)
- SCRAM-SHA-256 (modern, recommended)
- Certificate-based (future)

### Connection Security
- SSL/TLS encryption (Phase 3)
- Certificate validation
- Secure credential storage

### SQL Injection Prevention
- Parameterized queries
- Type-safe value binding
- No string concatenation

## Future Enhancements

### Phase 2
- Binary format support
- Prepared statements
- Connection pooling
- Transaction management

### Phase 3
- COPY protocol (bulk operations)
- LISTEN/NOTIFY (async notifications)
- SSL/TLS support
- Advanced authentication

### Phase 4
- Query pipelining
- Cursor support
- Streaming results
- Custom type plugins

---

**Last Updated**: 2024-11-07  
**Version**: 0.1.0-dev
