; ============================================================
;  Student Grade Management System  v1.0
;  Target: DOS 16-bit (MASM 5.0+, LINK 3.0+, DOSBox)
;  Build:  MASM SCORE; LINK SCORE;
;  Data:   score.txt (CSV: ID,Name,Course,Score)
;  Capacity: 100 records max, 43 bytes each
; ============================================================

.MODEL SMALL
.STACK 100H

; ============================================================
;  Constants
; ============================================================
MAX_STUDENT   EQU 100
RECORD_SIZE   EQU 43
ID_LEN        EQU 8
NAME_LEN      EQU 16
COURSE_LEN    EQU 16
FBUF_SIZE     EQU 4096

; ============================================================
;  PRINT_STR macro — print '$'-terminated string
; ============================================================
PRINT_STR MACRO msg
    PUSH AX
    PUSH DX
    MOV  AH, 09H
    LEA  DX, msg
    INT  21H
    POP  DX
    POP  AX
ENDM

; ============================================================
;  Data Segment
; ============================================================
.DATA
    ; ------ File I/O ------
    FILENAME    DB 'SCORE.TXT', 0
    FHANDLE     DW 0
    FBUF        DB FBUF_SIZE DUP(0)
    FBYTES      DW 0

    ; ------ Student record array ------
    ; Layout (43B): ID(8) Name(16) Course(16) Score(2) Deleted(1)
    STUDENTS    DB MAX_STUDENT * RECORD_SIZE DUP(0)
    SCOUNT      DW 0

    ; ------ Input buffer (INT 21H AH=0AH) ------
    ; [0]=max, [1]=actual_len, [2..]=chars
    INBUF       DB 20, 0, 20 DUP(0)
    SRCHKEY     DB 16 DUP(0)
    SRCHLEN     DW 0
    SRCHOFF     DW 0            ; search field offset (0=ID, 8=Name)

    ; ------ Course filter ------
    CRSFILT     DB COURSE_LEN DUP(0)
    CRSFILTLEN  DW 0

    ; ------ Output / build buffers ------
    LINEBUF     DB 64 DUP(0)     ; CSV line builder
    LINELEN     DW 0
    SCORESTR    DB 8 DUP(0)      ; score -> string
    NUMBUF      DB 8 DUP(0)      ; field print buffer

    ; ------ Statistics ------
    DIST        DW 5 DUP(0)      ; 5 score-range counts
    ST_TOTAL    DW 0
    ST_MAX      DW 0
    ST_MIN      DW 100
    ST_CNT      DW 0

    ; ------ Menu ------
    MSG_MENU    DB 0DH,0AH
                DB '+======================================+',0DH,0AH
                DB '|   Student Grade Management  v1.0     |',0DH,0AH
                DB '+======================================+',0DH,0AH
                DB '|  1. Add Record                       |',0DH,0AH
                DB '|  2. Search Record                    |',0DH,0AH
                DB '|  3. Modify Score                     |',0DH,0AH
                DB '|  4. Delete Record                    |',0DH,0AH
                DB '|  5. Statistics                       |',0DH,0AH
                DB '|  6. Histogram (score distribution)   |',0DH,0AH
                DB '|  7. List All Records                 |',0DH,0AH
                DB '|  0. Save & Exit                      |',0DH,0AH
                DB '+======================================+',0DH,0AH
                DB 'Select (0-7): $'

    MSG_LOAD_OK  DB 0DH,0AH,'[OK] score.txt loaded.$'
    MSG_LOAD_NEW DB 0DH,0AH,'[INFO] score.txt not found, created new file.$'
    MSG_SAVE_OK  DB 0DH,0AH,'[OK] Saved to score.txt.$'
    MSG_SAVE_ERR DB 0DH,0AH,'[ERROR] Save failed!$'
    MSG_EXIT     DB 0DH,0AH,'Goodbye!',0DH,0AH,'$'
    MSG_INVAL    DB 0DH,0AH,'[ERROR] Invalid input!$'
    MSG_NFOUND   DB 0DH,0AH,'[INFO] No matching record found.$'
    MSG_FULL     DB 0DH,0AH,'[ERROR] Capacity full (100 max)!$'
    MSG_EMPTY    DB 0DH,0AH,'[INFO] No records.$'
    MSG_DEL_OK   DB 0DH,0AH,'[OK] Record deleted.$'
    MSG_MOD_OK   DB 0DH,0AH,'[OK] Score updated.$'
    MSG_ADD_OK   DB 0DH,0AH,'[OK] Record added.$'

    MSG_ASK_ID   DB 0DH,0AH,'Student ID (1-8 chars): $'
    MSG_ASK_NAME DB 0DH,0AH,'Name: $'
    MSG_ASK_CRS  DB 0DH,0AH,'Course: $'
    MSG_ASK_SCR  DB 0DH,0AH,'Score (0-100): $'
    MSG_NEW_SCR  DB 0DH,0AH,'New score (0-100): $'
    MSG_SEL_WHICH DB 0DH,0AH,'Select course No: $'

    MSG_ASK_CRSFILT DB 0DH,0AH,'Course filter (Enter=all): $'

    MSG_SMODE    DB 0DH,0AH,'Search: 1=By ID  2=By Name  Select: $'
    MSG_FOUND    DB 0DH,0AH,'--- Search Results ---$'

    ; ------ Table header ------
    MSG_THEAD    DB 0DH,0AH
                 DB 'ID        Name              Course            Score',0DH,0AH
                 DB '--------  ----------------  ----------------  -----$'

    ; ------ Statistics ------
    MSG_STITLE   DB 0DH,0AH,'+========== Score Statistics ==========+$'
    MSG_AVG      DB 0DH,0AH,'Average : $'
    MSG_MAXS     DB 0DH,0AH,'Maximum : $'
    MSG_MINS     DB 0DH,0AH,'Minimum : $'
    MSG_RECCNT   DB 0DH,0AH,'Valid records: $'
    MSG_DTITLE   DB 0DH,0AH,'+========== Score Distribution ==========+$'
    MSG_D0       DB 0DH,0AH,'  90-100: $'
    MSG_D1       DB 0DH,0AH,'  80-89 : $'
    MSG_D2       DB 0DH,0AH,'  70-79 : $'
    MSG_D3       DB 0DH,0AH,'  60-69 : $'
    MSG_D4       DB 0DH,0AH,'  <60   : $'
    MSG_REN      DB ' ppl$'

    ; ------ Histogram ------
    MSG_HTITLE   DB 0DH,0AH,'+========== Score Histogram ==========+$'
    MSG_HSCALE1  DB 0DH,0AH,'  (each # = $'
    MSG_HSCALE2  DB ' person(s))$'
    BAR_CHAR     DB '#'

    ; ------ Common ------
    CRLF         DB 0DH,0AH,'$'
    SEPARATOR    DB '  $'
    COMMA_CHAR   DB ','

.CODE
; ============================================================
;  Main entry
; ============================================================
MAIN PROC FAR
    MOV  AX, @DATA
    MOV  DS, AX
    MOV  ES, AX

    CALL LOAD_FILE

MENU_LOOP:
    CALL SHOW_MENU
    CALL GET_CHAR

    CMP  AL, '0'
    JE   M_EXIT
    CMP  AL, '1'
    JE   M_ADD
    CMP  AL, '2'
    JE   M_SEARCH
    CMP  AL, '3'
    JE   M_MODIFY
    CMP  AL, '4'
    JE   M_DELETE
    CMP  AL, '5'
    JE   M_STATS
    CMP  AL, '6'
    JE   M_HIST
    CMP  AL, '7'
    JE   M_LIST
    JMP  MENU_LOOP

M_ADD:    CALL ADD_RECORD
          JMP  MENU_LOOP
M_SEARCH: CALL SEARCH_RECORD
          JMP  MENU_LOOP
M_MODIFY: CALL MODIFY_RECORD
          JMP  MENU_LOOP
M_DELETE: CALL DELETE_RECORD
          JMP  MENU_LOOP
M_STATS:  CALL SHOW_STATS
          JMP  MENU_LOOP
M_HIST:   CALL DRAW_HISTOGRAM
          JMP  MENU_LOOP
M_LIST:   CALL DISPLAY_ALL
          JMP  MENU_LOOP

M_EXIT:
    CALL SAVE_FILE
    PRINT_STR MSG_EXIT
    MOV  AH, 4CH
    INT  21H
MAIN ENDP

; ============================================================
;  Menu & Input
; ============================================================
SHOW_MENU PROC
    PRINT_STR MSG_MENU
    RET
SHOW_MENU ENDP

GET_CHAR PROC
    MOV  AH, 01H
    INT  21H
    RET
GET_CHAR ENDP

READ_LINE PROC
    MOV  INBUF[0], 19
    MOV  AH, 0AH
    LEA  DX, INBUF
    INT  21H
    RET
READ_LINE ENDP

NEWLINE PROC
    PRINT_STR CRLF
    RET
NEWLINE ENDP

; ============================================================
;  ====== File I/O ======
; ============================================================

; --- Load score.txt ---
LOAD_FILE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX

    ; Try to open existing file (read-only)
    MOV  AH, 3DH
    MOV  AL, 0
    LEA  DX, FILENAME
    INT  21H
    JC   LF_CREATE

    ; Read entire file
    MOV  [FHANDLE], AX
    MOV  BX, AX
    MOV  AH, 3FH
    MOV  CX, FBUF_SIZE - 1
    LEA  DX, FBUF
    INT  21H
    JC   LF_CLOSE
    MOV  [FBYTES], AX

    CALL PARSE_CSV

LF_CLOSE:
    MOV  AH, 3EH
    MOV  BX, [FHANDLE]
    INT  21H
    PRINT_STR MSG_LOAD_OK
    JMP  LF_DONE

LF_CREATE:
    MOV  AH, 3CH
    MOV  CX, 0
    LEA  DX, FILENAME
    INT  21H
    JC   LF_ERR
    MOV  BX, AX
    MOV  AH, 3EH
    INT  21H
LF_ERR:
    PRINT_STR MSG_LOAD_NEW

LF_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
LOAD_FILE ENDP

; --- Parse CSV buffer -> STUDENTS[] ---
PARSE_CSV PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA  SI, FBUF
    MOV  [SCOUNT], 0

PC_NEXT_REC:
    CMP  [SCOUNT], MAX_STUDENT
    JGE  PC_DONE

    ; Check if we have consumed all data
    PUSH SI
    LEA  AX, FBUF
    SUB  SI, AX
    CMP  SI, [FBYTES]
    POP  SI
    JGE  PC_DONE

    ; Skip leading CR / LF
    MOV  AL, [SI]
    CMP  AL, 0DH
    JE   PC_SKIP1
    CMP  AL, 0AH
    JE   PC_SKIP1
    CMP  AL, 00H
    JE   PC_DONE
    JMP  PC_PARSE

PC_SKIP1:
    INC  SI
    JMP  PC_NEXT_REC

PC_PARSE:
    ; Compute target record address
    MOV  AX, [SCOUNT]
    MOV  BX, RECORD_SIZE
    MUL  BX
    LEA  DI, STUDENTS
    ADD  DI, AX                ; DI = record base

    ; --- Parse ID (up to comma, max ID_LEN chars) ---
    MOV  CX, ID_LEN
    CALL PARSE_ONE_FIELD
    ADD  DI, ID_LEN

    ; --- Parse Name ---
    MOV  CX, NAME_LEN
    CALL PARSE_ONE_FIELD
    ADD  DI, NAME_LEN

    ; --- Parse Course ---
    MOV  CX, COURSE_LEN
    CALL PARSE_ONE_FIELD
    ADD  DI, COURSE_LEN

    ; --- Parse Score (decimal -> binary) ---
    CALL PARSE_SCORE_FIELD
    MOV  [DI], AX              ; store score (word)
    MOV  BYTE PTR [DI+2], 0    ; deleted flag = 0

    INC  [SCOUNT]
    JMP  PC_NEXT_REC

PC_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
PARSE_CSV ENDP

; --- Parse one CSV field ---
; Input:  SI -> source, CX = max field length, DI -> dest
; Output: dest space-padded, SI advanced past comma / CR / LF
; ---
PARSE_ONE_FIELD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DI

    MOV  BX, CX                ; BX = field max length

    ; Fill with spaces first
    MOV  AL, ' '
    CLD
    REP  STOSB
    SUB  DI, BX                ; DI back to field start

    ; Copy char by char until delimiter
PF_COPY:
    ; Check global bounds (SI vs FBUF + FBYTES)
    PUSH SI
    LEA  AX, FBUF
    SUB  SI, AX
    CMP  SI, [FBYTES]
    POP  SI
    JGE  PF_END

    MOV  AL, [SI]
    CMP  AL, ','               ; field delimiter
    JE   PF_COMMA
    CMP  AL, 0DH               ; end of line
    JE   PF_EOL
    CMP  AL, 0AH
    JE   PF_EOL
    CMP  AL, 00H
    JE   PF_END

    CMP  BX, 0
    JE   PF_SKIP               ; field full, skip remaining
    MOV  [DI], AL
    INC  DI
    DEC  BX

PF_SKIP:
    INC  SI
    JMP  PF_COPY

PF_COMMA:
    INC  SI                    ; skip comma
    JMP  PF_END

PF_EOL:
    ; Skip CR+LF
    CMP  BYTE PTR [SI], 0DH
    JNE  PF_CHECK_LF
    INC  SI
PF_CHECK_LF:
    CMP  BYTE PTR [SI], 0AH
    JNE  PF_END
    INC  SI

PF_END:
    POP  DI
    POP  CX
    POP  BX
    POP  AX
    RET
PARSE_ONE_FIELD ENDP

; --- Parse score field (decimal string -> AX) ---
PARSE_SCORE_FIELD PROC
    PUSH BX
    PUSH CX
    PUSH DX

    XOR  AX, AX

PSF_LOOP:
    PUSH SI
    LEA  BX, FBUF
    SUB  SI, BX
    CMP  SI, [FBYTES]
    POP  SI
    JGE  PSF_DONE

    MOV  BL, [SI]
    CMP  BL, '0'
    JB   PSF_SEP
    CMP  BL, '9'
    JA   PSF_SEP

    SUB  BL, '0'
    MOV  DX, 10
    MUL  DX
    ADD  AX, BX
    INC  SI
    JMP  PSF_LOOP

PSF_SEP:
    ; Skip separators
    CMP  BL, 0DH
    JNE  PSF_CHK_LF
    INC  SI
PSF_CHK_LF:
    CMP  BYTE PTR [SI], 0AH
    JNE  PSF_CHK_COMMA
    INC  SI
PSF_CHK_COMMA:
    CMP  BYTE PTR [SI], ','
    JNE  PSF_DONE
    INC  SI

PSF_DONE:
    POP  DX
    POP  CX
    POP  BX
    RET
PARSE_SCORE_FIELD ENDP

; --- Save to score.txt ---
SAVE_FILE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    ; Create / overwrite
    MOV  AH, 3CH
    MOV  CX, 0
    LEA  DX, FILENAME
    INT  21H
    JC   SF_ERR
    MOV  [FHANDLE], AX

    MOV  CX, [SCOUNT]
    JCXZ SF_CLOSE
    LEA  SI, STUDENTS

SF_LOOP:
    PUSH CX
    CMP  BYTE PTR [SI+42], 0
    JNE  SF_NEXT

    CALL BUILD_CSV_LINE

    MOV  AH, 40H
    MOV  BX, [FHANDLE]
    MOV  CX, [LINELEN]
    LEA  DX, LINEBUF
    INT  21H

SF_NEXT:
    ADD  SI, RECORD_SIZE
    POP  CX
    LOOP SF_LOOP

SF_CLOSE:
    MOV  AH, 3EH
    MOV  BX, [FHANDLE]
    INT  21H
    PRINT_STR MSG_SAVE_OK
    JMP  SF_DONE

SF_ERR:
    PRINT_STR MSG_SAVE_ERR

SF_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SAVE_FILE ENDP

; --- Build CSV line: record [SI] -> LINEBUF ---
BUILD_CSV_LINE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    LEA  DI, LINEBUF
    XOR  BX, BX                ; BX = line length (COPY_TRIMMED adds to it)
    MOV  DX, SI                ; DX = record base (SI is clobbered by COPY_TRIMMED)

    ; ---- Student ID ----
    MOV  SI, DX
    MOV  CX, ID_LEN
    CALL COPY_TRIMMED
    MOV  BYTE PTR [DI], ','
    INC  DI
    INC  BX

    ; ---- Name ----
    MOV  SI, DX
    ADD  SI, ID_LEN
    MOV  CX, NAME_LEN
    CALL COPY_TRIMMED
    MOV  BYTE PTR [DI], ','
    INC  DI
    INC  BX

    ; ---- Course ----
    MOV  SI, DX
    ADD  SI, ID_LEN + NAME_LEN
    MOV  CX, COURSE_LEN
    CALL COPY_TRIMMED
    MOV  BYTE PTR [DI], ','
    INC  DI
    INC  BX

    ; ---- Score (int -> string) ----
    MOV  SI, DX
    ADD  SI, ID_LEN + NAME_LEN + COURSE_LEN
    MOV  AX, [SI]
    CALL ITOA_SCORE
    ; Copy score digits, skip leading spaces
    LEA  SI, SCORESTR
BL_COPY_SCORE:
    MOV  AL, [SI]
    CMP  AL, ' '
    JE   BL_SKIP_SPC
    CMP  AL, '$'
    JE   BL_SCORE_DONE
    MOV  [DI], AL
    INC  DI
    INC  SI
    INC  BX
    JMP  BL_COPY_SCORE
BL_SKIP_SPC:
    INC  SI
    JMP  BL_COPY_SCORE
BL_SCORE_DONE:

    ; ---- CR+LF ----
    MOV  BYTE PTR [DI], 0DH
    MOV  BYTE PTR [DI+1], 0AH
    ADD  BX, 2
    MOV  [LINELEN], BX

    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
BUILD_CSV_LINE ENDP

; --- Copy field trimmed (remove trailing spaces) ---
; Input:  SI = source, CX = field length, DI = destination, BX = line length
; Output: DI advanced, BX incremented by chars copied
; ---
COPY_TRIMMED PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI

    ; Step 1: find last non-space position
    MOV  AX, CX                ; AX = effective length
    ADD  SI, CX
    DEC  SI                    ; SI = last char of field
    STD                        ; direction = backward

CT_SCAN:
    CMP  AX, 0
    JE   CT_COPY
    CMP  BYTE PTR [SI], ' '
    JNE  CT_COPY
    DEC  SI
    DEC  AX
    JMP  CT_SCAN

CT_COPY:
    CLD                        ; direction = forward
    POP  DI                    ; DI = original destination
    POP  SI                    ; SI = original source start
    MOV  CX, AX                ; CX = effective length
    JCXZ CT_DONE

CT_LOOP:
    MOV  AL, [SI]
    MOV  [DI], AL
    INC  SI
    INC  DI
    INC  BX
    LOOP CT_LOOP

CT_DONE:
    POP  CX
    POP  AX
    RET
COPY_TRIMMED ENDP

; ============================================================
;  ====== CRUD Operations ======
; ============================================================

; --- 1. Add Record ---
ADD_RECORD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    CMP  [SCOUNT], MAX_STUDENT
    JL   AR_OK
    PRINT_STR MSG_FULL
    JMP  AR_DONE

AR_OK:
    ; DI = STUDENTS + SCOUNT * RECORD_SIZE
    MOV  AX, [SCOUNT]
    MOV  BX, RECORD_SIZE
    MUL  BX
    LEA  DI, STUDENTS
    ADD  DI, AX

    ; --- Student ID ---
    PRINT_STR MSG_ASK_ID
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, ID_LEN
    JBE  AR_IDLEN_OK
    MOV  CX, ID_LEN
AR_IDLEN_OK:
    MOV  BX, CX                ; BX = actual copy count
    ; Fill entire field with spaces
    PUSH DI
    MOV  AL, ' '
    MOV  CX, ID_LEN
    CLD
    REP  STOSB
    POP  DI
    ; Copy input
    MOV  CX, BX
    LEA  SI, INBUF+2
    CLD
    REP  MOVSB
    ; Advance DI to end of ID field (start of Name)
    MOV  CX, ID_LEN
    SUB  CX, BX
    ADD  DI, CX

    ; --- Name ---
    PRINT_STR MSG_ASK_NAME
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, NAME_LEN
    JBE  AR_NAMLEN_OK
    MOV  CX, NAME_LEN
AR_NAMLEN_OK:
    MOV  BX, CX                ; BX = actual copy count
    PUSH DI
    MOV  AL, ' '
    MOV  CX, NAME_LEN
    CLD
    REP  STOSB
    POP  DI
    MOV  CX, BX
    LEA  SI, INBUF+2
    CLD
    REP  MOVSB
    ; Advance DI to end of Name field (start of Course)
    MOV  CX, NAME_LEN
    SUB  CX, BX
    ADD  DI, CX

    ; --- Course ---
    PRINT_STR MSG_ASK_CRS
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, COURSE_LEN
    JBE  AR_CRSLEN_OK
    MOV  CX, COURSE_LEN
AR_CRSLEN_OK:
    MOV  BX, CX                ; BX = actual copy count
    PUSH DI
    MOV  AL, ' '
    MOV  CX, COURSE_LEN
    CLD
    REP  STOSB
    POP  DI
    MOV  CX, BX
    LEA  SI, INBUF+2
    CLD
    REP  MOVSB
    ; Advance DI to end of Course field (start of Score)
    MOV  CX, COURSE_LEN
    SUB  CX, BX
    ADD  DI, CX

    ; --- Score ---
AR_SCORE:
    PRINT_STR MSG_ASK_SCR
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    LEA  SI, INBUF+2
    CALL ATOI
    CMP  AX, 0
    JL   AR_SCORE
    CMP  AX, 100
    JG   AR_SCORE
    MOV  [DI], AX
    MOV  BYTE PTR [DI+2], 0

    INC  [SCOUNT]
    PRINT_STR MSG_ADD_OK

AR_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ADD_RECORD ENDP

; --- 7. List All Records ---
DISPLAY_ALL PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH SI

    MOV  CX, [SCOUNT]
    CMP  CX, 0
    JNE  DA_HAS
    PRINT_STR MSG_EMPTY
    JMP  DA_DONE

DA_HAS:
    PRINT_STR MSG_THEAD
    LEA  SI, STUDENTS
DA_LOOP:
    PUSH CX
    CMP  BYTE PTR [SI+42], 0
    JNE  DA_NEXT
    CALL DISP_ONE
DA_NEXT:
    ADD  SI, RECORD_SIZE
    POP  CX
    LOOP DA_LOOP
    CALL NEWLINE

DA_DONE:
    POP  SI
    POP  CX
    POP  BX
    POP  AX
    RET
DISPLAY_ALL ENDP

; --- Display one record [SI] ---
DISP_ONE PROC
    PUSH AX
    PUSH CX
    PUSH SI

    ; Student ID
    CALL NEWLINE
    MOV  CX, ID_LEN
    CALL PRINT_FLD
    PRINT_STR SEPARATOR

    ; Name
    ADD  SI, ID_LEN
    MOV  CX, NAME_LEN
    CALL PRINT_FLD
    PRINT_STR SEPARATOR

    ; Course
    ADD  SI, NAME_LEN
    MOV  CX, COURSE_LEN
    CALL PRINT_FLD
    PRINT_STR SEPARATOR

    ; Score
    ADD  SI, COURSE_LEN
    MOV  AX, [SI]
    CALL PRINT_NUM

    POP  SI
    POP  CX
    POP  AX
    RET
DISP_ONE ENDP

; --- Print fixed-length field (char by char, AH=02H) ---
PRINT_FLD PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI

PFLD_LP:
    MOV  DL, [SI]
    MOV  AH, 02H
    INT  21H
    INC  SI
    LOOP PFLD_LP

    POP  SI
    POP  DX
    POP  CX
    POP  AX
    RET
PRINT_FLD ENDP

; --- 2. Search Record ---
SEARCH_RECORD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    PRINT_STR MSG_SMODE
    CALL GET_CHAR
    CMP  AL, '1'
    JE   SR_BY_ID
    CMP  AL, '2'
    JE   SR_BY_NAME
    JMP  SR_DONE

SR_BY_ID:
    PRINT_STR MSG_ASK_ID
    CALL READ_LINE
    ; Build search key (space-padded to ID_LEN)
    LEA  DI, SRCHKEY
    MOV  AL, ' '
    MOV  CX, ID_LEN
    CLD
    REP  STOSB
    LEA  DI, SRCHKEY
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, ID_LEN
    JBE  SR_L1
    MOV  CX, ID_LEN
SR_L1: LEA  SI, INBUF+2
    CLD
    REP  MOVSB
    MOV  [SRCHLEN], ID_LEN
    MOV  [SRCHOFF], 0           ; ID search starts at record offset 0
    JMP  SR_DO_SEARCH

SR_BY_NAME:
    PRINT_STR MSG_ASK_NAME
    CALL READ_LINE
    LEA  DI, SRCHKEY
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, 16
    JBE  SR_NAMLEN_OK
    MOV  CX, 16
SR_NAMLEN_OK:
    MOV  [SRCHLEN], CX
    LEA  SI, INBUF+2
    CLD
    REP  MOVSB
    ; Pad rest with spaces
    MOV  AL, ' '
    MOV  CX, 16
    SUB  CX, [SRCHLEN]
    REP  STOSB
    MOV  [SRCHLEN], 16
    MOV  [SRCHOFF], ID_LEN      ; Name search starts after 8-byte ID field

SR_DO_SEARCH:
    PRINT_STR MSG_FOUND
    PRINT_STR MSG_THEAD
    MOV  CX, [SCOUNT]
    LEA  SI, STUDENTS
    XOR  DX, DX                ; DX = match count

SR_LOOP:
    PUSH CX
    CMP  BYTE PTR [SI+42], 0
    JNE  SR_NEXT

    PUSH SI
    ADD  SI, [SRCHOFF]          ; point to ID (0) or Name (8) field
    LEA  DI, SRCHKEY
    MOV  CX, [SRCHLEN]
    CLD
    REPE CMPSB
    POP  SI
    JNE  SR_NEXT

    CALL DISP_ONE
    INC  DX

SR_NEXT:
    ADD  SI, RECORD_SIZE
    POP  CX
    LOOP SR_LOOP

    CMP  DX, 0
    JNE  SR_DONE
    PRINT_STR MSG_NFOUND

SR_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SEARCH_RECORD ENDP

; --- 3. Modify Score ---
MODIFY_RECORD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    PRINT_STR MSG_ASK_ID
    CALL READ_LINE
    ; Build search key (space-padded to ID_LEN)
    LEA  DI, SRCHKEY
    MOV  AL, ' '
    MOV  CX, ID_LEN
    CLD
    REP  STOSB
    LEA  DI, SRCHKEY
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, ID_LEN
    JBE  MR_IDOK
    MOV  CX, ID_LEN
MR_IDOK: LEA  SI, INBUF+2
    CLD
    REP  MOVSB

    ; ---- Phase 1: find & display all matching records ----
    MOV  CX, [SCOUNT]
    JCXZ MR_NFOUND
    LEA  SI, STUDENTS
    XOR  DX, DX                ; DX = match count
    LEA  BX, FBUF              ; BX = temp store for record pointers

MR_FLP:
    PUSH CX
    CMP  BYTE PTR [SI+42], 0
    JNE  MR_FNEXT

    PUSH SI
    PUSH DI
    LEA  DI, SRCHKEY
    MOV  CX, ID_LEN
    CLD
    REPE CMPSB
    POP  DI
    POP  SI
    JNE  MR_FNEXT

    ; Found -- display with sequence number
    INC  DX
    PUSH DX
    PUSH SI
    PUSH BX
    MOV  AX, DX
    CALL PRINT_NUM
    MOV  AH, 02H
    MOV  DL, '.'
    INT  21H
    MOV  DL, ' '
    INT  21H
    POP  BX
    POP  SI
    POP  DX                    ; balance PUSH DX (match count)

    CALL DISP_ONE
    CALL NEWLINE

    ; Store record pointer -> FBUF
    MOV  [BX], SI
    ADD  BX, 2

MR_FNEXT:
    ADD  SI, RECORD_SIZE
    POP  CX
    LOOP MR_FLP

    ; ---- Phase 2: handle selection ----
    CMP  DX, 0
    JNE  MR_HASMATCH
MR_NFOUND:
    PRINT_STR MSG_NFOUND
    JMP  MR_DONE

MR_HASMATCH:
    CMP  DX, 1
    JNE  MR_CHOOSE               ; multiple matches -> let user pick

    ; Single match -- use it directly
    MOV  AX, 1
    JMP  MR_GETPTR

MR_CHOOSE:
    PRINT_STR MSG_SEL_WHICH
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    LEA  SI, INBUF+2
    CALL ATOI
    CMP  AX, 1
    JL   MR_CHOOSE
    CMP  AX, DX
    JG   MR_CHOOSE

MR_GETPTR:
    ; Load record pointer from FBUF[(AX-1)*2]
    DEC  AX
    SHL  AX, 1
    LEA  BX, FBUF
    ADD  BX, AX
    MOV  SI, [BX]

    ; ---- Phase 3: get new score ----
MR_GETSCR:
    PRINT_STR MSG_NEW_SCR
    CALL READ_LINE
    XOR  CH, CH
    MOV  CL, INBUF[1]
    PUSH SI                    ; save record pointer
    LEA  SI, INBUF+2
    CALL ATOI
    POP  SI                    ; restore record pointer
    CMP  AX, 0
    JL   MR_GETSCR
    CMP  AX, 100
    JG   MR_GETSCR

    ADD  SI, ID_LEN + NAME_LEN + COURSE_LEN
    MOV  [SI], AX
    PRINT_STR MSG_MOD_OK

MR_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
MODIFY_RECORD ENDP


; --- 4. Delete Record (logical delete) ---
DELETE_RECORD PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI

    PRINT_STR MSG_ASK_ID
    CALL READ_LINE
    LEA  DI, SRCHKEY
    MOV  AL, ' '
    MOV  CX, ID_LEN
    CLD
    REP  STOSB
    LEA  DI, SRCHKEY
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, ID_LEN
    JBE  DR_L1
    MOV  CX, ID_LEN
DR_L1: LEA  SI, INBUF+2
    CLD
    REP  MOVSB

    MOV  CX, [SCOUNT]
    LEA  SI, STUDENTS

DR_LOOP:
    PUSH CX
    CMP  BYTE PTR [SI+42], 0
    JNE  DR_NEXT

    PUSH SI
    LEA  DI, SRCHKEY
    MOV  CX, ID_LEN
    CLD
    REPE CMPSB
    POP  SI
    JNE  DR_NEXT

    CALL DISP_ONE
    MOV  BYTE PTR [SI+42], 1
    PRINT_STR MSG_DEL_OK
    POP  CX
    JMP  DR_DONE

DR_NEXT:
    ADD  SI, RECORD_SIZE
    POP  CX
    LOOP DR_LOOP
    PRINT_STR MSG_NFOUND

DR_DONE:
    POP  DI
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DELETE_RECORD ENDP

; ============================================================
;  ====== Statistics & Histogram ======
; ============================================================

; --- Prompt for course filter ---
GET_COURSE_FILTER PROC
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH SI

    PRINT_STR MSG_ASK_CRSFILT
    CALL READ_LINE
    CALL NEWLINE

    XOR  CH, CH
    MOV  CL, INBUF[1]
    MOV  [CRSFILTLEN], CX       ; 0 means "all courses"

    JCXZ GCF_DONE               ; empty input -> show all

    ; Build space-padded filter (exact match on course field)
    LEA  DI, CRSFILT
    MOV  AL, ' '
    MOV  CX, COURSE_LEN
    CLD
    REP  STOSB                  ; fill with spaces

    LEA  DI, CRSFILT
    XOR  CH, CH
    MOV  CL, INBUF[1]
    CMP  CX, COURSE_LEN
    JBE  GCF_COPY
    MOV  CX, COURSE_LEN
GCF_COPY:
    LEA  SI, INBUF+2
    CLD
    REP  MOVSB

GCF_DONE:
    POP  SI
    POP  DI
    POP  CX
    POP  AX
    RET
GET_COURSE_FILTER ENDP

; --- Check if record matches course filter ---
; Input:  SI = record pointer, CRSFILT / CRSFILTLEN
; Output: ZF=1 if match (or filter empty), ZF=0 if no match
CHECK_COURSE PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI

    CMP  [CRSFILTLEN], 0
    JE   CC_MATCH              ; no filter = match all

    ADD  SI, ID_LEN + NAME_LEN ; point to course field
    LEA  DI, CRSFILT
    MOV  CX, COURSE_LEN
    CLD
    REPE CMPSB                 ; ZF=1 if full match, ZF=0 if mismatch
    JMP  CC_DONE

CC_MATCH:
    XOR  AX, AX
    CMP  AX, AX                ; set ZF=1

CC_DONE:
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
CHECK_COURSE ENDP

; --- Calculate distribution (fill DIST[5]) ---
CALC_DIST PROC
    PUSH AX
    PUSH CX
    PUSH SI
    PUSH DI

    LEA  DI, DIST
    MOV  CX, 5
    XOR  AX, AX
    CLD
    REP  STOSW                 ; zero out

    MOV  CX, [SCOUNT]
    JCXZ C_DST_DONE
    LEA  SI, STUDENTS

C_DST_LOOP:
    CMP  BYTE PTR [SI+42], 0
    JNE  C_DST_NEXT
    CALL CHECK_COURSE
    JNE  C_DST_NEXT
    MOV  AX, [SI + ID_LEN + NAME_LEN + COURSE_LEN]

    CMP  AX, 90
    JL   CD_CHK80
    INC  [DIST]
    JMP  C_DST_NEXT
CD_CHK80:
    CMP  AX, 80
    JL   CD_CHK70
    INC  [DIST+2]
    JMP  C_DST_NEXT
CD_CHK70:
    CMP  AX, 70
    JL   CD_CHK60
    INC  [DIST+4]
    JMP  C_DST_NEXT
CD_CHK60:
    CMP  AX, 60
    JL   CD_LOW
    INC  [DIST+6]
    JMP  C_DST_NEXT
CD_LOW:
    INC  [DIST+8]

C_DST_NEXT:
    ADD  SI, RECORD_SIZE
    LOOP C_DST_LOOP

C_DST_DONE:
    POP  DI
    POP  SI
    POP  CX
    POP  AX
    RET
CALC_DIST ENDP

; --- 5. Statistics ---
SHOW_STATS PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL GET_COURSE_FILTER       ; prompt for course name

    MOV  [ST_TOTAL], 0
    MOV  [ST_MAX], 0
    MOV  [ST_MIN], 100
    MOV  [ST_CNT], 0

    MOV  CX, [SCOUNT]
    CMP  CX, 0
    JNE  SS_HAS
    JMP  SS_NO_DATA
SS_HAS: LEA  SI, STUDENTS

SS_LOOP:
    CMP  BYTE PTR [SI+42], 0
    JNE  SS_NEXT
    CALL CHECK_COURSE
    JNE  SS_NEXT

    MOV  AX, [SI + ID_LEN + NAME_LEN + COURSE_LEN]
    INC  [ST_CNT]
    ADD  [ST_TOTAL], AX

    CMP  AX, [ST_MAX]
    JLE  SS_CHKMIN
    MOV  [ST_MAX], AX
SS_CHKMIN:
    CMP  AX, [ST_MIN]
    JGE  SS_NEXT
    MOV  [ST_MIN], AX

SS_NEXT:
    ADD  SI, RECORD_SIZE
    LOOP SS_LOOP

    ; Display
    PRINT_STR MSG_STITLE
    PRINT_STR MSG_RECCNT
    MOV  AX, [ST_CNT]
    CALL PRINT_NUM

    CMP  [ST_CNT], 0
    JE   SS_DIST

    PRINT_STR MSG_AVG
    MOV  AX, [ST_TOTAL]
    XOR  DX, DX
    MOV  CX, [ST_CNT]
    DIV  CX
    CALL PRINT_NUM

    PRINT_STR MSG_MAXS
    MOV  AX, [ST_MAX]
    CALL PRINT_NUM

    PRINT_STR MSG_MINS
    MOV  AX, [ST_MIN]
    CALL PRINT_NUM

SS_DIST:
    CALL CALC_DIST
    PRINT_STR MSG_DTITLE

    PRINT_STR MSG_D0
    MOV  AX, [DIST]
    CALL PRINT_NUM
    PRINT_STR MSG_REN

    PRINT_STR MSG_D1
    MOV  AX, [DIST+2]
    CALL PRINT_NUM
    PRINT_STR MSG_REN

    PRINT_STR MSG_D2
    MOV  AX, [DIST+4]
    CALL PRINT_NUM
    PRINT_STR MSG_REN

    PRINT_STR MSG_D3
    MOV  AX, [DIST+6]
    CALL PRINT_NUM
    PRINT_STR MSG_REN

    PRINT_STR MSG_D4
    MOV  AX, [DIST+8]
    CALL PRINT_NUM
    PRINT_STR MSG_REN
    JMP  SS_DONE

SS_NO_DATA:
    PRINT_STR MSG_EMPTY

SS_DONE:
    CALL NEWLINE
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SHOW_STATS ENDP

; --- 6. Histogram ---
DRAW_HISTOGRAM PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    CALL GET_COURSE_FILTER       ; prompt for course name
    CALL CALC_DIST

    ; Sum total for overview
    MOV  AX, [DIST]
    ADD  AX, [DIST+2]
    ADD  AX, [DIST+4]
    ADD  AX, [DIST+6]
    ADD  AX, [DIST+8]
    MOV  [ST_CNT], AX

    CMP  AX, 0
    JNE  DH_HASDATA
    PRINT_STR MSG_EMPTY
    JMP  DH_DONE

DH_HASDATA:
    ; Find max count -> determine scale (max bar width = 25)
    LEA  SI, DIST
    MOV  CX, 5
    XOR  AX, AX
DH_FINDMAX:
    CMP  [SI], AX
    JLE  DH_NEXTMAX
    MOV  AX, [SI]
DH_NEXTMAX:
    ADD  SI, 2
    LOOP DH_FINDMAX

    MOV  BX, 1                 ; default scale = 1
    CMP  AX, 25
    JLE  DH_SHOW
    XOR  DX, DX
    MOV  CX, 25
    DIV  CX
    INC  AX
    MOV  BX, AX                ; scale = max/25 + 1

DH_SHOW:
    PRINT_STR MSG_HTITLE
    PRINT_STR MSG_HSCALE1
    MOV  AX, BX
    CALL PRINT_NUM
    PRINT_STR MSG_HSCALE2
    CALL NEWLINE

    LEA  SI, DIST

    PRINT_STR MSG_D0
    MOV  AX, [SI]
    CALL DRAW_ONE_BAR

    PRINT_STR MSG_D1
    MOV  AX, [SI+2]
    CALL DRAW_ONE_BAR

    PRINT_STR MSG_D2
    MOV  AX, [SI+4]
    CALL DRAW_ONE_BAR

    PRINT_STR MSG_D3
    MOV  AX, [SI+6]
    CALL DRAW_ONE_BAR

    PRINT_STR MSG_D4
    MOV  AX, [SI+8]
    CALL DRAW_ONE_BAR

    ; Print total
    PRINT_STR MSG_RECCNT
    MOV  AX, [ST_CNT]
    CALL PRINT_NUM
    CALL NEWLINE

DH_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DRAW_HISTOGRAM ENDP

; --- Draw single bar: AX = count, BX = scale ---
DRAW_ONE_BAR PROC
    PUSH AX                     ; save original count for final print
    PUSH BX
    PUSH CX
    PUSH DX

    CMP  AX, 0
    JE   DOB_ZERO

    XOR  DX, DX
    DIV  BX                     ; AX = bar length (count / scale)
    CMP  AX, 0
    JNE  DOB_LOOP
    MOV  AX, 1                  ; non-zero gets at least 1 '#'

DOB_LOOP:
    MOV  CX, AX                 ; CX = bar length
    PUSH AX                     ; save bar length for padding
DOB_CHAR:
    MOV  AH, 02H
    MOV  DL, BAR_CHAR
    INT  21H
    LOOP DOB_CHAR

    ; Pad to fixed width (25 chars)
    POP  AX                     ; AX = bar length
    MOV  CX, 25
    SUB  CX, AX
    JBE  DOB_DONE               ; bar >= 25, no padding needed
DOB_PAD:
    MOV  AH, 02H
    MOV  DL, ' '
    INT  21H
    LOOP DOB_PAD
    JMP  DOB_DONE

DOB_ZERO:
    ; Print 25 spaces for empty bar
    MOV  CX, 25
DOB_ZERO_PAD:
    MOV  AH, 02H
    MOV  DL, ' '
    INT  21H
    LOOP DOB_ZERO_PAD

DOB_DONE:
    POP  DX
    POP  CX
    POP  BX
    POP  AX                     ; restore original count
    PRINT_STR SEPARATOR
    CALL PRINT_NUM
    PRINT_STR MSG_REN
    RET
DRAW_ONE_BAR ENDP

; ============================================================
;  ====== Utility Functions ======
; ============================================================

; --- ASCII -> integer: SI = string, CX = length, returns AX ---
ATOI PROC
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI

    XOR  AX, AX
    JCXZ AI_DONE
AI_LP:
    MOV  BL, [SI]
    CMP  BL, '0'
    JB   AI_DONE
    CMP  BL, '9'
    JA   AI_DONE
    SUB  BL, '0'
    MOV  DX, 10
    MUL  DX
    XOR  BH, BH
    ADD  AX, BX
    INC  SI
    LOOP AI_LP

AI_DONE:
    POP  SI
    POP  DX
    POP  CX
    POP  BX
    RET
ATOI ENDP

; --- Integer -> string: AX -> SCORESTR (right-aligned, leading spaces, '$' term) ---
ITOA_SCORE PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI

    ; Start from end
    LEA  DI, SCORESTR + 5
    MOV  BYTE PTR [DI], '$'
    DEC  DI

    CMP  AX, 0
    JNE  IS_CONV
    MOV  BYTE PTR [DI], '0'
    DEC  DI
    MOV  CX, 1
    JMP  IS_FILL

IS_CONV:
    XOR  CX, CX
IS_DIV:
    XOR  DX, DX
    MOV  BX, 10
    DIV  BX
    ADD  DL, '0'
    MOV  [DI], DL
    DEC  DI
    INC  CX
    CMP  AX, 0
    JNE  IS_DIV

IS_FILL:
    ; Leading spaces up to 6 bytes
IS_FILL_LP:
    CMP  DI, OFFSET SCORESTR - 1
    JBE  IS_DONE
    MOV  BYTE PTR [DI], ' '
    DEC  DI
    JMP  IS_FILL_LP

IS_DONE:
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
ITOA_SCORE ENDP

; --- Print integer (AX) ---
PRINT_NUM PROC
    PUSH AX
    PUSH DX
    PUSH SI

    CALL ITOA_SCORE
    ; Skip leading spaces
    LEA  SI, SCORESTR
PN_SKIP:
    CMP  BYTE PTR [SI], ' '
    JNE  PN_OUT
    INC  SI
    JMP  PN_SKIP
PN_OUT:
    MOV  AH, 09H
    MOV  DX, SI
    INT  21H

    POP  SI
    POP  DX
    POP  AX
    RET
PRINT_NUM ENDP

; ============================================================
END MAIN
