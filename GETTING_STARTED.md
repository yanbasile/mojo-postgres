# Getting Started with mojo-postgres

This guide will help you get up and running with mojo-postgres quickly.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Basic Connection](#basic-connection)
4. [Simple Queries](#simple-queries)
5. [Working with Types](#working-with-types)
6. [Prepared Statements](#prepared-statements)
7. [Connection Pooling](#connection-pooling)
8. [Batch Operations](#batch-operations)
9. [Transactions](#transactions)
10. [Best Practices](#best-practices)

---

## Prerequisites

- **Mojo**: Version 24.5 or later
- **PostgreSQL**: Version 12+ (tested with 16)
- **Operating System**: Linux, macOS, or Windows (with WSL)

### Check your Mojo version
```bash
mojo --version
```

### Start PostgreSQL (Docker)
```bash
# Quick test database
docker run -d \
  --name postgres-test \
  -p 5432:5432 \
  -e POSTGRES_USER=test \
  -e POSTGRES_PASSWORD=test \
  -e POSTGRES_DB=test \
  postgres:16

# Verify it's running
docker ps | grep postgres-test
```

---

## Installation

```bash
# Clone the repository
git clone https://github.com/yanbasile/mojo-postgres.git
cd mojo-postgres

# Run the basic example
mojo examples/basic_connection.mojo
```

---

## Basic Connection

Create a file `hello_postgres.mojo`:

```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    print("Connecting to PostgreSQL...")

    # Create connection
    var conn = PostgresConnection("localhost", 5432)

    # Connect with credentials
    conn.connect("test", "test", "test")

    print("✅ Connected successfully!")

    # Always close when done
    conn.close()

    print("✅ Connection closed")
```

Run it:
```bash
mojo hello_postgres.mojo
```

**Output:**
```
Connecting to PostgreSQL...
✅ Connected successfully!
✅ Connection closed
```

---

## Simple Queries

### CREATE TABLE
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create a table
    var _ = conn.query("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            age INT,
            created_at TIMESTAMP DEFAULT NOW()
        )
    """)

    print("✅ Table created")
    conn.close()
```

### INSERT Data
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Insert a user
    var _ = conn.query("""
        INSERT INTO users (name, email, age)
        VALUES ('Alice', 'alice@example.com', 30)
    """)

    print("✅ User inserted")
    conn.close()
```

### SELECT Data
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query users
    var result = conn.query("SELECT id, name, email, age FROM users")

    print("Users:")
    for i in range(result.row_count()):
        var id = result.get_int4(i, 0)
        var name = result.get_value(i, 1)
        var email = result.get_value(i, 2)
        var age = result.get_int4(i, 3)

        print("  [" + String(id) + "] " + name + " <" + email + "> (age: " + String(age) + ")")

    conn.close()
```

---

## Working with Types

mojo-postgres supports 14 PostgreSQL types. Here's how to use them:

### Integer Types
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var result = conn.query("SELECT 42::INT2, 1000::INT4, 9999999999::INT8")

    var int2_val = result.get_int2(0, 0)  # SMALLINT (16-bit)
    var int4_val = result.get_int4(0, 1)  # INTEGER (32-bit)
    var int8_val = result.get_int8(0, 2)  # BIGINT (64-bit)

    print("INT2:", int2_val)
    print("INT4:", int4_val)
    print("INT8:", int8_val)

    conn.close()
```

### Float Types
```mojo
var result = conn.query("SELECT 3.14::FLOAT4, 3.14159265358979::FLOAT8")

var float4_val = result.get_float4(0, 0)  # REAL (32-bit)
var float8_val = result.get_float8(0, 1)  # DOUBLE PRECISION (64-bit)

print("FLOAT4:", float4_val)
print("FLOAT8:", float8_val)
```

### Text Types
```mojo
var result = conn.query("SELECT 'Hello'::TEXT, 'World'::VARCHAR")

var text_val = result.get_value(0, 0)  # TEXT
var varchar_val = result.get_value(0, 1)  # VARCHAR

print("TEXT:", text_val)
print("VARCHAR:", varchar_val)
```

### Boolean
```mojo
var result = conn.query("SELECT TRUE, FALSE")

var bool1 = result.get_boolean(0, 0)
var bool2 = result.get_boolean(0, 1)

print("TRUE:", bool1)
print("FALSE:", bool2)
```

### Temporal Types
```mojo
var result = conn.query("""
    SELECT
        '2024-01-15 10:30:00'::TIMESTAMP,
        '2024-01-15 10:30:00+00'::TIMESTAMPTZ,
        '2024-01-15'::DATE,
        '10:30:00'::TIME
""")

var timestamp = result.get_timestamp(0, 0)
var timestamptz = result.get_timestamptz(0, 1)
var date = result.get_date(0, 2)
var time = result.get_time(0, 3)

print("TIMESTAMP:", timestamp.to_string())
print("DATE:", date.to_string())
print("TIME:", time.to_string())
```

### NUMERIC (Exact Decimals)
```mojo
var result = conn.query("SELECT 12345.6789::NUMERIC(10,4)")

var numeric = result.get_numeric(0, 0)
print("NUMERIC:", numeric.to_string())
```

### JSONB
```mojo
var result = conn.query("""
    SELECT '{"name": "Alice", "age": 30, "active": true}'::JSONB
""")

var json_str = result.get_jsonb(0, 0)
print("JSONB:", json_str)
```

---

## Prepared Statements

Prepared statements are **5-10x faster** than simple queries for repeated execution.

### Basic Prepared Statement
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Prepare statement ONCE
    var stmt = conn.prepare("SELECT * FROM users WHERE age > $1")

    # Execute MANY times (fast!)
    for min_age in range(20, 50, 5):
        var params = List[String]()
        params.append(String(min_age))

        var result = conn.execute_prepared(stmt, params)
        print("Users older than", min_age, ":", result.row_count())

    conn.close()
```

### Binary Format (3-5x faster encoding!)
```mojo
from src.protocol.connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    var stmt = conn.prepare("SELECT id, name FROM users WHERE age = $1")

    var params = List[String]()
    params.append("30")

    # Use binary format for results
    var result = conn.execute_prepared_binary(stmt, params)

    for i in range(result.row_count()):
        var id = result.get_int4(i, 0)
        var name = result.get_value(i, 1)
        print(id, name)

    conn.close()
```

---

## Connection Pooling

Connection pooling provides **100x faster** connection reuse!

### Basic Pool Usage
```mojo
from src.pool.connection_pool import ConnectionPool

fn main() raises:
    # Create pool
    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")

    # Configure pool size (min=5, max=20)
    pool.set_pool_size(5, 20)

    # Initialize pool (creates min connections)
    pool.initialize()

    # Acquire connection from pool (instant!)
    var conn = pool.acquire()

    # Use connection
    var result = conn.query("SELECT COUNT(*) FROM users")
    var count = result.get_int4(0, 0)
    print("Total users:", count)

    # Release back to pool (important!)
    pool.release(conn)

    # Cleanup
    pool.close_all()
```

### Pool Statistics
```mojo
from src.pool.connection_pool import ConnectionPool

fn main() raises:
    var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
    pool.set_pool_size(2, 10)
    pool.initialize()

    # Get pool stats
    var stats = pool.get_stats()
    print(stats.to_string())
    # Output: PoolStats(total=2, in_use=0, idle=2)

    var conn = pool.acquire()
    stats = pool.get_stats()
    print(stats.to_string())
    # Output: PoolStats(total=2, in_use=1, idle=1)

    pool.release(conn)
    pool.close_all()
```

---

## Batch Operations

Batch operations provide **10-50x faster** bulk inserts!

### Batch INSERT
```mojo
from src.protocol.connection import PostgresConnection
from src.core.batch_operations import BatchInsert

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Define columns
    var columns = List[String]()
    columns.append("name")
    columns.append("email")
    columns.append("age")

    # Create batch
    var batch = BatchInsert("users", columns)

    # Add rows
    for i in range(1000):
        var values = List[String]()
        values.append("User" + String(i))
        values.append("user" + String(i) + "@example.com")
        values.append(String(25 + (i % 30)))
        batch.add_row(values)

    # Execute as SINGLE INSERT (fast!)
    batch.execute(conn)

    print("✅ Inserted", batch.row_count(), "rows in single batch")

    conn.close()
```

### Batch UPDATE
```mojo
from src.protocol.connection import PostgresConnection
from src.core.batch_operations import BatchUpdate

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create batch
    var batch = BatchUpdate("users")

    # Add updates
    batch.add_update("age = age + 1", "age < 30")
    batch.add_update("age = age + 2", "age >= 30 AND age < 40")
    batch.add_update("age = age + 3", "age >= 40")

    # Execute in single transaction
    batch.execute(conn)

    print("✅ Executed", batch.update_count(), "updates in transaction")

    conn.close()
```

---

## Transactions

### Basic Transaction
```mojo
from src.protocol.connection import PostgresConnection
from src.protocol.transaction import begin_transaction, commit_transaction, rollback_transaction

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    try:
        # Start transaction
        begin_transaction(conn)

        # Multiple operations
        var _ = conn.query("UPDATE users SET age = age + 1 WHERE id = 1")
        var __ = conn.query("UPDATE users SET age = age + 1 WHERE id = 2")

        # Commit if successful
        commit_transaction(conn)
        print("✅ Transaction committed")

    except e:
        # Rollback on error
        rollback_transaction(conn)
        print("❌ Transaction rolled back:", e)

    conn.close()
```

### Savepoints
```mojo
from src.protocol.connection import PostgresConnection
from src.protocol.transaction import *

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    begin_transaction(conn)

    var _ = conn.query("UPDATE users SET age = 30 WHERE id = 1")

    # Create savepoint
    create_savepoint(conn, "sp1")

    var __ = conn.query("UPDATE users SET age = 40 WHERE id = 2")

    # Rollback to savepoint (undo second update)
    rollback_to_savepoint(conn, "sp1")

    commit_transaction(conn)  # Only first update committed

    conn.close()
```

---

## Best Practices

### 1. Always Close Connections
```mojo
fn query_database() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    try:
        var result = conn.query("SELECT * FROM users")
        # Process result...
    except:
        conn.close()
        raise

    conn.close()  # Always close!
```

### 2. Use Connection Pooling for Production
```mojo
# Create pool once at startup
var pool = ConnectionPool("localhost", 5432, "test", "test", "test")
pool.set_pool_size(10, 50)
pool.initialize()

# Reuse pool for all queries
fn handle_request() raises:
    var conn = pool.acquire()
    try:
        var result = conn.query("...")
        # Process...
    except:
        pool.release(conn)
        raise

    pool.release(conn)
```

### 3. Use Prepared Statements for Repeated Queries
```mojo
# ❌ Bad: Re-preparing every time
for i in range(1000):
    var stmt = conn.prepare("SELECT * FROM users WHERE id = $1")
    var params = List[String]()
    params.append(String(i))
    var result = conn.execute_prepared(stmt, params)

# ✅ Good: Prepare once
var stmt = conn.prepare("SELECT * FROM users WHERE id = $1")
for i in range(1000):
    var params = List[String]()
    params.append(String(i))
    var result = conn.execute_prepared(stmt, params)
```

### 4. Use Binary Format for Performance
```mojo
# Use binary format when querying numeric types
var stmt = conn.prepare("SELECT id, price, quantity FROM orders WHERE symbol = $1")
var params = List[String]()
params.append("BTC/USDT")

# Binary format is 3-5x faster!
var result = conn.execute_prepared_binary(stmt, params)
```

### 5. Use Batch Operations for Bulk Data
```mojo
# ❌ Bad: Individual inserts
for i in range(10000):
    var _ = conn.query("INSERT INTO logs (message) VALUES ('Log " + String(i) + "')")

# ✅ Good: Batch insert (50x faster!)
var batch = BatchInsert("logs", ["message"])
for i in range(10000):
    var values = List[String]()
    values.append("Log " + String(i))
    batch.add_row(values)
batch.execute(conn)
```

### 6. Use Transactions for Data Integrity
```mojo
# Money transfer example
begin_transaction(conn)
try:
    var _ = conn.query("UPDATE accounts SET balance = balance - 100 WHERE id = 1")
    var __ = conn.query("UPDATE accounts SET balance = balance + 100 WHERE id = 2")
    commit_transaction(conn)
except:
    rollback_transaction(conn)
    raise
```

---

## Next Steps

- 📖 Read [TOUR.md](TOUR.md) for a complete feature tour
- 🏗️ Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for internals
- 🔬 See [examples/](examples/) for more code samples
- 🚀 See [benchmarks/](benchmarks/) for performance tests

**Happy coding with mojo-postgres!** 🔥
