-- wrk script for mixed workload testing
-- Usage: wrk -t8 -c200 -d60s --script mixed-workload.lua http://localhost:8000

-- Initialize request counters and data
local counter = 0
local requests = {
   -- GET requests (70% of traffic)
   {method = "GET", path = "/", weight = 20},
   {method = "GET", path = "/api/simple", weight = 15},
   {method = "GET", path = "/api/data", weight = 15},
   {method = "GET", path = "/api/search?q=test", weight = 10},
   {method = "GET", path = "/api/cpu", weight = 3},
   {method = "GET", path = "/api/memory", weight = 3},
   {method = "GET", path = "/health", weight = 4},
   
   -- POST requests (20% of traffic)
   {method = "POST", path = "/api/data", weight = 15, body = true},
   {method = "POST", path = "/api/auth/login", weight = 5, body = true},
   
   -- Security test requests (10% of traffic - should be blocked)
   {method = "GET", path = "/api/search?q=%27+OR+1%3D1+--", weight = 3}, -- SQL injection
   {method = "GET", path = "/api/search?q=%3Cscript%3Ealert%28%27xss%27%29%3C%2Fscript%3E", weight = 3}, -- XSS
   {method = "GET", path = "/api/search?q=..%2F..%2F..%2Fetc%2Fpasswd", weight = 2}, -- Path traversal
   {method = "GET", path = "/api/error?error_type=500", weight = 2} -- Error endpoint
}

-- Calculate cumulative weights for weighted random selection
local total_weight = 0
for i, req in ipairs(requests) do
   total_weight = total_weight + req.weight
   req.cumulative_weight = total_weight
end

-- Setup function
setup = function(thread)
   thread:set("id", counter)
   counter = counter + 1
end

-- Select request based on weighted random distribution
function select_request()
   local rand = math.random(1, total_weight)
   for i, req in ipairs(requests) do
      if rand <= req.cumulative_weight then
         return req
      end
   end
   return requests[1] -- fallback
end

-- Generate request body for POST requests
function generate_body(path)
   if string.find(path, "/api/data") then
      return string.format([[{
         "message": "Load test message %d",
         "timestamp": "%s",
         "user_id": %d,
         "test_data": [1, 2, 3, 4, 5]
      }]], math.random(1, 1000), os.date("!%Y-%m-%dT%H:%M:%SZ"), math.random(1, 100))
   elseif string.find(path, "/api/auth/login") then
      local usernames = {"admin", "user", "test", "demo"}
      local passwords = {"secret", "password", "123456"}
      return string.format([[{
         "username": "%s",
         "password": "%s"
      }]], usernames[math.random(#usernames)], passwords[math.random(#passwords)])
   end
   return "{}"
end

-- Main request function
request = function()
   local req = select_request()
   local headers = {
      ["Accept"] = "application/json",
      ["User-Agent"] = "wrk-mixed-workload/1.0"
   }
   
   if req.method == "POST" and req.body then
      headers["Content-Type"] = "application/json"
      local body = generate_body(req.path)
      return wrk.format(req.method, req.path, headers, body)
   else
      return wrk.format(req.method, req.path, headers)
   end
end

-- Track response statistics
local status_counts = {}
local error_responses = {}

response = function(status, headers, body)
   -- Count status codes
   status_counts[status] = (status_counts[status] or 0) + 1
   
   -- Log interesting responses
   if status == 403 then
      -- Security block (expected for malicious requests)
   elseif status == 429 then
      -- Rate limited (may be expected)
   elseif status >= 500 then
      -- Server errors (unexpected)
      table.insert(error_responses, {status = status, body = body})
   end
end

-- Final results summary
done = function(summary, latency, requests)
   io.write("\n" .. string.rep("=", 60) .. "\n")
   io.write("Mixed Workload Load Test Results\n")
   io.write(string.rep("=", 60) .. "\n")
   
   -- Basic stats
   io.write(string.format("Total Requests:    %d\n", summary.requests))
   io.write(string.format("Duration:          %.2fs\n", summary.duration / 1000000))
   io.write(string.format("Requests/sec:      %.2f\n", summary.requests / (summary.duration / 1000000)))
   io.write(string.format("Transfer/sec:      %.2f KB\n", summary.bytes / (summary.duration / 1000000) / 1024))
   
   -- Error summary
   local total_errors = summary.errors.status + summary.errors.read + summary.errors.write + summary.errors.timeout
   io.write(string.format("Total Errors:      %d (%.2f%%)\n", total_errors, total_errors / summary.requests * 100))
   
   -- Status code distribution
   io.write("\nStatus Code Distribution:\n")
   for status, count in pairs(status_counts) do
      local percentage = count / summary.requests * 100
      io.write(string.format("  %d: %d (%.1f%%)\n", status, count, percentage))
   end
   
   -- Latency percentiles
   io.write("\nLatency Distribution:\n")
   io.write(string.format("  Average:  %.2fms\n", latency.mean))
   io.write(string.format("  50%%:      %.2fms\n", latency:percentile(50)))
   io.write(string.format("  75%%:      %.2fms\n", latency:percentile(75)))
   io.write(string.format("  90%%:      %.2fms\n", latency:percentile(90)))
   io.write(string.format("  95%%:      %.2fms\n", latency:percentile(95)))
   io.write(string.format("  99%%:      %.2fms\n", latency:percentile(99)))
   io.write(string.format("  99.9%%:    %.2fms\n", latency:percentile(99.9)))
   io.write(string.format("  Max:      %.2fms\n", latency.max))
   
   -- Security analysis
   local blocked_requests = status_counts[403] or 0
   local rate_limited = status_counts[429] or 0
   io.write("\nSecurity Analysis:\n")
   io.write(string.format("  Blocked (403):     %d requests\n", blocked_requests))
   io.write(string.format("  Rate Limited (429): %d requests\n", rate_limited))
   
   -- Performance analysis
   local success_rate = ((status_counts[200] or 0) + (status_counts[201] or 0)) / summary.requests * 100
   io.write("\nPerformance Analysis:\n")
   io.write(string.format("  Success Rate:      %.1f%%\n", success_rate))
   io.write(string.format("  Avg Latency:       %.2fms\n", latency.mean))
   
   -- Performance verdict
   if latency.mean < 50 and success_rate > 95 then
      io.write("  Verdict:           EXCELLENT ✅\n")
   elseif latency.mean < 100 and success_rate > 90 then
      io.write("  Verdict:           GOOD ✅\n")
   elseif latency.mean < 200 and success_rate > 85 then
      io.write("  Verdict:           ACCEPTABLE ⚠️\n")
   else
      io.write("  Verdict:           NEEDS IMPROVEMENT ❌\n")
   end
   
   -- Server errors (if any)
   if #error_responses > 0 then
      io.write("\nServer Errors (first 5):\n")
      for i = 1, math.min(5, #error_responses) do
         local err = error_responses[i]
         io.write(string.format("  %d: %s\n", err.status, string.sub(err.body, 1, 100)))
      end
   end
   
   io.write(string.rep("=", 60) .. "\n")
end