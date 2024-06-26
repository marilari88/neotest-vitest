set rtp+=.
set rtp+=.testdeps/plenary.nvim
set rtp+=.testdeps/nvim-nio
set rtp+=.testdeps/nvim-treesitter
set rtp+=.testdeps/neotest

lua <<EOF
require'nvim-treesitter.configs'.setup {
  -- Make sure we have javascript and typescript treesitter parsers installed so tests can run
  ensure_installed = { "javascript", "typescript" },
  sync_install = true
}
EOF

runtime! plugin/plenary.vim
