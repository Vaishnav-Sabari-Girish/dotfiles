return {
  "vyfor/cord.nvim",
  build = ":Cord update",
  event = "VeryLazy",
  opts = {
    enabled = true,
    log_level = vim.log.levels.OFF,
    editor = {
      client = "neovim",
      tooltip = "Skill issue, use Neovim",
      icon = nil,
    },
    display = {
      theme = "minecraft",
      flavor = "dark",
      view = "full",
      swap_fields = false,
      swap_icons = false,
    },
    timestamp = {
      enabled = true,
      reset_on_idle = false,
      reset_on_change = false,
      shared = false,
    },
    idle = {
      enabled = true,
      timeout = 300000,
      show_status = true,
      ignore_focus = true,
      unidle_on_focus = true,
      smart_idle = true,
      details = "Idling",
      state = nil,
      tooltip = "💤",
      icon = nil,
    },
    text = {
      default = nil,

      workspace = function(opts)
        return "Superior to IDE users in " .. opts.workspace
      end,

      viewing = function(opts)
        return "Inspecting " .. opts.filename .. " manually"
      end,

      editing = function(opts)
        return "Out-editing GUI users in " .. opts.filename
      end,

      file_browser = function(opts)
        return "Browsing files without a mouse in " .. opts.name
      end,

      plugin_manager = function(opts)
        return "Customizing what others download" .. " in " .. opts.name
      end,

      lsp = function(opts)
        return "Using LSP correctly in " .. opts.name
      end,

      docs = function(opts)
        return "Reading documentation voluntarily"
      end,

      vcs = function(opts)
        return "Committing code I actually understand"
      end,

      notes = function(opts)
        return "Writing notes instead of opening Notion"
      end,

      debug = function(opts)
        return "Finding bugs without Stack Overflow"
      end,

      test = function(opts)
        return "Verifying assumptions in " .. opts.name
      end,

      diagnostics = function(opts)
        return "Fixing my mistakes before production"
      end,

      games = function(opts)
        return "Gaming in my text editor"
      end,

      terminal = function(opts)
        return "Using the computer directly"
      end,

      dashboard = "Awaiting less capable developers",
    },
    buttons = nil,
    -- buttons = {
    --   {
    --     label = 'View Repository',
    --     url = function(opts) return opts.repo_url end,
    --   },
    -- },
    assets = nil,
    variables = true,
    hooks = {
      ready = nil,
      shutdown = nil,
      pre_activity = nil,
      post_activity = nil,
      idle_enter = nil,
      idle_leave = nil,
      workspace_change = nil,
      buf_enter = nil,
    },
    extensions = nil,
    advanced = {
      plugin = {
        autocmds = true,
        cursor_update = "on_hold",
        match_in_mappings = true,
        debounce = {
          delay = 50,
          interval = 750,
        },
      },
      server = {
        update = "fetch",
        pipe_path = nil,
        executable_path = nil,
        timeout = 300000,
      },
      discord = {
        pipe_paths = nil,
        reconnect = {
          enabled = false,
          interval = 5000,
          initial = true,
        },
        sync = {
          enabled = true,
          mode = "periodic",
          interval = 12000,
          reset_on_update = true,
          pad = true,
        },
      },
      workspace = {
        root_markers = {
          ".git",
          ".hg",
          ".svn",
        },
        limit_to_cwd = false,
      },
    },
  },
}
