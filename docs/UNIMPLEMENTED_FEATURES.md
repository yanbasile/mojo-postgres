# PostgreSQL Features Not Yet Implemented

This document lists PostgreSQL commands, types, and features that are **NOT** yet implemented in mojo-postgres.

> **Note**: Basic SQL commands (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, etc.) are **fully supported** through the `query()` method. This list focuses on advanced PostgreSQL-specific features and protocol extensions.

---

## 1. PostgreSQL Data Types (Not Implemented)

### Geometric Types
All geometric types are not yet supported:

- ❌ **POINT** - Geometric point (x, y)
- ❌ **LINE** - Infinite line
- ❌ **LSEG** - Line segment
- ❌ **BOX** - Rectangular box
- ❌ **PATH** - Geometric path
- ❌ **POLYGON** - Closed geometric path
- ❌ **CIRCLE** - Circle

**Impact**: Cannot store or query geometric data natively
**Workaround**: Use text representation or PostGIS
**Roadmap**: Marked as community contribution (Phase 5)

### Range Types
PostgreSQL range types for representing value ranges:

- ❌ **INT4RANGE** - Range of integers
- ❌ **INT8RANGE** - Range of bigints
- ❌ **NUMRANGE** - Range of numerics
- ❌ **TSRANGE** - Range of timestamps (no timezone)
- ❌ **TSTZRANGE** - Range of timestamps with timezone
- ❌ **DATERANGE** - Range of dates

**Impact**: Cannot represent ranges like "1-100" or date ranges natively
**Workaround**: Use two separate fields (start, end)
**Roadmap**: Deferred to Phase 5

### Composite Types
- ❌ **ROW / RECORD** - Composite row types
- ❌ **User-defined composite types** - CREATE TYPE ... AS

**Impact**: Cannot use PostgreSQL composite types
**Workaround**: Use JSON/JSONB or multiple columns
**Roadmap**: Deferred to Phase 5

### Enumeration Types
- ❌ **ENUM** - User-defined enumeration types

**Impact**: Cannot use PostgreSQL ENUMs
**Workaround**: Use VARCHAR with application-level validation
**Roadmap**: Deferred to Phase 5

### Domain Types
- ❌ **DOMAIN** - User-defined domain types

**Impact**: Cannot use PostgreSQL domains
**Workaround**: Use base types with application-level validation
**Roadmap**: Deferred to Phase 5

### Binary Data Types
- ❌ **BYTEA** - Binary data type (partially supported via TEXT encoding)
- ❌ **BIT** - Fixed-length bit string
- ❌ **BIT VARYING** - Variable-length bit string

**Impact**: Limited binary data support
**Workaround**: Use base64 encoding to TEXT
**Roadmap**: BYTEA planned for future, BIT types low priority

### Full-Text Search Types
- ❌ **TSVECTOR** - Text search vector
- ❌ **TSQUERY** - Text search query

**Impact**: Cannot use PostgreSQL full-text search natively
**Workaround**: Use LIKE/ILIKE or external search engine
**Roadmap**: Low priority, may be added in Phase 5

### XML Type
- ❌ **XML** - XML data type

**Impact**: Cannot store XML natively
**Workaround**: Use TEXT or JSONB
**Roadmap**: Low priority

### Money Type
- ❌ **MONEY** - Currency amount

**Impact**: Cannot use MONEY type
**Workaround**: Use NUMERIC(19,4) for financial calculations
**Roadmap**: Low priority (NUMERIC is preferred)

---

## 2. PostgreSQL Protocol Features (Not Implemented)

### Asynchronous Operations
- ❌ **Asynchronous query execution** - Non-blocking query execution
- ❌ **Multiple queries in flight** - Pipelining multiple queries
- ❌ **Query cancellation** - Cancel running queries (CancelRequest message)

**Impact**: Queries are blocking; cannot cancel long-running queries
**Workaround**: Use timeouts (implemented), run in separate thread
**Roadmap**: Marked as future enhancement (Phase 5)

### Binary Protocol Extensions
- ❌ **COPY BOTH** - Bidirectional COPY (for streaming replication)
- ❌ **Fast-path function calls** - Direct function invocation protocol

**Impact**: Cannot use replication protocol or fast-path calls
**Workaround**: Use standard query protocol
**Roadmap**: Low priority

### Extended Authentication
- ❌ **SCRAM-SHA-256** - Modern secure authentication (currently only MD5 and cleartext)
- ❌ **GSSAPI** - Kerberos authentication
- ❌ **SSPI** - Windows authentication
- ❌ **Certificate authentication** - Client certificate auth

**Impact**: Limited to MD5 and cleartext auth (SSL/TLS encryption is supported)
**Workaround**: Use SSL/TLS with MD5 auth
**Roadmap**: SCRAM-SHA-256 planned for Phase 5

### Replication Protocol
- ❌ **Logical replication** - Streaming logical replication
- ❌ **Physical replication** - Streaming physical replication
- ❌ **Replication slots** - Managing replication

**Impact**: Cannot implement replication clients
**Workaround**: Use external tools (pg_receivewal, etc.)
**Roadmap**: Not planned (specialized use case)

---

## 3. PostgreSQL SQL Features (Not Implemented)

### Cursors (Server-side)
- ❌ **DECLARE CURSOR** - Server-side cursors
- ❌ **FETCH** - Fetch from cursor
- ❌ **MOVE** - Move cursor position
- ❌ **CLOSE CURSOR** - Close cursor

**Impact**: Cannot use server-side cursors for large result sets
**Workaround**: Use LIMIT/OFFSET or fetch all results
**Roadmap**: May be added in Phase 5

### Procedural Languages
- ❌ **PL/pgSQL** - PostgreSQL procedural language (can execute but no special support)
- ❌ **PL/Python, PL/Perl, etc.** - Other procedural languages

**Impact**: Can execute stored procedures via query() but no special APIs
**Workaround**: Use query() method to call functions
**Roadmap**: Low priority (basic support works)

### Large Objects (LOBs)
- ❌ **lo_create, lo_open, lo_write, lo_read** - Large object API
- ❌ **OID** - Object identifier type (for large objects)

**Impact**: Cannot use PostgreSQL large object API
**Workaround**: Use BYTEA or external file storage
**Roadmap**: Low priority

### Two-Phase Commit
- ❌ **PREPARE TRANSACTION** - Prepare distributed transaction
- ❌ **COMMIT PREPARED** - Commit prepared transaction
- ❌ **ROLLBACK PREPARED** - Rollback prepared transaction

**Impact**: Cannot use distributed transactions (2PC)
**Workaround**: Use single-database transactions or external coordinator
**Roadmap**: Low priority (specialized use case)

### Advisory Locks
- ❌ **pg_advisory_lock** - Application-level locking
- ❌ **pg_advisory_unlock** - Unlock advisory locks
- ❌ **pg_try_advisory_lock** - Try to acquire lock

**Impact**: Cannot use PostgreSQL advisory locks
**Workaround**: Use external lock manager or table-level locks
**Roadmap**: Can be used via query(), no special API needed

---

## 4. PostgreSQL Extension Support (Not Implemented)

### PostGIS (Geographic Data)
- ❌ **GEOMETRY** - PostGIS geometry type
- ❌ **GEOGRAPHY** - PostGIS geography type
- ❌ **PostGIS functions** - Spatial operations

**Impact**: Cannot use PostGIS for GIS applications
**Workaround**: Use text representation of WKT/WKB
**Roadmap**: Community contribution (Phase 5)

### HSTORE (Key-Value)
- ❌ **HSTORE** - PostgreSQL key-value type

**Impact**: Cannot use HSTORE
**Workaround**: Use JSONB (which is implemented)
**Roadmap**: Low priority (JSONB is better)

### LTREE (Hierarchical Labels)
- ❌ **LTREE** - Hierarchical tree labels

**Impact**: Cannot use LTREE for hierarchical data
**Workaround**: Use adjacency list or nested sets pattern
**Roadmap**: Low priority

### TimescaleDB (Time-Series)
- ❌ **Hypertable-aware query planning** - Optimize queries for hypertables
- ❌ **Continuous aggregate helpers** - Continuous aggregates
- ❌ **Compression dictionary** - Compression support
- ❌ **Chunk-aware parallel queries** - Parallel chunk queries

**Impact**: TimescaleDB works but without optimizations
**Workaround**: Use standard query protocol (works fine for most use cases)
**Roadmap**: Planned for Phase 5 (important for MDDC-AI use case)

---

## 5. Advanced Driver Features (Not Implemented)

### Query Pipelining & Batching
- ❌ **Connection multiplexing** - Single connection for multiple logical sessions
- ❌ **Query result streaming** - Stream large results incrementally
- ❌ **Lazy result fetching** - Fetch results on-demand

**Impact**: Must fetch all results at once, cannot multiplex
**Workaround**: Use connection pooling, fetch all results
**Roadmap**: Planned for Phase 5

### Advanced Observability
- ❌ **Distributed tracing** - OpenTelemetry integration
- ❌ **Advanced performance profiling** - Detailed profiling
- ❌ **Query plan analysis** - EXPLAIN integration

**Impact**: Basic logging/metrics work, but no distributed tracing
**Workaround**: Use existing logging and metrics
**Roadmap**: OpenTelemetry planned for Phase 5

### Developer Experience
- ❌ **Query builder API** - Fluent query building
- ❌ **ORM-like interface** - Object-relational mapping
- ❌ **Migration tools** - Schema migration management
- ❌ **Schema introspection** - Automatic schema discovery

**Impact**: Must write raw SQL
**Workaround**: Write SQL queries directly (current approach)
**Roadmap**: May be added based on community demand (Phase 5)

### Memory Management
- ❌ **Custom memory allocators** - Specialized allocators for PostgreSQL data
- ❌ **Zero-copy result parsing** - Parse results without copying

**Impact**: Some memory copying occurs
**Workaround**: Current implementation is efficient enough for most use cases
**Roadmap**: Performance optimization for Phase 5

---

## 6. What IS Implemented (For Reference)

### ✅ Core SQL Commands
All standard SQL commands work through `query()`:
- SELECT, INSERT, UPDATE, DELETE
- CREATE, ALTER, DROP (tables, indexes, etc.)
- GRANT, REVOKE
- TRUNCATE, VACUUM, ANALYZE
- EXPLAIN, EXPLAIN ANALYZE
- SET, SHOW
- All DDL and DML commands

### ✅ Data Types (14 core + extensions)
- INT2, INT4, INT8
- FLOAT4, FLOAT8
- TEXT, VARCHAR
- BOOLEAN
- TIMESTAMP, TIMESTAMPTZ
- DATE, TIME
- NUMERIC
- JSONB
- **Arrays**: INT2[], INT4[], INT8[], TEXT[], VARCHAR[], BOOLEAN[]
- **Network**: UUID, INET, CIDR
- **Temporal**: INTERVAL

### ✅ Advanced Features
- COPY FROM/TO (bulk operations)
- LISTEN/NOTIFY (async notifications)
- SSL/TLS encryption
- Prepared statements
- Transactions (BEGIN/COMMIT/ROLLBACK)
- Savepoints
- Isolation levels

### ✅ Production Features
- Connection pooling
- Structured logging
- Prometheus metrics
- Retry logic
- Circuit breaker
- Health monitoring
- Query timeouts
- Connection validation

---

## 7. Summary by Priority

### High Priority (Phase 5)
- SCRAM-SHA-256 authentication
- BYTEA type
- Query result streaming
- TimescaleDB optimizations

### Medium Priority (Community-driven)
- Range types (INT4RANGE, TSTZRANGE, etc.)
- Composite types
- Enum types
- PostGIS support
- Query builder API

### Low Priority (Specialized)
- Geometric types
- Replication protocol
- Two-phase commit
- Large objects
- Cursors
- PL/pgSQL special support

### Not Planned
- HSTORE (use JSONB instead)
- MONEY (use NUMERIC instead)
- XML (use TEXT or JSONB)
- Fast-path protocol
- COPY BOTH

---

## 8. How to Use This Document

### If you need an unimplemented feature:

1. **Check workarounds** - Most features have viable workarounds
2. **Use query() for SQL** - All SQL commands work through the basic query interface
3. **Consider contributing** - Many features are marked for community contributions
4. **File an issue** - Request prioritization of features you need

### If you want to contribute:

See the ROADMAP.md for features marked as:
- **Good first issues**: Simple type handlers
- **Community contributions**: Extensions and specialized types
- **Phase 5**: Advanced features needing design discussion

---

## References

- [PostgreSQL Data Types](https://www.postgresql.org/docs/current/datatype.html)
- [PostgreSQL Protocol](https://www.postgresql.org/docs/current/protocol.html)
- [PostgreSQL SQL Commands](https://www.postgresql.org/docs/current/sql-commands.html)
- [mojo-postgres ROADMAP](../ROADMAP.md)

---

**Last Updated**: 2025-01-09
**Version**: Based on mojo-postgres v0.9.0
