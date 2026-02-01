// ============================================================================
// ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 
// CORRECTED VERSION - Fixed JK Flip-Flop Logic
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
    output wire nLS244,

    // debug internals    
    output wire PAGEIN,
    output wire PAGEOUT,
    output wire J,
    output wire K
        
);

    // ========================================================================
    // Internal Signals
    // ========================================================================
    wire pageinaddress;
    wire pageoutaddress;
    wire ioport;

    // State register: 0=paged OUT, 1=paged IN
    reg interface_enabled = 1'b0;

    // ========================================================================
    assign pageinaddress = ~A15 & ~A14 & ~A13 & ~A12 & ~A11 & ~A10 & ~A9 & ~A8 & ~A7 & ~A6 & ~A5 & ~A4 & ~A1 & ~A0;
    assign pageoutaddress = ~A15 & ~A14 & ~A13 & ~A12 & ~A11 & A10 & A9 & ~A8 & ~A7 & ~A6 & ~A5 & ~A4 & ~A3 & A2 & ~A1 & ~A0;
    assign ioport = A7 & A6 & A5 & ~A4 & A3 & A2 & A1 & A0;
    
	// Paging control signals (active HIGH when condition met)
	assign pagein_trigger = pageinaddress & ~nM1 & ~nMREQ;  // Page in during M1 cycle at 0x0000
	assign pageout_trigger = pageoutaddress & ~nMREQ;      // Page out when accessing 0x0604

    // State machine on memory cycle completion
    always @(posedge nMREQ) begin
        if (pagein_trigger)
            interface_enabled <= 1'b1;  // Page IN
        else if (pageout_trigger)
            interface_enabled <= 1'b0;  // Page OUT
        // else: hold current state
    end
    
	// nZX_ROMCS logic
	// When paged IN (Q=1), we want interface active, so nZX_ROMCS should be HIGH
	// When paged OUT (Q=0), we want ZX ROM active, so nZX_ROMCS should be LOW
	assign nZX_ROMCS = ~interface_enabled;  // Simple: Q directly controls it

	// Chip selects work when interface is paged IN (nZX_ROMCS HIGH)
	assign nROM_CS = ~(~A14 & ~A15 & ~A13 & interface_enabled & ~nMREQ);
	assign nRAM_CS = ~(~A14 & ~A15 & A13 & interface_enabled & ~nMREQ);    
    // ========================================================================
    // GAL23 - Timex Interface I/O Port Decode
    // ========================================================================
    
    // LS273: I/O write strobe for port 0x3F (ACTIVE HIGH)
    // GAL23 Equation: nLS273 = /nIORQ * /nWR * A5 * /A4 * p14 * A1 * A0
    // Active high when writing to port 0x3F
    // Port decode: A5=1, A4=0, A3=1 & A2=1 (via P14), A1=1, A0=1 = 0x3F
    assign LS273 = ~nIORQ & ~nWR & ioport;

    // nLS244: I/O read strobe for port 0x3F (ACTIVE LOW)
    // GAL23 Equation: /nLS244 = /nIORQ * /nRD * A5 * /A4 * p14 * A1 * A0
    // Active low when reading from I/O port 0x3F
    assign nLS244 = ~(~nIORQ & ~nRD & ioport);

    assign PAGEIN = pageinaddress;
    assign PAGEOUT = pageoutaddress;
    assign K = interface_enabled;

endmodule
