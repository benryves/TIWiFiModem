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
#define ESC     27
NONE            .equ    0
BOLD            .equ    1
UNDERLINE       .equ    4
BLINK           .equ    5
INVERSE         .equ    7

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
        bcall(_EnoughMem)
        jp     c, quittoshell
        
        ; if there is, insert it into the variable
        ex      de, hl
        ld      de, buffers
        bcall(_InsertMem)
        
        ; clear buffers
        ld      a, ' '
        ld      (de), a
        push    de
        pop     hl
        inc     de
        ld      bc, buffers_s - 1
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


        call    buildtable      ; build the font table
        call    recv_init       ; benryves: initialise the receive buffer

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
        bcall(_getcsc)
        
        cp      skYEqu  	    ; [Y=]
        call    z, setlocalecho ; local echo toggle
        
        jr      no_key

no_on_held:

        ; --- check keypad the normal way and respond accordingly ---
      call    catchup         ; *-* LINK CHECK *+*
        bcall(_getcsc)          ;        call    getch
        cp      skGraph         ;        cp      15h
        jp      z, exit         ; quit
        cp      skClear         ;        cp      45h
        call    z, vt100entirescreen
        cp      skZoom          ;        cp      13h
        call    z, jumphome     ; zoom to the left edge [ZOOM] button
        cp      skWindow        ; benryves:
        call    z, jumpcursor   ; bring the cursor into the current [WINDOW]
        cp      skTrace         ;        cp      14h
        call    z, mm_mode_swap ; toggle minimap mode
        cp      skYEqu          ;        cp      11h
        call    z, setwrap      ; toggle the character wrap
        cp      sk2nd           ;        cp      21h
        call    z, set2nd       ; set numeric
        cp      skAlpha         ;        cp      31h
        call    z, setalph      ; set capital
        cp      skMode          ;        cp      22h
        call    z, setmode      ; set extra
        cp      skGraphvar      ;        cp      32h
        call    z, setctrl      ; set ctrl
        
      call    catchup         ; *-* LINK CHECK *+*
        ld      d, a
        ld      a, (shift)
        cp      3
        ld      a, d
        jr      nz, no_vtarrows

        cp      skUp                ;        cp      25h
        call    z, send_vt100_up
        cp      skDown              ;        cp      34h
        call    z, send_vt100_down
        cp      skLeft              ;        cp      24h
        call    z, send_vt100_left
        cp      skRight             ;        cp      26h
        call    z, send_vt100_right
no_vtarrows:
        or      a               ;        cp      0
        jr      z, no_key       ; no key

      call    catchup         ; *-* LINK CHECK *+*
        call    keypad2ascii    ; convert the key into ASCII
      call    catchup         ; *-* LINK CHECK *+*
        or      a               ;        cp      0
        jr      z, no_key       ; key doesn't have an entry
        push    af
        ld      a, 1
        ld      (sendstat), a   ; flag the status bar to indicate send
      call    catchup         ; *-* LINK CHECK *+*
        pop     af
        call    sendbyte        ; chuck it out the window
      call    catchup         ; *-* LINK CHECK *+*
no_key:
        ; --- end ---

        ; --- check for incoming data ---
more_data:
      call    catchup         ; *-* LINK CHECK *+*
        call    recvbyte        ; get a byte from the recv buffer
        or      a               ;       cp      0
        jp      z, no_data      ; it's empty

      call    catchup         ; *-* LINK CHECK *+*
        ld      b, a
        ld      a, (in_seq)
        or      a               ;        cp      0
        ld      a, b
        jp      nz, add2esc     ; continue the current vt100 sequence
        cp      ESC
        jp      z, handle_esc   ; begin tracking a new vt100 sequence
      call    catchup         ; *-* LINK CHECK *+*
        call    putchar         ; display the character
      call    catchup         ; *-* LINK CHECK *+*
        jp      incoming_done

handle_esc:
        ld      a, 1
        ld      (in_seq), a     ; flag that we're in sequence
        ld      hl, seqbuf
        ld      a, ESC
        ld      (hl), a         ; load an ESC character into the sequence
        jp      incoming_done
add2esc:
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
        jp      z, seqoverflow  ; no match or sequence to big?
        cp      2
        call    z, erase_esc    ; perfect match was executed, delete now
        jp      incoming_done

seqoverflow:
      call    catchup         ; *-* LINK CHECK *+*
        call    killesc         ; output the sequence to the screen
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, 0
        ld      (in_seq), a     ; flag out the sequence pointer
        jp      incoming_done

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
        bcall(_DelMem)
        jp      quittoshell

;-----------+----------------------------------------------------+----------+
; Telnet 83 | AppVar helper functions                            | benryves |
;-----------+----------------------------------------------------+----------+

; find the existing appvar and unarchive it if possible
findappvar:
        ; does the appvar exist?
        ld      hl, appvarname
        rst     rMOV9TOOP1
        bcall(_ChkFindSym)
        ret     c
        
appvarexists:
        ; is the appvar in the archive?
        ld      a, b
        or      a
        ret     z

appvararchived:

        ; is there enough free RAM to unarchive it?
        ld      hl, term_s + sdata_s + 256
        bcall(_EnoughMem)
        ret     c
        
        ; unarchive the appvar and search for it again
        bcall(_Arc_Unarc)
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
        bcall(_EnoughMem)
        ret     c
        
        ; create the appvar
        ld      hl, term_s + sdata_s
        bcall(_CreateAppVar)

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
send_vt100_up:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, 'A'
        call    send_vt100_arrow
        pop     af
        ret
        
send_vt100_down:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, 'B'
        call    send_vt100_arrow
        pop     af
        ret
        
send_vt100_left:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, 'D'
        call    send_vt100_arrow
        pop     af
        ret
send_vt100_right:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        ld      a, 'C'
        call    send_vt100_arrow
        pop     af
        ret

send_vt100_arrow:
        push    af
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, ESC
        call    sendbyte
        ld      a, '['
        call    sendbyte
        pop     af
        call    sendbyte
      jp    catchup           ; *-* LINK CHECK *+*

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


set2nd:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (shift)
        cp      1
        jr      z, setshiftOff
        ld      a, 1
        ld      (shift), a
        xor     a           ;        ld      a, 0
        ret
setshiftOff
      call    catchup         ; *-* LINK CHECK *+*
        xor     a               ;        ld      a, 0
        ld      (shift), a
        xor     a               ;        ld      a, 0
        ret
setalph:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (shift)
        cp      2
        jr      z, setshiftOff
        ld      a, 2
        ld      (shift), a
        xor     a               ;        ld      a, 0
        ret
setmode:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (shift)
        cp      3
        jr      z, setshiftOff
        ld      a, 3
        ld      (shift), a
        xor     a               ;        ld      a, 0
        ret
setctrl:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (shift)
        cp      4
        jr      z, setshiftOff
        ld      a, 4
        ld      (shift), a
        xor     a               ;        ld      a, 0
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

setlocalecho:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (local_echo)
        xor     1
        ld      (local_echo), a
        xor a
        ret

putchar:
      call    catchup         ; *-* LINK CHECK *+*
        push    af
        call    cursor_off
        pop     af

        cp      0
        ret     z
        cp      128
        jr      c, putchar_next1
        ld      a, 0
putchar_next1:
      call    catchup         ; *-* LINK CHECK *+*
        cp      10
        jp      z, putnewline
        cp      13
        jp      z, putreturn
        cp      8
        jp      z, putbs
        cp      7
        jp      z, putbeep
        cp      9
        jp      z, puttab

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
        ;cp      128
        ;call    nc, setzero
        ld      (hl), a

        ld      a, (curx)
        inc     a
        ld      (curx), a
      call    catchup         ; *-* LINK CHECK *+*
        jp      cursor_moved

putnewline:
        ld      a, (scr_bot)
        ld      c, a
        ld      a, (pcury)
        cp      c
        jr      nc, putscroll

        inc     a
        ld      (pcury), a
        jp      cursor_moved
putreturn:
        ld      a, 0
        ld      (curx), a
        jp      cursor_moved
putbs:
        ld      a, (curx)
        or      a
        ret     z
        dec     a
        ld      (curx), a
        jp      cursor_moved
putscroll:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (scr_top)
        ld      c, a
        ld      b, 80
        call    mul
        ld      hl, term
        add     hl, bc
        ld      (n), hl

      call    catchup         ; *-* LINK CHECK *+*
        ld      hl, (n)
        ld      bc, 80
        add     hl, bc
        ld      (n2), hl

        ld      de, (n)
        ld      hl, (n2)

        ld      a, (scr_top)
        ld      b, a
        ld      a, (scr_bot)
        sub     b
        ld      b, a
        ld      c, 80
      call    catchup         ; *-* LINK CHECK *+*
        call    mul
      call    catchup         ; *-* LINK CHECK *+*

        ldir

        ;ld      de, term
        ;ld      hl, term + 80
        ;ld      bc, 1920 - 80
        ;ldir

      call    catchup         ; *-* LINK CHECK *+*
        ld      hl, term
        ld      a, (scr_bot)
        ld      b, a
        ld      c, 80
        call    mul
        add     hl, bc
        ld      (n), hl

      call    catchup         ; *-* LINK CHECK *+*
        ld      a, ' '
        ld      de, (n)
        ld      (de), a
        push    de
        pop     hl
        inc     de
        ld      bc, 80 - 1
        ldir

      call    catchup         ; *-* LINK CHECK *+*
        ;ld      de, term + 1920 - 80
        ;ld      hl, whitespace
        ;ld      bc, 80
        ;ldir
        ret
putcr:
      call    catchup         ; *-* LINK CHECK *+*
        call    putreturn
      call    catchup         ; *-* LINK CHECK *+*
        call    putnewline
      call    catchup         ; *-* LINK CHECK *+*
        ret
setzero:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, 0
        ret

putbeep:
      call    catchup         ; *-* LINK CHECK *+*
        ld      hl, 768
        ld      ix, GRAPH_MEM
        ld      bc, 0
xorlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (ix)
        xor     0ffh
        ld      (ix), a
        inc     ix
        dec     hl
        sbc     hl, bc
        cp      0
        jr      nz, xorlp
      call    catchup         ; *-* LINK CHECK *+*
        call    zap
      call    catchup         ; *-* LINK CHECK *+*
        ret

puttab:
        ld      a, (curx)
        cp      79
        ret     z
tablp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      b, a
        sub     8
        jr      nc, tablp

        ld      a, 8
        sub     b
        ld      b, a
        ld      a, (curx)
        add     a, b
        cp      80
        call    nc, fixtab
        ld      (curx), a
      call    catchup         ; *-* LINK CHECK *+*
        jp      cursor_moved
fixtab:
        ld      a, 79
      call    catchup         ; *-* LINK CHECK *+*
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
        cp      0
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
        ld      a, (local_echo)
        or      a
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
        cp      1
        ret     z
      call    catchup         ; *-* LINK CHECK *+*
        call    getxy
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (hl)
        ld      (curshad), a
        ld      a, 0
        ld      (hl), a
        ld      a, 1
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
        ld      a, 0
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
        ld      ix, vt100table
check_mainlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (ix)
        ld      b, a
        cp      255
        jr      z, check_done_nomatch
        push    bc
        push    ix
      call    catchup         ; *-* LINK CHECK *+*
        call    check_seqn
      call    catchup         ; *-* LINK CHECK *+*
        pop     ix
        pop     bc

        cp      1
        jp      z, check_done_partial
        cp      2
        jp      z, check_done_executed
        ld      a, b
        inc     a
        ld      c, a
        ld      b, 0
        add     ix, bc
        inc     ix
        inc     ix
        jp      check_mainlp

check_done_nomatch:
        ld      a, 0
        ret
check_done_partial:
        ld      a, 1
        ret
check_done_executed:
        ld      a, 2
        ret

check_seqn:
        ld      hl, seqbuf+1
        ld      a, 0
        ld      (check_partial), a
        ld      a, (ix)
        ld      b, a
        ld      a, (in_seq)
        dec     a
        cp      b
        call    c, check_resize
        inc     ix
check_seqlp:
      call    catchup         ; *-* LINK CHECK *+*
        push    bc
        ld      a, (ix)
        cp      0
        jr      z, check_digit
        jr      check_norm
check_digit:
        ld      a, (hl)
        sub     '0'
        jr      c, check_bad
        ld      a, (hl)
        sub     '9'+1
        jr      nc, check_bad
        jr      check_ok

check_norm:
        ld      b, a
        ld      a, (hl)
        cp      b
        jr      nz, check_bad
        jr      check_ok

check_ok:
        inc     hl
        inc     ix
        pop     bc
        djnz    check_seqlp

        ld      a, (check_partial)
        cp      1
        ret     z

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
        pop     bc
        ld      a, 0
        ret

check_resize:
        ld      b, a
        ld      a, 1
        ld      (check_partial), a
        ret


;-----------+----------------------------------------------------+----------+
; Telnet 83 | VT100 escape sequences                             | Infiniti |
;-----------+----------------------------------------------------+----------+
;i've never had more fun programming...

vt100cursorleftpress:
        ld      b, 1
        jr      vtcurleft
vt100cursorleft:
        call    getparam
        jr      vtcurleft
vt100cursorleftlots:
        call    getparam2
vtcurleft:
        ld      a, (curx)
        sub     b
        call    under0
        ld      (curx), a
        jp      cursor_moved

vt100cursorrightpress:
        ld      b, 1
        jr      vtcurright
vt100cursorright:
        call    getparam
        jr      vtcurright
vt100cursorrightlots:
        call    getparam2
vtcurright:
        ld      a, (wrap)
        dec     a
        ld      c, a
        ld      a, (curx)
        add     a, b
        call    over_c
        ld      (curx), a
        jp      cursor_moved

vt100cursoruppress:
        ld      b, 1
        jr      vtcurup
vt100cursorup:
        call    getparam
        jr      vtcurup
vt100cursoruplots:
        call    getparam2
vtcurup:
        ld      a, (pcury)
        sub     b
        call    under0
        ld      (pcury), a
        jp      cursor_moved

vt100cursordownpress:
        ld      b, 1
        jr      vtcurdown
vt100cursordown:
        call    getparam
        jr      vtcurdown
vt100cursordownlots:
        call    getparam2
vtcurdown:
        ld      c, 25-1
        ld      a, (pcury)
        add     a, b
        call    over_c
        ld      (pcury), a
        jp      cursor_moved

vt100cursorreset:
        ld      c, 1
        ld      b, 1
        jr      vt_gotoxy
vt100changecursor:
        call    getparam
        ld      a, b
        ld      c, a
        inc     hl
        call    getparam
        jr      vt_gotoxy
vt100changeud:
        call    getparam2
        ld      a, b
        ld      c, a
        inc     hl
        call    getparam
        jr      vt_gotoxy
vt100changelr:
        call    getparam
        ld      a, b
        ld      c, a
        inc     hl
        call    getparam2
        jr      vt_gotoxy
vt100changeudlr:
        call    getparam2
        ld      a, b
        ld      c, a
        inc     hl
        call    getparam2
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

vt100entirescreen:
        call    cursor_off
        ld      hl, term
        ld      bc, 2000
vtclearlp:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, ' '
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a, b
        or      c
        jr      nz, vtclearlp
        xor     a
        ld      (curx), a
        ld      (pcury), a ; benryves: was (cury)
        jp      cursor_moved

vt100erasebegcursor:
vt100erasecursorend:
;vt100erasecursorend:
        ret

vt100setscrolling:
        call    getparam
        dec     a
        cp      24
        ret     nc
        ld      (n), a
        inc     hl
        call    getparam
        dec     a
        cp      24
        ret     nc
        ld      (n2), a
        jp      vt100ss1
vt100setscrollingb:
        call    getparam
        dec     a
        cp      24
        ret     nc
        ld      (n), a
        inc     hl
        call    getparam2
        dec     a
        cp      24
        ret     nc
        ld      (n2), a
        jp      vt100ss1
vt100setscrollingt:
        call    getparam2
        dec     a
        cp      24
        ret     nc
        ld      (n), a
        inc     hl
        call    getparam
        dec     a
        cp      24
        ret     nc
        ld      (n2), a
        jp      vt100ss1
vt100setscrollingtb:
        call    getparam2
        dec     a
        cp      24
        ret     nc
        ld      (n), a
        inc     hl
        call    getparam2
        dec     a
        cp      24
        ret     nc
        ld      (n2), a
        jp      vt100ss1
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
        ret

vt100storecoords:
vt100restorecoords:
vt100index:
vt100reverseindex:
vt100nextline:
vt100eraseline:
        ret

vt100eraseendline:
        call    getxy
        ld      a, (curx)
        ld      b, a
        ld      a, 80
        sub     b
        cp      0
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

;vt100eraseendline:
vt100erasecursor:
        ret

vt100cursorstyle0:
        xor     a
        ld      (curattr), a
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
        jr      nz, vt100combinecursorstyle
        ld      (curattr), a
        ret
vt100combinecursorstyle:
        ld      a, 1
vt100cursorstylebits:
        add     a, a
        djnz    vt100cursorstylebits
        ld      b, a
        ld      a, (curattr)
        or      b
        ld      (curattr), a
        ret

vt100settab:
vt100cleartab:
;vt100cleartab:
vt100clearalltabs:
vt100statusrep:
vt100whatareyou:
;vt100whatareyou:
vt100reset:
vt100cursorreport:

vt100timefinish:
        ret

vt102localechooff:
        xor    a
        ld      (local_echo), a
        ret

vt102localechoon:
        ld      a, 1
        ld      (local_echo), a
        ret

getparam:
      call    catchup         ; *-* LINK CHECK *+*
        ld      a, (hl)
        inc     hl
        sub     '0'
        ld      b, a
        ret

getparam2:
      call    catchup         ; *-* LINK CHECK *+*
        push    bc
        ld      a, (hl)
        inc     hl
        sub     '0'
        ;slr     a
        ld      c, a
        ld      b, 9
getparam2lp:
        add     a, c
        djnz    getparam2lp
        ld      c, a
        ld      a, (hl)
        inc     hl
        sub     '0'
        add     a, c
        pop     bc
        ld      b, a
      call    catchup         ; *-* LINK CHECK *+*
        ret

under1:
        jr      c, under1fix
        jr      z, under1fix
        ret
under1fix:
        ld      a, 1
        ret

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

        .db 0,0,0,0                 ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13,34,"wrmh",0          ;9-F, enter, quote, wrmh, clear
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
        .db 0,0,0,0                 ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13,"+-*/^",0            ;9-F, enter, +-*/^, clear
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
        .db 0,0,0,0                 ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db 13,39,"WRMH",0          ;9-F, enter, quote, wrmh, clear
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
        .db 0,0,0,0                 ;1-4, arrows
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
        .db 0,0,0,0                 ;1-4, arrows
        .db 0,0,0,0                 ;5-8, unused
        .db "=",29,23,18,13,8,0     ;9-F
        .db 0                       ;10, unused
        .db "?",27,22,17,12,7,7     ;11-17
        .db 0                       ;18, unused
        .db ";".26,21,16,11,6,3,27  ;19-20
        .db ")",25,20,15,10,5,2,0   ;21-28
        .db 0                       ;29, unused
        .db 24,19,14,9,4,1,0        ;2A-30
        .db 0,0,0,0,0               ;31-35, graph, trace, zoom, window, y=
        .db 0,0,127                 ;36-38, 2nd, mode, del

;        .db   0,  0,  0,  0,  0        .db   0,  0,127,  0,  0
;        .db   0,  0, 27,  0,  0        .db   1,  2,  3,  7,  0
;        .db   4,  5,  6,  7,  8        .db   9, 10, 11, 12, 13
;        .db  14, 15, 16, 17, 18        .db  19, 20, 21, 22, 23
;        .db  24, 25, 26, 27, 29        .db   0,')',';','?','='


_blackstamp     .db 255,255,255,255,255,255,255,255

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
sx          = pcury + 1         ; .db     0       ; - Screen position (in characters)
sy          = sx + 1            ; .db     0       ; /

scr_top     = sy + 1            ; .db     0       ; top of scrolling region
scr_bot     = scr_top + 1       ; .db     23      ; bottom of scrolling region

curattr     = scr_bot + 1       ; .db     0       ; cursor attributes (bold, inverse, etc)

mm_mode     = curattr + 1       ; .db     1       ; show minimap never (0), manually scrolled (1), auto scrolled (2)

local_echo  = mm_mode + 1       ; .db     0

sdata_end   = local_echo + 1
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
in_seq      = seqbuf + 20       ; .db     0
;scurx   .db     0
;scury   .db     0

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
    .db $04,'[',$00,$00,'D'
    .dw vt100cursorleftlots
    .db $03,'[',$00,'D'
    .dw vt100cursorleft
    .db $02,'[','D'
    .dw vt100cursorleftpress
    .db $03,'[',$00,'C'
    .dw vt100cursorright
    .db $04,'[',$00,$00,'C'
    .dw vt100cursorrightlots
    .db $02,'[','C'
    .dw vt100cursorrightpress
    .db $03,'[',$00,'A'
    .dw vt100cursorup
    .db $04,'[',$00,$00,'A'
    .dw vt100cursoruplots
    .db $02,'[','A'
    .dw vt100cursoruppress
    .db $03,'[',$00,'B'
    .dw vt100cursordown
    .db $04,'[',$00,$00,'B'
    .dw vt100cursordownlots
    .db $02,'[','B'
    .dw vt100cursordownpress

    .db $02,'[','H'
    .dw vt100cursorreset
    .db $03,'[',';','H'
    .dw vt100cursorreset
    .db $05,'[',$00,';',$00,'H'
    .dw vt100changecursor
    .db $06,'[',$00,$00,';',$00,'H'
    .dw vt100changeud
    .db $06,'[',$00,';',$00,$00,'H'
    .dw vt100changelr
    .db $07,'[',$00,$00,';',$00,$00,'H'
    .dw vt100changeudlr
    .db $05,'[',$00,';',$00,'f'
    .dw vt100changecursor
    .db $06,'[',$00,$00,';',$00,'f'
    .dw vt100changeud
    .db $06,'[',$00,';',$00,$00,'f'
    .dw vt100changelr
    .db $07,'[',$00,$00,';',$00,$00,'f'
    .dw vt100changeudlr

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
    .db $06,'[',$00,';',$00,$00,'r'
    .dw vt100setscrollingb
    .db $06,'[',$00,$00,';',$00,'r'
    .dw vt100setscrollingt
    .db $07,'[',$00,$00,';',$00,$00,'r'
    .dw vt100setscrollingtb

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
    .db $02,'[','m'
    .dw vt100cursorstyle0                       ;vt100cursorstyle
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
    .db $01,'c'
    .dw vt100reset
    .db $03,'[','6','n'
    .dw vt100cursorreport

    ; benryves: VT102 extensions
    .db $04,'[','1','2','h'
    .dw vt102localechooff
    .db $04,'[','1','2','l'
    .dw vt102localechoon

    .db $02,'#',$00             ;this accounts for vt100 commands impossible on 85
    .dw vt100timefinish         ;this label just jumps them back to the end of vt100
    .db $03,'[',$00,'q'
    .dw vt100timefinish
    .db $05,'[',$00,';',$00,'q'
    .dw vt100timefinish
    .db $07,'[',$00,';',$00,';',$00,'q'
    .dw vt100timefinish
    .db $09,'[',$00,';',$00,';',$00,';',$00,'q'
    .dw vt100timefinish
    .db $02,'(','A'
    .dw vt100timefinish
    .db $02,')','A'
    .dw vt100timefinish
    .db $02,'(','B'
    .dw vt100timefinish
    .db $02,')','B'
    .dw vt100timefinish
    .db $02,'(',$00
    .dw vt100timefinish
    .db $02,')',$00
    .dw vt100timefinish
    .db $01,'O'
    .dw vt100timefinish
    .db $01,'N'
    .dw vt100timefinish
    .db $05,'[','2',';',$00,'y'
    .dw vt100timefinish
    .db $03,'[',$00,'h'
    .dw vt100timefinish
    .db $03,'[',$00,'l'
    .dw vt100timefinish
    .db $04,'[',$00,$00,'h'
    .dw vt100timefinish
    .db $04,'[',$00,$00,'l'
    .dw vt100timefinish
    .db $04,'[','?',$00,'h'
    .dw vt100timefinish
    .db $04,'[','?',$00,'l'
    .dw vt100timefinish
    .db $05,'[','?',$00,$00,'h'
    .dw vt100timefinish
    .db $05,'[','?',$00,$00,'l'
    .dw vt100timefinish
    .db $01,'='
    .dw vt100timefinish
    .db $01,'>'
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
