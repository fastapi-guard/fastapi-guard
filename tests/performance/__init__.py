"""
Performance test suite for FastAPI Guard.

This module contains benchmarks and load tests to measure the performance
impact of FastAPI Guard security components.

Test Categories:
- Benchmarks: Measure individual component performance
- Load Tests: Test under concurrent load and sustained traffic
- Memory Tests: Monitor memory usage and detect leaks
- Stress Tests: Find breaking points and limits

Usage:
    # Run all performance tests
    pytest tests/performance/

    # Run only benchmarks
    pytest tests/performance/test_benchmarks.py

    # Run only load tests
    pytest tests/performance/test_load_tests.py

    # Run with performance markers
    pytest -m performance

Direct Execution:
    # Run benchmarks directly
    python tests/performance/test_benchmarks.py

    # Run load tests directly
    python tests/performance/test_load_tests.py
"""

# Performance test markers for pytest
import pytest

# Register performance markers
def pytest_configure(config):
    """Configure pytest markers for performance tests"""
    config.addinivalue_line(
        "markers", "performance: mark test as a performance test"
    )
    config.addinivalue_line(
        "markers", "benchmark: mark test as a benchmark"
    )
    config.addinivalue_line(
        "markers", "load_test: mark test as a load test"
    )
    config.addinivalue_line(
        "markers", "stress_test: mark test as a stress test"
    )
    config.addinivalue_line(
        "markers", "memory_test: mark test as a memory usage test"
    )
    
    # Check for Redis availability
    try:
        import redis
        r = redis.Redis(host='localhost', port=6379, db=15)
        r.ping()
        config.redis_available = True
    except:
        config.redis_available = False


# Performance test configuration
PERFORMANCE_THRESHOLDS = {
    "waf_analysis_ms": 1.0,           # WAF analysis should be < 1ms
    "bot_detection_ms": 0.5,          # Bot detection should be < 0.5ms
    "rate_limit_check_ms": 1.0,       # Rate limit check should be < 1ms
    "ip_block_check_ms": 1.0,         # IP block check should be < 1ms
    "middleware_overhead_ms": 50.0,   # Total middleware overhead should be < 50ms
    "memory_baseline_mb": 200.0,      # Baseline memory usage should be < 200MB
    "memory_leak_mb": 50.0,           # Memory growth should be < 50MB over time
    "success_rate_percent": 95.0,     # Success rate should be > 95%
    "min_rps": 100.0                  # Minimum requests per second
}


# Utility functions for performance testing
def measure_execution_time(func, *args, **kwargs):
    """Measure execution time of a function"""
    import time
    start = time.perf_counter()
    result = func(*args, **kwargs)
    duration = time.perf_counter() - start
    return result, duration


async def measure_async_execution_time(func, *args, **kwargs):
    """Measure execution time of an async function"""
    import time
    start = time.perf_counter()
    result = await func(*args, **kwargs)
    duration = time.perf_counter() - start
    return result, duration


def get_memory_usage():
    """Get current memory usage in MB"""
    import psutil
    process = psutil.Process()
    return process.memory_info().rss / 1024 / 1024


def format_performance_results(results):
    """Format performance results for display"""
    formatted = []
    for name, stats in results.items():
        formatted.append(f"{name}:")
        if isinstance(stats, dict):
            for key, value in stats.items():
                if "time" in key.lower() or "duration" in key.lower():
                    formatted.append(f"  {key}: {value*1000:.2f}ms")
                elif "rps" in key.lower() or "requests_per_second" in key.lower():
                    formatted.append(f"  {key}: {value:.0f} req/s")
                elif "percent" in key.lower() or "rate" in key.lower():
                    formatted.append(f"  {key}: {value:.1f}%")
                else:
                    formatted.append(f"  {key}: {value}")
        else:
            formatted.append(f"  {stats}")
        formatted.append("")
    
    return "\n".join(formatted)


# Export performance utilities
__all__ = [
    "PERFORMANCE_THRESHOLDS",
    "measure_execution_time", 
    "measure_async_execution_time",
    "get_memory_usage",
    "format_performance_results"
]