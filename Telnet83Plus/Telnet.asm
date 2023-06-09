;-----------+----------------------------------------------------+----------+
; Telnet 83 | Z80 Source Code for the TI-83 Graphing Calculator  | Infiniti |
;-----------+----------------------------------------------------+----------+
;
;       1998 Justin Karneges
;
;       Telnet83 V1.6
;
;       Telnet83 is a terminal program for the TI-83.  It has an 80x25
;       scrolling view and vt100 emulation.
;
;       To Use:
;               -Link two calcs together with the regular link and talk.
;               -Connect a Graphlink to a device such as a modem or TNC and
;                then connect the Graphlink to the calculator.
;               -It will work with anything that uses the linkport.  Try the
;                IR link. =)
;
;       Note:   There are a few vt100 sequences that telnet83 will recognize
;               but not do anything in response.  These are mainly sequences
;               that either the calculator can't do OR they are so old and
;               unused that I left it out.
;
;
;
;       Programming Note:
;               The instruction:
;
;               call    catchup         ; *-* LINK CHECK *+*
;
;               appears VERY often in the code (like a hundred times).
;               In order to get 9600bps out of the calc, I have to check
;               the link port insanely often.  It makes the code very ugly
;               to read, but it is a necessary step.
;
;-----------+----------------------------------------------------+----------+
; Telnet 83 | Includes/Defines/Program Start                     | Infiniti |
;-----------+----------------------------------------------------+----------+
.binarymode ti8x
#include "ti83plus.inc"
#include "mirage.inc"

#define GRAPH_MEM       plotsscreen

BEL             .equ    7
BS              .equ    8
HT              .equ    9
VT              .equ    11
FF              .equ    12
CR              .equ    13
CAN             .equ    24
SUB             .equ    26
ESC             .equ    27

NONE            .equ    0
BOLD            .equ    1
UNDERLINE       .equ    4
BLINK           .equ    5
INVERSE         .equ    7

; (mode_flags)
INSERT:         .equ        %10000000 ; insert/overwrite
LINE_WRAP:      .equ        %01000000 ; line wrap
LOCAL_ECHO_OFF: .equ        %00100000 ; disable local echo
CRLF:           .equ        %00010000 ; use CRLF instead of just CR

PORT    .equ    0

  .org    $9d93
  .db     $BB,$6D



  ret
  .db   3
button:
    .db %00000000,%00000000
    .db %00000000,%00000000
    .db %00111011,%10100000
    .db %00010010,%00100000
    .db %00010011,%00100000
    .db %00010010,%00100000
    .db %00010011,%10111000
    .db %00000000,%00000000
    .db %00110011,%10111000
    .db %00101010,%00010000
    .db %00101011,%00010000
    .db %00101010,%00010000
    .db %00101011,%10010000
    .db %00000000,%00000000
    .db %00000000,%00000000
    .dw exit

;desc:
    .db "Telnet83+ V1.6 by Infiniti",0




;-----------+----------------------------------------------------+----------+
; Telnet 83 | Program                                            | Infiniti |
;-----------+----------------------------------------------------+----------+
start:
        ; benryves: disable MirageOS interrupt
        im      1
    
        ; benryves: we need to try to find the appvar before allocating buffers
        ; in case it's archived and we need to move it into RAM.
        call    findappvar
        
        ; benryves: allocate buffers by inserting memory into the end of the program
        
        ; first check for enough free memory
        ld      hl, buffers_s
        bcall   (_EnoughMem)
        jp     c, quittoshell
        
        ; if there is, insert it into the variable
        ex      de, hl
        ld      de, buffers
        bcall   (_InsertMem)
        
        ; reset the terminal
        call    vt100reset
        
        ; default sign-on message
        ld      hl, signon
        ld      de, term
        ld      ix, pcury

signon_line_loop:

        ld      a, (hl)
        inc     hl
        or      a
        jr      z, signon_end
        
        push    de

signon_char_loop:
        ld      (de), a
        inc     de
        ld      a, (hl)
        inc     hl
        or      a
        jr      nz, signon_char_loop
        
        pop     de
    
        ; advance to next line
        ex      de, hl
        ld      bc, 80
        add     hl, bc
        ex      de, hl
        
        inc     (ix)
        
        jr      signon_line_loop


signon_end:

        ; load data from the appvar
        call    loadappvar

;        call    RINDOFF         ; Turn off runindicator (not needed)
        bcall(_grbufclr)        ;        call    BUFCLR          ; Clear the graphbuf
        bcall(_grbufcpy)        ;        call    BUFCOPY         ; Copy the graphbuf to the LCD
    ;*****Using getcsc instead of getk, b/c getk is aka poop
        bcall(_getcsc)          ;        call    READKEY         ; Clear out the keypad buffer
;        ld      (spbackup), sp  ; backup the stack (for use with quitting) (quittoshell)

mainloop:
      call    catchup         ; *-* LINK CHECK *+*
        ; --- render the screen ---
        call    fix_bound       ; make sure the scrolling screen is inbounds
        call    render_text     ; draw up the terminal
        call    render_stat     ; draw the status bar at the bottom

        ld      a, (panned)
        ld      b, a
        ld      a, (mm_mode)
        and     b
        call    nz, render_minimap

        xor     a
        ld      (panned), a

        call    zap             ; copy to LCD
        ; --- end ---

      call    catchup         ; *-* LINK CHECK *+*

        ; --- check with direct input (for scrolling) ---
        ld      a, (shift)
        cp      3
        jr      z, no_directarrow

        ; Credit goes to Hideaki Omuro (CRASHMAN) for this.
        ; I didn't feel like writing it. =)
;        LD  A, $FF \ OUT ($01), A     ; Reset Port
;        LD  A, $FE \ OUT ($01), A     ; Mask out Arrows
;        IN  A, ($01)
        ld      a,$FE
        call    directin
        BIT 0, A \ CALL Z, scroll_down
        BIT 3, A \ CALL Z, scroll_up
        BIT 1, A \ CALL Z, scroll_left
        BIT 2, A \ CALL Z, scroll_right

      call    catchup         ; *-* LINK CHECK *+*

no_directarrow:
        ; --- end ---
        
        ; benryves: is the ON key held?
        in      a, ($04)
        and     %00001000
        jr      nz, no_on_held
        
      call    catchup         ; *-* LINK CHECK *+*
        ; ON is held, so use alternate functions
        bcall   (_getcsc)
        
        cp      skGraph
        call    z, togglelocalecho
        
        cp      skClear
        call    z, vt100reset
        
        cp      skEnter
        call    z, togglenewlinemode
        
        jp      no_key

no_on_held:

        ; --- check keypad the normal way and respond accordingly ---
      call    catchup         ; *-* LINK CHECK *+*
        bcall   (_getcsc)
        or      a
        jp      z, no_key
        
        cp      skGraph
        jp      z, exit         ; quit
        cp      skClear
        call    z, vt100entirescreenhome
        cp      skZoom
        call    z, jumphome     ; zoom to the left edge [ZOOM] button
        cp      skWindow
        call    z, jumpcursor   ; bring the cursor into the current [WINDOW]
        cp      skTrace
        call    z, mm_mode_swap ; toggle minimap mode
        cp      skYEqu
        call    z, setwrap      ; toggle the character wrap
        
        ; shift modes - do not call, only jump
        cp      sk2nd
        jp      z, toggle2nd    ; set numeric
        cp      skAlpha
        jp      z, togglealph   ; set capital
        cp      skMode
        jp      z, togglemode   ; set extra
        cp      skGraphvar
        jp      z, togglectrl   ; set ctrl
        
      call    catchup         ; *-* LINK CHECK *+*
        ld      d, a
        ld      a, (shift)
        cp      3
        ld      a, d
        jr      nz, no_vtarrows

        cp      05h             ; cursor keys are all in range 1-4
        jr      nc, no_vtarrows
        
        call    keypad2ascii
        
        push    af
      call    catchup         ; *-* LINK CHECK *+*
        call    sendescbracket
        pop     af
        jr      send_key_byte

no_vtarrows:
        
        ; double check it really isn't a cursor key
        cp      05h
        jr      c, no_key

      call    catchup         ; *-* LINK CHECK *+*
        call    keypad2ascii    ; convert the key into ASCII
      call    catchup         ; *-* LINK CHECK *+*
        or      a               ;        cp      0
        jr      z, no_key       ; key doesn't have an entry
send_key_byte:
        push    af
        and     %01111111       ; strip MSB (hack used to allow NUL to be typed and flag on RETURN key)
        push    af
        ld      a, 1
        ld      (sendstat), a   ; flag the status bar to indicate send
      call    catchup         ; *-* LINK CHECK *+*
        pop     af
        call    sendbyte        ; chuck it out the window
      call    catchup         ; *-* LINK CHECK *+*
        pop     af
        cp      13+128
        jr      nz, no_key
        ld      a, (mode_flags)
        and     CRLF
        jr      z, no_key
        ld      a, '\n'
        call    sendbyte
no_key:
        ; --- end ---

        ; --- check for incoming data ---
more_data:
      call    catchup         ; *-* LINK CHECK *+*
        call    recvbyte        ; get a byte from the recv buffer
        or      a               ;       cp      0
        jr      z, no_data      ; it's empty

      call    catchup         ; *-* LINK CHECK *+*
        ld      b, a
        ld      a, (in_seq)
        or      a               ;        cp      0
        ld      a, b
        jr      nz, add2esc     ; continue the current vt100 sequence
        cp      ESC
        jr      z, handle_esc   ; begin tracking a new vt100 sequence
      call    catchup         ; *-* LINK CHECK *+*
        call    putchar         ; display the character
      call    catchup         ; *-* LINK CHECK *+*
        jr      incoming_done

handle_esc:
        ld      a, 1
        ld      (in_seq), a     ; flag that we're in sequence
        ld      hl, seqbuf
        ld      a, ESC
        ld      (hl), a         ; load an ESC character into the sequence
        jr      incoming_done
add2esc:
        cp      ESC
        jr      z, handle_esc
        
        cp      CAN
        jr      nz, add2esc_not_can
        
        call    erase_esc
        jr      incoming_done
        
add2esc_not_can:
        
        ld      hl, seqbuf
        ld      d, a
        ld      a, (in_seq)
        ld      c, a
        inc     a
        ld      (in_seq), a     ; bump the sequence pointer
        ld      a, d
        ld      b, 0
        add     hl, bc
        ld      (hl), a         ; add in the new character to the sequence
        call    check_seq       ; see if the sequence has a match
        or      a               ;        cp      0
        jr      z, seqoverflow  ; no match or sequence to big?
        cp      2
        call    z, erase_esc    ; perfect match was executed, delete now
        jr      incoming_done

seqoverflow:
      call    catchup         ; *-* LINK CHECK *+*
        call    killesc         ; output the sequence to the screen
      call    catchup         ; *-* LINK CHECK *+*
        xor     a
        ld      (in_seq), a     ; flag out the sequence pointer

incoming_done:
      call    catchup         ; *-* LINK CHECK *+*
        jp      more_data
no_data:
      call    catchup         ; *-* LINK CHECK *+*
        ; --- end ---

        ; --- change cursor status ---
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (timer)
        cp      2
        jr      nz, noswap      ; not time to swap yet
        ld      a, 0
        ld      (timer), a      ; zero out the cursor timer
        ld      a, (curstat)
        or      a               ;        cp      0
        jr      z, curisoff
        call    cursor_off      ; if on, turn back off
        jr      aftertimer
curisoff:
        call    cursor_on       ; if off, turn back on
        jr      aftertimer
noswap:
        inc     a
        ld      (timer), a      ; increment the timer
aftertimer:
        ; --- end ---
      call    catchup         ; *-* LINK CHECK *+*
        jp      mainloop        ; loop back to the top!

exit:
        ; benryves: store program state in appvar
        call    saveappvar

        ; benryves: free dynamically-allocated buffers
        ld      hl, buffers
        ld      de, buffers_s
        bcall   (_DelMem)
        jp      quittoshell

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Keypad shift routines (jump, do not call)          | benryves |
;-----------+----------------------------------------------------+----------+
toggle2nd:
        ld      a, 1
        jr      toggle_shift
togglealph:
        ld      a, 2
        jr      toggle_shift
togglemode:
        ld      a, 3
        jr      toggle_shift
togglectrl:
        ld      a, 4
        ; fall-through

toggle_shift:  
      call    catchup         ; *-* LINK CHECK *+*
        push    bc
        ld      b, a
        ld      a, (shift)
        cp      b
        ld      a, b
        jr      nz, shift_on
        xor     a
shift_on:
        ld      (shift), a
        pop     bc
        xor     a
        jp      no_key

;-----------+----------------------------------------------------+----------+
; Telnet 83 | AppVar helper functions                            | benryves |
;-----------+----------------------------------------------------+----------+

; find the existing appvar and unarchive it if possible
findappvar:
        ; does the appvar exist?
        ld      hl, appvarname
        rst     rMOV9TOOP1
        bcall   (_ChkFindSym)
        ret     c
        
appvarexists:
        ; is the appvar in the archive?
        ld      a, b
        or      a
        ret     z

appvararchived:

        ; is there enough free RAM to unarchive it?
        ld      hl, term_s + sdata_s + 256
        bcall   (_EnoughMem)
        ret     c
        
        ; unarchive the appvar and search for it again
        bcall   (_Arc_Unarc)
        jr      findappvar


checkappvarsize:
        ; fetch size bytes into HL
        ex      de, hl
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ex      de, hl
        
        ; check the expected size
        ld      bc, term_s + sdata_s
        or      a
        sbc     hl, bc
        
        ; set the carry flag if size mismatch
        scf
        ret     nz
        or      a
        ret

; save the program state to the appvar
saveappvar:
        call    findappvar
        jr      nc, overwriteappvar
        
        ; is there enough space to create the appvar?
        ld      hl, term_s + sdata_s + 256
        bcall   (_EnoughMem)
        ret     c
        
        ; create the appvar
        ld      hl, term_s + sdata_s
        bcall   (_CreateAppVar)

overwriteappvar:
        ; restore character under the cursor
        push    de
        call    cursor_off
        pop     de

        call    checkappvarsize
        ret     c
        
        ; copy the terminal buffer over
        ld      hl, term
        ld      bc, term_s
        ldir
        
        ; copy variable data
        ld      hl, sdata
        ld      bc, sdata_s
        ldir
        
        or      a
        ret

; load the program state from the appvar
loadappvar:
        call    findappvar
        ret     c
        
        call    checkappvarsize
        ret     c
        
        ex      de, hl
        
        ; copy the terminal buffer over
        ld      de, term
        ld      bc, term_s
        ldir
        
        ; copy variable data
        ld      de, sdata
        ld      bc, sdata_s
        ldir
        
        or      a
        ret

appvarname:
    .db AppVarObj, "TELNET", 0

;        ld      sp, (spbackup)
;        call    CLRTSHD         ; Clear textshadow
;        call    GOHOME          ; Leave graphscreen and go to homescreen
;        call    BUFCLR          ; Clear the graphbuf
;        call    READKEY         ; Catch the clear press
;        call    HOMEUP          ; Place cursor at home
;        ret                     ; Exit program

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Helper functions                                   | Infiniti |
;-----------+----------------------------------------------------+----------+
killesc:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (in_seq)
        ld      b, a
        ld      hl, seqbuf
kill_lp:
      call    catchup         ; *-* LINK CHECK *+*
        push    bc
        push    hl
        ld      a, (hl)
      call    catchup         ; *-* LINK CHECK *+*
        call    putchar
      call    catchup         ; *-* LINK CHECK *+*
        pop     hl
        inc     hl
        pop     bc
        djnz    kill_lp
        xor     a               ;        ld      a, 0
        ld      (in_seq), a
        ret

erase_esc:
      call    catchup         ; *-* LINK CHECK *+*
        xor     a               ;        ld      a, 0
        ld      (in_seq), a
        ret

zap:
      call    catchup         ; *-* LINK CHECK *+*
        call    bufcopy_catchup
        ret

scroll_left:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, (sx)
        sub     4
        ld      (sx), a
        pop     af
        jr      scrolled
        
scroll_right:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, (sx)
        add     a, 4
        ld      (sx), a
        pop     af
        jr      scrolled
        
scroll_up:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, (sy)
        sub     2
        ld      (sy), a
        pop     af
        jr scrolled
        
scroll_down:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, (sy)
        add     a, 2
        ld      (sy), a
        pop     af
      ; jr scrolled ; fall-through

scrolled:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, (panned)
        or      1
        ld      (panned), a
        xor     a
        ld      (autoscroll), a
        pop af
      jp    catchup         ; *-* LINK CHECK *+*

jumphome:
        xor     a
        ld      (autoscroll), a
        
        ld      a, (sx)
        or      a
        ret     z
        
        xor     a
        ld      (sx), a
        
        ld      a, (panned)
        or      1
        ld      (panned), a
        ret

; benryves: scroll the window to bring the cursor into view
jumpcursor:
        ld      a, 1
        ld      (autoscroll), a
        call    cursor_to_window
        ret     z
        ld      a, (panned)
        or      1
        ld      (panned), a
        xor     a
        ret

cursor_to_window:
        push    bc
        
        ld      c, 0
        ld      a, (sx)
        ld      b, a

        ld      a, (curx)
        cp      80
        jr      nz, curx_not_80
        xor     a
curx_not_80:
        
        sub     b
        jr      nc, notoffleft
        
        add     a, b
        ld      (sx), a
        
        inc     c
        
        jr      notoffright
        
notoffleft:
        cp      24
        jr      c, notoffright
        
        add     a, b
        sub     23
        ld      (sx), a

        inc     c
        
notoffright:

        ld      a, (sy)
        ld      b, a

        ld      a, (pcury)        
        sub     b
        jr      nc, notofftop
        
        add     a, b
        ld      (sy), a
        
        inc     c
        
        jr      notoffbottom
        
notofftop:
        cp      10
        jr      c, notoffbottom
        
        add     a, b
        sub     9
        ld      (sy), a

        inc     c

notoffbottom:
        
        ld      a, c
        or      a
        ld      a, 0
        
        pop     bc
        ret

cursor_moved:
        ld      a, (autoscroll)
        or      a
        ret     z
        
        call    cursor_to_window
        ret     z
        ld      a, (panned)
        or      2
        ld      (panned), a
        xor     a
        ret

mm_mode_swap: ; benryves: now cycles between 0, 1 and 3 for manual/autoscroll modes.
        ld      a, (mm_mode)
        inc     a
        cp      2
        jr      nz, mm_not_2
        inc     a
mm_not_2:
        and     3
mmzero:
        ld      (mm_mode), a
        ret
        
setwrap:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (wrap)
        cp      80
        ld      a, 80
        jr      nz, setwrapvalue
setwrap24:
        ld      a, 24
setwrapvalue:
        ld      (wrap), a
        xor     a
        ret

togglelocalecho:
        ld      b, LOCAL_ECHO_OFF
        jr      toggleflags
togglenewlinemode:
        ld      b, CRLF
        ; fall-through
toggleflags:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (mode_flags)
        xor     b
        ld      (mode_flags), a
        xor     a
        ret

putchar:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        call    cursor_off
        pop     af

        or      a
        ret     z
        jp      p, putchar_next1
        ld      a, 22
putchar_next1:
      call    catchup         ; *-* LINK CHECK *+*
        cp      '\n'
        jr      z, putnewline
        cp      CR
        jr      z, putreturn
        cp      BS
        jr      z, putbs
        cp      BEL
        jp      z, putbeep
        cp      HT
        jp      z, puttab
        cp      VT
        jr      z, putnewline
        cp      FF
        jr      z, putnewline

      call    catchup         ; *-* LINK CHECK *+*
        ld      d, a
        ld      a, (curattr)
        and     %10000000       ; benryves: treat curattr as bitmask
        or      d
        
      call    catchup         ; *-* LINK CHECK *+*

        push    af
        ld      a, (wrap)
        ld      b, a
        ld      a, (curx)
        cp      b
      call    catchup         ; *-* LINK CHECK *+*
        call    nc, putcr
      call    catchup         ; *-* LINK CHECK *+*

      call    catchup         ; *-* LINK CHECK *+*
        call    getxy
      call    catchup         ; *-* LINK CHECK *+*
        pop     af
        ld      (hl), a

        ld      a, (curx)
        inc     a
        ld      (curx), a
      call    catchup         ; *-* LINK CHECK *+*
        jp      cursor_moved

putnewline:
        ld      a, (mode_flags)
        and     CRLF
        call    nz, putreturn
vt100index:
        ld      a, (scr_bot)
        ld      c, a
        ld      a, (pcury)
        cp      c
        jp      nc, scrollup

        inc     a
        ld      (pcury), a
        jp      cursor_moved

putreturn:
        xor     a
        ld      (curx), a
        jp      cursor_moved
putbs:
        ld      a, (curx)
        or      a
        ret     z
        dec     a
        ld      (curx), a
        jp      cursor_moved

vt100nextline:
putcr:
      call    catchup         ; *-* LINK CHECK *+*
        call    putreturn
      call    catchup         ; *-* LINK CHECK *+*
        call    putnewline
      call    catchup         ; *-* LINK CHECK *+*
        ret

putbeep:
      call    catchup         ; *-* LINK CHECK *+*
        ld      hl, GRAPH_MEM
        ld      bc, 768
xorlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (hl)
        cpl
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, xorlp
      call    catchup         ; *-* LINK CHECK *+*
        call    zap
      call    catchup         ; *-* LINK CHECK *+*
        ret

puttab:
        call    getcurtab
        ret     c
        
        ld      d, a
        
        ld      a, (wrap)
        dec     a
        ld      c, a
        
        call    getwrappedcurx
        jr      nz, puttab_nowrap
        
        call    putcr
        
        ld      a, (curx)
puttab_nowrap:
        cp      c
        ret     nc
        
        ld      b, a
        
        ; b = column, c = max column, d = bitmask, hl -> tab data
        
puttab_not_found:
        
        inc     b
        
        ld      a, b
        cp      c
        jr      z, puttab_found
        
        rrc     d
        jr      nc, puttab_not_advanced
        inc     hl
puttab_not_advanced:
            
        ld      a, (hl)
        and     d
        jr      z, puttab_not_found
        
        ld      a, b
        
puttab_found:
        ld      (curx), a
        jp      cursor_moved

findchar:
      call    catchup         ; *-* LINK CHECK *+*
        ld      e, a
        ld      hl, font
        ld      d, 0
        ld      b, 8
findlp:
      call    catchup         ; *-* LINK CHECK *+*
        add     hl, de
        djnz    findlp
        ret


buildtable:
        ld      ix, fonttable
        ld      hl, 0
        ld      de, 8
        ld      b, 128
buildlp:
        push    bc
        ld      a, l
        ld      (ix), a
        ld      a, h
        ld      (ix+1), a
        add     hl, de
        inc     ix
        inc     ix
        pop     bc
        djnz    buildlp
        ret

render_text:
      call    catchup         ; *-* LINK CHECK *+*
        ld      ix, GRAPH_MEM
        ld      (rptr), ix
        ld      a, 0
        ld      (rtype), a

        call    bufclr_catchup

        ld      hl, term
        ld      a, (sy)
        ld      c, a
        ld      b, 80
        call    mul
        add     hl, bc
        ld      b, 0
        ld      a, (sx)
        ld      c, a
        add     hl, bc

        ld      b, 10
st1:
        push    bc

        ld      b, 24
st2:
      call    catchup         ; *-* LINK CHECK *+*
        push    bc
        push    hl

        ld      a, 0
        ld      (rinv), a

        ld      a, (hl)
        bit     7, a
        jr      z, r_normal
        and     127
        ld      d, a
        ld      a, 1
        ld      (rinv), a
        ld      a, d
r_normal:
        ld      c, a
        ld      b, 0
        ld      ix, fonttable
        add     ix, bc
        add     ix, bc
        ld      c, (ix)
        ld      b, (ix+1)
        ld      hl, font
        add     hl, bc

        ld      a, (rinv)
        cp      1
        jr      nz, r_normal2
        ld      de, rtmp
        ld      bc, 8
      call    catchup         ; *-* LINK CHECK *+*
        ldir

        ld      hl, rtmp
        ld      b, 6
r_neglp:
        ld      a, (hl)
        xor     255
        and     %11110000
        ld      (hl), a
        inc     hl
        djnz    r_neglp
        ld      hl, rtmp

r_normal2:
        ld      ix, (rptr)
        ld      a, (rtype)
        or      a
        jr      z, rbnoff
        jr      rbyoff
rbnoff:
        call    blit_no_offset
        jr      rbnoff_done
rbyoff:
        call    blit_offset
        ld      ix, (rptr)
        inc     ix
        ld      (rptr), ix
rbnoff_done:
        call    swap_rtype

        pop     hl
        inc     hl
        pop     bc
        dec     b
        jp      nz, st2

        ld      ix, (rptr)
        ld      de, 60
        add     ix, de
        ld      (rptr), ix
        
        ld      bc, 56
        add     hl, bc

        pop     bc
        dec     b
        jp      nz, st1
        ret

blit_no_offset
      call    catchup         ; *-* LINK CHECK *+*
        ld      c, (hl)
        ld      a, (ix)
        or      c
        ld      (ix), a
        inc     hl

        ld      c, (hl)
        ld      a, (ix+12)
        or      c
        ld      (ix+12), a
        inc     hl

        ld      c, (hl)
        ld      a, (ix+24)
        or      c
        ld      (ix+24), a
        inc     hl

        ld      c, (hl)
        ld      a, (ix+36)
        or      c
        ld      (ix+36), a
        inc     hl

        ld      c, (hl)
        ld      a, (ix+48)
        or      c
        ld      (ix+48), a
        inc     hl

        ld      c, (hl)
        ld      a, (ix+60)
        or      c
        ld      (ix+60), a
        ld      a, 0
      call    catchup         ; *-* LINK CHECK *+*
        ret

blit_offset:
      call    catchup         ; *-* LINK CHECK *+*
        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix)
        or      c
        ld      (ix), a
        inc     hl

        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix+12)
        or      c
        ld      (ix+12), a
        inc     hl

        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix+24)
        or      c
        ld      (ix+24), a
        inc     hl

        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix+36)
        or      c
        ld      (ix+36), a
        inc     hl

        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix+48)
        or      c
        ld      (ix+48), a
        inc     hl

        ld      c, (hl)
        srl     c
        srl     c
        srl     c
        srl     c
        ld      a, (ix+60)
        or      c
        ld      (ix+60), a
        ld      a, 1
      call    catchup         ; *-* LINK CHECK *+*
        ret

swap_rtype:
        ld      a, (rtype)
        cp      1
        jr      z, swap_zero
        ld      a, 1
        ld      (rtype), a
        ret
swap_zero:
        ld      a, 0
        ld      (rtype), a
        ret


render_stat:
      call    catchup         ; *-* LINK CHECK *+*
        ld      e, 0
        ld      hl, statusleft
        call    drawstatus

        ld      e, 11
        ld      hl, statusright
        call    drawstatus
        
        ; top edge of status bar
        ld      hl, GRAPH_MEM + (60 * 12)
        ld      de, GRAPH_MEM + (60 * 12) + 1
        ld      (hl), $FF
        ld      bc, 11
        ldir
        
        ; bottom edge of status bar
        ld      hl, GRAPH_MEM + (63 * 12)
        ld      de, GRAPH_MEM + (63 * 12) + 1
        ld      (hl), $FF
        ld      bc, 11
        ldir

        ; shift state
        ld      a, (shift)
        or      a
        jr      z, stat_no_shift
        
        ld      hl, statusshade
        dec     a
        jr      z, stat_draw_shift
        
        ld      de, 2
        add     hl, de
        dec     a
        jr      z, stat_draw_shift
        
        add     hl, de
        dec     a
        jr      z, stat_draw_shift
        
        add     hl, de
        dec     a
        jr      nz, stat_no_shift

stat_draw_shift:
    
        ld      e, 0
        call    drawstatus
        
stat_no_shift:
        
        ld      e, 1
        ld      hl, statusfill
        ld      a, (wrap)
        cp      24
        call    z, drawstatus

        call    check_recv
        ld      e, 11
        ld      hl, statusfill
        call    nz, drawstatus

        ld      a, (sendstat)
        or      a
        ld      e, 10
        ld      hl, statusfill
        call    nz, drawstatus
        xor     a
        ld      (sendstat), a
        
        ld      e, 9
        ld      hl, statusshade
        ld      a, (mode_flags)
        and     LOCAL_ECHO_OFF
        call    z, drawstatus
        
        ld      e, 3
        ld      hl, statuscrlf
        ld      a, (mode_flags)
        and     CRLF
        call    nz, drawstatus

        ld      a, (mm_mode)
        or      a
        jr      z, statnext7
        dec     a                   ; benryves: now shows shaded for mode 1, solid for mode 3
        ld      e, 2
        ld      hl, statusshade
        jr      z, mm_shaded
        ld      hl, statusfill
mm_shaded:
        call    drawstatus
statnext7:

      call    catchup         ; *-* LINK CHECK *+*
        ret

render_minimap:
        ld      ix, GRAPH_MEM + 390 - 13
        ld      b, 255

        ld      a, (ix+0)
        or      1
        ld      (ix+0), a
        ld      (ix+1), b
        ld      (ix+2), b
        ld      (ix+3), b
        ld      (ix+4), b
        ld      (ix+5), b
        ld      a, (ix+6)
        or      128
        ld      (ix+6), a

        ld      ix, GRAPH_MEM + 390 - 13 + 300
        ld      a, (ix+0)
        or      1
        ld      (ix+0), a
        ld      (ix+1), b
        ld      (ix+2), b
        ld      (ix+3), b
        ld      (ix+4), b
        ld      (ix+5), b
        ld      a, (ix+6)
        or      128
        ld      (ix+6), a

        ld      b, 24
        ld      de, 12
        ld      hl, GRAPH_MEM + 390 - 1
mmprelp1:
        ld      a, (hl)
        or      1
        ld      (hl), a
        add     hl, de
        djnz    mmprelp1

        ld      b, 24
        ld      hl, GRAPH_MEM + 390 + 5
mmprelp2:
        ld      a, (hl)
        or      128
        ld      (hl), a
        add     hl, de
        djnz    mmprelp2


        ld      hl, GRAPH_MEM + 390
        ld      ix, term
        ld      b, 24
        ld      de, 7
mmlp:
        push    bc
      call    catchup         ; *-* LINK CHECK *+*
        ld      b, 5
mmlp2:
        push    bc

        ld      c, 0
        ld      b, 8
mmlp3:
        ld      a, (ix+0)
        cp      32
        jr      nz, mmfilled
        ld      a, (ix+1)
        cp      32
        jr      nz, mmfilled
        jr      mmblank

mmfilled:
        scf
        rl      c
        jr      mmnext
mmblank:
        sla     c
mmnext:
        inc     ix
        inc     ix
        djnz    mmlp3

        ld      (hl), c
        inc     hl
        pop     bc
        djnz    mmlp2

        add     hl, de
        pop     bc
        djnz    mmlp

        ld      a, (sy)
        add     a, 32
        ld      e, a
        ld      a, (sx)
        srl     a
        add     a, 48
        ld      bc, mmg1
        call    SPRXOR

        ld      a, (sy)
        add     a, 32
        ld      e, a
        ld      a, (sx)
        srl     a
        add     a, 48+8
        ld      bc, mmg2
        call    SPRXOR

        ld      a, (sy)
        add     a, 32+8
        ld      e, a
        ld      a, (sx)
        srl     a
        add     a, 48
        ld      bc, mmg3
        call    SPRXOR

        ld      a, (sy)
        add     a, 32+8
        ld      e, a
        ld      a, (sx)
        srl     a
        add     a, 48+8
        ld      bc, mmg4
        call    SPRXOR

        ret


fix_bound:
        call    fix_boundsx
        call    fix_boundsy
        ret

fix_boundsx:
        ld      a, (sx)
        ld      b, a
        and     128
        jr      nz, sx_neg
        ld      a, b
        cp      57
        jr      nc, sx_pos
        ret
sx_neg:
        xor     a           ;       ld      a, 0
        ld      (sx), a
        ret
sx_pos:
        ld      a, 56
        ld      (sx), a
        ret

fix_boundsy:
        ld      a, (sy)
        ld      b, a
        and     128
        jr      nz, sy_neg
        ld      a, b
        cp      15
        jr      nc, sy_pos
        ret
sy_neg:
        ld      a, 0
        ld      (sy), a
        ret
sy_pos:
        ld      a, 14
        ld      (sy), a
        ret

mul:
      call    catchup         ; *-* LINK CHECK *+*
        push    de
        push    hl
        ld      a, b
        or      a               ;        cp      0
        jr      z, mul0
        ld      hl, 0
        ld      a, c
        ld      e, a
        ld      d, 0
mulp:
        add     hl, de
        djnz    mulp
        push    hl
        pop     bc

        pop     hl
        pop     de
        ret
mul0:
        ld      bc, 0
        pop     hl
        pop     de
        ret

getxy:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (pcury)
        ld      c, a
        ld      b, 80
        ld      hl, term
        call    mul
        add     hl, bc
        ld      b, 0
        ld      a, (curx)
        ld      c, a
        add     hl, bc
      call    catchup         ; *-* LINK CHECK *+*
        ret

cursor_on:
        ld      a, (curstat)
        or      a
        ret     nz
      call    catchup         ; *-* LINK CHECK *+*
        call    getxy
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (hl)
        ld      (curshad), a
        xor     a
        ld      (hl), a
        inc     a
        ld      (curstat), a
        ret

cursor_off:
        ld      a, (curstat)
        or      a               ;        cp      0
        ret     z
      call    catchup         ; *-* LINK CHECK *+*
        call    getxy
        ld      a, (curshad)
        ld      (hl), a
        xor     a               ;        ld      a, 0
        ld      (curstat), a
      call    catchup         ; *-* LINK CHECK *+*
        ret

; getch - gets a keypress.  //save row:col in b:c
;getch:
;        call    _GetK

;        ld      a, (OP2+3)
;        ld      b, a
;        ld      a, (OP2+2)

;        cp      0
;        ret     z

;        ld      c, a
;        ld      a, b
;        cp      0
;        jp      nz, getch_ext
;        ld      a, c
;        ret

;getch_ext:
;      call    catchup         ; *-* LINK CHECK *+*
;        ld      d, a
;        srl     d
;        srl     d
;        srl     d
;        srl     d
;        ld      a, 0ah * 16
;        add     a, d
;      call    catchup         ; *-* LINK CHECK *+*
;        ret

keypad2ascii:
      call    catchup         ; *-* LINK CHECK *+*
;        cp      26h                     ; the right arrow is a special case
;        jr      nz, no_keypad_right     ; because it is the only key in
;        ld      a, 0                    ; column 6.  since column 6 isn't in
;        ret                             ; the key tables, it must be filtered
;no_keypad_right:                        ; out now.

 ;       ld      b, a
 ;       and     15
 ;       ld      e, a
 ;       ld      a, b
 ;       srl     a
 ;       srl     a
 ;       srl     a
 ;       srl     a
 ;       and     15
 ;       ld      d, a
 ;       dec     d
 ;       dec     e
 ;       push    de
 ;       ld      a, d
 ;       ld      d, 0
 ;       ld      e, a
        dec     a
        ld      e,a
        ld      d,0

;      call    catchup         ; *-* LINK CHECK *+*
;        ld      hl, keypad_table
;        ld      b, 5
;keypad_lp:
;      call    catchup         ; *-* LINK CHECK *+*
;        add     hl, de
;        djnz    keypad_lp

;        pop     de
;        ld      d, 0
;        add     hl, de

;      call    catchup         ; *-* LINK CHECK *+*
        ld      hl,keypad_table
        ld      a, (shift)
        cp      1
        call    z, keypad_2nd
        cp      2
        call    z, keypad_alph
        cp      3
        call    z, keypad_mode
        cp      4
        call    z, keypad_ctrl
        add     hl,de
        ld      a, (hl)
      call    catchup         ; *-* LINK CHECK *+*
        ret

keypad_2nd:
        ld      hl,keypad_table2
      jp      catchup         ; *-* LINK CHECK *+*
       
keypad_alph:
        ld      hl,keypad_table3
      jp    catchup         ; *-* LINK CHECK *+*
       
keypad_mode:
        ld      hl,keypad_table4
      jp    catchup         ; *-* LINK CHECK *+*
       
keypad_ctrl:
        ld      hl,keypad_table5
        xor     a
        ld      (shift), a
      jp    catchup         ; *-* LINK CHECK *+*
        

; benryves: simplified status bar drawing code:
; hl -> sprite, e = column.
drawstatus:

        push    hl              ; Save sprite address

          call    catchup

        ld      hl, GRAPH_MEM + (61 * 12)
        ld      d, 0
        add     hl, de

        pop     de              ; de->sprite
        ld      b, 2
ALOP1:  ld      a, (de)
          call    catchup
        or      (hl)            ; xor=erase/blit
        ld      (hl),a
        inc     de
        push    bc
        ld      bc, 12
        add     hl, bc
        pop     bc
        djnz    ALOP1

        ret

;---------= Fast Copy =---------
;Input: nothing
;Output: graph buffer is copied to the screen
bufcopy_catchup:
        push    af              ; [11] Save AF
        push    bc              ; [11] Save BC
        push    hl              ; [11] Save HL
        ld      a, $80          ; [ 7] Set Cursor to Top Row
        out     ($10), a        ; [11]
        call    $000B           ; benryves: delay
        ld      hl, PLOTSSCREEN ; [10] Copy GRAPH_MEM
        push    de              ; [11] Save DE
        ld      c, $20          ; [ 7] C = Cursor Column Number
        ld      a, c            ; [ 4] A = Cursor Column Number
_CLCD_Loop:
        ld      de, 12          ; [10] Increment number
        out     ($10), a        ; [11] Write Column Number to Port
        call    $000B           ; benryves: delay
        ld      b, $3F          ; [ 7] Repeat Loop 63 times
_CLCDClmLoop:
        call    catchup
        ld      a, (hl)         ; [ 7] Read data into A
        add     hl, de          ; [11] Increment pointer to next row
        out     ($11), a        ; [11] Write byte to LCD
        call    $000B           ; benryves: delay
        djnz    _CLCDClmLoop    ; [13] Loop [8]
        ld      de, -755        ; [10] Get ready to move to next column
        ld      a, (hl)         ; [ 7] Read data into A
        add     hl, de          ; [11] Update position to top of next column
        out     ($11), a        ; [11] Write byte to LCD
        call    $000B           ; benryves: delay
        inc     c               ; [ 4] Increment Cursor
        ld      a, c            ; [ 4]
        cp      $2D             ; [ 7]
        jr      nz, _CLCD_Loop  ; [12]/[ 7]
        pop     de              ; [10] Get DE back
        pop     hl              ; [10] Get HL back
        pop     bc              ; [10] Get BC back
        pop     af              ; [10] Get AF back
        ret                     ; [10]

bufclr_catchup:
        ld      de, 768
        ld      b, 0
        ld      hl, PLOTSSCREEN
bufclrlp:
        call    catchup
        ld      (hl), b
        inc     hl
        dec     de
        ld      a, d
        or      e
        jr      nz, bufclrlp
        ret

;-----------+----------------------------------------------------+----------+
; Telnet 83 | VT100 functions                                    | Infiniti |
;-----------+----------------------------------------------------+----------+
check_seq:
        ; clear the partial match flag
        xor     a
        ld      (check_partial), a
        
        ld      ix, vt100table
check_mainlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (ix)
        
        ld      b, a            ; total length of sequence
        inc     a               ; 255?
        jr      z, check_done_finished
        
        push    ix
      call    catchup         ; *-* LINK CHECK *+*
        call    check_seqn
      call    catchup         ; *-* LINK CHECK *+*
        pop     ix

        cp      2               ; did we execute the sequence?
        ret     z

        cp      1               ; was it a partial sequence?
        jr      nz, check_done_not_partial
        
        ld      (check_partial), a

check_done_not_partial:
        
        ld      c, (ix)
        inc     c
        ld      b, 0
        add     ix, bc
        inc     ix
        inc     ix
        jr      check_mainlp

check_done_finished:
        ; did we make any partial matches?
        ld      a, (check_partial)
        or      a
        ret     z
        
        ; has the sequence filled the buffer?
        ld      a, (in_seq)
        cp      seqbuf_s
        ld      a, 1
        ret     c
        xor     a
        ret

check_seqn:
        ld      hl, seqbuf+1
        ld      b, (ix)         ; B = total length of expected sequence pattern
        ld      a, (in_seq)
        ld      c, a            ; C = total length of received sequence characters
        inc     ix
check_seqlp:
        dec     c               ; are we out of characters to read?
        jr      z, check_out_of_seq
     call    catchup         ; *-* LINK CHECK *+*
        
        ld      a, (ix)
        or      a
        jr      nz, check_norm
        
check_digit:
        ld      a, (hl)
        cp      '0'
        jr      c, check_not_digit
        cp      '9'+1
        jr      c, check_digits

check_not_digit:
        ; expected a digit, didn't get one
        ; could be implicit 0, e.g. in ^[[;f for ^[[<y>;<x>f
        ld      a, b
        or      a
        jr      z, check_bad
        dec     b
        inc     ix
        ld      a, (ix)
        jr      check_norm

check_digits:
        
        inc     hl
        dec     c
        jr      z, check_out_of_seq
        
        ld      a, (hl)
        cp      '0'
        jr      c, check_digit_ended
        cp      '9'+1
        jr      nc, check_digit_ended
        
        jr      check_digits

check_digit_ended:
        dec     hl
        inc     c
        jr      check_ok

check_norm:
        cp      (hl)
        jr      nz, check_bad
        
check_ok:
        inc     hl
        inc     ix
        djnz    check_seqlp
        
        ld      hl, check_return_from
        push    hl
        call    cursor_off

        ld      hl, seqbuf+2
        ld      a, (ix)
        ld      c, a
        ld      a, (ix+1)
        ld      b, a
        push    bc
        pop     ix
        jp      (ix)
check_return_from:
        ld      a, 2
     call    catchup         ; *-* LINK CHECK *+*
        ret

check_bad:
        xor     a
        ret

check_out_of_seq:
        ld      a, 1
        ret

;-----------+----------------------------------------------------+----------+
; Telnet 83 | VT100 escape sequences                             | Infiniti |
;-----------+----------------------------------------------------+----------+
;i've never had more fun programming...

vt100cursorleft:
        call    getparam_zer1
vtcurleft:
        ld      a, (curx)
        sub     b
        call    under0
        ld      (curx), a
        jp      cursor_moved

vt100cursorright:
        call    getparam_zer1
vtcurright:
        ld      a, (wrap)
        dec     a
        ld      c, a
        ld      a, (curx)
        add     a, b
        call    over_c
        ld      (curx), a
        jp      cursor_moved

vt100cursorup:
        call    getparam_zer1
vtcurup:
        ld      a, (pcury)
        sub     b
        call    under0
        ld      (pcury), a
        jp      cursor_moved

vt100cursordown:
        call    getparam_zer1
vtcurdown:
        ld      c, 25-1
        ld      a, (pcury)
        add     a, b
        call    over_c
        ld      (pcury), a
        jp      cursor_moved

vt100entirescreenhome:
        call    vt100entirescreen
        ; fall-through

vt100cursorreset:
        ld      c, 1
        ld      b, 1
        jr      vt_gotoxy
vt100changecursor:
        call    getparam_zer1
        ld      a, b
        ld      c, a
        inc     hl
        call    getparam_zer1
vt_gotoxy:
        ld      a, c
        ld      d, a
        ld      a, b
        ld      c, a
        ld      a, d
        ld      b, a

        dec     c
        dec     b
        ld      a, c
        cp      80
        ret     nc
        ld      a, b
        cp      25
        ret     nc
        ld      a, c
        ld      (curx), a
        ld      a, b
        ld      (pcury), a
        jp      cursor_moved

vt100setscrolling:
        call    getparam_zer1
        dec     a
        cp      24
        ret     nc
        ld      (n), a
        inc     hl
        call    getparam
        jr      c, vt100setscroll_bottom
        ld      a, 25
vt100setscroll_bottom:
        dec     a
        cp      24
        ret     nc
        ld      (n2), a
vt100ss1:
        ld      a, (n)
        ld      b, a
        ld      a, (n2)
        cp      b
        ret     c
        ld      a, (n)
        ld      (scr_top), a
        ld      a, (n2)
        ld      (scr_bot), a
        jr      vt100cursorreset

vt100erasecursorend:            ; ED ^[[J or ^[[0J : erase from cursor to end of screen
        call    cursor_off
        call    getxy

      call    catchup         ; *-* LINK CHECK *+*
        
        push    hl
        ld      de, term + term_s - 1
        ex      de, hl
        or      a
        sbc     hl, de
        ld      b, h
        ld      c, l
        pop     hl
        jr      vtclearlp

vt100erasebegcursor:            ; ED ^[[1J : erase from beginning of display to cursor
        call    cursor_off
        call    getxy

      call    catchup         ; *-* LINK CHECK *+*

        ld      bc, 1 - term
        add     hl, bc
        ld      b, h
        ld      c, l
        ld      hl, term
        jr      vtclearlp

vt100entirescreen:              ; ED ^[[2J : erase entire screen
        call    cursor_off
        ld      hl, term
        ld      bc, term_s
vtclearlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, ' '
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, vtclearlp
        ret


scrollup:
      call    catchup         ; *-* LINK CHECK *+*
        
        ld      a, (scr_top)
        ld      c, a
        ld      b, 80
        call    mul
      
      call    catchup         ; *-* LINK CHECK *+*
        
        ld      hl, term
        add     hl, bc
        
        ld      d, h
        ld      e, l
        ld      bc, 80
        add     hl, bc
        
      call    catchup         ; *-* LINK CHECK *+*
      
        ld      a, (scr_top)
        ld      b, a
        ld      a, (scr_bot)
        sub     b
        ret     z
        ld      b, a
        ld      c, 80
        
      call    catchup         ; *-* LINK CHECK *+*
      
        call    mul
      
      call    catchup         ; *-* LINK CHECK *+*
        ldir
      call    catchup         ; *-* LINK CHECK *+*
      
        push    de
        pop     hl
        inc     de
        ld      (hl), ' '
        ld      bc, 80 - 1
        ldir

      call    catchup         ; *-* LINK CHECK *+*
      
        ret
        
vt100reverseindex:

        ld      a, (pcury)
        ld      c, a
        ld      a, (scr_top)
        cp      c
        jr      nc, scrolldown

        ld      a, c
        dec     a
        ld      (pcury), a
        jp      cursor_moved

scrolldown:
      call    catchup         ; *-* LINK CHECK *+*
        
        ld      a, (scr_bot)
        ld      c, a
        ld      b, 80
        call    mul
      
      call    catchup         ; *-* LINK CHECK *+*
        
        ld      hl, term + 79
        add     hl, bc
        
        ld      d, h
        ld      e, l
        ld      bc, -80
        add     hl, bc
        
      call    catchup         ; *-* LINK CHECK *+*
      
        ld      a, (scr_top)
        ld      b, a
        ld      a, (scr_bot)
        sub     b
        ret     z
        ld      b, a
        ld      c, 80
        
      call    catchup         ; *-* LINK CHECK *+*
      
        call    mul
      
      call    catchup         ; *-* LINK CHECK *+*
        lddr
      call    catchup         ; *-* LINK CHECK *+*
      
        push    de
        pop     hl
        dec     de
        ld      (hl), ' '
        ld      bc, 80 - 1 
        lddr

      call    catchup         ; *-* LINK CHECK *+*
      
        ret

vt100storecoords:               ; DECSC ^[7 : save cursor
        ld      hl, (curx)
        ld      de, (scurx)
        ld      (scurx), hl
        ld      a, (curattr)
        ld      (scurattr), a
        or      a
        sbc     hl, de
        jp      nz, cursor_moved
        ret
        
vt100restorecoords:             ; DECRC ^[8 : restore cursor
        ld      hl, (scurx)
        ld      de, (curx)
        ld      (curx), hl
        ld      a, (scurattr)
        ld      (curattr), a
        or      a
        sbc     hl, de
        jp      nz, cursor_moved
        ret
        
vt100eraseline:					; EL ^[[2K : erase complete line
        ld      a, (curx)
        push    af
        xor     a
        ld      (curx), a
        call    vt100eraseendline
        pop     af
        ld      (curx), a
        ret

vt100eraseendline:				; EL ^[[K or ^[[0K : erase from cursor to end of line
        call    cursor_off
        call    getxy
        ld      a, (curx)
        ld      b, a
        ld      a, 80
        sub     b
        ret     z
        ld      b, a

        ld      d, 32
        ld      a, (curattr)
        and     %10000000
        or      d           ; benryves: treat curattr as bitmask
vteel_lp:
        ld      (hl), a
        inc     hl
        djnz    vteel_lp
        ret

vt100erasecursor:				; EL ^[[1K : erase from start of line to cursor
        call    cursor_off
        call    getxy
        ld      a, (curx)
        ld      b, a
        inc     b

        ld      d, 32
        ld      a, (curattr)
        and     %10000000
        or      d           ; benryves: treat curattr as bitmask
vtec_lp:
        ld      (hl), a
        dec     hl
        djnz    vtec_lp
        ret

vt100cursorstyle1:
        ld      b, 1
        jr      vt100applycursorstyles
vt100cursorstyle2:
        ld      b, 2
        jr      vt100applycursorstyles
vt100cursorstyle3:
        ld      b, 3
        jr      vt100applycursorstyles
vt100cursorstyle4:
        ld      b, 4
        ; jr      vt100applycursorstyles ; fall-through

; benryves: support VT100 cursor style bitmasks
vt100applycursorstyles:
        push    bc
        call    getparam                ; param in both A and B
        call    vt100applycursorstyle
        inc     hl
        pop     bc
        djnz    vt100applycursorstyles
        ret
        
vt100applycursorstyle:
        or      a
        jr      nz, vt100notresetcursorstyle
        ld      (curattr), a
        ret
        
vt100notresetcursorstyle:
        ld      b, %10000000
        cp      7
        jr      z, vt100cursorstyleon
        cp      27
        ret     nz

vt100cursorstyleoff:
        ld      a, b
        cpl
        ld      b, a
        ld      a, (curattr)
        and     b
        ld      (curattr), a
        ret
        
vt100cursorstyleon:
        ld      a, (curattr)
        or      b
        ld      (curattr), a
        ret

vt100reset:
        
        ; clear buffers
        ld      hl, buffers
        ld      de, buffers + 1
        ld      bc, buffers_s - 1
        ld      (hl), ' '
        ldir
        
        ; clear data
        ld      hl, data
        ld      de, data + 1
        ld      bc, data_s - 1
        ld      (hl), 0
        ldir
        
        ; set certain non-zero variables
        ld      a, 80
        ld      (wrap), a
        ld      a, 23
        ld      (scr_bot), a
        ld      a, 1
        ld      (mm_mode), a
        ld      (autoscroll), a
        ld      a, LOCAL_ECHO_OFF
        ld      (mode_flags), a
        
        ; set up default 8-wide tab stops
        ld      hl, tab_stops + 1
        ld      de, tab_stops + 2
        ld      bc, 8
        ld      (hl), %10000000
        ldir

        call    buildtable      ; build the font table
        call    recv_init       ; benryves: initialise the receive buffer

        xor     a
        ret

getwrappedcurx:
        push    bc
        ld      a, (wrap)
        ld      b, a
        ld      a, (curx)
        cp      b
        pop     bc
        ret     nz
        xor     a
        ret

getcurtab:
        call    getwrappedcurx
gettab:                         ; in: a = cursor position, out: ca = invalid position, otherwise: hl->tab byte, a = bitmask
        
        ; range check
        cp      80
        ccf
        ret     c
        
        ; get pointer
        ld      c, a
        srl     c
        srl     c
        srl     c
        ld      b, 0
        ld      hl, tab_stops
        add     hl, bc
        
        ; get bitmask
        and     7
        ld      b, a
        ld      a, %10000000
        
        ret     z

gettab_bitmask:
        srl     a
        djnz    gettab_bitmask
        ret
        

vt100settab:                    ; HTS (horizontal tabulation set) ^[H
        call    getcurtab
        ret     c
        or      (hl)
        ld      (hl), a
        ret
        
vt100cleartab:                  ; TBC (tabulation clear) ^[[g or ^[[0g
        call    getcurtab
        ret     c
        cpl
        and     (hl)
        ld      (hl), a
        ret
        
vt100clearalltabs:              ; clears all horizontal tab stops ^[[3g
        ld      hl, tab_stops
        ld      de, tab_stops + 1
        ld      bc, 9
        ld      (hl), 0
        ldir
        ret

vt100timefinish:
        ret

vt100cursorreport:              ; CPR (cursor position report) ^[[6n
    
        ; response is ^[[<y>;<x>R
        
        call    sendescbracket
        
        ; send Y
        
        ld      a, (pcury)
        or      a
        jr      z, vt100cursorreport_homey
        
        inc     a
        call    sendparam
        
vt100cursorreport_homey:
        
        ld      a, ';'
        call    sendbyte
        
        ; send X
        
        ld      a, (curx)
        or      a
        jr      z, vt100cursorreport_homex
        
        inc     a
        call    sendparam

vt100cursorreport_homex:
        
        ld      a, 'R'
        jp      sendbyte
        
vt100statusrep:					; DSR (device status report) ^[[5n
        ld      hl, vt100ready
        ld      b, 3
        jp      sendescseq
vt100ready:
        .db     "[0n"

vt100whatareyou:				; DA (device attributes) ^[[c or ^[[0c, DECID (identify terminal) ^[Z
        ; possible responses:
        ; VT100: ^[[?1;0c
        ; VT102: ^[[?6c
        ; VT220: ^[[?62;0c
        ; VT320: ^[[?63;0c
        ld		hl, vt100attributes
        ld		b, 6
        jp      sendescseq
vt100attributes:
        .db		"[?1;0c"

vt100setmode:                   ; ^[[<mode>h SET MODE
        call    getparamflagmask
        ret     nz
        ld      a, (mode_flags)
        or      b
        jr      vt100changemode        
        
vt100resetmode:                 ; ^[[<mode>l RESET MODE
        call    getparamflagmask
        ret     nz
        ld      a, b
        cpl
        ld      b, a
        ld      a, (mode_flags)
        and     b
vt100changemode:
        ld      (mode_flags), a
        ret

getparamflagmask:
        call    getparam
getflagmask:
        ld      b, %10000000
        cp      4   ; insert/overwrite
        ret     z
        srl     b
        cp      7   ; line wrapping
        ret     z
        srl     b
        cp      12  ; local echo
        ret     z
        srl     b
        cp      20  ; new line/line feed
        ret     z
        ld      b, 0
        ret

getparam: ; benryves: now supports values with multiple digits
        ld      b, 0
        
        ld      a, (hl)
        cp      '0'
        jr      c, getparam_empty
        cp      '9'+1
        jr      nc, getparam_empty
        
getparamlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (hl)
        inc     hl
        sub     '0'
        add     a, b
        ld      b, a
        
        ld      a, (hl)
        cp      '0'
        jr      c, getparam_end
        cp      '9'+1
        jr      nc, getparam_end

      call    catchup         ; *-* LINK CHECK *+*

        ; we have another digit after the current one, so multiply what we have so far by 10
        ld      a, b
        add     a, a
        add     a, a
        add     a, a
        add     a, b
        add     a, b
        ld      b, a
        jr      getparamlp
        
getparam_end:
        ld      a, b
        scf
        ret

getparam_empty:
        xor     a           ; rcf
        ret

getparam_def1:              ; getparam, but if value is missing return 1 instead of 0.
        call    getparam
        ret     c
getparam_1:
        inc     a
        inc     b
        ret

getparam_zer1:              ; getparam, but if value is missing or 0 return 1 instead of 0.
        call    getparam
        or      a
        ret     nz
        jr      getparam_1
        
under0:
        ret     nc
        ld      a, 0
        ret

over_c:
        cp      c
        ret     c
        ret     z
        ld      a, c
        ret

;-----------+----------------------------------------------------+----------+
; Telnet 83 | ROM Call Defines                                   | Infiniti |
;-----------+----------------------------------------------------+----------+
;WAITKEY .equ     4CFEh  ; Wait for a key and read (getkey)
;BUFCLR  .equ     515Bh  ; Clear the graph backup
;BUFCOPY .equ     5164h  ; Copy the graph backup to the screen
;RINDOFF .equ     4795h  ; Turn off runindicator
;PRINTHL .equ     4709h  ; Print HL in dec. on the screen
;OP2TOP1 .equ     41C2h  ; Move OP2 to OP1
;CONVOP1 .equ     4EFCh  ; Convert fp value in OP1 to a 2 byte hex
;READKEY .equ     4A18h  ; Read key and place it in OP2 as a fp value
;GOHOME  .equ     47A1h  ; Go to home screen (finish gfx program)
;CLRTSHD .equ     4765h  ; Clear text shadow
;HOMEUP  .equ     4775h  ; Place cursor at home
;STRING  .equ     470Dh  ; Print 0 terminated string to screen (hl->string)

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Include files                                      | Infiniti |
;-----------+----------------------------------------------------+----------+
#include "sendrecv.h"
#include "sprxor.h"     ; movax's sprxor
#include "tl.h"         ; the file containing the linkport routines

#include "font.h"       ; the file containing the font
;-----------+----------------------------------------------------+----------+
; Telnet 83 | The 80x25 display                                  | Infiniti |
;-----------+----------------------------------------------------+----------+
keypad_table:
        ;*grr, how annoying, why can't you use a 
        ;decent keypress routine?*

        .db "BDCA"                  ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13+128,34,"wrmh",0      ;9-F, enter, quote, wrmh, clear
        .db 0                       ;10, unused
        .db "/@vqlg",9              ;11-17, negative, theta, vqlh, vars
        .db 0                       ;18, unused
        .db ".zupkfc",27            ;19-20, peroid, zupkfc, stat
        .db " ytojeb",0             ;21-28, space, ytojeb, xt0n
        .db 0                       ;29, unused
        .db "xsnida",0              ;2A-30, xsnida, alpha
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,8                   ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,  8,  0,  0
;        .db   0,  0, 27,  0,  0        .db 'a','b','c',  9,  0
;        .db 'd','e','f','g','h'        .db 'i','j','k','l','m'
;        .db 'n','o','p','q','r'        .db 's','t','u','v','w'
;        .db 'x','y','z','@', 34        .db   0,' ','.','/', 13
keypad_table2:
        .db "BDCA"                  ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13+128,"+-*/^",0        ;9-F, enter, +-*/^, clear
        .db 0                       ;10, unused
        .db "/","369)",0,9          ;11-17, \369), tan, vars
        .db 0                       ;18, unused
        .db ".258(",0,0,27          ;19-20, .258(, cos, prog, stat
        .db "0147,",0,0,0           ;21-28, 0147,, sin, apps, xt0n
        .db 0                       ;29,unused
        .db "><",0,0,0,0,0          ;2A-30, ><, log, square, inverse, math, alpha
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,8                   ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,  8,  0,  0
;        .db   0,  0, 27,  0,  0        .db   0,  0,  0,  9,  0
;        .db   0,  0,  0,  0,'^'        .db   0,',','(',')','/'
;        .db   0,'7','8','9','*'        .db '<','4','5','6','-'
;        .db '>','1','2','3','+'        .db   0,'0','.','\', 13
keypad_table3:
        .db "BDCA"                  ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13+128,39,"WRMH",0      ;9-F, enter, quote, wrmh, clear
        .db 0                       ;10, unused
        .db "?@VQLG",9              ;11-17, negative, theta, vqlh, vars
        .db 0                       ;18, unused
        .db ":ZUPKFC",27            ;19-20, peroid, zupkfc, stat
        .db " YTOJEB",0             ;21-28, space, ytojeb, xt0n ; benryves: made UPPERCASE
        .db 0                       ;29, unused
        .db "ZSNIDA",0              ;2A-30, xsnida, alpha
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,8                   ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,  8,  0,  0
;        .db   0,  0, 27,  0,  0        .db 'A','B','C',  9,  0
;        .db 'D','E','F','G','H'        .db 'I','J','K','L','M'
;        .db 'N','O','P','Q','R'        .db 'S','T','U','V','W'
;        .db 'X','Y','Z','@', 39        .db   0,' ',':','?', 13
keypad_table4:
        .db "BDCA"                  ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db "=~][|_",0              ;9-F, enter, quote, wrmh, clear
        .db 0                       ;10, unused
        .db "?#^(}",0,9             ;11-17, negative, theta, vqlh, vars
        .db 0                       ;18, unused
        .db ";@%*{",0,0,27          ;19-20, peroid, zupkfc, stat
        .db ")!$&`",0,0,0           ;21-28, space, ytojeb, xt0n
        .db 0                       ;29, unused
        .db "><",0,0,0,0,0          ;2A-30, xsnida, alpha
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,8                   ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,  8,  0,  0
;        .db   0,  0, 27,  0,  0        .db   0,  0,  0,  9,  0
;        .db   0,  0,  0,  0,'_'        .db   0,'`','{','}','|'
;        .db   0,'&','*','(','['        .db '<','$','%','^',']'
;        .db '>','!','@','#','~'        .db   0,')',';','?','='
keypad_table5:
        .db "BDCA"                  ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13+128,29,23,18,13,8,0  ;9-F enter, quote, wrmh, clear
        .db 0                       ;10, unused
        .db 31,27,22,17,12,7,128    ;11-17, negative, theta, vqlh, vars
        .db 0                       ;18, unused
        .db 30,26,21,16,11,6,3,27   ;19-20, peroid, zupkfc, stat
        .db 28,25,20,15,10,5,2,0    ;21-28, space, ytojeb, xt0n
        .db 0                       ;29, unused
        .db 24,19,14,9,4,1,0        ;2A-30, xsnida, alpha
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,127                 ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,127,  0,  0
;        .db   0,  0, 27,  0,  0        .db   1,  2,  3,  7,  0
;        .db   4,  5,  6,  7,  8        .db   9, 10, 11, 12, 13
;        .db  14, 15, 16, 17, 18        .db  19, 20, 21, 22, 23
;        .db  24, 25, 26, 27, 29        .db   0,')',';','?','='


signon
        .db "TELNET 83 v1.6", 0
        .db "by Justin Karneges, 1998", 0
        .db " ", 0
        .db "[Graph] = Quit", 0
        .db "[2nd]   = Numeric", 0
        .db "[Alpha] = Capital", 0
        .db "[Mode]  = Extra", 0
        .db "[X]     = Ctrl", 0
        .db 0
        
statusleft
        .db 10000000b
        .db 10000000b
statusbar
        .db 00000000b
        .db 00000000b
statusshade
        .db 10101011b
        .db 11010101b
statusfill
        .db 11111111b
        .db 11111111b
statusjail
        .db 10101010b
        .db 10101010b
statusctrl
        .db 10010100b
        .db 10100010b
statuscrlf
        .db 00100010b
        .db 00010100b
statusright
        .db 00000001b
        .db 00000001b

mmg1
        .db 11111111b
        .db 10000000b
        .db 10000000b
        .db 10000000b
        .db 10000000b
        .db 10000000b
        .db 10000000b
        .db 10000000b
mmg2
        .db 11110000b
        .db 00010000b
        .db 00010000b
        .db 00010000b
        .db 00010000b
        .db 00010000b
        .db 00010000b
        .db 00010000b
mmg3
        .db 10000000b
        .db 11111111b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
mmg4
        .db 00010000b
        .db 11110000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b
        .db 00000000b

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Data                                               | Infiniti |
;-----------+----------------------------------------------------+----------+

data        = saveSScreen

; saved data
sdata       = data

shift       = sdata + 0         ; .db     0
wrap        = shift + 1         ; .db     80

curx        = wrap + 1          ; .db     0       ; - Cursor position (in characters)
pcury       = curx + 1          ; .db     8       ; /
curattr     = pcury + 1         ; .db     0       ; cursor attributes (bold, inverse, etc)

scurx       = curattr + 1       ; .db     0       ; - Saved cursor position
scury       = scurx + 1         ; .db     0       ; /
scurattr    = scury + 1         ; .db     0       ; saved cursor attributes

sx          = scurattr + 1      ; .db     0       ; - Screen position (in characters)
sy          = sx + 1            ; .db     0       ; /

scr_top     = sy + 1            ; .db     0       ; top of scrolling region
scr_bot     = scr_top + 1       ; .db     23      ; bottom of scrolling region

tab_stops   = scr_bot + 1       ; .db     0,1,..  ; tab stops

mm_mode     = tab_stops + 10    ; .db     1       ; show minimap never (0), manually scrolled (1), auto scrolled (2)

mode_flags  = mm_mode + 1       ; .db     0

sdata_end   = mode_flags + 1
sdata_s     = sdata_end - sdata

; temporary data
tdata       = sdata_end

rtmp        = tdata + 0         ; .db     0,0,0,0,0,0,0,0
rinv        = rtmp + 8          ; .db     0

rptr        = rinv + 1          ; .dw     0
rtype       = rptr + 2          ; .db     0

check_partial = rtype + 1       ; .db     0

timer       = check_partial + 1 ; .db     0       ; Timer used for flashing cursor
curstat     = timer + 1         ; .db     0       ; Current status of cursor
curshad     = curstat + 1       ; .db     0       ; Character that's behind the cursor

sendstat    = curshad + 1       ; .db    0  ; flag to force statusbar to display send status
                                ; upon keypress even if it was sent so fast that
                                ; there's no data pending

panned      =  sendstat + 1     ; .db     0       ; did you pan the screen during the previous loop?
autoscroll  =  panned + 1       ; .db     1       ; should the screen autoscroll to show the cursor?

n           = autoscroll + 1    ; .dw     0       ; temp var
n2          = n + 2             ; .dw     0       ; temp var

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Buffers                                            | Infiniti |
;-----------+----------------------------------------------------+----------+
; #define BUFSIZE 32

; buffer for vt100 sequences

seqbuf      = n2 + 2            ; .db     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
seqbuf_s    = 20
in_seq      = seqbuf + seqbuf_s ; .db     0

; backup of register SP
;spbackup .dw    0

tdata_end   = in_seq + 1
tdata_s     = tdata_end - tdata

data_end    = tdata_end + 0
data_s      = sdata_s + tdata_s

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Code from Zterm for the TI-85 (Zshell)             | Infiniti |
;-----------+----------------------------------------------------+----------+

; The following was taken directly from Zterm.  I love the function table
; concept.  I'm not to fond of the sequence parameter method, though...


    ;format \/\/\/ - - first byte - length of command
    ;                  next few from first byte - command
    ;          next two - place to jump execution
    ;          last in table - $FF, terminator

vt100table:
    .db $03,'[',$00,'D'
    .dw vt100cursorleft
    .db $03,'[',$00,'C'
    .dw vt100cursorright
    .db $03,'[',$00,'A'
    .dw vt100cursorup
    .db $03,'[',$00,'B'
    .dw vt100cursordown

    .db $02,'[','H'
    .dw vt100cursorreset
    .db $05,'[',$00,';',$00,'H'
    .dw vt100changecursor
    .db $02,'[','f'
    .dw vt100cursorreset
    .db $05,'[',$00,';',$00,'f'
    .dw vt100changecursor

    .db $03,'[','2','J'
    .dw vt100entirescreen
    .db $03,'[','1','J'
    .dw vt100erasebegcursor
    .db $02,'[','J'
    .dw vt100erasecursorend
    .db $03,'[','0','J'
    .dw vt100erasecursorend
    
    .db $05,'[',$00,';',$00,'r'
    .dw vt100setscrolling
    
    .db $01,'7'
    .dw vt100storecoords
    .db $01,'8'
    .dw vt100restorecoords
    .db $01,'D'
    .dw vt100index
    .db $01,'M'
    .dw vt100reverseindex
    .db $01,'E'
    .dw vt100nextline
    .db $03,'[','2','K'
    .dw vt100eraseline
    .db $02,'[','K'
    .dw vt100eraseendline
    .db $03,'[','0','K'
    .dw vt100eraseendline
    .db $03,'[','1','K'
    .dw vt100erasecursor
    .db $03,'[',$00,'m'
    .dw vt100cursorstyle1                       ;vt100cursorstyle
    .db $05,'[',$00,';',$00,'m'
    .dw vt100cursorstyle2                       ;vt100cursorstyle
    .db $07,'[',$00,';',$00,';',$00,'m'
    .dw vt100cursorstyle3                       ;vt100cursorstyle
    .db $09,'[',$00,';',$00,';',$00,';',$00,'m'
    .dw vt100cursorstyle4                       ;vt100cursorstyle

    .db $01,'H'
    .dw vt100settab
    .db $02,'[','g'
    .dw vt100cleartab
    .db $03,'[','0','g'
    .dw vt100cleartab
    .db $03,'[','3','g'
    .dw vt100clearalltabs
    
    .db $03,'[','5','n'
    .dw vt100statusrep
    .db $02,'[','c'
    .dw vt100whatareyou
    .db $03,'[','0','c'
    .dw vt100whatareyou
    .db $01,'Z'
    .dw vt100whatareyou
    .db $01,'c'
    .dw vt100reset
    .db $03,'[','6','n'
    .dw vt100cursorreport
    
    .db $03,'[',$00,'h'         ; ^[[<mode>h set mode
    .dw vt100setmode
    .db $03,'[',$00,'l'         ; ^[[<mode>l reset mode
    .dw vt100resetmode
    
    ; swallowed VT100 commands below
    .db $02,'#',$00             ; ^[#3/^[#4 double height line (DECDHL), ^[#5 single width line (DECSWL), ^[#6 double-width line (DECDWL)
    .dw vt100timefinish
    .db $03,'[',$00,'q'         ; ^[<led>q: LED status
    .dw vt100timefinish
    .db $05,'[',$00,';',$00,'q'
    .dw vt100timefinish
    .db $07,'[',$00,';',$00,';',$00,'q'
    .dw vt100timefinish
    .db $09,'[',$00,';',$00,';',$00,';',$00,'q'
    .dw vt100timefinish
    .db $02,'(','A'             ; ^[(A (SCS): UK character set as G0
    .dw vt100timefinish
    .db $02,')','A'             ; ^[)A (SCS): UK character set as G1
    .dw vt100timefinish
    .db $02,'(','B'             ; ^[(B (SCS): US character set as G0.
    .dw vt100timefinish
    .db $02,')','B'             ; ^[)B (SCS): UK character set as G1
    .dw vt100timefinish
    .db $02,'(',$00             ; ^[(0 special characters and line drawing, ^[(1 alternate ROM, ^[(2 alternate ROM special character set as G0.
    .dw vt100timefinish
    .db $02,')',$00             ; ^[)0 special characters and line drawing, ^[(1 alternate ROM, ^[(2 alternate ROM special character set as G1.
    .dw vt100timefinish
    .db $01,'N'                 ; ^[N single shift 2 (SS2) selects G2 (default) character set for one character.
    .dw vt100timefinish
    .db $01,'O'                 ; ^[O single shift 3 (SS3) selects G3 (default) character set for one character.
    .dw vt100timefinish
    .db $05,'[','2',';',$00,'y' ; ^[2;<test>y (DECTST): Invoke confidence test.
    .dw vt100timefinish
    .db $04,'[','?',$00,'h'     ; ^[[?<mode>h set ANSI-compatible mode
    .dw vt100timefinish
    .db $04,'[','?',$00,'l'     ; ^[[?<mode>l reset ANSI-compatible mode
    .dw vt100timefinish
    .db $01,'='                 ; ^[= enter application keypad mode
    .dw vt100timefinish
    .db $01,'>'                 ; ^[> exit application keypad mode
    .dw vt100timefinish
    
    .db $FF

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Dynamic memory allocated at the end of the program | benryves |
;-----------+----------------------------------------------------+----------+

buffers     = $

term        = buffers + 0
term_s      = 80 * 25

recvbuf     = term + term_s
recvbuf_s   = MAXRECV

fonttable   = recvbuf + recvbuf_s
fonttable_s = 256

buffers_s   = term_s + recvbuf_s + fonttable_s

;-----------+----------------------------------------------------+----------+
; Telnet 83 | Well, that's all folks!                            | Infiniti |
;-----------+----------------------------------------------------+----------+
.end
