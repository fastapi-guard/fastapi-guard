-- wrk script for POST requests with JSON data
-- Usage: wrk -t4 -c100 -d30s --script post-data.lua http://localhost:8000/api/data

-- Setup function called once per thread
setup = function(thread)
   thread:set("id", counter())
   counter = (counter or 0) + 1
end

-- Request function called for each request
request = function()
   -- Generate random test data
   local data = {
      message = "Load test message " .. math.random(1, 1000),
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      user_id = math.random(1, 100),
      session_id = "session_" .. math.random(1000, 9999),
      data = {1, 2, 3, 4, 5},
      metadata = {
         source = "wrk_load_test",
         thread_id = id
      }
   }
   
   -- Convert to JSON
   local json = require("json")
   local body = json.encode(data)
   
   -- Return POST request
   return wrk.format("POST", "/api/data", {
      ["Content-Type"] = "application/json",
      ["Accept"] = "application/json",
      ["User-Agent"] = "wrk-load-test/1.0"
   }, body)
end

-- Response function called for each response
response = function(status, headers, body)
   -- Log errors
   if status ~= 200 then
      print("Error: " .. status .. " - " .. body)
   end
end

-- Done function called once when test completes
done = function(summary, latency, requests)
   io.write("------------------------------\n")
   io.write("Load Test Results Summary:\n")
   io.write("------------------------------\n")
   io.write(string.format("Requests:      %d\n", summary.requests))
   io.write(string.format("Duration:      %.2fs\n", summary.duration / 1000000))
   io.write(string.format("Req/sec:       %.2f\n", summary.requests / (summary.duration / 1000000)))
   io.write(string.format("Bytes/sec:     %.2f KB\n", summary.bytes / (summary.duration / 1000000) / 1024))
   io.write(string.format("Error rate:    %.2f%%\n", (summary.errors.status + summary.errors.read + summary.errors.write + summary.errors.timeout) / summary.requests * 100))
   io.write("\nLatency Distribution:\n")
   io.write(string.format("50%%: %.2fms\n", latency:percentile(50)))
   io.write(string.format("75%%: %.2fms\n", latency:percentile(75)))
   io.write(string.format("90%%: %.2fms\n", latency:percentile(90)))
   io.write(string.format("95%%: %.2fms\n", latency:percentile(95)))
   io.write(string.format("99%%: %.2fms\n", latency:percentile(99)))
   io.write(string.format("Max: %.2fms\n", latency.max))
end