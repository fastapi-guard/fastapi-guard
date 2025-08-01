# Load Testing Guide

This guide provides comprehensive instructions for load testing FastAPI Guard to measure performance, security effectiveness, and scalability.

## Quick Start

### 1. Start Test Server

```bash
# Start test server with balanced security
python scripts/load_test_server.py --security balanced

# Or with specific configuration
python scripts/load_test_server.py --security production --redis-url redis://localhost:6379/1
```

### 2. Run Load Tests

```bash
# Apache Bench - Simple load test
ab -n 1000 -c 10 http://localhost:8000/

# wrk - Mixed workload
wrk -t8 -c100 -d60s --script load_test_configs/wrk-scripts/mixed-workload.lua http://localhost:8000

# Locust - Interactive load testing
locust -f load_test_configs/locustfile.py --host=http://localhost:8000

# Artillery - Configuration-driven testing
artillery run load_test_configs/artillery-config.yml
```

## Test Server Configuration

### Security Levels

The test server supports different security configurations:

| Level | WAF | Bot Detection | Rate Limiting | IP Blocklist | Use Case |
|-------|-----|---------------|---------------|--------------|----------|
| `none` | ❌ | ❌ | ❌ | ❌ | Baseline performance |
| `minimal` | ✅ (permissive) | ❌ | ✅ (high limits) | ❌ | Light protection |
| `balanced` | ✅ (balanced) | ✅ | ✅ (moderate) | ✅ | Production ready |
| `production` | ✅ (balanced) | ✅ | ✅ (optimized) | ✅ | Production config |
| `high` | ✅ (strict) | ✅ (strict) | ✅ (strict) | ✅ | Maximum security |

### Starting Test Server

```bash
# Basic server
python scripts/load_test_server.py

# Production-like setup
python scripts/load_test_server.py \
  --security production \
  --workers 4 \
  --redis-url redis://localhost:6379/1 \
  --log-level info

# High security testing
python scripts/load_test_server.py \
  --security high \
  --host 0.0.0.0 \
  --port 8000
```

## Load Testing Tools

### Apache Bench (ab)

Simple HTTP load testing tool included with Apache.

#### Basic Usage

```bash
# Simple load test
ab -n 1000 -c 10 http://localhost:8000/

# More intensive test
ab -n 5000 -c 50 -t 60 http://localhost:8000/api/data

# POST requests
ab -n 1000 -c 20 -p post_data.json -T application/json http://localhost:8000/api/data
```

#### Example Results

```
Requests per second:    500.32 [#/sec] (mean)
Time per request:       19.987 [ms] (mean)
Time per request:       1.999 [ms] (mean, across all concurrent requests)
Transfer rate:          125.45 [Kbytes/sec] received

Percentage of the requests served within a certain time (ms)
  50%     18
  66%     20
  75%     22
  80%     24
  90%     28
  95%     35
  98%     45
  99%     52
 100%     67 (longest request)
```

### wrk

Modern HTTP benchmarking tool with Lua scripting support.

#### Basic Usage

```bash
# Simple load test
wrk -t12 -c400 -d30s http://localhost:8000/

# With custom script
wrk -t8 -c100 -d60s --script load_test_configs/wrk-scripts/mixed-workload.lua http://localhost:8000
```

#### Available Scripts

1. **mixed-workload.lua** - Realistic mixed API workload
2. **post-data.lua** - POST requests with JSON payloads  
3. **security-test.lua** - Security testing with malicious payloads

#### Mixed Workload Example

```bash
wrk -t8 -c200 -d60s --script load_test_configs/wrk-scripts/mixed-workload.lua http://localhost:8000
```

Expected output:
```
Mixed Workload Load Test Results
============================================================
Total Requests:    12000
Duration:          60.05s 
Requests/sec:      199.83
Transfer/sec:      45.32 KB

Status Code Distribution:
  200: 8400 (70.0%)
  403: 2400 (20.0%) 
  429: 600 (5.0%)
  401: 600 (5.0%)

Security Analysis:
  Blocked (403):     2400 requests
  Rate Limited (429): 600 requests

Performance Analysis:
  Success Rate:      70.0%
  Avg Latency:       45.23ms
  Verdict:           GOOD ✅
```

#### Security Testing Example

```bash
wrk -t4 -c50 -d30s --script load_test_configs/wrk-scripts/security-test.lua http://localhost:8000
```

This script tests various attack patterns and measures how effectively FastAPI Guard blocks them.

### Locust

Python-based load testing tool with web UI and programmatic control.

#### Installation

```bash
pip install locust
```

#### Usage

```bash
# Web UI mode (recommended)
locust -f load_test_configs/locustfile.py --host=http://localhost:8000

# Open http://localhost:8089 in browser to control test

# Headless mode
locust -f load_test_configs/locustfile.py --host=http://localhost:8000 --headless -u 100 -r 10 -t 300s

# With CSV output
locust -f load_test_configs/locustfile.py --host=http://localhost:8000 --headless -u 50 -r 5 -t 600s --csv=results
```

#### User Classes Available

- **FastAPIGuardUser** - Normal API usage patterns
- **MaliciousUser** - Simulates attacks (low weight)
- **HighVolumeUser** - High-frequency requests
- **WebUser** - Fast HTTP user for performance
- **SecurityTestTaskSet** - Focused security testing

#### Example Web UI Workflow

1. Start Locust: `locust -f load_test_configs/locustfile.py --host=http://localhost:8000`
2. Open http://localhost:8089
3. Configure test:
   - Number of users: 100
   - Spawn rate: 10 users/second
   - Duration: 10 minutes
4. Click "Start swarming"
5. Monitor real-time statistics and graphs
6. Download results when complete

### Artillery

Configuration-driven load testing with detailed reporting.

#### Installation

```bash
npm install -g artillery
```

#### Usage

```bash
# Run configured test
artillery run load_test_configs/artillery-config.yml

# Quick test
artillery quick --count 100 --num 10 http://localhost:8000/

# With custom rate
artillery quick --count 1000 --num 50 --duration 60 http://localhost:8000/api/data
```

#### Configuration Features

The `artillery-config.yml` includes:

- **Multi-phase load pattern** - Warm-up, ramp-up, sustained, peak, cool-down
- **Mixed scenarios** - Different user behavior patterns
- **Security testing** - Malicious payload injection
- **Performance thresholds** - Automated pass/fail criteria
- **Detailed reporting** - HTML and JSON outputs

#### Example Results

```
Summary report @ 14:30:15(+0100) 2023-01-01
  Scenarios launched:  5000
  Scenarios completed: 4985
  Requests completed:  24925
  Mean response/sec:   415.42
  Response time (msec):
    min: 1.2
    max: 245.6
    median: 12.3
    p95: 45.2
    p99: 89.1
  Codes:
    200: 17450
    403: 5025  
    429: 2450
```

## Performance Benchmarking

### Running Benchmarks

```bash
# Run all benchmarks
python scripts/run_benchmarks.py

# Run specific components
python scripts/run_benchmarks.py --components waf,rate_limiter

# Include load tests
python scripts/run_benchmarks.py --load-tests

# With Redis testing
python scripts/run_benchmarks.py --redis-url redis://localhost:6379/1

# Generate HTML report only
python scripts/run_benchmarks.py --format html
```

### Benchmark Components

The benchmark suite tests:

1. **WAF Performance**
   - Pattern matching speed
   - Custom pattern performance
   - Memory usage

2. **Bot Detection Performance**
   - User agent analysis
   - Behavioral analysis
   - Detection accuracy

3. **Rate Limiter Performance**
   - Memory vs Redis backends
   - Sliding window algorithms
   - Concurrent request handling

4. **IP Blocklist Performance**
   - Lookup speed
   - Large blocklist handling
   - CIDR matching

5. **Middleware Performance**
   - End-to-end request processing
   - Configuration impact
   - Memory stability

### Expected Performance Targets

| Component | Target | Measurement |
|-----------|--------|-------------|
| WAF Analysis | <1ms | Per request |
| Bot Detection | <0.5ms | Per request |
| Rate Limiting | <1ms | Per check |
| IP Blocking | <1ms | Per check |
| Total Overhead | <50ms | Per request |
| Memory Usage | <200MB | Baseline |
| Success Rate | >95% | Under load |

## Security Testing

### Testing Attack Scenarios

FastAPI Guard should effectively block common web attacks:

#### SQL Injection

```bash
# Test SQL injection protection
curl "http://localhost:8000/api/search?q='; DROP TABLE users; --"
# Expected: 403 Forbidden

curl "http://localhost:8000/api/search?q=' OR 1=1 --"
# Expected: 403 Forbidden
```

#### Cross-Site Scripting (XSS)

```bash
# Test XSS protection
curl "http://localhost:8000/api/search?q=<script>alert('xss')</script>"
# Expected: 403 Forbidden

curl "http://localhost:8000/api/search?q=javascript:alert('xss')"
# Expected: 403 Forbidden
```

#### Path Traversal

```bash
# Test path traversal protection
curl "http://localhost:8000/api/search?q=../../../etc/passwd"
# Expected: 403 Forbidden

curl "http://localhost:8000/api/search?q=..\\..\\..\\windows\\system32\\config\\sam"
# Expected: 403 Forbidden
```

#### Bot Detection

```bash
# Test bot detection
curl -H "User-Agent: sqlmap/1.4.3" "http://localhost:8000/api/data"
# Expected: 403 Forbidden

curl -H "User-Agent: bot/1.0" "http://localhost:8000/api/data"
# Expected: 403 Forbidden
```

#### Rate Limiting

```bash
# Test rate limiting (run multiple times quickly)
for i in {1..20}; do curl "http://localhost:8000/api/limited"; done
# Expected: First few succeed (200), then rate limited (429)
```

### Automated Security Testing

Use the security test script for comprehensive testing:

```bash
wrk -t4 -c50 -d30s --script load_test_configs/wrk-scripts/security-test.lua http://localhost:8000
```

This script will:
- Send various attack payloads
- Measure block rate effectiveness
- Test performance under attack
- Provide security assessment

## Production Load Testing

### Pre-Production Testing

Before deploying to production, run comprehensive load tests:

```bash
# 1. Start production-configured server
python scripts/load_test_server.py \
  --security production \
  --workers 4 \
  --redis-url redis://localhost:6379/1

# 2. Run mixed workload test
wrk -t12 -c400 -d300s --script load_test_configs/wrk-scripts/mixed-workload.lua http://localhost:8000

# 3. Run security effectiveness test
wrk -t8 -c100 -d60s --script load_test_configs/wrk-scripts/security-test.lua http://localhost:8000

# 4. Run sustained load test
artillery run load_test_configs/artillery-config.yml

# 5. Generate benchmark report
python scripts/run_benchmarks.py --load-tests --format all
```

### Production Monitoring

During production load testing:

1. **Monitor System Resources**
   ```bash
   # Monitor CPU, memory, disk
   htop
   
   # Monitor network
   iftop
   
   # Monitor Redis (if used)
   redis-cli monitor
   ```

2. **Check Application Metrics**
   ```bash
   # Security status
   curl http://localhost:8000/api/security/info
   
   # Health check
   curl http://localhost:8000/health
   ```

3. **Review Logs**
   ```bash
   # Application logs
   tail -f app.log
   
   # Security events
   grep "BLOCKED" app.log | tail -20
   ```

### Load Testing Checklist

Before declaring load testing complete:

- [ ] **Performance Requirements Met**
  - [ ] Response time < 100ms (95th percentile)
  - [ ] Throughput > target RPS
  - [ ] Error rate < 1%
  - [ ] Memory usage stable

- [ ] **Security Requirements Met**
  - [ ] >95% malicious requests blocked
  - [ ] No false positives on legitimate traffic
  - [ ] Rate limiting working correctly
  - [ ] Bot detection effective

- [ ] **Stability Requirements Met**
  - [ ] No memory leaks over time
  - [ ] Graceful degradation under extreme load
  - [ ] Recovery after load spikes
  - [ ] No crashes or errors

- [ ] **Documentation Complete**
  - [ ] Performance baselines recorded
  - [ ] Load test results archived
  - [ ] Capacity planning completed
  - [ ] Monitoring thresholds set

## Troubleshooting Load Tests

### Common Issues

#### High Error Rates

```bash
# Check server logs
tail -f app.log

# Verify server is running
curl http://localhost:8000/health

# Check resource usage
top
```

#### Poor Performance

```bash
# Test without security (baseline)
python scripts/load_test_server.py --security none

# Compare with minimal security
python scripts/load_test_server.py --security minimal

# Check Redis connection
redis-cli ping
```

#### Rate Limiting Issues

```bash
# Check rate limit configuration
curl http://localhost:8000/api/security/info

# Test single request
curl -v http://localhost:8000/api/limited
```

#### Security Not Working

```bash
# Test malicious payload manually
curl "http://localhost:8000/api/search?q=<script>alert('test')</script>"

# Check security configuration
curl http://localhost:8000/api/security/info
```

### Debug Mode

Run server in debug mode for detailed logging:

```bash
python scripts/load_test_server.py --security balanced --log-level debug
```

### Performance Profiling

For detailed performance analysis:

```bash
# Run with profiling
python -m cProfile -o profile.stats scripts/load_test_server.py

# Analyze profile
python -m pstats profile.stats
```

## Best Practices

### Load Test Planning

1. **Define Objectives**
   - Performance targets
   - Security requirements
   - Scalability goals

2. **Test Environment**
   - Match production hardware
   - Use realistic data
   - Include external dependencies

3. **Test Scenarios**
   - Normal user behavior
   - Peak load conditions
   - Attack scenarios
   - Failure conditions

### Test Execution

1. **Baseline Testing**
   - Test without security first
   - Establish performance baseline
   - Identify bottlenecks

2. **Incremental Testing**
   - Add security components gradually
   - Measure impact of each component
   - Optimize configuration

3. **Realistic Testing**
   - Use production-like data
   - Include malicious traffic
   - Test over extended periods

### Results Analysis

1. **Performance Metrics**
   - Response time percentiles
   - Throughput (RPS)
   - Error rates
   - Resource utilization

2. **Security Metrics**
   - Block rate effectiveness
   - False positive rate
   - Attack detection accuracy

3. **Capacity Planning**
   - Maximum supported load
   - Scaling requirements
   - Resource planning

This comprehensive load testing guide ensures FastAPI Guard performs well under real-world conditions while maintaining strong security protection.