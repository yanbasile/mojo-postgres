# 🔥 mojo-postgres

Pure Mojo PostgreSQL driver for high-performance database access.

> ⚠️ **Alpha Status**: This driver is under active development. Core functionality (Phase 1) is being implemented. Not production-ready yet.

## Why Mojo-Postgres?

Traditional Python database drivers (psycopg2, asyncpg) are excellent but limited by Python's performance constraints. For high-frequency data ingestion (like time-series data, trading systems, IoT), we need:

- **Zero-copy operations**: Direct memory access without Python overhead
- **Predictable latency**: No GIL, no garbage collection pauses  
- **SIMD acceleration**: Vectorized encoding/decoding of bulk data
- **Compile-time optimization**: Type-safe protocol implementation

### Performance Goals (vs psycopg2)
```
Metric                  psycopg2        mojo-postgres (target)
─────────────────────────────────────────────────────────────
Single INSERT           ~1,000/sec      ~10,000/sec (10x)
Bulk COPY               ~50,000/sec     ~500,000/sec (10x)
Connection setup        ~2ms            ~0.5ms (4x)
Memory per connection   ~500KB          ~50KB (10x reduction)
```

## Current Status

### Phase 1: Core Types (In Progress - 0% complete)

| Type | Status | Priority | Notes |
|------|--------|----------|-------|
| INT4 | 📋 TODO | P0 | Foundation type |
| INT8 | 📋 TODO | P0 | Timestamps, large numbers |
| FLOAT8 | 📋 TODO | P0 | **CRITICAL** for trading prices |
| TIMESTAMPTZ | 📋 TODO | P0 | **CRITICAL** for TimescaleDB |
| TEXT | 📋 TODO | P0 | Strings, symbols |
| NUMERIC | 📋 TODO | P0 | Exact financial calculations |
| BOOLEAN | 📋 TODO | P0 | Flags |
| JSONB | 📋 TODO | P1 | Flexible metadata |

[See full roadmap →](ROADMAP.md)

## Quick Start (Coming Soon)

### Installation
```bash
# Clone the repository
git clone https://github.com/yanbasile/mojo-postgres.git
cd mojo-postgres

# Requires Mojo 24.5 or later
mojo --version
```

### Basic Usage (Target API)
```mojo
from mojo_postgres import PostgresClient

fn main() raises:
    # Connect to database
    var client = PostgresClient.connect(
        host="localhost",
        port=5432,
        database="mydb",
        user="postgres",
        password="password"
    )
    
    # Simple query
    var result = client.query("SELECT * FROM users WHERE id = $1", 42)
    
    # Iterate results
    for row in result:
        print(row.get_int("id"), row.get_text("name"))
    
    client.close()
```

### TimescaleDB Example (Target API)
```mojo
from mojo_postgres import PostgresClient
from time import now

fn insert_orderbook_snapshot(client: PostgresClient) raises:
    var timestamp = now()
    var query = """
        INSERT INTO orderbook_snapshots 
        (timestamp, exchange, symbol, bid_price, ask_price, volume)
        VALUES ($1, $2, $3, $4, $5, $6)
    """
    
    client.execute(query,
        timestamp,
        "binance",
        "BTC/USDT", 
        42150.50,
        42151.25,
        1.5
    )
```

## Contributing

We welcome contributions! Especially for Phase 2 & 3 type implementations.

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for:
- Type handler implementation guide
- Testing requirements
- Code review process

**Good First Issues**: Look for `good-first-issue` label
- UUID type handler
- DATE type handler  
- INET type handler

## Architecture
```
mojo-postgres/
├── src/
│   ├── protocol/          # PostgreSQL wire protocol
│   │   ├── connection.mojo
│   │   ├── messages.mojo
│   │   └── auth.mojo
│   ├── types/             # Type encoding/decoding
│   │   ├── numeric.mojo   # INT*, FLOAT*, NUMERIC
│   │   ├── temporal.mojo  # TIMESTAMP*, INTERVAL
│   │   ├── text.mojo      # TEXT, VARCHAR, CHAR
│   │   └── json.mojo      # JSON, JSONB
│   ├── pool/              # Connection pooling
│   └── client.mojo        # High-level API
└── tests/
    ├── unit/              # Type & protocol tests
    └── integration/       # Real PostgreSQL tests
```

[Detailed architecture →](docs/ARCHITECTURE.md)

## Roadmap

- **Q1 2025**: Phase 1 complete (15 core types, simple query)
- **Q2 2025**: Phase 2 (extended query, prepared statements, pooling)
- **Q3 2025**: Phase 3 (COPY protocol, LISTEN/NOTIFY)
- **Q4 2025**: v1.0 production release

## Project Background

Built for the [MDDC-AI](https://github.com/yanbasile/mddc-ai) cryptocurrency trading system, which requires:
- High-frequency orderbook data collection (100Hz+)
- TimescaleDB integration for time-series storage
- Sub-millisecond latency for trading decisions
- Zero-copy data pipelines from network to GPU

## Resources

- [PostgreSQL Frontend/Backend Protocol](https://www.postgresql.org/docs/current/protocol.html)
- [PostgreSQL Type OIDs](https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat)
- [Mojo Documentation](https://docs.modular.com/mojo/)
- [TimescaleDB Documentation](https://docs.timescale.com/)

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

Inspired by:
- [psycopg2](https://www.psycopg.org/) - The gold standard Python PostgreSQL driver
- [rust-postgres](https://github.com/sfackler/rust-postgres) - Excellent Rust implementation
- [tokio-postgres](https://github.com/sfackler/rust-postgres/tree/master/tokio-postgres) - Async Rust driver

---

**Status**: 🚧 Alpha - Under Active Development  
**Mojo Version**: 24.5+  
**PostgreSQL**: 12+ (tested with 16)  
**Maintainer**: [@yanbasile](https://github.com/yanbasile)
