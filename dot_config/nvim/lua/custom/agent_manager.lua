local M = {}

--- Find the project root (Git root or current working directory)
local function get_project_root()
  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error == 0 and git_root and git_root ~= '' then
    return git_root
  end
  return vim.fn.getcwd()
end

--- Path to .picked-agent file in current project root
local function get_config_file_path()
  return get_project_root() .. '/.picked-agent'
end

--- Ensure .picked-agent and .99 are added to .git/info/exclude so they are never committed or tracked
local function ensure_git_ignored(root)
  if vim.fn.isdirectory(root .. '/.git') == 1 then
    local info_dir = root .. '/.git/info'
    if vim.fn.isdirectory(info_dir) ~= 1 then
      vim.fn.mkdir(info_dir, 'p')
    end
    local exclude_path = info_dir .. '/exclude'
    local lines = {}
    if vim.fn.filereadable(exclude_path) == 1 then
      lines = vim.fn.readfile(exclude_path)
    end
    local patterns = {
      ['.picked-agent'] = '^%.picked%-agent',
      ['.99'] = '^%.99',
    }
    local modified = false
    for entry, pat in pairs(patterns) do
      local exists = false
      for _, line in ipairs(lines) do
        if line:match(pat) then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(lines, entry)
        modified = true
      end
    end
    if modified then
      vim.fn.writefile(lines, exclude_path)
    end
  end
end

--- Read previously picked agent from .picked-agent if it exists
local function read_picked_agent()
  local root = get_project_root()
  local file = root .. '/.picked-agent'
  if vim.fn.filereadable(file) == 1 then
    -- If a git repo exists now (e.g. git init happened after the file was created),
    -- automatically ensure it is added to .git/info/exclude
    ensure_git_ignored(root)

    local lines = vim.fn.readfile(file)
    if #lines > 0 then
      local agent = vim.trim(lines[1])
      if agent == 'antigravity' or agent == 'claude-code' then
        return agent
      end
    end
  end
  return nil
end

--- Save agent choice to .picked-agent and ensure git ignore
local function save_picked_agent(agent)
  local root = get_project_root()
  local file = root .. '/.picked-agent'
  vim.fn.writefile({ agent }, file)
  ensure_git_ignored(root)
  vim.notify('AI Agent for project set to: ' .. agent .. ' (saved in .picked-agent)', vim.log.levels.INFO)
end

--- Available agents for picker
local available_agents = {
  { id = 'antigravity', name = 'Antigravity (Gemini CLI / agy)' },
  { id = 'claude-code', name = 'Claude Code' },
}

--- Open fuzzy finder (Telescope / vim.ui.select) to pick an agent
function M.prompt_select_agent(callback)
  vim.ui.select(available_agents, {
    prompt = 'Select AI Agent for this project:',
    format_item = function(item)
      return item.name
    end,
  }, function(choice)
    if choice then
      save_picked_agent(choice.id)
      if callback then
        callback(choice.id)
      end
    end
  end)
end

M.get_picked_agent = read_picked_agent
M.save_picked_agent = save_picked_agent

--- Ensure an agent is selected; if not, prompt the user with fuzzy finder first
function M.ensure_agent(callback)
  local agent = read_picked_agent()
  if agent then
    if callback then
      callback(agent)
    end
  else
    M.prompt_select_agent(callback)
  end
end

--- Execute the selected agent with the specified variant ('new', 'continue', 'verbose')
function M.execute_agent(agent, variant)
  if agent == 'claude-code' then
    local ok, claude = pcall(require, 'claude-code')
    if not ok then
      vim.notify('claude-code.nvim plugin not found', vim.log.levels.ERROR)
      return
    end
    if variant == 'continue' then
      claude.toggle_with_variant 'continue'
    elseif variant == 'verbose' then
      claude.toggle_with_variant 'verbose'
    else
      claude.toggle()
    end
  elseif agent == 'antigravity' then
    local ok, agy = pcall(require, 'antigravity')
    if not ok then
      vim.notify('antigravity-cli.nvim plugin not found', vim.log.levels.ERROR)
      return
    end

    if variant == 'continue' then
      agy.config.cmd = 'agy --continue'
    elseif variant == 'verbose' then
      agy.config.cmd = 'agy'
    else
      agy.config.cmd = 'agy'
    end
    agy.toggle()
  else
    vim.notify('Unknown agent: ' .. tostring(agent), vim.log.levels.ERROR)
  end
end

--- Main entry point for actions: 'new', 'continue', 'verbose'
function M.run(variant)
  local agent = read_picked_agent()
  if agent then
    M.execute_agent(agent, variant)
  else
    -- First time: prompt with fuzzy finder
    M.prompt_select_agent(function(chosen_agent)
      M.execute_agent(chosen_agent, variant)
    end)
  end
end

--- Force prompt to switch the project's agent
function M.switch_agent()
  M.prompt_select_agent(function(chosen_agent)
    vim.notify('Switched to: ' .. chosen_agent, vim.log.levels.INFO)
  end)
end

function M.setup()
  -- Normal mode keymaps under <leader>a
  vim.keymap.set('n', '<leader>an', function()
    M.run 'new'
  end, { desc = '[A]gent: [N]ew' })
  vim.keymap.set('n', '<leader>ac', function()
    M.run 'continue'
  end, { desc = '[A]gent: [C]ontinue' })
  vim.keymap.set('n', '<leader>av', function()
    M.run 'verbose'
  end, { desc = '[A]gent: [V]erbose' })
  vim.keymap.set('n', '<leader>as', function()
    M.switch_agent()
  end, { desc = '[A]gent: [S]witch agent' })
  vim.keymap.set('n', '<leader>aa', function()
    M.run 'new'
  end, { desc = '[A]gent: Toggle [A]gent' })

  -- Terminal mode keymaps to toggle/hide the window
  vim.keymap.set('t', '<leader>aa', function()
    M.run 'new'
  end, { desc = '[A]gent: Toggle [A]gent' })

  -- Visual mode send selection (delegates to antigravity ask_selection)
  vim.keymap.set('v', '<leader>as', function()
    local ok, agy = pcall(require, 'antigravity')
    if ok and agy.ask_selection then
      agy.ask_selection()
    else
      vim.notify('Selection sending not available', vim.log.levels.WARN)
    end
  end, { desc = '[A]gent: [S]end selection' })
end

return M
