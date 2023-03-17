;кФФФФФФФФФФФФФФФФТФФФФФФФФФФФФФФФФТФФФФФФФФФФФФФФФФФФФФФТФФФФФФФТФФФФФФФФФФФФП
;Гллллл Z80 ллллллГ    Sprite83    ГлллллллллллллллллллллГ movax ГллллллллллллГ
;РФФФФФФФФФФФФФФФФСФФФФФФФФФФФФФФФФСФФФФФФФФФФФФФФФФФФФФФСФФФФФФФСФФФФФФФФФФФФй

; Sprite xor routine v1.0
; Coded by Hannes Edfeldt in 1997

; This routine uses xor to draw the sprite, therefore you can erase the sprite
; by just drawing it again at the same x and y coordinates. See xordemo.z80
; for an example of how to use this routine.

; Feel free to use this routine in your own productions as long as you give me
; some credit.

; This file should of course be viewed in a DOS texteditor ;)

; Hannes Edfeldt -+- movax@algonet.se -+- http://www.algonet.se/~movax


;мллллллллллллп SPRXOR пллллллллллллллллллллллллллллллллллллллллллллллллллллллл
;кФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФП
;Г Xor 8x8 sprite ў a=x, e=y, bc=sprite address                               Г
;РФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФФй
SPRXOR:

        push    bc              ; Save sprite address

;лллл   Calculate the address in graphbuf   лллл

        ld      hl,0            ; Do y*12
        ld      d,0
        add     hl,de
        add     hl,de
        add     hl,de
        add     hl,hl
        add     hl,hl

        ld      d,0             ; Do x/8
        ld      e,a
        srl     e
        srl     e
        srl     e
        add     hl,de

        ld      de,plotsscreen
        add     hl,de           ; Add address to graphbuf

        ld      b,00000111b     ; Get the remainder of x/8
        and     b
        cp      0               ; Is this sprite aligned to 8*n,y?
        jp      z,XALIGN


;лллл   Non aligned sprite blit starts here   лллл

        pop     ix              ; ix->sprite
        ld      d,a             ; d=how many bits to shift each line

        ld      e,8             ; Line loop
XLILOP:  ld      b,(ix+0)        ; Get sprite data

        ld      c,0             ; Shift loop
        push    de
XSHLOP:  srl     b
        rr      c
        dec     d
        jp      nz,XSHLOP
        pop     de

        ld      a,b             ; Write line to graphbuf
        xor     (hl)
        ld      (hl),a
        inc     hl
        ld      a,c
        xor     (hl)
        ld      (hl),a

        ld      bc,11           ; Calculate next line address
        add     hl,bc
        inc     ix              ; Inc spritepointer

      call    catchup
        dec     e
        jp      nz,XLILOP        ; Next line

        jp      XDONE1


;лллл   Aligned sprite blit starts here   лллл

XALIGN:                          ; Blit an aligned sprite to graphbuf
        pop     de              ; de->sprite
        ld      b,8
XALOP1:  ld      a,(de)
        xor     (hl)
        ld      (hl),a
        inc     de
        push    bc
        ld      bc,12
        add     hl,bc
        pop     bc
      call      catchup
        djnz    XALOP1

XDONE1:
        ret
;мллллллллллллм SPRXOR мллллллллллллллллллллллллллллллллллллллллллллллллллллллл


;кФФФФФФФФФФФФФФФФТФФФФФФФФФФФФФФФФТФФФФФФФФФФФФФФФФФФФФФТФФФФФФФТФФФФФФФФФФФФП
;Гллллл Z80 ллллллГ    Sprite83    ГлллллллллллллллллллллГ movax ГллллллллллллГ
;РФФФФФФФФФФФФФФФФСФФФФФФФФФФФФФФФФСФФФФФФФФФФФФФФФФФФФФФСФФФФФФФСФФФФФФФФФФФФй
