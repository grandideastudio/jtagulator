{{
+----------------------+------------------+--------+------------------+--------+
| ReadPulseWidths.spin | (C)2007          | V1.0   | by David Carrier | Nov 07 |
|                      | Parallax, Inc.   |        |                  |        |
+----------------------+------------------+--------+------------------+--------+
|                                                                              |
| Records the most recent low and high pulse durations on specified input pins |
| Requires one cog and up 64 longs availible to run                            |
|                                                                              |
+------------------------------------------------------------------------------+


Usage:
* Create an array with two longs for every pin that will be monitored, then 
  write a long into the first location in the array to specify which pins to
  monitor
* For every bit set to a logic '1' the corresponding 'ina' pin will be monitored
* After everything is set up, call Start(@InputMask) to begin 
* Every time a valid pulse is recieved, the pulse width will be written to the
  appropriate location within the array

For example, to monitor I/O pins 0, 5, 13, and 21:

Include this file in an OBJ block:

  ReadPulseWidths : "ReadPulseWidths.spin"

Create an array, in a VAR block, with two longs per monitored pin:
  In this case, there are eight longs dedicated for PulseData, 2 each for
  pins 0, 5, 13, 21

  long  PulseData[8]

Set the appropriate bits in PulseData[0]
  In this case set 0, 5, 13, 21, to a logic '1'

                          21       13        5    0
                           |        |        |    |
                           v        v        v    v 
  PulseData := %00000000_00100000_00100000_00100001
  or
  PulseData := constant(|< 21 + |< 13 + |< 5 + |< 0)

Start the object:

  ReadPulseWidths.Start(@PulseData)

Read the data:                                                                             
  Every time a pulse ends, the pulse time will automatically be recorded in the
  array. The first two longs store the low then high times for the lowest
  numbered pin being monitored. The low then high times for the next highest pin
  are stored in the next two longs. This repeats for every pin being monitored.


  For example, for the first pin, in this case pin 0 use these variables:
    LowTime := PulseData[0]
    HighTime := PulseData[1]
    For the second pin, in this case pin 5 use these variables:
    LowTime := PulseData[2]
    HighTime := PulseData[3]
    For the second pin, in this case pin 13 use these variables:
    LowTime := PulseData[4]
    HighTime := PulseData[5]
    For the second pin, in this case pin 21 use these variables:
    LowTime := PulseData[6]
    HighTime := PulseData[7]
  Even though pin 21 is the 22 pin, it is the fourth one being monitored, so it
  is in the fourth set of variables.

A full low-high-low transition must occur before a high time will be recorded
A full high-low-high transition must occur before a low time will be recorded
After the first transition has occured for a given pin, every subsiquent
transition will result in either a low or high pulse time being updated
}}


VAR

  byte                cog

                                                           
PUB Start(InputMask)            'Start a new cog with the assembly routine

  return cog := cognew(@Entry, InputMask)


PUB Stop                        'Stop the currently running cog, if any

  if !cog
    cogstop(cog)


DAT                             'Assembly program

                        org

Entry                   mov     Mask, par               'Read Mask data from                                                             
                        rdlong  Mask, Mask              'main RAM

                        mov     Offset, par             'Reset main RAM to '0'
                        mov     Temp, #0                
                        mov     Index, Mask
Init                    shr     Index, #1       wc, wz
        if_c            wrlong  Temp, Offset            'Set longs of main RAM
        if_c            add     Offset, #4              'to '0' for every pin   
        if_c            wrlong  Temp, Offset            'that is monitored 
        if_c            add     Offset, #4              
        if_nz           jmp     #Init

                        mov     Unchanged, Mask         'Set 'Unchanged' for
                                                        'all monitored pins
                        mov     State, ina              'Record initial states
                        mov     Original, State         'and keep a reference
                        
WaitChange              mov     LastState, State        'Remeber last state 
                        waitpne LastState, Mask         'Wait for any monitored                                          
                        mov     State, ina              'pin to change state
                        and     State, Mask             'Ignore non-wached pins

                        mov     Time, cnt               'Update timer

                        mov     First, Original         'Check for initial pin 
                        xor     First, State            'transitions, record
                        and     First, Unchanged        'them, then remove them
                        xor     Unchanged, First        'from 'Unchanged'

Decode                  mov     Index, Neg1             'Reset pin counter

                        mov     NewState, State         'State and Mask must 
                        mov     Temp, Mask              'be preserved
                        
Again                   shr     Temp, #1        wc, wz  'Try next pin
        if_z_and_nc     jmp     #WaitChange             'Last monitored pin?
        if_nc           jmp     #Done                   'Is pin being monitored?
                        
                        add     Index, #1               'Increment counter

                        test    LastState, #1   wz      'z = !LastState.0
                        test    NewState, #1    wc      'c = NewState.0
        if_z_ne_c       jmp     #Done                   'If there was no change,
                                                        'check the next pin
                        mov     Offset, Index           'Point Offset to the                        
                        add     Offset, #LastRecord     'appropriate LastRecord

'These two instructions modify the later 'sub' and 'mov' instructions so that
'the 'LastRecord' pointer is replaced with the new Index + LastRecord offset
                        movs    ReadLastRecord, Offset  
                        movd    WriteLastRecord, Offset 
                                                        
                        mov     DeltaTime, Time         'Subtract old record      
ReadLastRecord          sub     DeltaTime, LastRecord   'from current time

WriteLastRecord         mov     LastRecord, Time        'Write back current time

                        mov     Offset, Index           'Point Offset to the 
                        shl     Offset, #3              'propper RAM location
        if_z_and_c      add     Offset, #4              'If falling edge, store
                        add     Offset, par             'in the previous word
                        test    First, #1       wz      'Ignore first transition
        if_z            wrlong  DeltaTime, Offset       'Write the appropriate 
                                                        'PulseData variable
Done                    shr     LastState, #1           'Queue in the next pins
                        shr     NewState, #1
                        shr     First, #1
                        jmp     #Again                  

Neg1          long      -1      '$1F_FF_FF_FF

Mask          res       1       'Pins that are being monitored
                                 
Unchanged     res       1       'Pins that have never changed state
Original      res       1       'Original state of monitored pins
First         res       1       'Pins that just had their first transition
                                 
LastState     res       1       'Last state of monitored pins
State         res       1       'Current state of monitored pins
NewState      res       1       'Working register to keep 'State' unmodified
                                 
LastRecord    res       32      'Cnt values for last transition of each pin
Time          res       1       'Cnt value for most recent transition
DeltaTime     res       1       'Difference between 'Time' and 'LastRecord'
                                 
Offset        res       1       'Temporary and working registers
Index         res       1
Temp          res       1
