# PostgreSQL Type System

Complete reference for PostgreSQL types and their implementation status.

## Type Handler Implementation Status

### ✅ Phase 1: Core Types (MDDC-AI Priority)

| Type | OID | Mojo Type | Status | Priority |
|------|-----|-----------|--------|----------|
| INT2 | 21 | Int16 | 📋 TODO | P0 |
| INT4 | 23 | Int32 | 📋 TODO | P0 |
| INT8 | 20 | Int64 | 📋 TODO | P0 |
| FLOAT4 | 700 | Float32 | 📋 TODO | P1 |
| FLOAT8 | 701 | Float64 | 📋 TODO | P0 |
| NUMERIC | 1700 | String | 📋 TODO | P0 |
| BOOLEAN | 16 | Bool | 📋 TODO | P0 |
| TEXT | 25 | String | 📋 TODO | P0 |
| VARCHAR | 1043 | String | 📋 TODO | P0 |
| CHAR | 1042 | String | 📋 TODO | P1 |
| BYTEA | 17 | DynamicVector[UInt8] | 📋 TODO | P1 |
| TIMESTAMP | 1114 | Int64 | 📋 TODO | P1 |
| TIMESTAMPTZ | 1184 | Int64 | 📋 TODO | P0 |
| INTERVAL | 1186 | Duration | 📋 TODO | P1 |
| JSON | 114 | String | 📋 TODO | P1 |
| JSONB | 3802 | String | 📋 TODO | P0 |

### 🟡 Phase 2: Common Types

| Type | OID | Mojo Type | Status |
|------|-----|-----------|--------|
| DATE | 1082 | Int32 | 📋 TODO |
| TIME | 1083 | Int64 | 📋 TODO |
| TIMETZ | 1266 | Struct | 📋 TODO |
| UUID | 2950 | String | 📋 TODO |
| INET | 869 | String | 📋 TODO |
| CIDR | 650 | String | 📋 TODO |
| MACADDR | 829 | String | 📋 TODO |

### 🔴 Phase 3: Advanced Types

| Category | Types | Status |
|----------|-------|--------|
| Geometric | POINT, LINE, BOX, POLYGON, etc. | 📋 TODO |
| Range | INT4RANGE, TSTZRANGE, etc. | 📋 TODO |
| Arrays | ANY[], TEXT[], INT4[], etc. | 📋 TODO |
| Composite | RECORD, custom types | 📋 TODO |

## Type Encoding Formats

### Binary Format (Preferred)

Network byte order (big-endian), compact representation.

#### INT4 (OID 23)
```
Size: 4 bytes
Format: Big-endian signed integer

Example: 42
Bytes: [0x00, 0x00, 0x00, 0x2A]
```

#### INT8 (OID 20)
```
Size: 8 bytes
Format: Big-endian signed long

Example: 1234567890
Bytes: [0x00, 0x00, 0x00, 0x00, 0x49, 0x96, 0x02, 0xD2]
```

#### FLOAT8 (OID 701)
```
Size: 8 bytes
Format: IEEE 754 double precision (big-endian)

Example: 3.14159
Bytes: [0x40, 0x09, 0x21, 0xF9, 0xF0, 0x1B, 0x86, 0x6E]
```

#### TIMESTAMPTZ (OID 1184)
```
Size: 8 bytes
Format: Microseconds since 2000-01-01 00:00:00 UTC (big-endian)
Note: NOT Unix epoch! PostgreSQL uses 2000-01-01 as epoch.

Example: 2024-01-01 00:00:00 UTC
PostgreSQL epoch offset: 757382400000000 microseconds
```

#### TEXT (OID 25)
```
Size: Variable
Format: UTF-8 encoded string (no null terminator in binary)

Example: "Hello"
Bytes: [0x48, 0x65, 0x6C, 0x6C, 0x6F]
Length prefix: Included in message framing
```

#### NUMERIC (OID 1700)
```
Size: Variable
Format: Complex - sign, weight, scale, digits array
Digits: Base-10000 (each digit 0-9999)

Example: 123.45
Structure:
  - ndigits: 2
  - weight: 0
  - sign: 0x0000 (positive)
  - dscale: 2
  - digits: [1, 2345] (base-10000)

This is the most complex type to implement!
```

#### JSONB (OID 3802)
```
Size: Variable
Format: Binary JSON (version 1)
Header: 1 byte version (0x01)
Body: JEntry array + data

This is complex - recommend starting with JSON text format
```

### Text Format

Human-readable representation used in simple query protocol.

| Type | Example Text |
|------|-------------|
| INT4 | "42" |
| FLOAT8 | "3.14159" |
| TEXT | "Hello World" |
| BOOLEAN | "t" or "f" |
| TIMESTAMPTZ | "2024-01-01 00:00:00+00" |
| NUMERIC | "123.45" |
| NULL | (empty, length = -1) |

## NULL Handling

In PostgreSQL wire protocol:
- **Binary format**: Length field = -1 (0xFFFFFFFF)
- **Text format**: Length field = -1
```mojo
fn encode_nullable[T: TypeHandler](value: Optional[T]) -> Message:
    if value.is_none():
        return Message(length=-1)  # NULL indicator
    else:
        return T.encode_binary(value.value())
```

## Type OID Reference

Full list: [pg_type.dat](https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat)

### Commonly Used OIDs
```
16    - BOOLEAN
17    - BYTEA
20    - INT8 (BIGINT)
21    - INT2 (SMALLINT)
23    - INT4 (INTEGER)
25    - TEXT
114   - JSON
700   - FLOAT4 (REAL)
701   - FLOAT8 (DOUBLE PRECISION)
1043  - VARCHAR
1082  - DATE
1114  - TIMESTAMP
1184  - TIMESTAMPTZ
1700  - NUMERIC
2950  - UUID
3802  - JSONB
```

## Implementation Guide

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Type handler template
- Testing requirements
- Integration test setup

## Resources

- [PostgreSQL Data Types](https://www.postgresql.org/docs/current/datatype.html)
- [Binary Wire Protocol](https://www.postgresql.org/docs/current/protocol-message-formats.html)
- [Type Input/Output Functions](https://github.com/postgres/postgres/tree/master/src/backend/utils/adt)

---

**Last Updated**: 2024-11-07
