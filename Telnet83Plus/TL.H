; TL.H
;
; sendrecv.h MUST contain the following functions:
;
; checkbyte -
;       input: none
;       return: carry flag set if no byte was recieved, otherwise A = byte
;
; send_outbyte -
;       input: A = byte to send
;       return: none
;
#define MAXRECV 2048

recv_init:
        ld      hl, 0
        ld      (recv_start), hl
        ld      (recv_end), hl
        ld      hl, MAXRECV-1
        ld      (recv_free), hl
        ret

check_recv:
        ld      bc, (recv_start)
        ld      hl, (recv_end)
        or      a ; benryves: ensure carry is cleared?
        sbc     hl, bc
        ld      a, 0
        ret     z
        ld      a, 1
        ret

check_send:
        ret
sendbyte:
        call    send_outbyte
        ret

catchup:
        push    af
        push    hl
        
        ; benryves: check if there's any free space in the receive buffer first
        ld      hl, (recv_free)
        ld      a, h
        or      l
        jr      z, catchupnofirst

        call    checkbyte
        jr      c, catchupnofirst

        push    de
        push    bc
        jr      catchupnext

catchuplp:
        call    tryreceivebyte
        jr      c, catchupdone

catchupnext:
        ld      bc, (recv_end)
        ld      hl, recvbuf
        add     hl, bc
        ld      (hl), a
        ld      hl, MAXRECV
        inc     bc
        or      a ; benryves: ensure carry is cleared?
        sbc     hl, bc
        jr      nz, catchup2
        ld      bc, 0
catchup2:
        ld      (recv_end), bc
        
        ; benryves: decrement free space in receive buffer
        ld      hl, (recv_free)
        dec     hl
        ld      (recv_free), hl
        ld      a, h
        or      l
        
        ; benryves: only loop around if there's free space in the buffer
        jr      nz, catchuplp
        jr      catchupdone

catchupnofirst:
        pop     hl
        pop     af
        ret

catchupdone:
        pop     bc
        pop     de
        pop     hl
        pop     af
        ret

recvbyte:
        xor     a
        ld      hl, (recv_start)
        ld      bc, (recv_end)
        sbc     hl, bc
        ret     z

        ld      hl, recvbuf
        ld      bc, (recv_start)
        add     hl, bc
        ld      a, (hl)
        ld      hl, MAXRECV
        inc     bc
        or      a ; benryves: ensure carry is cleared?
        sbc     hl, bc
        jr      nz, recvbyte2
        ld      bc, 0
recvbyte2:
        ld      (recv_start), bc
        
        ; benryves: free up space in buffer
        ld      bc, (recv_free)
        inc     bc
        ld      (recv_free), bc

        ld      b, a
        xor     a
        inc     a
        ld      a, b
        ret

;#define MAXSEND 96

;send_start      .dw     0
;send_end        .dw     0
recv_start      .dw     0
recv_end        .dw     0
recv_free       .dw     0

;sendbuf
;.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
;.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

recvbuf
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.dw     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
