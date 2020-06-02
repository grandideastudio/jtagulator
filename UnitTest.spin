{
    MIT License
    
    Copyright (C) 2019  Adam Green (https://github.com/adamgreen)
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
}
' Unit test framework for Propeller based testing. Kind of limited
' with what I can do here as there is no preprocessor.

OBJ
    pst: "Parallax Serial Terminal"

VAR
    ' Pointer to the name of the test currently running.
    LONG m_pTestName     
    
    LONG m_passCount
    LONG m_failCount
    LONG m_ignoreCount
    LONG m_checksFailed
    LONG m_checkCount   
    
PUB init
    ' Default to using pins 30 (tx) and 31 (rx) at 115200 baud for UART settings.
    initRxTx(31, 30, 0, 115200)
    m_passCount~
    m_failCount~
    m_ignoreCount~
    m_pTestName~

PUB initRxTx(rxPin, txPin, mode, baudRate)
    pst.StartRxTx(rxPin, txPin, mode, baudRate)
    pst.Clear

PUB start(pTestName)
    m_pTestName := pTestName
    m_checksFailed~
    m_checkCount~

PUB checkLong(pMessage, actual, expected)
    RESULT := actual == expected
    IF NOT RESULT
        pst.NewLine
        pst.Str(STRING("FAIL: "))
        pst.Str(m_pTestName)
        pst.NewLine
        pst.Str(STRING("      "))
        pst.Str(pMessage)
        pst.NewLine
        pst.Str(STRING("        actual: "))
        printDecAndHex(actual)
        pst.NewLine
        pst.Str(STRING("      expected: "))
        printDecAndHex(expected)
        pst.NewLine
        m_checksFailed++
    m_checkCount++

PRI printDecAndHex(value)
    pst.Dec(value)
    pst.Str(STRING("($"))
    pst.Hex(value, 8)
    pst.Char(")")
    
PUB end
    IF m_checksFailed > 0
        pst.Char("x")
        m_failCount++
    ELSEIF m_checkCount == 0
        pst.Char("!")
        m_ignoreCount++
    ELSE
        pst.Char(".")
        m_passCount++

PUB stats
    pst.NewLine
    pst.NewLine
    pst.Str(STRING(" Tests passed: "))
    pst.Dec(m_passCount)
    pst.NewLine
    pst.Str(STRING(" Tests failed: "))
    pst.Dec(m_failCount)
    pst.NewLine
    pst.Str(STRING("Tests ignored: "))
    pst.Dec(m_ignoreCount)
    pst.NewLine
    pst.Str(STRING("  Total tests: "))
    pst.Dec(m_passCount + m_failCount + m_ignoreCount)
    pst.NewLine
        