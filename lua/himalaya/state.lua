local M = {}

M.current_account = ""
M.current_folder = nil -- Discovered dynamically from mailboxes
M.current_page = 1
M.current_envelope_count = 0 -- Number of emails in current view
M.current_envelopes = {} -- Envelopes currently displayed in main view
M.sidebar = nil -- Buffer number
M.main = nil -- Buffer number
M.email = nil -- Buffer number for email reading pane
M.is_open = false
M.folder_list = {} -- Flat list of accessible folders/mailboxes
M.folder_lines = {} -- Sidebar line number -> mailbox name (selectable lines)
M.account_lines = {} -- Account sidebar line number -> account name

-- Native window UI (see himalaya.ui.windows)
M.tab = nil -- Himalaya tabpage
M.prev_tab = nil -- Tabpage to return to when closing
M.prev_win = nil -- Window to return to when closing
M.prev_buf = nil -- Buffer to restore when the Himalaya tab is the only one
M.wins = {} -- { folders = win, accounts = win, list = win }
M.accounts = nil -- Accounts sidebar buffer
M.email_buffers = {} -- Message id -> reader buffer
M.email_state = {} -- Reader buffer -> per-message render state
M.closing = false -- Guard against re-entrant close/BufDelete handlers
M.refresh_timer = nil -- uv timer for the periodic refresh
M.refreshing = false -- Guard against overlapping refreshes
M.refresh_last = nil -- uv.now() of the last focus-driven refresh

function M.reset_ui()
	M.is_open = false
	M.sidebar = nil
	M.main = nil
	M.accounts = nil
	M.email = nil
	M.wins = {}
	M.tab = nil
	M.email_buffers = {}
	M.email_state = {}
	M.account_lines = {}
	M.selected_email_id = nil
	M.current_folder = nil
	M.refresh_timer = nil
	M.refreshing = false
	M.refresh_last = nil
end

return M
