local zettel = require("zettel")
return require("telescope").register_extension({
  setup = function(ext_config, config)
    -- access extension config and user config
  end,
  exports = {
    find_incoming = function(opts) zettel.pickers.zettel_picker(opts, "incoming", "open") end,
    find_outgoing = function(opts) zettel.pickers.zettel_picker(opts, "outgoing", "open") end,
    find_all = function(opts) zettel.pickers.zettel_picker(opts, "all", "open") end,
    insert_link = function(opts) zettel.pickers.zettel_picker(opts, "all", "insert") end,
  },
})
