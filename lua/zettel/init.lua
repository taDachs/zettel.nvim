local M = {}
M.config = {
  root_dir = "~/notes/zettelkasten", -- root dir for notes
  format = "md",                     -- file ending for notes
  link_pattern = "%[%[([^%]]+)%]%]", -- pattern for matching links, first group should match the link itself
  tag_pattern = "#([%w%-%_]+)",      -- pattern for matching tags
  title_pattern = "^# (.*)$",        -- pattern for matching title of file
  open_cmd = "edit",                 -- command used for opening files
}

function M.path_to_id(path)
  path = vim.fs.normalize(path)
  local id = vim.fs.basename(path)
  id = id:sub(1, id:len() - M.config.format:len() - 1)

  return id
end

-- @param id ID
-- @return string
function M.get_path(id)
  return vim.fs.normalize(M.config.root_dir .. "/" .. id .. "." .. M.config.format)
end

-- @alias ID string

-- @class Node
-- @field incoming Node[]
-- @field outgoing Node[]
-- @field id ID
-- @field title string
-- @field tags string[]
local Node = {}
Node.__index = Node

function Node.new()
  local self = setmetatable({}, Node)

  self.outgoing = {}
  self.incoming = {}
  self.tags = {}

  return self
end

-- @class Graph
-- @field nodes { [string]: boolean }
local Graph = {}
Graph.__index = Graph

-- @return Graph
function Graph.new()
  local self = setmetatable({}, Graph)

  self.nodes = {}

  return self
end

-- loads a node from a given path
-- @param path string
-- @return Node
function Graph:add_from_path(path)
  path = vim.fs.normalize(path)
  local id = M.path_to_id(path)
  self.nodes[id] = Node.new()
  self.nodes[id].id = id

  -- not yet created
  if not vim.loop.fs_stat(path) then
    return self.nodes[id]
  end

  for line in io.lines(path) do
    if not self.nodes[id].title then
      self.nodes[id].title = line:match(M.config.title_pattern)
    end

    for link_url in line:gmatch(M.config.link_pattern) do
      local link_target
      if not self.nodes[link_url] then
        local zettel_path = M.get_path(link_url)
        link_target = self:add_from_path(zettel_path)
      else
        link_target = self.nodes[link_url]
      end

      table.insert(self.nodes[id].outgoing, link_target)

      if not vim.tbl_contains(link_target.incoming, self.nodes[id]) then
        table.insert(link_target.incoming, self.nodes[id])
      end
    end

    for tag in line:gmatch(M.config.tag_pattern) do
      if not vim.tbl_contains(self.nodes[id].tags, tag) then
        table.insert(self.nodes[id].tags, tag)
      end
    end
  end

  return self.nodes[id]
end

function Graph:get_nodes_by_tag(tag)
  local nodes = {}
  for _, node in pairs(self.nodes) do
    if vim.tbl_contains(node.tags, tag) then
      table.insert(nodes, node)
    end
  end
  return nodes
end

-- @return string[]
function Graph:get_all_tags()
  local tags = {}
  for _, node in pairs(self.nodes) do
    for _, tag in pairs(node.tags) do
      if not vim.tbl_contains(tags, tag) then
        table.insert(tags, tag)
      end
    end
  end
  return tags
end

M.generate_name = function()
  local current_date = os.date "*t"
  local date_string = string.format(
    "%04d%02d%02d%02d%02d%02d",
    current_date.year,
    current_date.month,
    current_date.day,
    current_date.hour,
    current_date.min,
    current_date.sec
  )
  return date_string
end

M.insert_new_link = function()
  local filename = M.generate_name()

  -- Create the text to insert
  local text_to_insert = "[[" .. filename .. "]]"

  -- Insert the text under the cursor
  vim.api.nvim_put({ text_to_insert }, "b", true, true)
end

M.get_link_under_cursor = function()
  -- Get the current line
  local line = vim.api.nvim_get_current_line()

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_col = cursor[2] + 1

  -- surround pattern in group to get the whole match
  local pattern = "(" .. M.config.link_pattern .. ")"
  -- Iterate over matches and obtain start and end positions
  for full_link, link_url in string.gmatch(line, pattern) do
    local start_pos, end_pos = string.find(line, full_link, 1, true)
    if cursor_col >= start_pos and cursor_col <= end_pos then
      return link_url
    end
  end

  return nil
end

M.follow_link_under_cursor = function()
  local link = M.get_link_under_cursor()
  if not link then
    return
  end

  local full_path = M.get_path(link)
  vim.cmd(M.config.open_cmd .. " " .. full_path)
end

function M.get_current_node()
  local current_file_path = vim.api.nvim_buf_get_name(0)
  local current_id = M.path_to_id(current_file_path)
  return M.graph.nodes[current_id]
end

-- @param nodes Node[]
function M.set_qflist(nodes)
  local entries = {}
  for _, node in pairs(nodes) do
    local entry = { filename = M.get_path(node.id), lnum = 1, col = 1, text = node.title }
    table.insert(entries, entry)
  end
  vim.fn.setqflist(entries)
end

function M.setup(opts)
  M.config.root_dir = opts.root_dir or M.config.root_dir
  M.config.format = opts.format or M.config.format
  M.config.link_pattern = opts.link_pattern or M.config.link_pattern
  M.config.tag_pattern = opts.tag_pattern or M.config.tag_pattern
  M.config.title_pattern = opts.title_pattern or M.config.title_pattern
  M.config.open_cmd = opts.open_cmd or M.config.open_cmd

  if not M.graph then
    M.graph = Graph.new()

    for file in vim.fs.dir(M.config.root_dir) do
      file = vim.fs.normalize(M.config.root_dir .. "/" .. file)
      if vim.loop.fs_stat(file).type == "file" then
        M.graph:add_from_path(file)
      end
    end
  end

  local zettel_group = vim.api.nvim_create_augroup("zettel.nvim", { clear = true })

  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = vim.fs.normalize(M.config.root_dir .. "/" .. "*" .. M.config.format),
    callback = function()
      local current_file_path = vim.api.nvim_buf_get_name(0)
      M.graph:add_from_path(current_file_path)
    end,
    group = zettel_group,
  })

  vim.api.nvim_create_user_command("ZettelIn", function() M.set_qflist(M.get_current_node().incoming) end, {})
  vim.api.nvim_create_user_command("ZettelOut", function() M.set_qflist(M.get_current_node().outgoing) end, {})
  vim.api.nvim_create_user_command("ZettelAll", function() M.set_qflist(M.graph.nodes) end, {})
  vim.api.nvim_create_user_command("ZettelTag", function(opts) M.set_qflist(M.graph:get_nodes_by_tag(opts.args)) end,
    { nargs = 1, complete = function() return M.graph:get_all_tags() end})
end

return M
