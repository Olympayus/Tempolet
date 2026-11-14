# 2026 节假日数据

- 文件：`2026.json`
- 年份：2026
- 上游仓库：https://github.com/NateScarlet/holiday-cn
- 来源 commit：`a8a8b4e8e960e1934a8b62aad34663a66a53b578`（`master`，2026-11-12）
- 来源 URL（commit 固定）：
  https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@a8a8b4e8e960e1934a8b62aad34663a66a53b578/2026.json
- 拉取日期：2026-11-14
- 文件 SHA-256：`0dcfd8004351e132ce15e8444de4df123265b3f490f7e2f8346631122cb5b709`
- 官方公告：https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm

下载时使用 `@master` 拉取，随后按上述 commit 重新拉取并逐字节比对，内容一致。

## 数据结构

顶层含 `year`、`papers`（官方公告链接）与 `days`；`days[]` 的每一项含
`name`、`date`（`YYYY-MM-DD`）与 `isOffDay`。本应用按 `isWorkday = !isOffDay`
导入，`isOffDay: false` 的日期为调休上班日（如 2026-01-04、2026-02-14）。

## 许可证

MIT License, Copyright (c) 2019 NateScarlet

上游项目以 MIT 许可证发布；本文件仅作为内置静态数据随应用分发，运行时不联网更新。
