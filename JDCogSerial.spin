{{
JDCogSerial.spin :
  V08.07.01 - Initial Release
  V09.01.10 - Added MIT license for OBEX
  v09.03.19 - Fixed some bugs in the spin code
      
It has the following features:
1) The buffer memory is in the cog! The buffers have been set to use the
   maximum amount of cog space. They may be easily changed - see the CON
   section. There are over 1300 bytes of buffer space available.
2) The VAR footprint is tiny - only 6 longs!!!
3) In only supports FullDuplexSerial mode %0000.
4) It supports standard baud rates up to 230400 and non-standard up to above
   345600 (345600 = 115200 * 3).
5) The nature of the object allows easy use of the object from other
   modules. For Example:
   --------------------------------------------------------------------
     JDCogSerialDemo.spin                                              
   --------------------------------------------------------------------
   CON                                                                 
     _clkmode      = xtal1 + pll16x                                    
     _xinfreq      = 5_000_000
                                                                                                                     |
     BaudRate      = 38400                                             
     RxPin         = |<31                                              
     TxPin         = |<30                                              
                                                                       
   OBJ                                                                 
     Comms : "JDCogSerial"                                             
     Sub : "SubObject"                                                 
                                                                       
   VAR                                                                 
     long CommPtr                                                      
                                                                       
   PUB Start                                                           
     CommPtr := Comms.start(RxPin, TxPin, BaudRate)                    
     if CommPtr then                                                   
       Sub.Init(CommPtr)                                               
       Sub.SendGreeting
                                        
   --------------------------------------------------------------------
     SubObject.spin                                                    
   --------------------------------------------------------------------
   VAR                                                                 
     long RxPtr, TxPtr                                                 
                                                                       
   PUB Init(CommPtr)                                                   
     RxPtr := CommPtr                                                  
     TxPtr := CommPtr + 4                                              
                                                                       
   PUB Rx : RxByte                                                     
     repeat while (RxByte := long[RxPtr]) < 0                          
     long[RxPtr] := -1                                                 
                                                                       
   PUB Tx(TxByte)                                                      
     repeat while long[TxPtr] => 0                                     
     long[TxPtr] := TxByte                                             
                                                                       
   PUB Str(StringPtr)                                                  
     repeat strsize(StringPtr)                                         
       Tx(byte[StringPtr++])                                           
                                                                       
   PUB SendGreeting                                                    
     Str(string("Hello",13,10))
                                             
   --------------------------------------------------------------------
     Read and Write a byte using PASM                 
   --------------------------------------------------------------------
   ' Receive a byte into rx                                            
   aRx      rdlong  rx,RxPtr        'Check the receiver                                   
            shl     rx,#1  WC       'Carry set if no byte available       
     if_c   jmp     #aRx            'Wait for a byte to be received                                   
            wrlong  MinusOne,RxPtr  'Mark the byte as having been read                                     
            ...
   RxPtr    long    0               'Initialized in spin or at cog start                                                           
   rx       long    0
   MinusOne long    -1
                      
                                                                       
   ' Transmit a byte from tx, also need a temporary variable         
   aTx      rdlong  temp,TxPtr      'Check the transmitter                                   
            shl     temp,#1  WC     'Carry set if transmitter is idle     
     if_nc  jmp     #aTx            'Wait til the transmitter is idle                                   
            wrlong  tx,TxPtr        'Write the byte into the transmitter                                   
            ...                                                        
   TxPtr    long    0               'Initialized in spin or at cog start                                                           
   tx       long    0                                                  
   temp     long    0
   --------------------------------------------------------------------
}}


CON                                                                     
' The buffer sizes may be freely adjusted. As long as the code still compiles
' to fit into the cog. The sizes are currently at their maximum. The sizes are
' number of longs, so the number of bytes stored is four times as many!

  RX1FIFO_SIZE = 167    '668 bytes
  TX1FIFO_SIZE = 168    '672 bytes
                                               
VAR
  long cog                             'cog flag/id

  long rx1_buf                         '5 longs
  long tx1_buf
  long rx1_mask
  long tx1_mask
  long baud1_ticks

PUB Start(rxpin, txpin, baudrate) : addr
{{
  +---------------------------------------------------------------------+
  |Purpose:                                                             |
  |  Start a single port serial driver - uses a single cog.             |
  +---------------------------------------------------------------------+           
  |Inputs:                                                              |
  |  rxpin and txpin are passed in as pin masks. The transmitter        |
  |    may be disabled by passing in a mask of 0. The receiver may be   |
  |    disabled by simply ignoring it.                                  |
  |  baudrate etc Is passed in as the desired baudrate. The transmit    |
  |    / receive pair operate at the same baudrate.                     |
  +---------------------------------------------------------------------+           
  |Output:                                                              |
  |  Returns the address of the shared memory space if a cog was        |
  |  successfully started, or 0 if no cog available.                    |
  +---------------------------------------------------------------------+
}}
  Stop
  rx1_buf     := -1                    'Set receiver to idle
  tx1_buf     := -1                    'Set transmitter to idle
  rx1_mask    := rxpin                 'Set receive pin
  tx1_mask    := txpin                 'Set transmit pin
  baud1_ticks := CLKFREQ / baudrate    'Set baudrate
  cog := cognew(@entry, @rx1_buf) + 1  'Start the cog
  if cog
    addr := @rx1_buf

PUB Stop
{{ Stop serial driver - frees the cog that was used }}
  if cog
    cogstop(cog~ - 1)

PUB rxflush
{ Flush receive buffer }
  repeat until rxcheck < 0

PUB rxcheck : rxbyte
{ Check if byte received (never waits)
  returns < 0 if no byte received, $00..$FF if byte }
  if (rxbyte := rx1_buf) => 0
    rx1_buf := -1

PUB rxtime(ms) : rxbyte | t
{ Wait ms milliseconds for a byte to be received
  returns -1 if no byte received, $00..$FF if byte }
  t := cnt
  repeat until (rxbyte := rxcheck) => 0 or (cnt - t) / (clkfreq / 1000) > ms

PUB rx : rxbyte
{ Receive byte (may wait for byte)
  returns $00..$FF }
  repeat while (rxbyte := rx1_buf) < 0
  rx1_buf := -1

PUB tx(txbyte)
{ Send byte (may wait for room in buffer) }
  repeat while tx1_buf => 0
  tx1_buf := txbyte

PUB str(stringptr)
{ Send a string }
  repeat strsize(stringptr)
    tx(byte[stringptr++])

PUB strmax(stringptr, maxcount)
{{Send maxcount characters of a string.
  Parameter:
    stringptr - pointer to a string to send.
    maxcount - number of characters to send from string pointer.}}
  repeat maxcount
    tx(byte[stringptr++])

DAT
                    ORG     0
'
' Initialisation. 
'
entry               mov     t1,PAR
                    mov     t2,#5
:en1                mov     rx1ptr,t1
                    add     :en1,c512
                    add     t1,#4
                    djnz    t2,#:en1
                    mov     t2,#3
:en2                rdlong  rx1mask,rx1mask
                    add     :en2,c513
                    djnz    t2,#:en2
                    or      OUTA,tx1mask
                    or      DIRA,tx1mask
                    jmp     dRx1

c512                long    512
c513                long    513
                    
rx1ptr              long    0    
tx1ptr              long    0 
rx1mask             long    0
tx1mask             long    0
baud1               long    0
'
' Receiver 
'
aRx1_Start          mov     rx1bits,#9          '# of bits to receive
                    mov     rx1cnt,baud1
                    shr     rx1cnt,#2           'quarter of a bit tick ...
                    add     rx1cnt,baud1        '... plus a full bit tick
                    mov     dRx1,#aRx1_Wait
                    
aRx1_Wait           test    rx1mask, INA  WC    'Wait for start bit
    if_c            jmp     #aRx1_Get                                 
                    add     rx1cnt, CNT
                    mov     dRx1,#aRx1_Bits
                    
aRx1_Bits           mov     t1,rx1cnt           'Check if bit receive period done
                    sub     t1,cnt
                    cmps    t1,#0         WC    'Time to sample yet?
    if_nc           jmp     #aRx1_Get
                    test    rx1mask, INA  WC    'Receive bit into carry
                    rcr     rx1data,#1          'Carry into Rx buffer
                    add     rx1cnt,baud1        'Go to next bit period
                    djnz    rx1bits,#aRx1_Bits  'Get next bit
    if_nc           jmp     #aRx1_Start
                    and     rx1data,cRxAnd      'Mask out the unwanted bits
                    rol     rx1data,rx1rol      'Put the data into the correct byte
                    mov     dRx1,#aRx1_Put
                    jmp     dTx1                'Go do some transmitter code

                    'General variables for the receiver
cRxAnd              long    %0111_1111_1000_0000_0000_0000_0000_0000
rx1len              long    0
rx1maxlen           long    (tx1fifo - rx1fifo - 1) * 4
dRx1                long    aRx1_Start
                    'Variables used to receive a byte into the FIFO
rx1data             long    0
rx1bits             long    0
rx1cnt              long    0
rx1rol              long    9
rx1out              long    0
rx1put              long    rx1fifo
rx1putb             long    $80
                    'Variables used to grab a byte from the FIFO
rx1ror              long    0                    
rx1get              long    rx1fifo
rx1getb             long    $80

aRx1_Put            cmp     rx1len,rx1maxlen  WZ
    if_z            jmp     #(aRx1_Get+2)
                    mov     dRx1,#aRx1_Start
                    add     rx1len,#1
                    or      rx1out,rx1data      'Merge in the new data byte
arp1                mov     rx1fifo,rx1out      'Write to the FIFO memory
                    add     rx1rol,#8           'Prapare for the next byte
                    rol     rx1putb,#8  WC      'C true every 4 cycles
    if_nc           jmp     dTx1
                    add     rx1put,#1
                    cmp     rx1put,#tx1fifo   WZ
    if_z            mov     rx1put,#rx1fifo
                    movd    arp1,rx1put         'Set the new FIFO destination 
                    mov     rx1out,#0
                    jmp     dTx1

aRx1_Get            cmp     rx1len,#0  WZ
    if_z            jmp     dTx1
                    rdlong  t1,rx1ptr
                    shl     t1,#1    WC         'Is the receive buffer empty?
    if_nc           jmp     dTx1                'Jump if not
                    sub     rx1len,#1
arg1                mov     t1,rx1fifo
                    ror     t1,rx1ror
                    and     t1,#$ff
                    wrlong  t1,rx1ptr 
                    add     rx1ror,#8
                    rol     rx1getb,#8  WC      'C true every 4 cycles
    if_nc           jmp     dTx1
                    add     rx1get,#1
                    cmp     rx1get,#tx1fifo  WZ
    if_z            mov     rx1get,#rx1fifo
                    movs    arg1,rx1get
                    jmp     dTx1
'
' Transmitter 
'
aTx1_Start          cmp     tx1len,#0   WZ
    if_z            jmp     #aTx1_Put
                    mov     dTx1,#aTx1_Byte
                    sub     tx1len,#1
atg1                mov     tx1data,tx1fifo
                    ror     tx1data,tx1ror
                    and     tx1data,#$ff
                    add     tx1ror,#8
                    rol     tx1getb,#8  WC
    if_nc           jmp     dRx1     
                    add     tx1get,#1
                    cmp     tx1get,#fifo1end  WZ
    if_z            mov     tx1get,#tx1fifo
                    movs    atg1,tx1get
                    jmp     dRx1

aTx1_Byte           shl     tx1data,#2
                    or      tx1data,cFixedBits  'or in a idle line state and a start bit
                    mov     tx1bits,#11
                    mov     tx1cnt,cnt
aTx1_Bits           shr     tx1data,#1   WC
                    muxc    OUTA,tx1mask        
                    add     tx1cnt,baud1        'Bit period counter
                    mov     dTx1,#aTx1_Wait
                    jmp     dRx1

aTx1_Wait           mov     t1,tx1cnt           'Check bit period
                    sub     t1,CNT
                    cmps    t1,#0       WC      'Is bit period done yet?
    if_nc           jmp     #aTx1_Put
                    djnz    tx1bits,#aTx1_Bits  'Transmit next bit
                    mov     dTx1,#aTx1_Start
                    jmp     dRx1

aTx1_Put            cmp     tx1len,#(fifo1end-tx1fifo) WZ
    if_z            jmp     dRx1
                    rdlong  t1,tx1ptr
                    shl     t1,#1    NR, WC
    if_c            jmp     dRx1
                    wrlong  cMinusOne,tx1ptr
                    add     tx1len,#1
                    and     t1,#$ff
                    shl     t1,tx1rol
                    add     tx1rol,#8
                    or      tx1out,t1
atp1                mov     tx1fifo,tx1out    
                    rol     tx1putb,#8  WC
    if_nc           jmp     dRx1
                    add     tx1put,#1
                    cmp     tx1put,#fifo1end  WZ
    if_z            mov     tx1put,#tx1fifo
                    movd    atp1,tx1put
                    mov     tx1out,#0
                    jmp     dRx1
         
                    'General variables for the transmitter
tx1len              long    0
tx1maxlen           long    (fifo1end - tx1fifo - 1) * 4
dTx1                long    aTx1_Start
                    'Variables used to grab the transmit a byte from the FIFO
tx1data             long    0
tx1bits             long    0
tx1cnt              long    0
tx1ror              long    0
tx1get              long    tx1fifo
tx1getb             long    $80
                    'Variables used to receive a byte into the FIFO
tx1rol              long    0
tx1put              long    tx1fifo
tx1putb             long    $80
tx1out              long    0

'
' Data
'
cFixedBits          long    %1_0000_0000_0_1    'Stop + 8 x Data + Start + Idle bits
cMinusOne           long    -1     

t1                  long    0
t2                  long    0

'
' The buffer sizes may be freely adjusted. As long as the code still compiles
' into the cog. The sizes are currently at their maximum, but may be adjusted
' to favour either the receiver or tranmitter.
'
rx1fifo             res     RX1FIFO_SIZE
tx1fifo             res     TX1FIFO_SIZE
fifo1end

                    FIT     496
                    
{{
 ---------------------------------------------------------------------------
                Terms of use: MIT License                                   
 --------------------------------------------------------------------------- 
   Permission is hereby granted, free of charge, to any person obtaining a  
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation 
  the rights to use, copy, modify, merge, publish, distribute, sublicense,  
    and/or sell copies of the Software, and to permit persons to whom the   
    Software is furnished to do so, subject to the following conditions:    
                                                                            
   The above copyright notice and this permission notice shall be included  
           in all copies or substantial portions of the Software.           
                                                                            
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER   
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     
                       DEALINGS IN THE SOFTWARE.                            
 --------------------------------------------------------------------------- 
}}                    