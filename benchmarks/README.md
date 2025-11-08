# Benchmarks

Performance benchmarks for mojo-postgres, comparing against Python PostgreSQL drivers (psycopg2 and asyncpg).

## Performance Targets

Our goal is to achieve **10x performance improvement** over psycopg2 for most operations:

| Metric | psycopg2 | mojo-postgres (target) | Status |
|--------|----------|------------------------|--------|
| Connection setup | ~2ms | ~0.5ms (4x faster) | 📋 TODO |
| Single INSERT | ~1,000/sec | ~10,000/sec (10x) | 📋 TODO |
| Bulk COPY | ~50,000/sec | ~500,000/sec (10x) | 📋 TODO |
| Memory/connection | ~500KB | ~50KB (10x reduction) | 📋 TODO |

## Available Benchmarks

### Task 1.1 Benchmarks (Connection & Auth)

- **bench_connection.mojo** - Connection establishment time (TCP + auth + ready)
- **bench_auth.mojo** - MD5 password hashing overhead
- **bench_socket_throughput.mojo** - Raw socket I/O throughput
- **bench_memory.mojo** - Memory usage per connection

### Python Baselines

- **baseline/bench_connection.py** - psycopg2 connection benchmark
- **baseline/bench_connection_async.py** - asyncpg connection benchmark

## Prerequisites

### PostgreSQL Test Database

You need a running PostgreSQL instance for benchmarking:

```bash
# Using Docker (recommended for consistency)
docker run -d \
  --name postgres-bench \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=benchpass \
  -e POSTGRES_USER=benchuser \
  -e POSTGRES_DB=benchdb \
  postgres:16

# Verify it's running
docker ps | grep postgres-bench
```

### Python Environment (for baselines)

```bash
cd benchmarks/baseline
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Running Benchmarks

### Run All Mojo Benchmarks

```bash
# From project root
cd benchmarks

# Connection benchmark
mojo bench_connection.mojo

# Authentication benchmark
mojo bench_auth.mojo

# Socket throughput benchmark
mojo bench_socket_throughput.mojo

# Memory usage benchmark
mojo bench_memory.mojo
```

### Run Python Baselines

```bash
cd benchmarks/baseline
source venv/bin/activate

# psycopg2 benchmark
python bench_connection.py

# asyncpg benchmark
python bench_connection_async.py
```

### Compare Results

The Mojo benchmarks will automatically attempt to compare against Python baselines if available. You can also manually compare by running both and noting the times.

## Benchmark Configuration

Default configuration (can be modified in each benchmark file):

```mojo
# Connection details
const HOST = "localhost"
const PORT = 5432
const DATABASE = "benchdb"
const USER = "benchuser"
const PASSWORD = "benchpass"

# Benchmark parameters
const ITERATIONS = 1000        # Number of iterations
const WARMUP_ITERATIONS = 10   # Warmup runs (not counted)
```

## Understanding Results

Each benchmark outputs:

### Timing Statistics
- **Mean**: Average time per operation
- **Median**: 50th percentile (middle value)
- **P95**: 95th percentile (slower than 95% of runs)
- **P99**: 99th percentile (slower than 99% of runs)
- **Min/Max**: Fastest and slowest runs
- **Throughput**: Operations per second

### Performance Rating

- ✅ **TARGET EXCEEDED**: 10x+ faster than Python
- ✅ **EXCELLENT**: 4x+ faster than Python
- ✅ **GOOD**: 2x+ faster than Python
- ⚠️ **SLOWER THAN TARGET**: Faster, but below 2x goal
- ❌ **NEEDS OPTIMIZATION**: Slower than Python

## Example Output

```
======================================================================
Benchmark: PostgreSQL Connection Establishment
======================================================================
Iterations:      1000
Total Time:      486.23 ms
Mean:            486.23 μs
Median:          475.12 μs
Min:             421.34 μs
Max:             892.45 μs
P95:             612.78 μs
P99:             745.23 μs
Memory:          45.2 KB
Throughput:      2056 ops/sec
======================================================================

======================================================================
COMPARISON: mojo-postgres vs psycopg2
======================================================================
Mojo:            0.486 ms
psycopg2:        2.145 ms
Speedup:         4.41x faster
Status:          ✅ EXCELLENT (4x+ faster)
======================================================================
```

## Profiling

For detailed profiling, you can use:

### Linux `perf`
```bash
perf record -g mojo bench_connection.mojo
perf report
```

### macOS Instruments
```bash
# Compile first
mojo build bench_connection.mojo
# Then profile with Instruments
```

## Troubleshooting

### Connection Refused
- Ensure PostgreSQL is running: `docker ps`
- Check port mapping: `docker port postgres-bench`
- Verify credentials match

### Slow Benchmarks
- Ensure PostgreSQL is on localhost (network latency matters)
- Check Docker resource limits
- Disable debug logging
- Use release build (Mojo may add this in future)

### Memory Benchmarks Inaccurate
- Close other applications
- Run multiple times and average
- Use dedicated benchmark machine for production measurements

## Adding New Benchmarks

See `harness.mojo` for the benchmark framework. Basic template:

```mojo
from benchmarks.harness import benchmark, BenchmarkResult

fn my_operation() raises:
    # Your code to benchmark
    pass

fn main() raises:
    var result = benchmark[my_operation]("My Operation", iterations=1000)
    result.print_report()
```

## Continuous Benchmarking

For tracking performance over time, consider:
- Running benchmarks on every commit
- Storing results in a database
- Plotting trends
- Setting up alerts for regressions

(Infrastructure for this coming in Phase 2)

## Contributing

When adding new features:
1. Add corresponding benchmarks
2. Include Python baseline comparison
3. Document expected performance improvement
4. Update this README

## Resources

- [PostgreSQL Performance Tips](https://www.postgresql.org/docs/current/performance-tips.html)
- [Mojo Performance Guide](https://docs.modular.com/mojo/manual/performance/)
- [psycopg2 Performance](https://www.psycopg.org/docs/usage.html#optimization)
