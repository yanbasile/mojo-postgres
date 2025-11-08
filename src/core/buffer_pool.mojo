"""
Buffer Pool for efficient memory management.

Provides:
- Pre-allocated buffer reuse (reduce allocations)
- Buffer pooling for network operations
- Memory-efficient bulk operations

Benefits:
- Reduce GC pressure (fewer allocations)
- Faster buffer allocation (reuse existing)
- Better memory locality

Example:
    var pool = BufferPool(8192)  # 8KB buffers
    var buffer = pool.acquire()
    # Use buffer...
    pool.release(buffer)
"""

from collections import List


# ============================================================================
# Buffer
# ============================================================================

@value
struct Buffer:
    """
    Reusable buffer for network operations.

    Provides pre-allocated memory to reduce allocation overhead.
    """
    var data: List[UInt8]
    var capacity: Int
    var length: Int
    var buffer_id: Int

    fn __init__(inout self, capacity: Int, buffer_id: Int):
        """
        Initialize buffer with given capacity.

        Args:
            capacity: Buffer capacity in bytes
            buffer_id: Unique ID for tracking
        """
        self.data = List[UInt8]()
        self.capacity = capacity
        self.length = 0
        self.buffer_id = buffer_id

        # Pre-allocate
        for i in range(capacity):
            self.data.append(0)

    fn reset(inout self):
        """Reset buffer for reuse."""
        self.length = 0
        # Data remains allocated


# ============================================================================
# Buffer Pool
# ============================================================================

struct BufferPool:
    """
    Pool of reusable buffers.

    Reduces allocation overhead by reusing buffers.

    Example:
        var pool = BufferPool(8192)
        var buffer = pool.acquire()
        # Use buffer...
        pool.release(buffer)
    """
    var buffer_size: Int
    var available_buffers: List[Buffer]
    var in_use_buffers: List[Buffer]
    var next_buffer_id: Int
    var total_buffers: Int
    var max_buffers: Int

    fn __init__(inout self, buffer_size: Int = 8192, max_buffers: Int = 100):
        """
        Initialize buffer pool.

        Args:
            buffer_size: Size of each buffer in bytes (default 8KB)
            max_buffers: Maximum number of buffers to create
        """
        self.buffer_size = buffer_size
        self.available_buffers = List[Buffer]()
        self.in_use_buffers = List[Buffer]()
        self.next_buffer_id = 0
        self.total_buffers = 0
        self.max_buffers = max_buffers

    fn acquire(inout self) raises -> Buffer:
        """
        Acquire buffer from pool.

        Returns existing buffer if available, otherwise creates new one.

        Returns:
            Buffer ready for use

        Raises:
            Error if max_buffers limit reached
        """
        # Check for available buffer
        if len(self.available_buffers) > 0:
            # Reuse existing buffer
            var buffer = self.available_buffers[len(self.available_buffers) - 1]

            # Remove from available
            var new_available = List[Buffer]()
            for i in range(len(self.available_buffers) - 1):
                new_available.append(self.available_buffers[i])
            self.available_buffers = new_available

            # Add to in-use
            self.in_use_buffers.append(buffer)
            return buffer

        # No available buffers, create new one
        if self.total_buffers >= self.max_buffers:
            raise Error(
                "Buffer pool exhausted: " + String(self.total_buffers) +
                " buffers in use, max is " + String(self.max_buffers)
            )

        var new_buffer = Buffer(self.buffer_size, self.next_buffer_id)
        self.next_buffer_id += 1
        self.total_buffers += 1

        self.in_use_buffers.append(new_buffer)
        return new_buffer

    fn release(inout self, buffer: Buffer):
        """
        Release buffer back to pool.

        Args:
            buffer: Buffer to release
        """
        # Reset buffer
        # (We can't modify the buffer parameter directly in Mojo's current type system,
        #  so we'll create a fresh one when re-acquiring)

        # Remove from in-use
        var new_in_use = List[Buffer]()
        for i in range(len(self.in_use_buffers)):
            if self.in_use_buffers[i].buffer_id != buffer.buffer_id:
                new_in_use.append(self.in_use_buffers[i])

        self.in_use_buffers = new_in_use

        # Add to available
        self.available_buffers.append(buffer)

    fn get_stats(self) -> BufferPoolStats:
        """
        Get buffer pool statistics.

        Returns:
            BufferPoolStats with current state
        """
        return BufferPoolStats(
            self.total_buffers,
            len(self.in_use_buffers),
            len(self.available_buffers),
            self.buffer_size
        )


# ============================================================================
# Buffer Pool Statistics
# ============================================================================

@value
struct BufferPoolStats:
    """Buffer pool statistics."""
    var total_buffers: Int
    var in_use_buffers: Int
    var available_buffers: Int
    var buffer_size: Int

    fn utilization(self) -> Float64:
        """Calculate buffer utilization (0.0 to 1.0)."""
        if self.total_buffers == 0:
            return 0.0
        return Float64(self.in_use_buffers) / Float64(self.total_buffers)

    fn to_string(self) -> String:
        """Return string representation."""
        var util_pct = self.utilization() * 100.0
        return "BufferPoolStats(total=" + String(self.total_buffers) + \
               ", in_use=" + String(self.in_use_buffers) + \
               ", available=" + String(self.available_buffers) + \
               ", size=" + String(self.buffer_size) + " bytes" + \
               ", utilization=" + String(util_pct) + "%)"


# ============================================================================
# Memory Statistics
# ============================================================================

@value
struct MemoryStats:
    """Overall memory statistics for optimizations."""
    var total_allocations: Int
    var total_bytes_allocated: Int
    var reused_buffers: Int
    var cache_hits: Int

    fn allocation_efficiency(self) -> Float64:
        """Calculate allocation efficiency (higher is better)."""
        if self.total_allocations == 0:
            return 0.0
        return Float64(self.reused_buffers) / Float64(self.total_allocations)

    fn to_string(self) -> String:
        """Return string representation."""
        var efficiency_pct = self.allocation_efficiency() * 100.0
        return "MemoryStats(allocations=" + String(self.total_allocations) + \
               ", bytes=" + String(self.total_bytes_allocated) + \
               ", reused=" + String(self.reused_buffers) + \
               ", efficiency=" + String(efficiency_pct) + "%)"
