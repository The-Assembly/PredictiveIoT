
--
-- No-op log functions if they aren't needed
--
if p_data.log_level == "FORCE" or
   p_data.log_level == "AUDIT" or
   p_data.log_level == "ERROR" or
   p_data.log_level == "WARN"  or
   p_data.log_level == "INFO"  then
    log.trace = function() end
    log.debug = function() end
end

if p_data.log_level == "DEBUG" then   
    log.trace = function() end
end

---------------------------------------------------------------
-- ThingWorx, (c)2012 ThingWorx
--
-- A simple script for launching a Thing based on a template.
-- The name of the script is used as the Thing's name. The
-- script must also have a property 'template' that is the
-- name of the template to use.
---------------------------------------------------------------
require "template"
local template = "templates." .. p_data.template
local mod = require(template)
mod:new(p_data):start()
