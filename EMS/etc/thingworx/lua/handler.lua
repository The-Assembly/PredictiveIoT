local base = _G
local log = require "log"
local json = require "json"
local utils = require "utils"
local stringx = require "stringx"
local tablex = require "tablex"
local os = base.os
local math = base.math
local table = base.table
local string = base.string
local ps_utils = base.ps_utils
local ps_script = base.ps_script
local ps_http = base.ps_http
local ps_rap = base.ps_rap
local ps_dir = base.ps_dir
local ps_mutex = base.ps_mutex
local tw_utils = base.ps_utils
local p_data = p_data
local thingworx = thingworx

--------------------------------------------------------------------------------
-- This module is the base type for all Handlers in the framework.
-- A Handler is a modular way to implement the reading and writing of property
-- values to different data sources. Each handler is required to implement a 
-- read and write function to handle the reading and writing of property values.
--
-- <p>The read function must implement the following signature:</p>
--
-- <p><code>read(me, pt, headers, query)</code></p>
--
-- <ul>
--  <li>me: A reference to the currently executing thing.</li>
--  <li>pt: The property table. This is the full property table as defined in
--          the thing's template file. The attributes defined in that table
--          are all available for use, in addition to other fields as described
--          below.</li>
--  <li>headers: A table of the HTTP headers that accompanied the GET 
--               request for this property.</li>
--  <li>query: A table of the query parameters included in the URL of the GET
--               request for this property.</li>
-- </ul>
--
-- <p>
-- Each property table also includes three important fields: <strong>name
-- </strong>, <strong>value</strong>, <strong>time</strong>, and 
-- <strong>quality</strong>. The name field contains the name of the property 
-- being read. The <em>value, time</em>, and <em>quality</em> fields must be set 
-- by your handler in order for the framework to return the correct value for the 
-- property request. The <em>value</em> field should be set to whatever value is 
-- determined by your handler to be the result of the read request. The 
-- <em>time</em> field is set to the time that the value was determined, in 
-- milliseconds since 01/01/0001. tw_utils.currentTime() can be used to set this 
-- field to the current time. The <em>quality</em> field should be set to 'GOOD', 
-- 'BAD', or 'UNKNOWN', depending on how certain you are of the quality of your 
-- handler's result.
-- </p>
--
-- <p>
-- If you have not provided defaults for these values in your template file,
-- then the fields will have the following values when read() is called for 
-- the first time. pt.value will default to '0'. pt.time will default to the 
-- start time of the thing. pt.quality will default to 'UNKNOWN'.
-- </p>
--
-- <p>The write function must implement the following signature:</p>
--
-- <p><code>write(me, pt, headers, query, data)</code></p>
--
-- <ul>
--  <li>me: A reference to the currently executing thing.</li>
--  <li>pt: The property table. This is the full property table as defined in
--          the thing's template file. The attributes defined in that table
--          are all available for use, as well as the <em>name</em> field, 
--          which contains the name of the property being set.
--  <li>headers: A table of the HTTP headers that accompanied the PUT
--               request for this property.</li>
--  <li>query: A table of the query parameters included in the URL of the PUT
--               request for this property.</li>
--  <li>data: A table with the single field <strong>value</strong> which holds
--            the new value for the property.
-- </ul>
--
-- <p>
-- The write function is responsible for extracting the data.value field and 
-- using it to set the value of the underlying resource. Note that the write
-- function <strong>should not</strong> set the pt.value, pt.time, or 
-- pt.quality fields. This should only happen in the read function.
-- </p>
--------------------------------------------------------------------------------
module "thingworx.handler"

--------------------------------------------------------------------------------
-- Converts a standard Lua module into a Handler. This method should be used 
-- during the module initialization of any new Handler:
-- <pre>module ("handlers.newhandler", thingworx.handler.extend)</pre>
--
-- This will place the core Lua libraries, core Lua functions, all ThingWorx
-- libraries, and common utlities into the new Handler's scope.
--
-- It also adds the following variables into the handler's scope:
-- <ul>
--  <li>p_data: The table of configuration data linked to the Thing. This table
--              can be populated with settings via the script resource's config
--              file, or directly within a handler or template.</li>
--  <li>name: The name of the current Thing.</li>
--  <li>services: An empty table that can be populated with services specific to 
--                the new handler.</li>
--  <li>properties: An empty table that can be populated with properties specific to 
--                  the new handler.</li>
--  <li>tasks: An empty table that can be populated with tasks specific to 
--             the new handler.</li>
-- </ul>
--
-- @param m The module to be extended.
--
function extend(m)
  log.info("thingworx.handler", "Creating a new handler.")

  m.base = base
  m.p_data = p_data
  m.name = p_data.name
  m.log = log
  m.json = json
  m.thingworx = thingworx
  m.server, m.tw_server = thingworx.server, thingworx.server

  -- Add all the ps_* libs and their tw_* aliases to the local 
  -- scope of the new handler.
  m.ps_rap, m.tw_rap, m.tw_ems = ps_rap, ps_rap, ps_rap
  m.ps_dir, m.tw_dir = ps_dir, ps_dir
  m.ps_script, m.tw_script = ps_script, ps_script
  m.ps_utils, m.tw_utils = ps_utils, ps_utils
  m.ps_mutex, m.tw_mutex = ps_mutex, ps_mutex
  m.ps_http, m.tw_http = ps_http, ps_http

  -- Add all the core lua libs to the handler's local scope
  m.coroutine = base.coroutine
  m.debug = base.debug
  m.file = base.file
  m.io = base.io
  m.math = base.math
  m.os = base.os
  m.package = base.package
  m.string = base.string
  m.table = base.table

  -- Put the core lua functions into the template's local scope
  m.assert, m.collectgarbage, m.dofile, m.error, m.getfenv, m.getmetatable, 
  m.ipairs, m.load, m.loadfile, m.loadstring, m.module, m.next, m.pairs, 
  m.pcall, m.print, m.rawequal, m.rawget, m.rawset, m.require, m.select, 
  m.setfenv, m.setmetatable, m.tonumber, m.tostring, m.type, m.unpack, m.xpcall = 
  base.assert, base.collectgarbage, base.dofile, base.error, base.getfenv, 
  base.getmetatable, base.ipairs, base.load, base.loadfile, base.loadstring, 
  base.module, base.next, base.pairs, base.pcall, base.print, base.rawequal, 
  base.rawget, base.rawset, base.require, base.select, base.setfenv, 
  base.setmetatable, base.tonumber, base.tostring, base.type, base.unpack, base.xpcall

  -- Create these tables so template authors don't have to
  m.services = {}
  m.properties = {}
  m.tasks = {}

  -- Setup empty 'open' and 'close' functions in the handler that get called from
  -- the template at startup and shutdown. Handlers can override these for custom
  -- lifecycle events.
  m.open  = function() log.info(m._NAME, "Opened") end
  m.close = function() log.info(m._NAME, "Closed") end
end
