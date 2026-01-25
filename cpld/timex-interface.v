// ============================================================================
// ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 
// ============================================================================
// 
// Replaces:
//   - GAL16 (address decoding, chip selects, JK flip-flop control)
//   - GAL23 (I/O port decoding)
//   - LS109 J-K flip-flop (page-in/out state)
//
// Memory Map (when paged in):
//   0x0000-0x0FFF: 4KB ROM
//   0x1000-0x1FFF: ROM echo (A12 not decoded)
//   0x2000-0x27FF: 2KB RAM
//   0x2800-0x3FFF: RAM echoes (A11-A12 not decoded)
//
// Paging:
//   Pages IN:  Read from 0x0000 or 0x0008
//   Pages OUT: Access to 0x0604 region
//
// I/O Port: 0x3F (A5=1, A4=0, A3=1, A2=1, A1=1, A0=1)
//
// ============================================================================

module timex_interface (

    // ========================================================================
    // ZX Spectrum Side Signals
    // ========================================================================
    
    // ZX Spectrum Address Bus
    input wire A0,
    input wire A1,
    input wire A2,
    input wire A3,
    input wire A4,
    input wire A5,
    input wire A6,
    input wire A7,
    input wire A8,
    input wire A9,
    input wire A10,
    input wire A11,
    input wire A12,
    input wire A13,
    input wire A14,
    input wire A15,
    
    // ZX Spectrum Control Signals
    input wire nIORQ,
    input wire nMREQ,
    input wire nRD,
    input wire nWR,
    input wire nM1,
    
    // ZX Spectrum ROM Chip Select
    output wire nZX_ROMCS,

    // Timex Interface Select Outputs
    output wire nROM_CS,
    output wire nRAM_CS,
    output wire LS273,
    output wire nLS244
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    wire P14;    // I/O address decode helper (from GAL16)
    wire P19;    // Address range detector (0x0000-0x1FFF) (from GAL16)
    wire O13;    // Address 0x0000 detector (from GAL23, uses P19 from GAL16)
    wire ff_J;   // JK flip-flop J input (page-out condition)
    wire ff_K;   // JK flip-flop K input (page-in condition)
    reg ff_Q;    // JK flip-flop state (0=paged out, 1=paged in)

    // ========================================================================
    // GAL16 - Address Decode Logic
    // ========================================================================
    
    // P19: Active (low) when addressing 0x0000-0x1FFF range
    // GAL16 Equation: /P19 = /A14 * /A15 * /A13
    assign P19 = ~(~A14 & ~A15 & ~A13);
    
    // P14: I/O address decode helper (active low)
    // GAL16 Equation: /P14 = /A3 + /A2
    // Active low when either A3=0 or A2=0
    assign P14 = ~(~A3 | ~A2);
    
    // ========================================================================
    // GAL23 - Address 0x0000 Detector
    // ========================================================================
    
    // O13: Detects access to address 0x0000
    // GAL23 Equation: /o13 = /A12 * /A8 * /A11 * /A7 * /A6 * /A5 * /A4 * /p19 * /A1 * /A0
    // Active low only when all address bits are 0 and P19 is active (low)
    assign O13 = ~(~A12 & ~A8 & ~A11 & ~A7 & ~A6 & ~A5 & ~A4 & ~P19 & ~A1 & ~A0);
    
    // ========================================================================
    // GAL16 - JK Flip-Flop Control Logic
    // ========================================================================
    
    // ff_J: Page-out condition (SET)
    // GAL16 Equation: /ls109_J = A10 + A9 + A2 + O13 + nM1
    // Active low triggers page-out
    assign ff_J = ~(A10 | A9 | A2 | O13 | nM1);
    
    // ff_K: Page-in condition (RESET)
    // GAL16 Equation: /ls109_K = A10 * A9 * /A3 * A2 * /O13 * /nM1
    // Active low when accessing 0x0600 range during non-M1
    assign ff_K = ~(A10 & A9 & ~A3 & A2 & ~O13 & ~nM1);
    
    // ========================================================================
    // LS109 - Page-in/out Flip-Flop
    // ========================================================================
    // Clocked by nMREQ rising edge (memory cycle completion)
    // JK Truth Table (active-low inputs):
    //   J=1, K=1: Hold current state
    //   J=1, K=0: Reset (page in, Q=0)
    //   J=0, K=1: Set (page out, Q=1)
    //   J=0, K=0: Toggle state
    always @(posedge nMREQ) begin
        case ({ff_J, ff_K})
            2'b11: ff_Q <= ff_Q;      // Hold
            2'b10: ff_Q <= 1'b0;      // Page in (K active)
            2'b01: ff_Q <= 1'b1;      // Page out (J active)
            2'b00: ff_Q <= ~ff_Q;     // Toggle
        endcase
    end
    
    // ========================================================================
    // GAL16 - Memory Chip Select Generation
    // ========================================================================
    
    // nZX_ROMCS: Master ROM control signal
    // GAL16 Equation: /nZXROMCS = /ls109J * /ls109Q
    assign nZX_ROMCS = ~(~ff_J & ~ff_Q);
    
    // nROM_CS: Interface ROM chip select (0x0000-0x1FFF)
    // GAL16 Equation: /nROMCS = /A14 * /A15 * /A13 * nZXROMCS * /nMREQ
    assign nROM_CS = ~(~A14 & ~A15 & ~A13 & nZX_ROMCS & ~nMREQ);
    
    // nRAM_CS: Interface RAM chip select (0x2000-0x3FFF)
    // GAL16 Equation: /nRAMCS = /A14 * /A15 * A13 * nZXROMCS * /nMREQ
    assign nRAM_CS = ~(~A14 & ~A15 & A13 & nZX_ROMCS & ~nMREQ);
    
    // ========================================================================
    // GAL23 - Timex Interface I/O Port Decode
    // ========================================================================
    
    // LS273: I/O write strobe for port 0x3F (ACTIVE HIGH)
    // GAL23 Equation: nLS273 = /nIORQ * /nWR * A5 * /A4 * p14 * A1 * A0
    // Active high when writing to port 0x3F
    // Port decode: A5=1, A4=0, A3=1 & A2=1 (via P14), A1=1, A0=1 = 0x3F
    assign LS273 = ~nIORQ & ~nWR & A5 & ~A4 & P14 & A1 & A0;

    // nLS244: I/O read strobe for port 0x3F (ACTIVE LOW in GAL equation)
    // GAL23 Equation: /nLS244 = /nIORQ * /nRD * A5 * /A4 * p14 * A1 * A0
    // Active low when reading from I/O port 0x3F
    assign nLS244 = ~(~nIORQ & ~nRD & A5 & ~A4 & P14 & A1 & A0);

endmodule
