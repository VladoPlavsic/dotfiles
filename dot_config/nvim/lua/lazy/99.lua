return {
  'ThePrimeagen/99',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local _99 = require '99'
    local Providers = require '99.providers'
    local BaseProvider = Providers.BaseProvider
    local agent_manager = require 'custom.agent_manager'

    --- Custom 99 Provider that delegates to the project's chosen agent (Claude Code or Antigravity)
    --- and executes with continuous session (--continue) to preserve ongoing context between invocations.
    local ContinuousAgentProvider = setmetatable({}, { __index = BaseProvider })

    function ContinuousAgentProvider:_get_provider_name()
      local agent = agent_manager.get_picked_agent() or 'agent'
      return 'ContinuousAgentProvider(' .. agent .. ')'
    end

    function ContinuousAgentProvider:_get_default_model()
      local agent = agent_manager.get_picked_agent()
      if agent == 'claude-code' then
        return 'claude-sonnet-4-5'
      else
        return 'auto'
      end
    end

    function ContinuousAgentProvider:_build_command(query, context)
      local agent = agent_manager.get_picked_agent() or 'antigravity'
      if agent == 'claude-code' then
        local cmd = {
          'claude',
          '--continue',
          '--dangerously-skip-permissions',
        }
        if context.model and context.model ~= '' and not context.model:match '^opencode' and context.model ~= 'auto' then
          table.insert(cmd, '--model')
          table.insert(cmd, context.model)
        end
        table.insert(cmd, '--print')
        table.insert(cmd, query)
        return cmd
      else
        local cmd = {
          'agy',
          '--continue',
          '--dangerously-skip-permissions',
        }
        if context.model and context.model ~= '' and not context.model:match '^opencode' and not context.model:match '^claude' and context.model ~= 'auto' then
          table.insert(cmd, '--model')
          table.insert(cmd, context.model)
        end
        table.insert(cmd, '--print')
        table.insert(cmd, query)
        return cmd
      end
    end

    function ContinuousAgentProvider:make_request(query, context, observer)
      local agent = agent_manager.get_picked_agent()
      if not agent then
        agent_manager.prompt_select_agent(function()
          BaseProvider.make_request(self, query, context, observer)
        end)
      else
        BaseProvider.make_request(self, query, context, observer)
      end
    end

    _99.setup {
      provider = ContinuousAgentProvider,
      tmp_dir = './.99/tmp',
      completion = {
        source = 'native',
      },
    }

    -- Keymaps for 99
    vim.keymap.set('v', '<leader>9v', function()
      _99.visual()
    end, { desc = '[9]9: [V]isual edit selection' })

    vim.keymap.set('n', '<leader>9s', function()
      _99.search()
    end, { desc = '[9]9: [S]earch project' })

    vim.keymap.set('n', '<leader>9b', function()
      _99.vibe()
    end, { desc = '[9]9: Vi[b]e session' })

    vim.keymap.set('n', '<leader>9o', function()
      _99.open()
    end, { desc = '[9]9: [O]pen last result' })

    vim.keymap.set('n', '<leader>9l', function()
      _99.view_logs()
    end, { desc = '[9]9: View [L]ogs' })

    vim.keymap.set('n', '<leader>9x', function()
      _99.stop_all_requests()
    end, { desc = '[9]9: Stop/Cancel requests' })

    vim.keymap.set('n', '<leader>9i', function()
      _99.info()
    end, { desc = '[9]9: [I]nfo' })
  end,
}
