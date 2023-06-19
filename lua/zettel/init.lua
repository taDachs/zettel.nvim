local M = {}
M.config = {
  root_dir = "~/notes/zettelkasten", -- root dir for notes
  format = "md", -- file ending for notes
  link_pattern = "%[%[([^%]]+)%]%]", -- pattern for matching links
  tag_pattern = "#([%w%-%_]+)", -- pattern for matching tags
  title_pattern = "^# (.*)$", -- pattern for matching title of file
  open_cmd = "edit", -- command used for opening files
}

-- @alias ID string
local function pathToId(path)
  path = vim.fs.normalize(path)
  local id = vim.fs.basename(path)
  id = id:sub(1, id:len() - M.config.format:len() - 1)

  return id
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

function Node.new()
  local self = setmetatable({}, Node)

  self.outgoing = {}
  self.incoming = {}
  self.tags = {}

  return self
end

-- loads a node from a given path
-- @param path string
-- @return Node
function Graph:addFromPath(path)
  path = vim.fs.normalize(path)
  local id = pathToId(path)
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
        link_target = self:addFromPath(zettel_path)
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

  -- Iterate over matches and obtain start and end positions
  for link_url in string.gmatch(line, M.config.link_pattern) do
    local start_pos, end_pos = string.find(line, "[[" .. link_url .. "]]", 1, true)
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

-- @param id ID
-- @return string
function M.get_path(id)
  return M.config.root_dir .. "/" .. id .. "." .. M.config.format
end

M.pickers = {}

-- @param node Node
local function nodeToEntry(node)
  local title
  if node.title then
    title = node.title .. " (" .. node.id .. ")"
  else
    title = node.id
  end
  return {
    display = title,
    value = M.get_path(node.id),
    ordinal = node.title or node.id,
    id = node.id,
  }
end

-- @param type "incoming"|"outgoing"|"all"
-- @param action "insert"|"open"
function M.pickers.zettel_picker(opts, type, action)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  opts = opts or { "list-names" }

  local current_file_path = vim.api.nvim_buf_get_name(0)
  local current_id = pathToId(current_file_path)
  local current_node = M.graph.nodes[current_id]

  local results = {}
  if type == "incoming" then
    results = current_node.incoming
  elseif type == "outgoing" then
    results = current_node.outgoing
  elseif type == "all" then
    for _, v in pairs(M.graph.nodes) do
      results[#results + 1] = v
    end
  else
    return
  end

  local finder = finders.new_table({
    results = results,
    entry_maker = nodeToEntry,
  })


  local default_action
  if action == "insert" then
    default_action = function(prompt_bufnr)
      local id = action_state.get_selected_entry().id
      local new_link = "[[" .. id .. "]]"

      local mode = vim.api.nvim_get_mode().mode
      actions.close(prompt_bufnr)
      if mode == 'i' then
        vim.api.nvim_put({ new_link }, 'b', true, true)
        vim.api.nvim_feedkeys('a', 'n', true)
      else
        vim.api.nvim_put({ new_link }, '', true, true)
      end
    end
  elseif action == "open" then
    default_action = function(prompt_bufnr)
      local id = action_state.get_selected_entry().id
      local path = M.get_path(id)
      actions.close(prompt_bufnr)
      vim.cmd(M.config.open_cmd .. " " .. path)
    end
  end

  pickers
      .new(opts, {
        prompt_title = "Zettelkasten " .. type,
        finder = finder,
        sorter = conf.generic_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(_, map)
          actions.select_default:replace(default_action)
          return true
        end,
      })
      :find()
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
        M.graph:addFromPath(file)
      end
    end
  end

  local zettel_group = vim.api.nvim_create_augroup("zettel.nvim", { clear = true })

  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    pattern = vim.fs.normalize(M.config.root_dir .. "/" .. "*" .. M.config.format),
    callback = function()
      local current_file_path = vim.api.nvim_buf_get_name(0)
      M.graph:addFromPath(current_file_path)
    end,
    group = zettel_group,
  })

  vim.notify("Zettelkasten loaded")
end

return M
