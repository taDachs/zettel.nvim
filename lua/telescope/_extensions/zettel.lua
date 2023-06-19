local zettel = require("zettel")

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values

local function node_to_entry(node)
  local title
  if node.title then
    title = node.title .. " (" .. node.id .. ")"
  else
    title = node.id
  end
  return {
    display = title,
    value = zettel.get_path(node.id),
    ordinal = node.title or node.id,
    id = node.id,
  }
end

local function build_picker(opts, nodes, action)
  local finder = finders.new_table({
    results = nodes,
    entry_maker = node_to_entry,
  })
  return pickers
      .new(opts, {
        prompt_title = "Zettel",
        finder = finder,
        sorter = conf.generic_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(_, map)
          actions.select_default:replace(action)
          return true
        end,
      })
end

local function incoming_zettel_picker(opts)
  opts = opts or { "list-names" }
  local current_node = zettel.get_current_node()
  local nodes = current_node.incoming
  build_picker(opts, nodes):find()
end

local function outgoing_zettel_picker(opts)
  opts = opts or { "list-names" }
  local current_node = zettel.get_current_node()
  local nodes = current_node.outgoing
  build_picker(opts, nodes):find()
end

local function all_zettel_picker(opts)
  opts = opts or { "list-names" }
  local nodes = {}
  for _, v in pairs(zettel.graph.nodes) do
    nodes[#nodes + 1] = v
  end
  build_picker(opts, nodes):find()
end

local function insert_link_picker(opts)
  opts = opts or { "list-names" }
  local nodes = {}
  for _, v in pairs(zettel.graph.nodes) do
    nodes[#nodes + 1] = v
  end
  build_picker(opts, nodes, function(prompt_bufnr)
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
  end):find()
end

local function tag_picker(opts)
  opts = opts or { "list-names" }
  local tag = vim.ui.input({ prompt = "Tag: " }, function(input)
    if not tag then
      return
    end
    local nodes = zettel.graph:get_nodes_by_tag(tag)
    build_picker(opts, nodes):find()
  end)
end


return require("telescope").register_extension({
  setup = function(ext_config, config)
    -- access extension config and user config
  end,
  exports = {
    find_incoming = incoming_zettel_picker,
    find_outgoing = outgoing_zettel_picker,
    find_all = all_zettel_picker,
    insert_link = insert_link_picker,
    tag = tag_picker,
  },
})
