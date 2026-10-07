return {
    "sindrets/diffview.nvim",
    keys = {
        { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>",      desc = "Git file history" },
        { "<leader>gh", ":'<,'>DiffviewFileHistory<cr>",       desc = "Git selection history", mode = "v" },
        { "<leader>gH", "<cmd>DiffviewFileHistory<cr>",        desc = "Git repo history" },
        { "<leader>gw", "<cmd>DiffviewOpen<cr>",               desc = "Git diff working tree" },
        { "<leader>gm", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>", desc = "Git diff vs main" },
        { "<leader>gt", "<cmd>DiffviewToggleFiles<cr>",        desc = "Git toggle file panel" },
        { "<leader>gc", "<cmd>DiffviewClose<cr>",              desc = "Git close" },
    }
}
