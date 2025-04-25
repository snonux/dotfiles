require("CopilotChat").setup {
  -- See Configuration section for options
}

local timer = vim.loop.new_timer() -- Initialize the timer

vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
        if vim.bo.filetype == "copilot-chat" then
            local copilot_chat_buf = vim.api.nvim_get_current_buf()
            vim.cmd("wincmd _") -- Maximize height
            vim.cmd("wincmd |") -- Maximize width
            local file_path = vim.fn.expand("~/.copilot_chat_output.txt")

            -- Start the timer with a 2-second interval
            timer:start(1000, 1000, vim.schedule_wrap(function()
                if copilot_chat_buf and vim.api.nvim_buf_is_valid(copilot_chat_buf) then
                    -- Get all lines in the buffer
                    local lines = vim.api.nvim_buf_get_lines(copilot_chat_buf, 0, -1, false)
                    
                    -- Check for the stopping condition
                    for _, line in ipairs(lines) do
                        if line:find("^COPILOT_END") then
                            print("Stopping write process: 'COPILOT_END' detected.")
                            timer:stop()
                            -- Write the buffer content to the file
                            vim.api.nvim_buf_call(copilot_chat_buf, function()
                                vim.cmd("write! " .. file_path)
                            end)
                            vim.cmd("qa!")
                            return
                        end
                    end
                    
                    -- Write the buffer content to the file
                    vim.api.nvim_buf_call(copilot_chat_buf, function()
                        vim.cmd("write! " .. file_path)
                    end)
                end
            end))
        end
    end,
})
