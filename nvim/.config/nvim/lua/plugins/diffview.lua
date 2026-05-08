return {
    "sindrets/diffview.nvim",
    keys = {
        { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Git file history" },
        { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",   desc = "Git repo history" },
        { "<leader>gc", "<cmd>DiffviewClose<cr>",          desc = "Git close" },
    }
}
