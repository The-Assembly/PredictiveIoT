
module("handlers.https", thingworx.handler.extend)

function makeHttpRequest(method, key, headers, data, isSSL)
	-- Make the external call
	-- Get the host, port, path, and query string
	-- Find the query string first
  local _, queryTable = tw_utils.parseQueryParams(key)
  local host = string.sub(key, 1, string.find(key, "/") - 1)
  local port = 80

	if string.find(host, ":") then
		port = string.sub(host, string.find(host, ":") + 1)
		host = string.sub(host, 1, string.find(host, ":") - 1)
	else
		if isSSL then port = "443" end
	end
	local path = "/" .. (string.sub(key, string.find(key, "/") + 1) or "")
	local result, code
	-- Default to a GET
	if string.lower(method) == "put" then
		result, code, headers = ps_http.put(host, port, path, data, headers)
	else 
		result, code, headers = ps_http.get(host, port, path, headers, queryTable)
  end
	if code and code == 200 then
		return code, result, headers
	else
		log.error("makeHttpRequest", "Error: Request to http://%s:%s%s returned %d", host, port, path, code)
		return headers, 500, ""
	end
end

function read(me, pt, headers, query)
  log.debug(me.name, "Making http request to get property %s. url: %s", pt.name, pt.key)
  local method = pt.getMethod or "GET"
  local code, resp = makeHttpRequest(method, pt.key, headers, nil, true)

  if code == 200 then
    local success, jresp = pcall(json.decode, resp)

    if success and type(jresp) == "table" then 
      pt.value = jresp[pt.name] or jresp.value or jresp.result 
      if not pt.value then
        _, pt.value = next(jresp) -- Just use the first key:value found
      end
      pt.time = jresp.time or os.time() * 1000
      pt.quality = jresp.quality or "GOOD"
    elseif success then
      pt.value = resp 
      pt.time = os.time() * 1000
      pt.quality = "GOOD"
    else 
      log.warn(me.name, "Could not json.decode read result for property %s. Setting quality to UNKNOWN.", pt.name)
      pt.quality = "UNKNOWN"
    end
  else
    log.warn(me.name, "Could not read current value of %s. Setting quality to UNKNOWN. Resp: ", pt.name, resp)
    pt.quality = "UNKNOWN"
    return code, resp
  end

  return 200
end

function write(me, pt, headers, query, data)
  log.debug(me.name, "Making http request to set property %s. url: %s, data: %s", pt.name, pt.key, d)
  local method = pt.getMethod or "PUT"
  return makeHttpRequest(method, pt.key, headers, json.encode(data), true)
end
