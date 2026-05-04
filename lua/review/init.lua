local M = {}
local ns_id = vim.api.nvim_create_namespace("review_comments")

local function get_git_root()
  local result = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error ~= 0 or #result == 0 then return vim.fn.getcwd() end
  return result[1]
end

local function get_review_file()
  return get_git_root() .. "/.review.md"
end

local function get_relative_path()
  local git_root = get_git_root()
  local full = vim.fn.expand("%:p")
  if vim.startswith(full, git_root .. "/") then
    return full:sub(#git_root + 2)
  end
  return vim.fn.expand("%:.")
end

local function parse_comments()
  local comments = {}
  local f = io.open(get_review_file(), "r")
  if not f then return comments end
  local content = f:read("*all")
  f:close()

  local cur_key, cur_text = nil, nil
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    local file, lnum, text = line:match("^%- %[([^:]+):(%d+)%] (.+)$")
    if file then
      if cur_key then comments[cur_key] = cur_text end
      cur_key = file .. ":" .. lnum
      cur_text = text
    elseif cur_key and line:match("^  ") then
      cur_text = cur_text .. "\n" .. line:sub(3)
    else
      if cur_key then
        comments[cur_key] = cur_text
        cur_key, cur_text = nil, nil
      end
    end
  end
  return comments
end

function M.show_comments()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  local rel = get_relative_path()
  if rel == "" then return end

  for key, text in pairs(parse_comments()) do
    local file, lnum = key:match("^(.+):(%d+)$")
    if file == rel then
      local row = tonumber(lnum) - 1
      local first_line = text:match("^([^\n]+)")
      vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, 0, {
        virt_text = { { "  " .. first_line, "DiagnosticVirtualTextInfo" } },
        virt_text_pos = "eol",
      })
    end
  end
end

function M.add_comment()
  local rel = get_relative_path()
  local lnum = vim.fn.line(".")

  if rel == "" then
    vim.notify("review: cannot determine file path", vim.log.levels.WARN)
    return
  end

  local ibuf = vim.api.nvim_create_buf(false, true)
  vim.bo[ibuf].buftype = "nofile"
  vim.bo[ibuf].filetype = "markdown"

  local width = math.min(80, vim.o.columns - 6)
  local win = vim.api.nvim_open_win(ibuf, true, {
    relative = "cursor",
    width = width,
    height = 5,
    row = 1,
    col = 0,
    style = "minimal",
    border = "rounded",
    title = string.format(" %s:%d ", rel, lnum),
    title_pos = "center",
  })
  vim.wo[win].wrap = true
  vim.cmd("startinsert")

  local function submit()
    local lines = vim.api.nvim_buf_get_lines(ibuf, 0, -1, false)
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines)
    end
    vim.api.nvim_win_close(win, true)
    if #lines == 0 then return end

    local entry = string.format("- [%s:%d] %s\n", rel, lnum, lines[1])
    for i = 2, #lines do
      entry = entry .. "  " .. lines[i] .. "\n"
    end

    local review_file = get_review_file()
    local needs_header = true
    local existing = io.open(review_file, "r")
    if existing then
      local c = existing:read("*all")
      existing:close()
      needs_header = not c:match("## Review Comments")
    end

    local out = io.open(review_file, "a")
    if not out then
      vim.notify("review: cannot write " .. review_file, vim.log.levels.ERROR)
      return
    end
    if needs_header then out:write("## Review Comments\n\n") end
    out:write(entry)
    out:close()

    vim.notify(string.format("review: comment added at %s:%d", rel, lnum))
    M.show_comments()
  end

  local function cancel()
    vim.api.nvim_win_close(win, true)
  end

  local opts = { buffer = ibuf, nowait = true }
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, opts)
  vim.keymap.set("n", "<Esc>", cancel, opts)
  vim.keymap.set("n", "q", cancel, opts)
end

function M.open_review()
  vim.cmd("split " .. get_review_file())
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    callback = M.show_comments,
  })
end

return M
