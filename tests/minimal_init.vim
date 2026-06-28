set rtp+=.
set rtp+=.testdeps/plenary.nvim
set rtp+=.testdeps/nvim-treesitter
set rtp+=.testdeps/neotest
set rtp+=.testdeps/nvim-nio

lua <<EOF
-- Install javascript and typescript treesitter parsers synchronously so tests can run.
-- Uses the nvim-treesitter `main` branch API (requires Neovim 0.12+); the legacy
-- `nvim-treesitter.configs` module was removed when the default branch became the
-- incompatible rewrite on 2026-04-03.
require('nvim-treesitter').setup {}
require('nvim-treesitter').install({ 'javascript', 'typescript' }):wait(300000)
EOF

runtime! plugin/plenary.vim
