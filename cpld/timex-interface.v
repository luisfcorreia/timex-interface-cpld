// ============================================================================
// ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 
// ============================================================================
// 
// ZX Spectrum side:
//   - GAL23 (I/O port decoding)
//   - GAL16 (address decoding, chip selects)
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

module wd1770_sd (

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
    wire P14;    // I/O address decode helper
    wire P19;    // Address range detector (0x0000-0x1FFF)
    wire O13;    // Address 0x0000 detector (feedback for paging logic)
    wire ff_J;   // JK flip-flop J input (page-out condition)
    wire ff_K;   // JK flip-flop K input (page-in condition)
    reg ff_Q;    // JK flip-flop state (0=paged out, 1=paged in)

    // ========================================================================
    // Address Decode Logic (from original GAL16)
    // ========================================================================
    
    // P19: Active (low) when addressing 0x0000-0x1FFF range
    // Equation: /P19 = /A14 * /A15 * /A13
    // Active low when A15=0, A14=0, A13=0
    assign P19 = A14 | A15 | A13;
    
    // P14: I/O address decode helper
    // Equation: /P14 = /A3 + /A2
    // Active low when either A3=0 or A2=0
    assign P14 = A3 | A2;
    
    // O13: Detects access to address 0x0000 in base range
    // Equation: /O13 = /A12 * /A8 * /A11 * /A7 * /A6 * /A5 * /A4 * /P19 * /A1 * /A0
    // Active low only when all address bits are 0 and P19 is active
    // Used as feedback to flip-flop for page-in detection
    assign O13 = A12 | A8 | A11 | A7 | A6 | A5 | A4 | ~P19 | A1 | A0;
    
    // ========================================================================
    // JK Flip-Flop Control Logic (from original GAL16)
    // ========================================================================
    
    // ff_J: Page-out condition (SET)
    // Equation: /ls109_J = A10 + A9 + A2 + O13 + nM1
    // Triggers when accessing addresses outside base ROM range or during M1 cycle
    // Active low triggers page-out: A10=1 or A9=1 (addr >= 0x0200)
    //                                A2=1 (specific addresses)
    //                                O13=0 (address 0x0000 access)
    //                                nM1=0 (instruction fetch)
    assign ff_J = A10 | A9 | A2 | O13 | nM1;
    
    // ff_K: Page-in condition (RESET)
    // Equation: /ls109_K = A10 * A9 * /A3 * A2 * /O13 * /nM1
    // Triggers on specific I/O access pattern (0x0600 range during non-M1)
    // Active low when: A10=1, A9=1, A3=0, A2=1, O13=1, nM1=1
    // This corresponds to I/O region around 0x0604
    assign ff_K = ~A10 | ~A9 | A3 | ~A2 | O13 | nM1;
    
    // ========================================================================
    // Page-in/out Flip-Flop (replaces LS109 J-K flip-flop)
    // ========================================================================
    // Clocked by nMREQ rising edge (memory cycle completion)
    // JK Truth Table:
    //   J=0, K=0: Hold current state
    //   J=0, K=1: Reset (page in, Q=0)
    //   J=1, K=0: Set (page out, Q=1)
    //   J=1, K=1: Toggle state
    always @(posedge nMREQ) begin
        case ({ff_J, ff_K})
            2'b00: ff_Q <= ff_Q;      // Hold
            2'b01: ff_Q <= 1'b0;      // Page in
            2'b10: ff_Q <= 1'b1;      // Page out
            2'b11: ff_Q <= ~ff_Q;     // Toggle
        endcase
    end
    
    // ========================================================================
    // Memory Chip Select Generation
    // ========================================================================
    
    // nZX_ROMCS: Master ROM control signal
    // Equation: /nZXROM = /ls109_J * /ls109_Q
    // Active low when ROM should be visible (both J and Q are low)
    assign nZX_ROMCS = ff_J | ff_Q;
    
    // nROM_CS: Interface ROM chip select (0x0000-0x1FFF)
    // Equation: /nIFROM = /A14 * /A15 * /A13 * nZXROM * /nMREQ
    // Active low when:
    //   - Addressing 0x0000-0x1FFF (A15=0, A14=0, A13=0)
    //   - ROM is paged in (nZX_ROMCS=0)
    //   - Memory request active (nMREQ=0)
    assign nROM_CS = A14 | A15 | A13 | ~nZX_ROMCS | nMREQ;
    
    // nRAM_CS: Interface RAM chip select (0x2000-0x3FFF)
    // Equation: /nIFRAM = /A14 * /A15 * A13 * nZXROM * /nMREQ
    // Active low when:
    //   - Addressing 0x2000-0x3FFF (A15=0, A14=0, A13=1)
    //   - ROM is paged in (nZX_ROMCS=0)
    //   - Memory request active (nMREQ=0)
    assign nRAM_CS = A14 | A15 | ~A13 | ~nZX_ROMCS | nMREQ;
    
    // ========================================================================
    // Timex Interface I/O Port Decode (from original GAL23)
    // ========================================================================
    
    // LS273: I/O write strobe for port 0x3F (ACTIVE HIGH)
    // Equation: nLS273 = /IORQ * /WR * A5 * /A4 * p14 * A1 * A0
    // Active high when writing to I/O port 0x3F:
    //   A5=1, A4=0, A3=1, A2=1 (via P14), A1=1, A0=1
    //   nIORQ=0, nWR=0
    // Port decode: 0bXX11XXXX with lower bits 111111 = 0x3F
    assign LS273 = ~nIORQ & ~nWR & A5 & ~A4 & P14 & A1 & A0;

    // nLS244: I/O read strobe for port 0x3F (ACTIVE LOW)
    // Equation: /nLS244 = /IORQ * /RD * A5 * /A4 * p14 * A1 * A0
    // Active low when reading from I/O port 0x3F:
    //   A5=1, A4=0, A3=1, A2=1 (via P14), A1=1, A0=1
    //   nIORQ=0, nRD=0
    // Same port as LS273 for bidirectional WD1770 register access
    assign nLS244 = ~(~nIORQ & ~nRD & A5 & ~A4 & P14 & A1 & A0);

endmodule
