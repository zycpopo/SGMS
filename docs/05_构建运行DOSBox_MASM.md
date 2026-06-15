# MASM + DOSBox 构建运行说明

## 项目文件结构

```text
信息管理系统/
├── SCORE.ASM         ; 主源码文件
├── MASM.EXE          ; Microsoft Macro Assembler
├── LINK.EXE          ; Microsoft Linker
├── DEBUG.EXE         ; DOS 调试器（可选）
├── EDIT.COM          ; DOS 文本编辑器（可选）
├── score.txt         ; 数据文件（首次运行时自动创建）
└── *.md              ; 文档文件
```

## Windows 安装 DOSBox

从 https://www.dosbox.com/ 下载并安装。

## Linux 安装 DOSBox

Ubuntu：

```bash
sudo apt update
sudo apt install dosbox
```

启动：

```bash
dosbox
```

## 挂载项目目录

假设项目在 `E:\微机原理\信息管理系统`（Windows）或 `/home/user/grade-management`（Linux）。

进入 DOSBox 后执行：

**Windows 路径：**

```dos
mount c E:\微机原理\信息管理系统
c:
dir
```

**Linux 路径：**

```dos
mount c /home/user/grade-management
c:
dir
```

> **注意：** DOSBox 的 `mount` 命令不支持中文路径名。如果路径中包含中文字符，请将项目文件夹移到纯英文路径下，或使用 DOSBox-X（支持中文路径）。

## MASM 编译

```dos
MASM SCORE.ASM;
```

成功后生成 `SCORE.OBJ`。

如果提示输入目标文件名、列表文件等，直接按回车即可（分号 `;` 后缀表示全部采用默认值）。

## LINK 链接

```dos
LINK SCORE.OBJ;
```

成功后生成 `SCORE.EXE`。

## 运行程序

```dos
SCORE.EXE
```

程序会自动加载 `score.txt`（如果存在），否则创建新文件。

## 一次完整命令

```dos
mount c E:\微机原理\信息管理系统
c:
MASM SCORE.ASM;
LINK SCORE.OBJ;
SCORE.EXE
```

## 如果使用 TASM

```dos
TASM SCORE.ASM
TLINK SCORE.OBJ
SCORE.EXE
```

## 常见问题

### "Bad command or file name"

当前目录没有 MASM.EXE 或 LINK.EXE。执行 `dir` 检查文件是否存在。确保 MASM.EXE 和 LINK.EXE 已复制到项目目录中。

### "Cannot open file"

- 检查文件名是否为 8.3 格式（`SCORE.ASM`，`SCORE.TXT`）
- 确认文件存在于挂载的目录中
- 在 DOSBox 中文件名大小写不敏感

### 中文路径无法挂载

DOSBox 标准版不支持中文路径名。解决方法：
1. 将项目文件夹移到纯英文路径（如 `E:\asmproj\`）
2. 或使用 DOSBox-X（支持中文路径）

### "Out of memory" 或 "Symbol not defined"

- 检查所有标签引用是否完全匹配
- 验证 `.MODEL SMALL` 和段设置
- 确保正确使用 `@DATA`

### "Phase error" 或 "Syntax error"

MASM 发现语法错误。常见原因：
- 使用了 32 位寄存器（EAX 等）
- 字符串缺少 `$` 结束符
- 操作数大小不匹配（byte vs word）
- 使用了 386+ 指令（如 MOVZX）

建议在 DOSBox 中编译时查看错误行号，回到源码对应行排查。

### 程序运行后乱码

程序使用英文 ASCII 界面。如果看到乱码，请检查：
- 源码文件编码为 ASCII 或 GBK（不要使用 UTF-8 with BOM）
- DOSBox 使用默认配置

### 程序启动卡死

- 检查 `score.txt` 是否为有效 CSV（无二进制内容）
- 确认文件大小不超过 4KB
- 确认文件换行为 CR+LF 格式

### 数据没有保存

- 程序只在选择选项 `0`（Save & Exit）时才保存数据
- 如果直接关闭 DOSBox 窗口，数据将丢失
- 检查目录是否可写

## 使用示例数据测试

项目提供了包含 15 条记录的示例 `score.txt`：

```
20240001,Alice,Calculus,85
20240002,Bob,Calculus,92
...
```

在运行程序前将其复制到项目目录即可。
