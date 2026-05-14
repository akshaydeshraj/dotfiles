-- ============================================================
-- Elixir + Phoenix layer for kickstart.nvim
--
-- LSP picture (May 2026):
--   * ElixirLS    — stable, complete, Mason-installable. Used here.
--   * Expert      — official elixir-lang/expert LSP, at v0.1.0-rc.
--                   When stable, replace `elixirls` below with `expert`.
--   * NextLS/Lexical — being merged into Expert; skip.
-- ============================================================

local gh = function(repo) return 'https://github.com/' .. repo end

-- ------------------------------------------------------------
-- 1. LSP: ElixirLS
--    nvim-lspconfig provides cmd + root_dir defaults; we only
--    override settings. vim.lsp.config merges with those defaults.
-- ------------------------------------------------------------
vim.lsp.config('elixirls', {
  settings = {
    elixirLS = {
      dialyzerEnabled = true,
      fetchDeps = false,
      enableTestLenses = true,
      suggestSpecs = true,
    },
  },
})
vim.lsp.enable 'elixirls'

-- ------------------------------------------------------------
-- 2. Auto-install elixir-ls via Mason on first run
-- ------------------------------------------------------------
do
  local ok, registry = pcall(require, 'mason-registry')
  if ok then
    registry.refresh(function()
      if registry.has_package 'elixir-ls' and not registry.is_installed 'elixir-ls' then
        registry.get_package('elixir-ls'):install()
      end
    end)
  end
end

-- ------------------------------------------------------------
-- 3. Formatter: `mix format` via conform.nvim
--    conform.setup ran earlier in init.lua; we just add entries.
-- ------------------------------------------------------------
do
  local ok, conform = pcall(require, 'conform')
  if ok then
    conform.formatters_by_ft.elixir = { 'mix' }
    conform.formatters_by_ft.eelixir = { 'mix' }
    conform.formatters_by_ft.heex = { 'mix' }
  end
end

-- ------------------------------------------------------------
-- 4. elixir-tools.nvim — :Mix, pipe transforms, projectionist
--    We disable its LSP bootstrappers since Mason owns elixir-ls.
-- ------------------------------------------------------------
vim.pack.add {
  gh 'nvim-lua/plenary.nvim',
  gh 'elixir-tools/elixir-tools.nvim',
}
require('elixir').setup {
  nextls = { enable = false },
  credo = { enable = false },
  elixirls = { enable = false },
  projectionist = { enable = true },
}

-- ------------------------------------------------------------
-- 5. Treesitter parsers
--    kickstart auto-installs on file open; this just pre-warms.
-- ------------------------------------------------------------
do
  local ok, ts = pcall(require, 'nvim-treesitter')
  if ok then ts.install { 'elixir', 'heex', 'eex' } end
end

-- ------------------------------------------------------------
-- 6. Credo linting via nvim-lint
--    MIX_ENV=test avoids tripping Phoenix dev code-reload.
--    nvim-lint runs on BufWritePost/InsertLeave (see lint.lua).
-- ------------------------------------------------------------
do
  local ok, lint = pcall(require, 'lint')
  if ok then
    lint.linters_by_ft.elixir = { 'credo' }
    lint.linters_by_ft.eelixir = { 'credo' }
    lint.linters_by_ft.heex = { 'credo' }
    -- touch linters.credo to trigger lazy load, then override env
    if lint.linters.credo then lint.linters.credo.env = { MIX_ENV = 'test' } end
  end
end
