-- ~/.config/nvim/lua/cflow_to_mermaid.lua
local M = {}

local function sanitize_id(name)
  local clean = name:gsub("[^%w]", "_")
  if clean == "" then
    clean = "node"
  end
  return clean
end

-- Safely get text from a node
local function get_text(node, bufnr)
  if not node then
    return ""
  end
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)
  if ok and text then
    return text
  end
  local start_row, start_col, end_row, end_col = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
  if #lines == 0 then
    return ""
  end
  if #lines == 1 then
    return lines[1]:sub(start_col + 1, end_col)
  else
    lines[1] = lines[1]:sub(start_col + 1)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    return table.concat(lines, "\n")
  end
end

-- Robust capture lookup by NAME instead of positional index.
-- Handles both "single node" and "list of nodes" match shapes
-- (nvim 0.10+ can return either depending on quantifiers).
local function get_capture(query, match, name)
  for id, node in pairs(match) do
    if query.captures[id] == name then
      if type(node) == "table" then
        node = node[1] -- unwrap list form, take first node
      end
      return node
    end
  end
  return nil
end

-- Per-language query definitions.
-- Every def_query MUST capture @func_name and @body.
-- Every call_query MUST capture @callee.
local LANGS = {
  c = {
    def_query = [[
      (function_definition
        declarator: (function_declarator
          declarator: (identifier) @func_name)
        body: (compound_statement) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
  cpp = {
    def_query = [[
      (function_definition
        declarator: (function_declarator
          declarator: (identifier) @func_name)
        body: (compound_statement) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
  python = {
    def_query = [[
      (function_definition
        name: (identifier) @func_name
        body: (block) @body)
    ]],
    call_query = [[(call function: (identifier) @callee)]],
  },
  rust = {
    def_query = [[
      (function_item
        name: (identifier) @func_name
        body: (block) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
  go = {
    def_query = [[
      (function_declaration
        name: (identifier) @func_name
        body: (block) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
  javascript = {
    def_query = [[
      (function_declaration
        name: (identifier) @func_name
        body: (statement_block) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
  typescript = {
    def_query = [[
      (function_declaration
        name: (identifier) @func_name
        body: (statement_block) @body)
    ]],
    call_query = [[(call_expression function: (identifier) @callee)]],
  },
}

-- Map vim filetype -> treesitter parser language name.
local FT_TO_LANG = {
  c = "c",
  cpp = "cpp",
  python = "python",
  rust = "rust",
  go = "go",
  javascript = "javascript",
  typescript = "typescript",
  javascriptreact = "javascript",
  typescriptreact = "typescript",
}

-- Common libc / system calls to exclude from the graph — these are noise,
-- not part of your program's logic. Extend as needed, or set
-- opts.include_libc = true when calling generate_flowchart to keep them.
local IGNORE_CALLS = {
  printf = true,
  fprintf = true,
  sprintf = true,
  snprintf = true,
  malloc = true,
  free = true,
  calloc = true,
  realloc = true,
  memcpy = true,
  memset = true,
  memmove = true,
  strlen = true,
  strcpy = true,
  strncpy = true,
  strcmp = true,
  strcat = true,
  poll = true,
  read = true,
  write = true,
  close = true,
  open = true,
  exit = true,
  perror = true,
  assert = true,
}

function M.generate_flowchart(opts)
  opts = opts or {}
  local bufnr = 0
  local ft = vim.bo[bufnr].filetype
  local lang = FT_TO_LANG[ft]

  if not lang then
    vim.notify("cflow: unsupported filetype '" .. ft .. "'", vim.log.levels.WARN)
    return
  end

  local lang_def = LANGS[lang]
  local parser_ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not parser_ok or not parser then
    vim.notify("No Tree-sitter parser available for " .. lang, vim.log.levels.WARN)
    return
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local def_ok, def_query = pcall(vim.treesitter.query.parse, lang, lang_def.def_query)
  if not def_ok then
    vim.notify("Failed to parse function-def query for " .. lang, vim.log.levels.ERROR)
    return
  end

  local calls_ok, calls_query = pcall(vim.treesitter.query.parse, lang, lang_def.call_query)
  if not calls_ok then
    vim.notify("Failed to parse call-expr query for " .. lang, vim.log.levels.ERROR)
    return
  end

  local edges = {} -- { {caller_id, callee_id, caller_name, callee_name}, ... }
  local func_nodes = {} -- id -> name, for functions actually defined in this file
  local node_set = {}
  local has_relations = false

  for _, match, _ in def_query:iter_matches(root, bufnr, 0, -1) do
    local caller_node = get_capture(def_query, match, "func_name")
    local body_node = get_capture(def_query, match, "body")
    if caller_node and body_node then
      local caller_name = get_text(caller_node, bufnr)
      local caller_id = sanitize_id(caller_name)
      func_nodes[caller_id] = caller_name
      node_set[caller_id] = true

      for _, c_match, _ in calls_query:iter_matches(body_node, bufnr, 0, -1) do
        local callee_node = get_capture(calls_query, c_match, "callee")
        local callee_name = get_text(callee_node, bufnr)
        local callee_id = sanitize_id(callee_name)
        local skip = callee_id == "" or callee_id == "node"
        if not opts.include_libc then
          skip = skip or IGNORE_CALLS[callee_name]
        end
        if not skip then
          node_set[callee_id] = true
          table.insert(edges, { caller_id, callee_id, caller_name, callee_name })
          has_relations = true
        end
      end
    end
  end

  if not has_relations then
    vim.notify("No function calls discovered via Tree-sitter in this file.", vim.log.levels.WARN)
    return
  end

  -- Emit Graphviz DOT instead of Mermaid: dot's ranking handles
  -- flat/wide call graphs far better than mermaid's dagre engine.
  local dot_lines = {
    "digraph callgraph {",
    "  rankdir=TB;",
    "  ranksep=0.6;",
    "  nodesep=0.4;",
    "  splines=ortho;",
    '  node [shape=box, style="rounded,filled", fillcolor="#e5e7eb", fontname="Helvetica", fontsize=11];',
    '  edge [color="#555555"];',
  }

  for id, name in pairs(func_nodes) do
    if name == "main" then
      table.insert(
        dot_lines,
        string.format('  %s [label="%s", fillcolor="#ff9966", fontcolor="white", penwidth=2];', id, name)
      )
    else
      table.insert(dot_lines, string.format('  %s [label="%s"];', id, name))
    end
  end

  -- external/leaf calls not defined in this file get a dimmer style
  for id in pairs(node_set) do
    if not func_nodes[id] then
      for _, e in ipairs(edges) do
        if e[2] == id then
          table.insert(
            dot_lines,
            string.format('  %s [label="%s", fillcolor="#f5f5f5", fontcolor="#888888"];', id, e[4])
          )
          break
        end
      end
    end
  end

  for _, e in ipairs(edges) do
    table.insert(dot_lines, string.format("  %s -> %s;", e[1], e[2]))
  end

  table.insert(dot_lines, "}")

  local dot_code = table.concat(dot_lines, "\n")
  local out_dot = vim.fn.getcwd() .. "/call_graph.dot"
  local file = io.open(out_dot, "w")
  if not file then
    vim.notify("Failed to write DOT file", vim.log.levels.ERROR)
    return
  end
  file:write(dot_code)
  file:close()

  -- Render to SVG via graphviz if available, otherwise just open the .dot
  if vim.fn.executable("dot") == 1 then
    local out_svg = vim.fn.getcwd() .. "/call_graph.svg"
    local result =
      vim.fn.system(string.format("dot -Tsvg %s -o %s", vim.fn.shellescape(out_dot), vim.fn.shellescape(out_svg)))
    if vim.v.shell_error == 0 then
      vim.notify("Flowchart generated: " .. out_svg, vim.log.levels.INFO)
      vim.cmd("silent !xdg-open " .. vim.fn.shellescape(out_svg) .. " &")
    else
      vim.notify("dot render failed: " .. result, vim.log.levels.ERROR)
      vim.cmd("split " .. out_dot)
    end
  else
    vim.notify(
      "graphviz 'dot' not found — opening raw .dot file. Install graphviz for SVG rendering.",
      vim.log.levels.WARN
    )
    vim.cmd("split " .. out_dot)
  end
end

return M
