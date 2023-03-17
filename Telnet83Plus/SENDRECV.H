;stime   .db     255
;stimeout:
;        ld      a, (stime)
;        dec     a
;        ld      (stime), a
;        ret

#define LINKPORT 0
;#define LINKMASK 12
#define	LINKMASK	3
#define		D0LD1L	3	;values for port 
#define		D0LD1H	1
#define 		D0HD1L	2
#define		D0HD1H	0

checkbyte:
TryReceiveByte:
        in a,(LINKPORT)
        and LINKMASK
        cp LINKMASK
        scf
        ret z
ReceiveByteCont:
        call LinkPrep
        jr ReceiveCont
ReceiveByte:
        call LinkPrep
ReceiveBits:
        ld de,-1
WaitRecBit:
        call CheckLink
        jr z,LinkFailed
        cp LINKMASK
        jr z,WaitRecBit
ReceiveCont:
        sub (LINKMASK/3)*2  ; benryves: parens added to fix order of operations bug in assembler
        ld a,(LINKMASK/3)*2 ; 
        ld d,D0LD1H
        jr c,ReceiveLow
        rra
        ld d,D0HD1L
ReceiveLow:
        rr c
        ld (AckBit),a
        ld a,d
        out (LINKPORT),a
        ld de,-1
WaitAckRec:
        call CheckLink
        cp 0
AckBit =$-1
        jr nz,WaitAckRec
        ld a,D0HD1H
        out (LINKPORT),a
        ld d,4
WaitReadyRec:
        dec d
        jr z,ReadyRec
        in a,(LINKPORT)
        cp LINKMASK
        jr nz,WaitReadyRec
ReadyRec:
        djnz ReceiveBits
        jr LinkSuccess


LinkPrep:
        ex (sp),hl
        push bc
        push de
        set 2,(iy+12h)
        ld b,8
        jp (hl)

send_outbyte:
;SendByte:
        call LinkPrep
        ld c,a
        ;ld a, 255
        ;ld (stime), a
SendBits:
        rr c
        ld a,D0LD1H
        jr nc,SendLow
        ld a,D0HD1L
SendLow:
        out (LINKPORT),a
        ld de,-1
WaitAckSend:
        call CheckLink
        jr nz,WaitAckSend
SendAcked:
        ld a,D0HD1H
        out (LINKPORT),a
        ld de,-1
WaitReadySend:
        call CheckLink
        cp LINKMASK
        jr nz,WaitReadySend
        djnz SendBits
LinkSuccess:

        or 0
.org $-1
LinkFailed:
        scf
        res 2,(iy+12h)
;#ifdef TI83
	ld	a,D0HD1H		;        ld a,0D0h
        out (0),a
;#endif
        ld a,c
        pop de
        pop bc
        pop hl
        ret

CheckLink:
        pop hl
        dec de
        ld a,d
        or e
        jr z,LinkFailed
        ld a,0BFh
        ;call stimeout
        ;cp      0
        ;call  _readkeypad
        ;bit 6,a
        ;jr z,LinkFailed
        in a,(LINKPORT)
        and LINKMASK
        jp (hl)
