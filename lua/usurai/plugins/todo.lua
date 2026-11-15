local os_config = require("usurai.config.os")

-- Built-in Task & Roadmap Manager: masisz/todo.nvim
local todo_spec = os_config.plugin_source("masisz/todo.nvim", "public-git", "todo.nvim")
todo_spec.cond = function()
  local cfg = vim.g.usurai or {}
  return cfg.enable_todo ~= false
end
todo_spec.cmd = {
  "TodoNew",
  "TodoList",
  "TaskNew",
  "TaskList",
  "RoadmapNew",
  "RoadmapList",
  "RoadmapView",
  "RoadmapViewStop",
  "RoadmapExport",
}
todo_spec.keys = {
  { "<leader>Tn", "<Cmd>TodoNew<CR>", desc = "新規タスク (TodoNew)" },
  { "<leader>Tl", "<Cmd>TodoList<CR>", desc = "タスク一覧 (TodoList)" },
  { "<leader>Tr", "<Cmd>RoadmapList<CR>", desc = "ロードマップ一覧 (RoadmapList)" },
}
todo_spec.opts = function()
  local cfg = vim.g.usurai or {}
  return vim.tbl_deep_extend("force", {
    directory = "~/tasks",
    extension = "task",
  }, cfg.todo or {})
end

return {
  todo_spec,
}
