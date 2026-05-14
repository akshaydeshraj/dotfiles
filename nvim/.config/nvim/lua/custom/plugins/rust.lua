-- ============================================================
-- Rust layer for kickstart.nvim
--
-- Stack (May 2026):
--   * rustaceanvim — filetype plugin, manages rust-analyzer itself.
--     We do NOT add rust_analyzer to kickstart's `servers` table;
--     doing so would create two LSP clients fighting over the buffer.
--   * rust-analyzer — installed via rustup/brew, NOT Mason
--     (Mason versions drift from your toolchain → subtle breakage).
--   * Clippy — surfaced through rust-analyzer's `checkOnSave`.
--   * rustfmt — driven by conform.
-- ============================================================

local gh = function(repo) return 'https://github.com/' .. repo end

-- ------------------------------------------------------------
-- 1. rustaceanvim config (must be set BEFORE the plugin loads
--    its filetype hook, hence vim.g.* not setup())
-- ------------------------------------------------------------
vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ['rust-analyzer'] = {
        checkOnSave = { command = 'clippy' },
        cargo = { allFeatures = true },
        procMacro = { enable = true },
        inlayHints = {
          bindingModeHints = { enable = true },
          closureReturnTypeHints = { enable = 'always' },
          lifetimeElisionHints = { enable = 'skip_trivial' },
        },
      },
    },
  },
  tools = {
    float_win_config = { border = 'rounded' },
  },
}

vim.pack.add { gh 'mrcjkb/rustaceanvim' }

-- ------------------------------------------------------------
-- 2. Formatter: rustfmt via conform.nvim
-- ------------------------------------------------------------
do
  local ok, conform = pcall(require, 'conform')
  if ok then conform.formatters_by_ft.rust = { 'rustfmt' } end
end

-- ------------------------------------------------------------
-- 3. Treesitter parser
-- ------------------------------------------------------------
do
  local ok, ts = pcall(require, 'nvim-treesitter')
  if ok then ts.install { 'rust' } end
end
