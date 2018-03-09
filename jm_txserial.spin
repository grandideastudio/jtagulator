'' =================================================================================================
''
''   File....... jm_txserial.spin
''   Purpose.... True mode serial transmit driver -- with buffer
''   Author..... Jon "JonnyMac" McPhalen (aka Jon Williams)
''               Copyright (c) 2009 Jon McPhalen
''               -- some elements "borrowed" from fullduplexserial and simple_serial
''               -- see below for terms of use
''   E-mail..... jon@jonmcphalen.com
''   Started.... 
''   Updated.... 16 JUL 2009
''
'' =================================================================================================

'' Modified by Joe Grand 3/9/18, changed from 2 stop bits to 1 stop bit


var

  long  cog

  word  txHead                                                  ' head pointer (0..255)
  word  txTail                                                  ' tail pointer (0..255)
  byte  txBuf[256]                                              ' transmit buffer 


pub init(txd, baud) : okay

'' Creates true mode transmit UART on pin txd at baud rate

  cleanup                                                       ' stop cog if running
  flush                                                         ' clear buffer

  txmask   := 1 << txd                                          ' set tx cog vars 
  bitticks := clkfreq / baud 
  headpntr := @txHead 
  tailpntr := @txTail 
  bufpntr  := @txBuf  

  okay := cog := cognew(@txserial, 0) + 1     


pub cleanup

'' Stops serial TX driver; frees a cog

  if cog
    cogstop(cog~ - 1)


pub tx(c)

'' Move c into transmit buffer if room is available
'' -- will wait if buffer is full

  repeat until (txTail <> ((txHead + 1) & $FF))
  txBuf[txHead] := c
  txHead := (txHead + 1) & $FF


pub str(pntr)

'' Transmit z-string at pntr

  repeat strsize(pntr)
    tx(byte[pntr++])
    

pub dec(value) | i

'' Print a decimal number

  if value < 0
    -value
    tx("-")

  i := 1_000_000_000

  repeat 10
    if value => i
      tx(value / i + "0")
      value //= i
      result~~
    elseif result or i == 1
      tx("0")
    i /= 10


pub hex(value, digits)

'' Print a hexadecimal number

  value <<= (8 - digits) << 2
  repeat digits
    tx(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))


pub bin(value, digits)

'' Print a binary number

  value <<= (32 - digits)
  repeat digits
    tx((value <-= 1) & 1 + "0")       


pub flush

'' Flushes TX buffer

  longfill(@txHead, 0, 65)                                     ' clear pointers (1) and buffer (64)
  

dat

                        org     0

txserial                mov     outa, txmask                    ' set to idle (true mode)
                        mov     dira, txmask                    ' make output                

waitbuf                 rdword  tmp1, headpntr                  ' tmp1 = txHead
                        rdword  tmp2, tailpntr                  ' tmp2 = txTail
                        cmp     tmp1, tmp2              wz      ' equal?
                if_e    jmp     #waitbuf                        ' if yes, keep waiting

gettail                 mov     tmp1, bufpntr                   ' tmp1 := @txbuf[0]
                        add     tmp1, tmp2                      ' tmp1 := @txbuf[txTail]
                        rdbyte  txwork, tmp1                    ' txWork := txbuf[txTail] 

updatetail              add     tmp2, #1                        ' inc txTail
                        and     tmp2, #$FF                      ' wrap to 0 if necessary
                        wrword  tmp2, tailpntr                  ' save

transmit                or      txwork, STOP_BITS               ' set stop bit(s)
                        shl     txwork, #1                      ' add start bit
                        mov     txcount, #10                    ' start + 8 data + 1 stop 
                        mov     txtimer, bitticks               ' load bit timing
                        add     txtimer, cnt                    ' sync with system counter

txbit                   shr     txwork, #1              wc      ' move bit0 to C
                        muxc    outa, txmask                    ' output the bit
                        waitcnt txtimer, bitticks               ' let timer expire, reload   
                        djnz    txcount, #txbit                 ' update bit count

                        jmp     #waitbuf  

' -------------------------------------------------------------------------------------------------

STOP_BITS               long    $FFFF_FF00  

txmask                  long    0-0                             ' mask for tx pin
bitticks                long    0-0                             ' ticks per bit
headpntr                long    0-0                             ' pointer to head position
tailpntr                long    0-0                             ' pointer to tail position
bufpntr                 long    0-0                             ' pointer to txBuf[0]

txwork                  res     1                               ' byte to transmit
txcount                 res     1                               ' bits to transmit
txtimer                 res     1                               ' tx bit timer

tmp1                    res     1
tmp2                    res     1  
                                 
                        fit     492
                        

dat

{{

  Copyright (c) 2009 Jon McPhalen (aka Jon Williams)

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}                    