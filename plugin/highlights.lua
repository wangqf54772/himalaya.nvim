-- Highlight groups for himalaya.nvim
-- Don't set bg so cursorline shows through
vim.api.nvim_set_hl(0, "HimalayaFlag", { fg = vim.api.nvim_get_hl(0, { name = "Special" }).fg })
vim.api.nvim_set_hl(0, "HimalayaFrom", { fg = vim.api.nvim_get_hl(0, { name = "Identifier" }).fg })
vim.api.nvim_set_hl(0, "HimalayaSubject", { fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg })
vim.api.nvim_set_hl(0, "HimalayaDate", { fg = vim.api.nvim_get_hl(0, { name = "Comment" }).fg })
vim.api.nvim_set_hl(0, "HimalayaFolder", { fg = vim.api.nvim_get_hl(0, { name = "Directory" }).fg })
vim.api.nvim_set_hl(0, "HimalayaFolderActive", { fg = vim.api.nvim_get_hl(0, { name = "Directory" }).fg, bold = true })
vim.api.nvim_set_hl(0, "HimalayaFolderDisabled", { fg = vim.api.nvim_get_hl(0, { name = "Comment" }).fg })
vim.api.nvim_set_hl(0, "HimalayaUnread", { fg = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn" }).fg or vim.api.nvim_get_hl(0, { name = "WarningMsg" }).fg, bold = true })

-- Native window UI
vim.api.nvim_set_hl(0, "HimalayaWinbar", { fg = vim.api.nvim_get_hl(0, { name = "Normal" }).fg, bold = true })
vim.api.nvim_set_hl(0, "HimalayaAccount", { link = "HimalayaFolder" })
vim.api.nvim_set_hl(0, "HimalayaAccountActive", { link = "HimalayaFolderActive" })
vim.api.nvim_set_hl(0, "HimalayaAccountDefault", { link = "HimalayaUnread" })
