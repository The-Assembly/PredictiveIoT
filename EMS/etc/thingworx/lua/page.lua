
require "log"

local base   = _G
local table  = base.table
local format = base.string.format
local log    = base.log

local default_style = { [==[
body { font-family: arial,sans-serif; font-size: small; }
h1 { font-size: x-large; }
p, table { font-size: small; }
p { margin: 10px 0 10px 0; }
table { border-collapse: collapse; margin: 10px 0 20px 0; }
th, td { 
  border: 1px solid #C1DAD7;
  text-align: left;
  padding: 6px 6px 6px 12px; }"
]==],
}

-----------------------------------------------------------------------
-- A module for creating basic HTML pages through the construction of 
-- a simple set of tables.
--
module "page"

-----------------------------------------------------------------------
-- Create a new page 'object' with the given title. This page will
-- produce a default HTML page that can be populated with additional
-- HTML content.
--
function new(self, title)
    base.assert(title, "Page requires a title.")
    local id = title:lower():match("(%w*)") .. "_body"
    local t = { 
        title = title,
        id = id,
        doctype = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">",
        html_open = "<html>",
        body_open = "<body id='" .. id .. "'>",
        head = { "" },
        style = default_style,
        body = { "" },
        headers = { ["Content-Type"] = "text/html" },
        status = 200,
    }
    base.setmetatable(t, {__index = self})
    return t
end

function addHeadContent(self, str, ...)
    table.insert(self.head, str:format(...))
end

function addContent(self, str, ...)
    table.insert(self.body, str:format(...))
end

-- See render_table
function addTable(self, ...)
    self:addContent(self:render_table(...))
end

-- See render_list
function addList(self, ...)
    self:addContent(self:render_list(...))
end

-----------------------------------------------------------------------
--
-- Page Rendering Functions
--
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Render the page according to the status code supplied. A 200 
-- results in a successful page rendering. A 301, 302, or 303 will 
-- cause a redirect to be sent. Any other code will cause the default 
-- error page to be rendered.
--
-- Parameter:
--  * code: The HTTP status code to use. If this is 200 the remaining
--          parameters are ignored. Defaults to 200.
--  * msg:  An error message for a non-200 page. If the page is a 
--          redirect, this field is used to supply the path.
--  * desc: A more detailed error description. Only used for non-200
--          and non-redirecting pages.
--
-- Returns:
--  * A status code (number)
--  * Response headers (table)
--  * Response body (string)
--
-- These return values can be used as the return values for a callback
-- function registered with ps_http.
-----------------------------------------------------------------------
function render(self, code, msg, desc)
    code = code or self.status

    if (code == 200) then 
        return self:success()
    elseif (code == 301 or code == 302 or code == 303) then
        return self:redirect(code, msg)
    else
        return self:error(code, msg, desc)
    end
end

function success(self)
    local output = ""

    if self.headers["Content-Type"] == "text/html" then
        output = format("%s\n\n%s\n", self.doctype, self.html_open)
        output = format("%s<head>\n <title>%s</title>\n", output, self.title)

        for i,v in base.ipairs(self.head) do
            output = format("%s%s\n", output, v)
        end

        if (#self.style > 0) then
            output = format("%s%s\n <!--\n\n", output, " <style type='text/css'>")
            for i,v in base.ipairs(self.style) do
                output = format("%s%s\n", output, v)
            end
            output = format("%s -->\n </style>\n", output)
        end

        output = format("%s</head>\n%s\n", output, self.body_open)
    elseif self.headers["Content-Type"] == "text/xml" then
        output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    end

    for i,v in base.ipairs(self.body) do
        output = format("%s%s\n", output, v)
    end

    if self.headers["Content-Type"] == "text/html" then
        output = format("%s</body>\n</html>\n", output)
    end

    return self.status, self.headers, output
end

function error(self, code, msg, desc)
    log.error("error", "Returning error (%d): %s.", code, msg)
    self.status = code or 500
    msg = msg or "Internal Server Error"
    desc = desc or " "
    self.body = { "<h2>Status: " .. self.status .. "</h2>", 
                  "<strong>" .. msg .. "</strong>",
                  "<hr />", 
                  "<p>" .. desc .. "</p>" }

    return self:success()
end

function redirect(self, code, path)
    code = code or 303
    log.debug("redirect", "Redirect (%d) to %s.", code, path)
    return code, { Location = path, Connection = "close" } , ""
end

-----------------------------------------------------------------------
--
-- Table and List Rendering Functions. These are class functions
-- and cannot be called on page objects.
--
-----------------------------------------------------------------------

-----------------------------------------------------------------------
-- Take a Lua table and render it as HTML. The Lua table must be an
-- array and each element must be another table. The sub-tables
-- represent the rows in the HTML table. If the row table is integer
-- indexed, then each row is rendered in the order specified in the
-- array. If it is string indexed, the 'headers' table is used to
-- determine the ordering of the cells in the row. This means that
-- the values in the integer indexed 'header' array must match the
-- keys used in each row.
--
-- Parameters: 
--  * t: The array of arrays to render.
--  * id: The HTML id to use for the table element. This must be 'nil'
--        if no id is desired.
--  * class: The HTML class to use for the table element. This must 
--           be 'nil' if no class is desired.
--  * headers: An array of strings to use as the headers for the HTML
--             table.
--  * tr_class: The HTML class to use for each <tr> element. This must
--              be 'nil' if no class is desired.
--  * th_class: The HTML class to use for each <th> element. This must
--              be 'nil' if no class is desired.
--  * td_class: The HTML class to use for each <td> element. This must
--              be 'nil' if no class is desired.
-- Returns:
--  * A string containing the rendered HTML table.
--
-----------------------------------------------------------------------
function render_table(self, rows, id, class, headers, tr_class, th_class, td_class)
    if id       then id       = " id='"    .. id       .. "'" else id       = "" end
    if class    then class    = " class='" .. class    .. "'" else class    = "" end
    if tr_class then tr_class = " class='" .. tr_class .. "'" else tr_class = "" end
    if th_class then th_class = " class='" .. th_class .. "'" else th_class = "" end
    if td_class then td_class = " class='" .. td_class .. "'" else td_class = "" end

    local output = format("  <table%s%s>\n", id, class)

    if (headers and #headers > 0) then
        output = format("%s   <tr%s>", output, tr_class)
        for _,v in base.ipairs(headers) do
            output = format("%s<th%s>%s</th>", output, td_class, v)
        end
        output = format("%s</tr>\n", output)
    end

    if (rows) then
        for _,row in base.ipairs(rows) do
            output = format("%s   <tr%s>", output, tr_class)
            if (#row > 0) then -- The row is an array
                for _,v in base.ipairs(row) do
                    output = format("%s<td%s>%s</td>", output, td_class, v)
                end
            elseif headers then -- The row is a table, render using headers for keys
                for _,header in base.pairs(headers) do
                    output = format("%s<td%s>%s</td>", output, td_class, row[header])
                end
            else -- The row is a table, but who knows how we should display it?
                for k,v in base.pairs(row) do
                    output = format("%s<td%s>%s = %s</td>", output, td_class, k, v)
                end
            end
            output = format("%s</tr>\n", output)
        end
    end

    return format("%s  </table>", output)
end

-----------------------------------------------------------------------
-- Render a HTML ul, ol, or dl list using the given table as the
-- content.
--
-- Parameters:
--  * t: The table containing values for the list. An integer indexed
--       table will result in a ul or ol, a string indexed table will
--       result in a dl.
--  * ordered: A boolean specifying whether to render a ul (false) 
--             or dl (true).
--  * id: The id of the list element. Use nil if you prefer no id.
--  * class: The class of the list element. Use nil if you prefer 
--           no id.
--  * li_class: The class of the li elements. Use nil if you prefer 
--              no id.
--  * dt_class: The class of the dt elements. Use nil if you prefer 
--              no id.
--  * dd_class: The class of the dd elements. Use nil if you prefer 
--              no id.
-----------------------------------------------------------------------
function render_list(self, t, ordered, id, class, li_class, dt_class, dd_class)
    if id       then id       = " id='"    .. id       .. "'" else id       = "" end
    if class    then class    = " class='" .. class    .. "'" else class    = "" end
    if li_class then li_class = " class='" .. li_class .. "'" else li_class = "" end
    if dt_class then dt_class = " class='" .. dt_class .. "'" else dt_class = "" end
    if dd_class then dd_class = " class='" .. dd_class .. "'" else dd_class = "" end

    local output = format("  <ul%s%s>\n", id, class)

    if (t and #t > 0) then -- This is a order or unordered list
        if (ordered) then
            output = format("  <ol%s%s>\n", id, class)
        end

        for _,li_val in base.ipairs(t) do
            output = format("%s    <li%s>%s</li>\n", output, li_class, li_val)
        end

        output = format("%s  </ul>", output)
        if (ordered) then
            output = format("%s  </ol>", output)
        end
    else -- This is a definition list
        output = format("  <dl%s%s>\n", id, class)

        for dt,dd in base.pairs(t) do
            output = format("%s    <dt%s>%s</dt><dd%s>%s</dd>\n", output, dt_class, dt, dd_class, dd)
        end
        output = format("%s  </dl>", output)
    end

    return output
end

