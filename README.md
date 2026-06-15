# 学生成绩管理系统 (Student Grade Management System)

基于 MASM 的 DOS 16 位汇编语言课程项目，实现完整的学生成绩 CRUD 管理、统计分析及文本可视化。

## 功能

- **文件读写** — 启动时自动加载 `score.txt`，退出时保存所有有效记录（CSV 格式）
- **添加记录** — 录入学号、姓名、课程、成绩（0-100 校验）
- **查找记录** — 按学号或姓名精确匹配，表格形式展示结果
- **修改成绩** — 按学号查找后更新成绩
- **删除记录** — 逻辑删除（标记位），数据物理保留但不显示/统计/保存
- **成绩统计** — 有效记录数、平均分、最高分、最低分、分数段分布
- **柱状图** — 字符 `#` 绘制水平柱状图，自动缩放
- **列表显示** — 格式化表格展示全部有效记录

## 主界面

```text
+======================================+
|   Student Grade Management  v1.0     |
+======================================+
|  1. Add Record                       |
|  2. Search Record                    |
|  3. Modify Score                     |
|  4. Delete Record                    |
|  5. Statistics                       |
|  6. Histogram (score distribution)   |
|  7. List All Records                 |
|  0. Save & Exit                      |
+======================================+
Select (0-7):
```

## 运行环境

- **DOSBox** 或 **DOSBox-X**（推荐）
- **MASM 5.0+** + **LINK 3.0+**（已包含在项目中）
- 兼容 8086 / 16 位实模式 / DOS int 21h

## 快速开始

1. 安装 [DOSBox](https://www.dosbox.com/)

2. 启动 DOSBox，挂载项目目录：

   ```dos
   mount c E:\WeiJi\IMS
   c:
   ```

3. 编译 & 链接 & 运行：

   ```dos
   MASM SCORE_V2.ASM;
   LINK SCORE_V2.OBJ;
   SCORE_V2.EXE
   ```

> 分号 `;` 表示全部采用默认文件名，无需手动输入。

## 文件结构

```
IMS/
├── SCORE_V2.ASM       # 主源码（MASM 16 位汇编）
├── SCORE_V2.EXE       # 编译后的可执行程序
├── SCORE_V2.OBJ       # 编译中间文件
├── MASM.EXE           # Microsoft Macro Assembler
├── LINK.EXE           # Microsoft Linker
├── DEBUG.EXE          # DOS 调试器（可选）
├── EDIT.COM           # DOS 文本编辑器（可选）
├── score.txt          # CSV 数据文件
├── docs/              # 详细设计文档
└── README.md
```

## 数据格式

`score.txt` 使用 CSV 格式，每条记录一行：

```
学号,姓名,课程,成绩
20240001,Alice,Calculus,85
20240002,Bob,English,92
```

### 内存记录布局（43 字节/条，最大 100 条）

| 偏移 | 长度 | 字段 | 说明 |
|------|------|------|------|
| 0 | 8B | 学号 | 右补空格 |
| 8 | 16B | 姓名 | 右补空格 |
| 24 | 16B | 课程 | 右补空格 |
| 40 | 2B | 成绩 | Word (0-100) |
| 42 | 1B | 删除标记 | 0=有效，1=已删除 |

## 构建说明

| 工具 | 版本 | 用途 |
|------|------|------|
| MASM.EXE | 5.0+ | 汇编编译 |
| LINK.EXE | 3.0+ | 目标文件链接 |
| DOSBox | 任意 | DOS 环境模拟 |

也可使用 TASM 代替 MASM：

```dos
TASM SCORE_V2.ASM
TLINK SCORE_V2.OBJ
SCORE_V2.EXE
```

## 文档

详细设计文档见 `docs/` 目录：

| 文档 | 内容 |
|------|------|
| `01_项目概述.md` | 项目总览与定位 |
| `02_功能流程提示.md` | 功能流程与交互逻辑 |
| `03_UI布局规范.md` | 界面布局规范 |
| `04_功能设计.md` | 详细功能设计 |
| `05_构建运行DOSBox_MASM.md` | 构建与运行说明 |
| `06_低版本DOS_MASM兼容.md` | 低版本 DOS 兼容性 |
| `07_测试与验收.md` | 测试用例与验收标准 |
| `08_报告与演示笔记.md` | 报告与演示指南 |
| `09_扩展功能.md` | 扩展功能设计 |

## 常见问题

- **中文路径无法挂载** — 将项目移到纯英文路径，或使用 DOSBox-X
- **"Bad command or file name"** — 确认 MASM.EXE 和 LINK.EXE 在当前目录
- **程序启动卡死** — 检查 `score.txt` 是否为有效 CSV 且换行为 CR+LF
- **数据未保存** — 必须选择 `0 (Save & Exit)` 才会写回文件
