# 2026 节假日数据

- 文件：`2026.json`
- 来源 URL：https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/2026.json
- 上游仓库：https://github.com/NateScarlet/holiday-cn
- 官方公告：https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm
- 拉取日期：2026-11-14

## 数据结构

顶层含 `year`、`papers`（官方公告链接）与 `days`；`days[]` 的每一项含
`name`、`date`（`YYYY-MM-DD`）与 `isOffDay`。本应用按 `isWorkday = !isOffDay`
导入，`isOffDay: false` 的日期为调休上班日（如 2026-01-04、2026-02-14）。

## 许可证

MIT License, Copyright (c) 2019 NateScarlet

上游项目以 MIT 许可证发布；本文件仅作为内置静态数据随应用分发，运行时不联网更新。
