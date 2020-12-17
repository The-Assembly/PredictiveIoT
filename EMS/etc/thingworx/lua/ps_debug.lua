--------------------------------------------------------------------
-- You can use this script in two ways:
-- 1. Place it in your current directory and then set your
--    package.path manually in this file.
-- 2. Set you LUA_PATH to include the location of this file, as
--    well as the other lua libs you will use.
-- You then require this file. Require will return a table
-- containing the init method.  Call this method with the following
-- params (defaults in parens):
--  script_name: The name of your script (DEBUGGING)
--  script_dir: The directory where scripts are located (./scripts)
--  script_file: The file name of your script (<name>.lua)
--  rap_host: The hostname of the rap (localhost)
--  rap_port: The port the rap listens on (8000)
--  rap_timeout: Timeout for interaction with the rap, in
--               milliseconds (10000 ms)
--------------------------------------------------------------------

--------------------------------------------------------------------
-- Set package.path and package.cpath here.  You should also
-- include the location of the ps_library.dll.

package.path  = "..\\lua_libs\\?.lua;"  .. package.path
package.cpath = "..\\lua_clibs\\win32\\?.dll;..\\debug_ps_library\\?.dll;" .. package.cpath

--------------------------------------------------------------------

assert(not p_data, "p_data already defined.")

-- Set up our EMS host/port
p_data = {}
p_data.rap_host = "localhost"
p_data.rap_port = 8000
p_data.rap_timeout = 10000
p_data.name = "DEBUGING"
p_data.script_directory = ".\\scripts"
p_data.run = true

print("Loading debug library.")
require "ps_library"

-- Change our logging to print statements so they show up in the debugger
ps_logger = {
    force = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), "FORCE: ", ...) end,
    audit = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), "AUDIT: ", ...) end,
    error = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), "ERROR: ", ...) end,
    warn  = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), " WARN: ", ...) end,
    info  = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), " INFO: ", ...) end,
    debug = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), "DEBUG: ", ...) end,
    trace = function(...) print(ps_utils.datetimeToString(ps_utils.currentTime()), "TRACE: ", ...) end,
}

return {
    -- This function provides a way to initialize the p_data table.
    -- @param t A table of p_data values. You probably want to pass in at
    --          least the script name. {name = 'the_script'}
    init = function(t)
        for k,v in pairs(t) do
            p_data[k] = v
        end

        ps_logger.force("Script name:        " .. p_data.name)
        ps_logger.force("Script dir:         " .. p_data.script_directory)
        ps_logger.force("Script rap_host:    " .. p_data.rap_host)
        ps_logger.force("Script rap_port:    " .. p_data.rap_port)
        ps_logger.force("Script rap_timeout: " .. p_data.rap_timeout)
    end
}
