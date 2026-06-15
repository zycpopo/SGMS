# 低版本 DOS + MASM 兼容规范

## 汇编模式

必须使用简化段指令：

```asm
.MODEL SMALL
.STACK 100H
.DATA
.CODE
```

入口：

```asm
MAIN PROC FAR
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  ES, AX          ; ES = DS，用于字符串操作
    ...
    MOV  AH, 4CH
    INT  21H
MAIN ENDP
END MAIN
```

## 允许使用的寄存器

仅 16 位寄存器：

| 寄存器 | 用途 |
|--------|------|
| AX | 累加器、函数返回值、DOS 功能号 |
| BX | 基址、文件句柄、通用 |
| CX | 计数器、字符串长度 |
| DX | 数据、乘法高位字 |
| SI | 源变址（字符串操作） |
| DI | 目的变址（字符串操作） |
| BP | 基址指针（本项目未使用） |
| SP | 栈指针（由 .STACK 管理） |
| DS, ES, SS | 段寄存器 |

## 禁止使用的内容

- **32 位寄存器**：EAX、EBX、ECX、EDX、ESI、EDI、EBP、ESP
- **处理器伪指令**：`.386`、`.486`、`.586`、`.686`
- **内存模型**：`.MODEL FLAT`
- **32 位寻址**：不能使用 `[EAX]`、`[EBX+ESI*4]` 等
- **Windows API**：不能使用 `INVOKE`、Win32 调用
- **Linux 系统调用**：不能使用 `int 80h`
- **NASM 语法**：不能使用 `org 100h` COM 风格、`section .text`
- **中文界面字符串**：程序中面向用户的字符串必须使用英文 ASCII
- **长文件名**：使用 8.3 格式

## 8086 指令集注意事项

### 需要避免的指令

| 指令 | 原因 | 替代方案 |
|------|------|----------|
| `MOVZX` | 仅 386+ 支持 | `XOR CH,CH` / `MOV CL, src` |
| `MOVSX` | 仅 386+ 支持 | 手动符号扩展 |
| `PUSH imm` | 80186+ | `MOV reg, imm` / `PUSH reg` |
| `SHL reg, imm` (imm>1) | 80186+ | `MOV CL, imm` / `SHL reg, CL` |

### 替换 MOVZX 示例

不能这样写：
```asm
MOVZX CX, BYTE PTR [INBUF+1]
```

应改为：
```asm
XOR  CH, CH
MOV  CL, [INBUF+1]
```

本项目已将源码中所有 MOVZX 替换为上述兼容写法。

## 匿名标签

MASM 5.0+ 支持 `@@` 匿名标签：

```asm
    CMP  CX, MAX
    JBE  @F          ; 向前跳转到下一个 @@
    MOV  CX, MAX
@@:                  ; 标签位置
```

`@F` = 向前最近 `@@`，`@B` = 向后最近 `@@`。匿名标签的作用范围限定在最近的非匿名标签内（通常是所在 PROC 内），不同 PROC 之间的 `@@` 互不干扰。

## 字符串输出

DOS `int 21h AH=09h` 要求字符串以 `$` 结尾：

```asm
MSG  DB 'Hello, World!$'
     LEA  DX, MSG
     MOV  AH, 09H
     INT  21H
```

本项目使用 PRINT_STR 宏包装此操作：

```asm
PRINT_STR MACRO msg
    PUSH AX
    PUSH DX
    MOV  AH, 09H
    LEA  DX, msg
    INT  21H
    POP  DX
    POP  AX
ENDM
```

## 缓冲输入

DOS `int 21h AH=0Ah`：

```asm
INBUF  DB 20, 0, 20 DUP(0)   ; [0]=最大长度, [1]=实际长度, [2..]=字符
       LEA  DX, INBUF
       MOV  AH, 0AH
       INT  21H
       ; 输入长度: MOV CL, INBUF[1]
       ; 输入字符: LEA SI, INBUF+2
```

注意：缓冲输入不会在字符串末尾添加 `$` 结束符。使用时需根据 INBUF[1] 中的实际长度来处理。

## 文件操作

| 功能号 | AH | 说明 |
|--------|----|------|
| 创建/截断 | 3CH | CX=属性, DS:DX=文件名 |
| 打开已有 | 3DH | AL=模式(0=读), DS:DX=文件名 |
| 读取 | 3FH | BX=句柄, CX=字节数, DS:DX=缓冲区 |
| 写入 | 40H | BX=句柄, CX=字节数, DS:DX=数据 |
| 关闭 | 3EH | BX=句柄 |

所有文件函数出错时 CF=1，错误码在 AX 中。

## 段寄存器初始化

程序启动时必须初始化 DS：

```asm
MOV  AX, @DATA
MOV  DS, AX
MOV  ES, AX       ; 设置 ES=DS 以使用字符串操作 (MOVSB, STOSB, CMPSB)
```

## 栈

使用 `.STACK 100H` 提供 256 字节栈空间。子程序中如修改寄存器，应保护现场：

```asm
MY_PROC PROC
    PUSH AX
    PUSH BX
    PUSH CX
    ...
    POP  CX
    POP  BX
    POP  AX
    RET
MY_PROC ENDP
```

## ASCII 边框字符

使用标准 ASCII 制表字符：

```
+ - | =
```

**不要**使用 Unicode/CP437 扩展字符（如 `╔╗╚╝║═`）——它们可能在某些 DOS 配置下显示异常。

## REP 前缀指令

本项目中使用的字符串操作：

| 指令 | 用途 |
|------|------|
| `REP MOVSB` | 从 DS:SI 复制 CX 字节到 ES:DI |
| `REP STOSB` | 用 AL 填充 ES:DI 处 CX 字节 |
| `REPE CMPSB` | 比较字节，遇不匹配停止 |

使用前务必用 `CLD` 清除方向标志（正向）。

## 数字输出

DOS 没有内置十进制输出功能。`ITOA_SCORE` 过程将整数 0-65535 转换为 ASCII：

1. 反复除以 10
2. 余数存储为 ASCII 数字（'0' + 余数）
3. 前方位置用空格填充
4. 以 '$' 结尾

## 文件名规范

为兼容低版本 DOS，使用 8.3 文件名：
- `SCORE.ASM`、`SCORE.OBJ`、`SCORE.EXE`
- `SCORE.TXT`（数据文件）
