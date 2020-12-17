
module("handlers.inmemory", thingworx.handler.extend)

--------------------------------------------------------------------------------
-- Read the current value for the given property. This handler stores the value
-- in a table, in memory.  Those values are copied from the table into the 
-- property's current value, time, and quality fields.  The inmemory table
-- is then set to nil. Any further reads that happen before a call to 'write'
-- will simply result in the current values being unchanged.
--
-- @param me The thing being operated on
-- @param pt The property table for the property being read. This contains all
--           of the fields configured on the property in the thing's template
--           file.
-- @param headers The HTTP headers from the request that initiated this read.
--                These can typically be ignored.
-- @param query The HTTP query parameters from the request that initiated this 
--              read. These can typically be ignored.
--
-- @return The status code indicating success or failure of the read.
--
function read(me, pt, headers, query)

  tw_mutex.lock()

  -- Set the 'current' values if the internal 'next' cache 
  -- has been updated
  if pt.next then
    pt.value = pt.next.value
    pt.time = pt.next.time
    pt.quality = pt.next.quality
  end

  pt.next = nil
  tw_mutex.unlock()
  
  return 200
end

--------------------------------------------------------------------------------
-- Write a new value to the given property. This handler stores the value
-- in a table, in memory. If the inmemory table does not exist it will be
-- created. The last value written via this function is what will be copied into
-- pt.value, pt.time, and pt.quality on any subsequent calls to read().
--
-- @param me The thing being operated on.
-- @param pt The property table for the property to be written to. This contains 
--           all of the fields configured on the property in the thing's 
--           template file.
-- @param headers The HTTP headers from the request that initiated this read.
--                These can typically be ignored.
-- @param query The HTTP query parameters from the request that initiated this 
--              read. These can typically be ignored.
--
-- @return The status code indicating success or failure of the write.
--
function write(me, pt, headers, query, data)

  tw_mutex.lock()

  pt.next = {
    value = data.value,
    time = os.time() * 1000,
    quality = data.quality or "GOOD"
  }

  tw_mutex.unlock()

  return 200
end
