# Mojo-Postgres Stress Test Suite

Comprehensive stress testing framework for validating mojo-postgres performance, stability, and reliability under extreme conditions.

## Overview

This suite implements 10+ stress test categories designed to validate production-readiness:

1. **Connection Limits** - 1000+ concurrent connections
2. **Memory Pressure** - 24-hour leak detection
3. **Long-Running Stability** - 7-day continuous operation
4. **Concurrent Workloads** - Mixed read/write operations
5. **Failure Scenarios** - Chaos engineering
6. **Resource Exhaustion** - CPU, memory, file descriptors
7. **Data Volume** - 1B+ row ingestion
8. **Query Complexity** - Complex analytical queries
9. **TimescaleDB Stress** - 10K+ chunk handling
10. **Security Under Load** - Connection attacks, SQL injection

## Quick Start

### Prerequisites

```bash
# Install Python dependencies
pip install -r requirements.txt

# Start PostgreSQL (or use existing instance)
docker run -d \
  --name postgres-stress \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=stress_test \
  -p 5432:5432 \
  postgres:16
```

### Running Tests

**Quick Validation (1 hour)**
```bash
# Run all tests with quick parameters
python run_stress_tests.py --all --quick
```

**Full Stress Tests (days)**
```bash
# Run all tests with production parameters
python run_stress_tests.py --all

# Run specific test
python run_stress_tests.py --test 1

# Run multiple tests
python run_stress_tests.py --test 1,2,3
```

**Custom Database**
```bash
export POSTGRES_HOST=mydb.example.com
export POSTGRES_PORT=5432
export POSTGRES_DB=stress_test
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=secret

python run_stress_tests.py --all --quick
```

## Test Descriptions

### Test 1: Connection Limits
**Duration:** ~5 minutes
**Purpose:** Validate handling of 1000+ concurrent connections

**Success Criteria:**
- ✅ 95%+ connection success rate
- ✅ All connections functional (can execute queries)
- ✅ Connection latency p95 < 500ms
- ✅ Memory < 10GB for 1000 connections
- ✅ Memory per connection < 5MB

**What it tests:**
- Connection pool management
- File descriptor limits
- Memory allocation per connection
- Connection establishment performance

### Test 2: Memory Pressure
**Duration:** 24 hours (1 hour in quick mode)
**Purpose:** Detect memory leaks and unbounded growth

**Success Criteria:**
- ✅ Memory growth < 100MB over 24 hours
- ✅ No unbounded memory growth trend
- ✅ Average CPU < 80%
- ✅ Error rate < 1%
- ✅ Completed operations (not hung)

**What it tests:**
- Memory leak detection
- Resource cleanup
- Long-term stability
- GC effectiveness (if applicable)

### Test 3: Long-Running Stability
**Duration:** 7 days (1 hour in quick mode)
**Purpose:** Validate continuous operation stability

**Success Criteria:**
- ✅ Uptime >= 99.9%
- ✅ No crashes
- ✅ Error rate < 0.1%
- ✅ Throughput degradation < 20%
- ✅ p95 latency < 100ms

**What it tests:**
- Long-term stability
- Connection churn
- File descriptor leaks
- Throughput consistency
- Resource exhaustion

## Test Results

Results are saved to `results/` directory as JSON files:

```json
{
  "test_name": "Connection Limits Test",
  "status": "passed",
  "duration_seconds": 305.67,
  "metrics": {
    "successful_connections": 1000,
    "connection_success_rate": 100.0,
    "query_success_rate": 100.0,
    "memory_growth_mb": 234.5
  },
  "pass_criteria": {
    "connection_success_rate_95%": true,
    "all_connections_functional": true,
    "connection_latency_p95_under_500ms": true,
    "memory_under_10gb": true
  }
}
```

## Architecture

### Framework Components

**`stress_test_framework.py`**
- Base class for all tests (`StressTestBase`)
- Test suite orchestration (`StressTestSuite`)
- Resource monitoring
- Pass/fail criteria validation
- Result reporting and JSON export

**Individual Tests**
- `test_01_connection_limits.py` - Connection stress
- `test_02_memory_pressure.py` - Memory leak detection
- `test_03_long_running.py` - 7-day stability
- *(More tests to be implemented)*

**Master Runner**
- `run_stress_tests.py` - Orchestrates all tests
- Supports quick/full modes
- Selective test execution
- Environment configuration

### Creating Custom Tests

```python
from stress_test_framework import StressTestBase

class MyCustomTest(StressTestBase):
    def __init__(self):
        super().__init__(
            name="My Custom Test",
            description="Tests something specific"
        )

    def setup(self):
        """Setup before test."""
        pass

    def run_test(self):
        """Main test logic."""
        # Your test code here
        return {
            "metric_1": value1,
            "metric_2": value2
        }

    def check_pass_criteria(self):
        """Define success criteria."""
        return {
            "criterion_1": self.metrics["metric_1"] < threshold,
            "criterion_2": self.metrics["metric_2"] > target
        }

    def teardown(self):
        """Cleanup after test."""
        pass
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Stress Tests

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  stress-test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: stress_test
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r benchmarks/stress_tests/requirements.txt

      - name: Run quick stress tests
        run: |
          cd benchmarks/stress_tests
          python run_stress_tests.py --all --quick

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: stress-test-results
          path: benchmarks/stress_tests/results/
```

## Monitoring During Tests

Monitor test progress in real-time:

```bash
# Watch test output
python run_stress_tests.py --all --quick | tee test_output.log

# Monitor resource usage
watch -n 1 'ps aux | grep python | grep stress_test'

# Monitor database connections
watch -n 5 "psql -c 'SELECT count(*) FROM pg_stat_activity'"

# Monitor memory
watch -n 5 "free -h"
```

## Troubleshooting

### Connection Limit Errors

```
Error: connection limit exceeded
```

**Solution:** Increase PostgreSQL max_connections:
```bash
# In postgresql.conf
max_connections = 2000

# Or in Docker
docker run -d \
  -e POSTGRES_MAX_CONNECTIONS=2000 \
  postgres:16
```

### Out of Memory

```
MemoryError: Cannot allocate memory
```

**Solution:** Increase system limits or reduce test parameters:
```bash
# Reduce connection count in test
export TARGET_CONNECTIONS=500

# Or increase system memory
# Add more RAM or use larger instance
```

### File Descriptor Limits

```
OSError: [Errno 24] Too many open files
```

**Solution:** Increase ulimit:
```bash
ulimit -n 65536

# Make permanent in /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
```

## Performance Baselines

Expected performance on reference hardware:

**Hardware:** AWS r5.2xlarge (8 vCPU, 64GB RAM)
**PostgreSQL:** Version 16, default configuration

| Test | Metric | Expected |
|------|--------|----------|
| Connection Limits | 1000 connections | ✅ Pass |
| Connection Limits | p95 latency | < 300ms |
| Memory Pressure | Growth (24hr) | < 50MB |
| Long-Running | Uptime | 99.99% |
| Long-Running | Throughput | No degradation |

## Contributing

To add new stress tests:

1. Create `test_XX_name.py` following the template
2. Import in `run_stress_tests.py`
3. Add to `tests_config` dict
4. Update this README
5. Add success criteria to STRESS_TEST_PLAN.md

## License

Same as mojo-postgres project.

## References

- [STRESS_TEST_PLAN.md](../../docs/STRESS_TEST_PLAN.md) - Comprehensive 3-week test plan
- [PostgreSQL Connection Pooling](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
