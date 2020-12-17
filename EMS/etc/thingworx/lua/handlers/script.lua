
module("handlers.script", thingworx.handler.extend)

function read(me, pt, headers, query, script_name)

  local key, key_query_params = tw_utils.parseQueryParams(pt.key)
  local method = pt.getMethod or "GET"

  -- This is the 4.0+ plus case. If a script_name is passed 
  -- in, it is to handle the backward compatible case.
  if not script_name then
    -- Get the script name from the key
    script_name = key:match("^/?(.-)/")
    key = key:sub(#script_name + 2)
  end

  log.debug(me.name, "Executing property read via script handler. script: %s, path: %s", script_name, key)
  local code, resp = ps_script.executeCallback(script_name, method, key, headers, key_query_params)

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

function write(me, pt, headers, query, data, script_name)

  local method = pt.setMethod or "PUT"
  local key, key_query_params = tw_utils.parseQueryParams(pt.key)

  -- This is the 4.0+ plus case. If a script_name is passed 
  -- in, it is to handle the backward compatible case.
  if not script_name then
    -- Get the script name from the key
    script_name = key:match("^/?(.-)/")
    key = key:sub(#script_name + 2)
  end

  -- The scripts need to see the json content hidden inside of the form parameter 'content'
  local d = { content = json.encode(data) }

  log.debug(me.name, "Executing property write via script handler. script: %s, path: %s", script_name, key)
  local code, resp = ps_script.executeCallback(script_name, method, key, headers, key_query_params, d)

  if code == 200 then
    return code
  else
    return code, resp
  end
end
