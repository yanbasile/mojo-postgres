# Quick Start Guide - mojo-postgres v1.0.0

Get up and running with mojo-postgres in 5 minutes!

## Prerequisites

**1. Install Mojo** (if not already installed)
```bash
curl https://get.modular.com | sh -
modular install mojo
```

**2. Set up PostgreSQL**
```bash
# Option A: Using Docker (recommended for testing)
docker run -d \
  --name postgres-test \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  -e POSTGRES_USER=test \
  -e POSTGRES_DB=test \
  postgres:16

# Option B: Install locally
# macOS
brew install postgresql@16
brew services start postgresql@16

# Ubuntu/Debian
sudo apt-get install postgresql-16
sudo systemctl start postgresql
```

**3. Clone mojo-postgres**
```bash
git clone https://github.com/yanbasile/mojo-postgres.git
cd mojo-postgres
```

---

## Your First Query (60 seconds)

Create `my_first_query.mojo`:

```mojo
from connection import PostgresConnection

fn main() raises:
    # Connect
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Query
    var result = conn.execute("SELECT version()")

    # Display
    print("PostgreSQL version:")
    print(result.get_string(0, 0))

    # Close
    conn.close()
```

Run it:
```bash
mojo my_first_query.mojo
```

**Expected output:**
```
PostgreSQL version:
PostgreSQL 16.1 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 12.2.0, 64-bit
```

✅ **Congratulations!** You just queried PostgreSQL from Mojo.

---

## Insert Data (2 minutes)

Create `insert_data.mojo`:

```mojo
from connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create table
    _ = conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
    """)

    # Insert data
    _ = conn.execute("""
        INSERT INTO users (name, email)
        VALUES ('Alice', 'alice@example.com'),
               ('Bob', 'bob@example.com'),
               ('Charlie', 'charlie@example.com')
    """)

    # Query back
    var result = conn.execute("SELECT id, name, email FROM users ORDER BY id")

    print("Users:")
    for i in range(result.row_count()):
        var id = result.get_int(i, 0)
        var name = result.get_string(i, 1)
        var email = result.get_string(i, 2)
        print("  ", id, "-", name, "(" + email + ")")

    conn.close()
```

Run it:
```bash
mojo insert_data.mojo
```

**Expected output:**
```
Users:
   1 - Alice (alice@example.com)
   2 - Bob (bob@example.com)
   3 - Charlie (charlie@example.com)
```

---

## Connection Pooling (Production-Ready)

For production, use connection pooling for 100x better performance:

Create `use_pool.mojo`:

```mojo
from pool import create_connection_pool

fn main() raises:
    # Create pool (reuses connections)
    var pool = create_connection_pool(
        host="localhost",
        port=5432,
        database="test",
        user="test",
        password="test",
        min_connections=5,
        max_connections=20
    )

    # Acquire connection from pool
    var conn = pool.acquire()

    # Use connection
    var result = conn.execute("SELECT COUNT(*) FROM users")
    var count = result.get_int(0, 0)
    print("Total users:", count)

    # Return to pool (NOT close!)
    pool.release(conn)

    # Close pool when done
    pool.close_all()
```

**Key difference:** `pool.release(conn)` returns the connection to the pool for reuse, while `conn.close()` permanently closes it.

---

## Prepared Statements (10-20x Faster)

For repeated queries, use prepared statements:

```mojo
from connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Prepare statement once
    var stmt = conn.prepare("""
        SELECT id, name, email
        FROM users
        WHERE id = $1
    """)

    # Execute multiple times with different parameters
    var result1 = stmt.execute(1)  # Get user with id=1
    var result2 = stmt.execute(2)  # Get user with id=2
    var result3 = stmt.execute(3)  # Get user with id=3

    print("User 1:", result1.get_string(0, 1))
    print("User 2:", result2.get_string(0, 1))
    print("User 3:", result3.get_string(0, 1))

    conn.close()
```

**Performance:** Prepared statements parse the SQL once and execute many times. **10-20x faster** than repeating `execute()`.

---

## Transactions (ACID Guarantees)

Ensure data consistency with transactions:

```mojo
from connection import PostgresConnection

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    try:
        # Begin transaction
        conn.begin()

        # Multiple operations (all-or-nothing)
        _ = conn.execute("UPDATE users SET email = 'newemail@example.com' WHERE id = 1")
        _ = conn.execute("INSERT INTO audit_log (action) VALUES ('email_changed')")

        # Commit if successful
        conn.commit()
        print("✅ Transaction committed successfully")

    except:
        # Rollback on error
        conn.rollback()
        print("❌ Transaction rolled back")

    conn.close()
```

---

## Bulk Operations with COPY (100x Faster)

For large data sets, use the COPY protocol:

```mojo
from connection import PostgresConnection
from copy import CopyWriter

fn main() raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("test", "test", "test")

    # Create COPY writer
    var copy = CopyWriter(conn, "users", List[String]("name", "email"))

    # Add 10,000 rows efficiently
    for i in range(10000):
        copy.add_row(List[String](
            "User" + String(i),
            "user" + String(i) + "@example.com"
        ))

    # Execute COPY
    copy.execute()

    print("✅ Inserted 10,000 rows using COPY protocol")

    conn.close()
```

**Performance:** COPY is **10-100x faster** than INSERT for bulk data.

---

## TimescaleDB Time-Series (New in v1.0.0!)

For time-series data, use TimescaleDB with hypertables:

```mojo
from timescaledb.pool import create_timescaledb_pool

fn main() raises:
    var pool = create_timescaledb_pool(
        host="localhost",
        port=5432,
        database="trading",
        user="postgres",
        password="postgres",
        min_connections=5,
        max_connections=20
    )

    var conn = pool.pool.acquire()

    # Create hypertable
    _ = conn.execute("""
        CREATE TABLE IF NOT EXISTS sensor_data (
            time TIMESTAMPTZ NOT NULL,
            sensor_id INT NOT NULL,
            temperature FLOAT8,
            humidity FLOAT8
        )
    """)

    _ = conn.execute("""
        SELECT create_hypertable(
            'sensor_data', 'time',
            if_not_exists => TRUE
        )
    """)

    # Query hypertable metadata
    var metadata = pool.get_hypertable_metadata("sensor_data")
    print("Hypertable:", metadata.table_name)
    print("Time column:", metadata.time_column)
    print("Number of chunks:", metadata.num_chunks)

    pool.pool.release(conn)
    pool.pool.close_all()
```

**TimescaleDB benefits:**
- 2-5x faster time-range queries (chunk pruning)
- 50-90% storage reduction (compression)
- 10-100x faster aggregations (continuous aggregates)

See `examples/mddc_ai_trading.mojo` for complete trading system example!

---

## Next Steps

### Examples to Try

1. **Simple Queries**
   ```bash
   mojo examples/simple_query.mojo
   ```

2. **Connection Pooling**
   ```bash
   mojo examples/connection_pool.mojo
   ```

3. **Transactions**
   ```bash
   mojo examples/transactions.mojo
   ```

4. **Production Demo (E-Commerce)**
   ```bash
   mojo examples/demo_ecommerce.mojo
   ```

5. **TimescaleDB Trading System**
   ```bash
   mojo examples/mddc_ai_trading.mojo
   mojo examples/mddc_ai_analytics.mojo
   ```

### Comprehensive Guides

- **[TOUR.md](TOUR.md)** - Complete feature tour
- **[MDDC_AI_INTEGRATION.md](MDDC_AI_INTEGRATION.md)** - TimescaleDB trading system
- **[RESILIENCE_GUIDE.md](RESILIENCE_GUIDE.md)** - Enterprise features
- **[ACCOMPLISHMENTS.md](ACCOMPLISHMENTS.md)** - Full feature list

### Learn More

- **[ROADMAP.md](../ROADMAP.md)** - Project roadmap and status
- **[USE_CASES.md](USE_CASES.md)** - 12 real-world use cases
- **[BENCHMARK_PLAN.md](BENCHMARK_PLAN.md)** - Performance testing
- **[RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md)** - What's new in v1.0.0

---

## Common Patterns

### Pattern 1: Read-Only Query

```mojo
from pool import create_connection_pool

fn query_user_by_email(email: String) raises -> Int:
    var pool = create_connection_pool(...)
    var conn = pool.acquire()

    var stmt = conn.prepare("SELECT id FROM users WHERE email = $1")
    var result = stmt.execute(email)
    var user_id = result.get_int(0, 0)

    pool.release(conn)
    return user_id
```

### Pattern 2: Transactional Write

```mojo
fn transfer_money(from_id: Int, to_id: Int, amount: Float64) raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("bank", "user", "password")

    conn.begin()

    try:
        _ = conn.execute("UPDATE accounts SET balance = balance - " + String(amount) + " WHERE id = " + String(from_id))
        _ = conn.execute("UPDATE accounts SET balance = balance + " + String(amount) + " WHERE id = " + String(to_id))
        conn.commit()
    except:
        conn.rollback()
        raise Error("Transfer failed")

    conn.close()
```

### Pattern 3: Batch Insert

```mojo
from copy import CopyWriter

fn bulk_insert_logs(logs: List[LogEntry]) raises:
    var conn = PostgresConnection("localhost", 5432)
    conn.connect("logs", "user", "password")

    var copy = CopyWriter(conn, "logs", List[String]("timestamp", "level", "message"))

    for log in logs:
        copy.add_row(List[String](log.timestamp, log.level, log.message))

    copy.execute()
    conn.close()
```

---

## Troubleshooting

### Connection Refused

```
Error: connection refused (localhost:5432)
```

**Solution:** Ensure PostgreSQL is running:
```bash
# Check if running
docker ps  # If using Docker
# OR
sudo systemctl status postgresql  # If installed locally

# Start if needed
docker start postgres-test
# OR
sudo systemctl start postgresql
```

### Authentication Failed

```
Error: authentication failed for user "test"
```

**Solution:** Check your credentials:
```bash
# Test connection with psql
psql -h localhost -U test -d test -W

# If that works, check your Mojo code has correct credentials
```

### Table Already Exists

```
Error: relation "users" already exists
```

**Solution:** Use `CREATE TABLE IF NOT EXISTS` or drop the table first:
```mojo
_ = conn.execute("DROP TABLE IF EXISTS users")
```

---

## Performance Tips

1. **Use Connection Pooling** - 100x faster than creating new connections
2. **Use Prepared Statements** - 10-20x faster for repeated queries
3. **Use COPY for Bulk Inserts** - 10-100x faster than INSERT
4. **Enable Binary Protocol** - 3-5x faster encoding/decoding
5. **Use TimescaleDB for Time-Series** - 2-5x faster queries, 90% compression

---

## Need Help?

- **Documentation:** Full guides in `docs/` directory
- **Examples:** 20+ examples in `examples/` directory
- **Issues:** https://github.com/yanbasile/mojo-postgres/issues
- **Release Notes:** [RELEASE_NOTES_v1.0.0.md](RELEASE_NOTES_v1.0.0.md)

---

**Congratulations!** 🎉 You're now ready to build high-performance database applications with mojo-postgres!

Next: Try the [complete feature tour](TOUR.md) or explore [real-world use cases](USE_CASES.md).
