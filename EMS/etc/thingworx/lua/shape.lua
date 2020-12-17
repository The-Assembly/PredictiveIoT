
require "thingworx.shapes.metadata"

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
-- A Shape is a modular way to add a specific set of functionality to a 
-- template. Each shape is a collection of services, properties, and tasks.
-- When a shape is required within a template, its services, properties, and
-- tasks are added to template.
--
-- This module is the base type for all Shapes in the framework.
--------------------------------------------------------------------------------
module "thingworx.shape"

--------------------------------------------------------------------------------
-- Converts a standard Lua module into a Shape. This method should be used 
-- during the module initialization of any new Shape:
-- <pre>module ("shapes.newshape", thingworx.shape.extend)</pre>
--
-- This will place the core Lua libraries, core Lua functions, all ThingWorx
-- libraries, and common utlities into the new shape's scope.
--
-- It also adds the following variables into the shape's scope:
-- <ul>
--  <li>me: A reference to this shape.</li>
--  <li>p_data: The table of configuration data linked to the Thing. This table
--              can be populated with settings via the script resource's config
--              file, or directly within a shape or template.</li>
--  <li>name: The name of the current Thing.</li>
--  <li>services: An empty table that can be populated with services specific to 
--                the new shape.</li>
--  <li>properties: An empty table that can be populated with properties specific to 
--                  the new shape.</li>
--  <li>tasks: An empty table that can be populated with tasks specific to 
--             the new shape.</li>
-- </ul>
--
function extend(m)
  log.info("thingworx.shape", "Creating a new shape.")

  m.me = m
  m.base = base
  m.p_data = p_data
  m.name = p_data.name
  m.log = log
  m.json = json
  m.thingworx = thingworx
  m.server, m.tw_server = thingworx.server, thingworx.server
  m.stringUtils = stringUtils
  m.dataShapes = base.dataShapes
  m.DataShape = base.DataShape -- table of defined data shapes

  -- Add all the ps_* libs and their tw_* aliases to the local 
  -- scope of the new shape.
  m.ps_rap, m.tw_rap, m.tw_ems = ps_rap, ps_rap, ps_rap
  m.ps_dir, m.tw_dir = ps_dir, ps_dir
  m.ps_script, m.tw_script = ps_script, ps_script
  m.ps_utils, m.tw_utils = ps_utils, ps_utils
  m.ps_mutex, m.tw_mutex = ps_mutex, ps_mutex
  m.ps_http, m.tw_http = ps_http, ps_http
  m.tw_datashape = tw_datashape
  m.tw_infotable = tw_infotable 

  -- Add all the core lua libs to the shape's local scope
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

	--The following section maps the metadata shape functions to the table passed in to the
	--extend method so that they will be available to any extended shape
	m.input = base.shapes.metadata.input
	m.output = base.shapes.metadata.output
	m.description = base.shapes.metadata.description
	m.private = base.shapes.metadata.private
	--The following function in the metadata.lua initializes the serviceDefinitions and definedServiceDefinitions
	--to be used by derived shapes service and property metadata
	m.serviceDefinitions, m.definedServiceDefinitions = base.shapes.metadata.init(m)

  -- Setup empty 'start' and 'stop' functions in the shape that get called from
  -- the template at startup and shutdown. Shapes can override these for custom
  -- lifecycle events.
  m.start = function() log.info(m._NAME, "Initialized") end
  m.stop  = function() log.info(m._NAME, "Stopped") end
end
