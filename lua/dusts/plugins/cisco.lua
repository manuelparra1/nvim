return {
    "momota/cisco.vim",
    ft = "cisco", -- Only load this plugin when filetype is 'cisco'
    config = function()
        -- Ensure comments work correctly (using ! for cisco)
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "cisco",
            callback = function()
                vim.bo.commentstring = "! %s"
            end,
        })
    end,
}
