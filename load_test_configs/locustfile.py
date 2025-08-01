"""
Locust load test configuration for FastAPI Guard.

Usage:
    locust -f locustfile.py --host=http://localhost:8000
    
    # Web UI (default)
    locust -f locustfile.py --host=http://localhost:8000 --web-port 8089
    
    # Headless mode
    locust -f locustfile.py --host=http://localhost:8000 --headless -u 100 -r 10 -t 300s
    
    # With custom parameters
    locust -f locustfile.py --host=http://localhost:8000 --headless -u 50 -r 5 -t 600s --csv=results
"""
import random
import json
from locust import HttpUser, task, between, events
from locust.contrib.fasthttp import FastHttpUser


class FastAPIGuardUser(HttpUser):
    """Simulates a typical user interacting with FastAPI Guard protected endpoints"""
    
    # Wait time between requests (simulates user think time)
    wait_time = between(1, 5)
    
    def on_start(self):
        """Called when a user starts"""
        # Check if server is healthy
        response = self.client.get("/health")
        if response.status_code != 200:
            print(f"Health check failed: {response.status_code}")
    
    @task(20)
    def get_root(self):
        """Get root endpoint - most common request"""
        self.client.get("/")
    
    @task(15)
    def get_simple_api(self):
        """Get simple API endpoint"""
        self.client.get("/api/simple")
    
    @task(10)
    def get_data(self):
        """Get data from API"""
        response = self.client.get("/api/data")
        if response.status_code == 200:
            data = response.json()
            # Simulate processing the data
            if "users" in data:
                user_count = len(data["users"])
    
    @task(8)
    def post_data(self):
        """Post data to API"""
        payload = {
            "message": f"Test message {random.randint(1, 1000)}",
            "timestamp": "2023-01-01T00:00:00Z",
            "user_id": random.randint(1, 100),
            "data": [1, 2, 3, 4, 5]
        }
        
        response = self.client.post("/api/data", json=payload)
        if response.status_code != 200:
            print(f"POST failed: {response.status_code}")
    
    @task(12)
    def search_api(self):
        """Search API with various queries"""
        queries = [
            "user data",
            "product information", 
            "system status",
            "search term",
            "api documentation",
            "test query",
            "sample data",
            "configuration",
            "performance metrics",
            "security logs"
        ]
        
        query = random.choice(queries)
        self.client.get(f"/api/search?q={query}")
    
    @task(3)
    def cpu_intensive(self):
        """Occasionally hit CPU-intensive endpoint"""
        self.client.get("/api/cpu")
    
    @task(2)
    def memory_intensive(self):
        """Occasionally hit memory-intensive endpoint"""
        self.client.get("/api/memory")
    
    @task(5)
    def authenticate(self):
        """Simulate authentication attempts"""
        credentials = {
            "username": random.choice(["admin", "user", "test", "demo"]),
            "password": random.choice(["secret", "password", "123456", "admin"])
        }
        
        response = self.client.post("/api/auth/login", json=credentials)
        # Expect mostly 401s for invalid credentials
        if response.status_code not in [200, 401]:
            print(f"Unexpected auth response: {response.status_code}")
    
    @task(4)
    def rate_limited_endpoint(self):
        """Hit rate limited endpoint"""
        self.client.get("/api/limited")
    
    @task(1)
    def security_info(self):
        """Check security configuration"""
        self.client.get("/api/security/info")


class MaliciousUser(HttpUser):
    """Simulates malicious traffic that should be blocked by security middleware"""
    
    wait_time = between(0.5, 2)  # More aggressive timing
    weight = 5  # Lower weight - fewer malicious users
    
    @task(10)
    def sql_injection_attempts(self):
        """Attempt SQL injection attacks"""
        payloads = [
            "'; DROP TABLE users; --",
            "' OR 1=1 --",
            "' UNION SELECT * FROM passwords --",
            "admin'--",
            "' OR 'a'='a",
            "1' OR '1'='1",
            "'; INSERT INTO users VALUES ('hacker', 'password'); --"
        ]
        
        payload = random.choice(payloads)
        with self.client.get(f"/api/search?q={payload}", catch_response=True) as response:
            if response.status_code == 403:
                response.success()  # Expected to be blocked
            elif response.status_code == 200:
                response.failure("SQL injection not blocked!")
    
    @task(8)
    def xss_attempts(self):
        """Attempt XSS attacks"""
        payloads = [
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert('xss')>",
            "javascript:alert('xss')",
            "<svg onload=alert('xss')>",
            "<iframe src=javascript:alert('xss')></iframe>",
            "<body onload=alert('xss')>",
            "'+alert('xss')+'",
            "%3Cscript%3Ealert('xss')%3C/script%3E"
        ]
        
        payload = random.choice(payloads)
        with self.client.get(f"/api/search?q={payload}", catch_response=True) as response:
            if response.status_code == 403:
                response.success()  # Expected to be blocked
            elif response.status_code == 200:
                response.failure("XSS attempt not blocked!")
    
    @task(5)
    def path_traversal_attempts(self):
        """Attempt path traversal attacks"""
        payloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "....//....//....//etc/passwd",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "..%252f..%252f..%252fetc%252fpasswd",
            "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd"
        ]
        
        payload = random.choice(payloads)
        with self.client.get(f"/api/search?q={payload}", catch_response=True) as response:
            if response.status_code == 403:
                response.success()  # Expected to be blocked
            elif response.status_code == 200:
                response.failure("Path traversal not blocked!")
    
    @task(7)
    def bot_user_agents(self):
        """Use bot user agents that should be detected"""
        bot_agents = [
            "bot/1.0",
            "spider/2.0", 
            "crawler/1.5",
            "scraper/3.0",
            "harvester/1.0",
            "sqlmap/1.4.3",
            "nikto/2.1.6",
            "masscan/1.0",
            "nmap/7.80",
            "curl/7.68.0"
        ]
        
        headers = {"User-Agent": random.choice(bot_agents)}
        with self.client.get("/api/data", headers=headers, catch_response=True) as response:
            if response.status_code == 403:
                response.success()  # Expected to be blocked
            elif response.status_code == 200:
                response.failure("Bot not detected!")
    
    @task(3)
    def brute_force_login(self):
        """Attempt brute force login attacks"""
        usernames = ["admin", "administrator", "root", "user", "test"]
        passwords = ["password", "123456", "admin", "password123", "qwerty"]
        
        credentials = {
            "username": random.choice(usernames),
            "password": random.choice(passwords)
        }
        
        # Multiple rapid attempts to trigger brute force protection
        for _ in range(3):
            self.client.post("/api/auth/login", json=credentials)


class HighVolumeUser(HttpUser):
    """Simulates high-volume legitimate traffic"""
    
    wait_time = between(0.1, 0.5)  # Very fast requests
    weight = 10  # Higher weight for more users
    
    @task(30)
    def rapid_api_calls(self):
        """Make rapid API calls to test rate limiting"""
        endpoints = ["/", "/api/simple", "/api/data", "/health"]
        endpoint = random.choice(endpoints)
        self.client.get(endpoint)
    
    @task(10)
    def burst_requests(self):
        """Send burst of requests"""
        for _ in range(5):
            self.client.get("/api/simple")


class WebUser(FastHttpUser):
    """High-performance user using FastHttpUser for better performance"""
    
    wait_time = between(1, 3)
    weight = 15
    
    @task(25)
    def browse_api(self):
        """Browse API endpoints like a web user"""
        self.client.get("/")
    
    @task(15)
    def get_data_fast(self):
        """Fast data retrieval"""
        self.client.get("/api/data")
    
    @task(10)
    def search_fast(self):
        """Fast search requests"""
        query = f"search{random.randint(1, 100)}"
        self.client.get(f"/api/search?q={query}")


# Event listeners for custom reporting
@events.request.add_listener
def on_request(request_type, name, response_time, response_length, exception, context, **kwargs):
    """Custom request event handler"""
    if exception:
        print(f"Request failed: {request_type} {name} - {exception}")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when test starts"""
    print("Starting FastAPI Guard load test...")
    print(f"Target host: {environment.host}")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when test stops"""
    print("FastAPI Guard load test completed.")
    
    # Print summary statistics
    stats = environment.stats
    print(f"Total requests: {stats.total.num_requests}")
    print(f"Total failures: {stats.total.num_failures}")
    if stats.total.num_requests > 0:
        failure_rate = stats.total.num_failures / stats.total.num_requests * 100
        print(f"Failure rate: {failure_rate:.2f}%")
        print(f"Average response time: {stats.total.avg_response_time:.2f}ms")
        print(f"95th percentile: {stats.total.get_response_time_percentile(0.95):.2f}ms")
        print(f"99th percentile: {stats.total.get_response_time_percentile(0.99):.2f}ms")


# Custom task sets for different test scenarios
class SecurityTestTaskSet(HttpUser):
    """Focused on testing security features"""
    
    wait_time = between(1, 3)
    
    @task
    def test_waf_protection(self):
        """Test WAF protection specifically"""
        malicious_queries = [
            "'; DROP TABLE users; --",
            "<script>alert('xss')</script>",
            "../../../etc/passwd"
        ]
        
        for query in malicious_queries:
            with self.client.get(f"/api/search?q={query}", catch_response=True) as response:
                if response.status_code == 403:
                    response.success()
                else:
                    response.failure(f"Security bypass: {response.status_code}")
    
    @task
    def test_rate_limiting(self):
        """Test rate limiting specifically"""
        # Make rapid requests to trigger rate limiting
        for i in range(10):
            with self.client.get("/api/limited", catch_response=True) as response:
                if i < 5 and response.status_code == 200:
                    response.success()
                elif i >= 5 and response.status_code == 429:
                    response.success()  # Expected rate limiting
                else:
                    response.failure(f"Unexpected rate limit behavior: {response.status_code}")


# Export user classes for different test scenarios
__all__ = [
    "FastAPIGuardUser",
    "MaliciousUser", 
    "HighVolumeUser",
    "WebUser",
    "SecurityTestTaskSet"
]