"""
Benchmark harness for mojo-postgres performance testing.

Provides utilities for:
- High-precision timing
- Statistical analysis (mean, median, p95, p99)
- Memory usage tracking
- Formatted output
"""

from time import now
from memory import memset_zero
from sys.info import sizeof


struct BenchmarkResult:
    """Results from a single benchmark run."""
    var name: String
    var iterations: Int
    var total_ns: Int
    var min_ns: Int
    var max_ns: Int
    var mean_ns: Float64
    var median_ns: Float64
    var p95_ns: Float64
    var p99_ns: Float64
    var memory_bytes: Int

    fn __init__(inout self, name: String, iterations: Int):
        self.name = name
        self.iterations = iterations
        self.total_ns = 0
        self.min_ns = 0
        self.max_ns = 0
        self.mean_ns = 0.0
        self.median_ns = 0.0
        self.p95_ns = 0.0
        self.p99_ns = 0.0
        self.memory_bytes = 0

    fn print_report(self):
        """Print a formatted benchmark report."""
        print("=" * 70)
        print("Benchmark:", self.name)
        print("=" * 70)
        print("Iterations:     ", self.iterations)
        print("Total Time:     ", self._format_duration(self.total_ns))
        print("Mean:           ", self._format_duration(Int(self.mean_ns)))
        print("Median:         ", self._format_duration(Int(self.median_ns)))
        print("Min:            ", self._format_duration(self.min_ns))
        print("Max:            ", self._format_duration(self.max_ns))
        print("P95:            ", self._format_duration(Int(self.p95_ns)))
        print("P99:            ", self._format_duration(Int(self.p99_ns)))
        if self.memory_bytes > 0:
            print("Memory:         ", self._format_memory(self.memory_bytes))
        print("Throughput:     ", self._format_throughput())
        print("=" * 70)

    fn _format_duration(self, ns: Int) -> String:
        """Format nanoseconds into human-readable string."""
        if ns < 1000:
            return String(ns) + " ns"
        elif ns < 1_000_000:
            return String(Float64(ns) / 1000.0) + " μs"
        elif ns < 1_000_000_000:
            return String(Float64(ns) / 1_000_000.0) + " ms"
        else:
            return String(Float64(ns) / 1_000_000_000.0) + " s"

    fn _format_memory(self, bytes: Int) -> String:
        """Format bytes into human-readable string."""
        if bytes < 1024:
            return String(bytes) + " B"
        elif bytes < 1024 * 1024:
            return String(Float64(bytes) / 1024.0) + " KB"
        else:
            return String(Float64(bytes) / (1024.0 * 1024.0)) + " MB"

    fn _format_throughput(self) -> String:
        """Calculate operations per second."""
        if self.total_ns == 0:
            return "N/A"
        var ops_per_sec = Float64(self.iterations) / (Float64(self.total_ns) / 1_000_000_000.0)
        return String(Int(ops_per_sec)) + " ops/sec"


struct Timer:
    """High-precision timer for benchmarking."""
    var start_time: Int

    fn __init__(inout self):
        self.start_time = now()

    fn elapsed_ns(self) -> Int:
        """Get elapsed time in nanoseconds."""
        return now() - self.start_time

    fn reset(inout self):
        """Reset the timer."""
        self.start_time = now()


fn benchmark[func: fn() raises -> None](name: String, iterations: Int) raises -> BenchmarkResult:
    """
    Run a benchmark function multiple times and collect statistics.

    Args:
        func: The function to benchmark (must be parameterized)
        name: Name of the benchmark
        iterations: Number of times to run the function

    Returns:
        BenchmarkResult with timing statistics
    """
    var result = BenchmarkResult(name, iterations)
    var timings = List[Int](capacity=iterations)

    # Warmup run
    func()

    # Timed runs
    for i in range(iterations):
        var timer = Timer()
        func()
        var elapsed = timer.elapsed_ns()
        timings.append(elapsed)

    # Calculate statistics
    result.total_ns = 0
    result.min_ns = timings[0]
    result.max_ns = timings[0]

    for i in range(len(timings)):
        var t = timings[i]
        result.total_ns += t
        if t < result.min_ns:
            result.min_ns = t
        if t > result.max_ns:
            result.max_ns = t

    result.mean_ns = Float64(result.total_ns) / Float64(iterations)

    # Sort for percentiles
    _sort_timings(timings)

    result.median_ns = Float64(timings[iterations // 2])
    result.p95_ns = Float64(timings[Int(Float64(iterations) * 0.95)])
    result.p99_ns = Float64(timings[Int(Float64(iterations) * 0.99)])

    return result


fn _sort_timings(inout timings: List[Int]):
    """Simple bubble sort for timing data (good enough for benchmarks)."""
    var n = len(timings)
    for i in range(n):
        for j in range(0, n - i - 1):
            if timings[j] > timings[j + 1]:
                var temp = timings[j]
                timings[j] = timings[j + 1]
                timings[j + 1] = temp


fn print_comparison(mojo_result: BenchmarkResult, python_ns: Float64, python_name: String):
    """
    Print a comparison between Mojo and Python benchmark results.

    Args:
        mojo_result: Mojo benchmark result
        python_ns: Python benchmark mean time in nanoseconds
        python_name: Name of the Python driver
    """
    print("\n" + "=" * 70)
    print("COMPARISON: mojo-postgres vs", python_name)
    print("=" * 70)

    var speedup = python_ns / mojo_result.mean_ns
    var mojo_ms = mojo_result.mean_ns / 1_000_000.0
    var python_ms = python_ns / 1_000_000.0

    print("Mojo:          ", String(mojo_ms), "ms")
    print(python_name + ":", String(python_ms), "ms")
    print("Speedup:       ", String(speedup), "x faster")

    if speedup >= 10.0:
        print("Status:        ✅ TARGET EXCEEDED (10x+ faster)")
    elif speedup >= 4.0:
        print("Status:        ✅ EXCELLENT (4x+ faster)")
    elif speedup >= 2.0:
        print("Status:        ✅ GOOD (2x+ faster)")
    elif speedup >= 1.0:
        print("Status:        ⚠️  SLOWER THAN TARGET")
    else:
        print("Status:        ❌ NEEDS OPTIMIZATION")

    print("=" * 70)
