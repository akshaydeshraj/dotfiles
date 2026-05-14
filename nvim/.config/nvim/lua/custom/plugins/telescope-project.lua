-- ============================================================
-- telescope-project.nvim
--
-- Workspace switcher built on Telescope. Tracks projects in
-- ~/.local/share/nvim/telescope-projects.txt and discovers more
-- under `base_dirs` below.
--
-- Keymaps inside the picker:
--   <c-d>  delete project   <c-v>  browse files (find_files)
--   <c-b>  browse files     <c-s>  search in files (live_grep)
--   <c-r>  rename project   <c-f>  sync with nvim-tree
--   <c-w>  change workspace <c-a>  add project (cwd)
-- ============================================================

local gh = function(repo) return 'https://github.com/' .. repo end

vim.pack.add { gh 'nvim-telescope/telescope-project.nvim' }

-- Merge the project extension config into the existing telescope setup.
-- Telescope's setup is idempotent and merges options on subsequent calls.
require('telescope').setup {
  extensions = {
    project = {
      base_dirs = {
        { path = '~/Code/personal', max_depth = 3 },
        { path = '~/Code/work', max_depth = 3 },
      },
      hidden_files = false,
      theme = 'dropdown',
      order_by = 'recent',
      search_by = 'title',
      sync_with_nvim_tree = false,
      on_project_selected = function(prompt_bufnr)
        -- Default behavior: change directory and open find_files.
        require('telescope._extensions.project.actions').change_working_directory(prompt_bufnr, false)
        require('telescope.builtin').find_files()
      end,
    },
  },
}

require('telescope').load_extension 'project'

vim.keymap.set('n', '<leader>sp', function() require('telescope').extensions.project.project {} end, { desc = '[S]earch [P]rojects' })
