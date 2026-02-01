// ============================================================================
// ZX Spectrum + Timex FDD Interface CPLD - XC9572XL 
// ============================================================================
// 
// Replaces three chips from original design:
//   - GAL16 (address decoding, chip selects, JK flip-flop control)
//   - GAL23 (I/O port decoding)
//   - LS109 J-K flip-flop (page-in/out state)
//
// Memory Map (when paged in):
//   0x0000-0x0FFF: 4KB ROM
//   0x2000-0x27FF: 2KB RAM
//
// Paging:
//   Pages IN:  Read from 0x0000 or 0x0008
//   Pages OUT: Access to 0x0604 region
//
// I/O Port: 0x3F fully decoded from lower 8 bits (independant from interface activation)
//
// ============================================================================

module timex_interface (

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
    wire pageinaddress;
    wire pageoutaddress;
    wire ioport;
    wire pagein;
    wire pageout;

    // State register: 0=paged OUT, 1=paged IN
    reg interface_enabled = 1'b0;

    // ========================================================================
    // Full address decoding, activates on 0x0000 or 0x0008 bus access
    assign pageinaddress = (~A15 & ~A14 & ~A13 & ~A12 & ~A11 & ~A10 & ~A9 & ~A8 & ~A7 & ~A6 & ~A5 & ~A4 & ~A3 & ~A2 & ~A1 & ~A0) |
                           (~A15 & ~A14 & ~A13 & ~A12 & ~A11 & ~A10 & ~A9 & ~A8 & ~A7 & ~A6 & ~A5 & ~A4 &  A3 & ~A2 & ~A1 & ~A0);

    // ========================================================================
    // Full address decoding, activates on 0x0604 bus access
    assign pageoutaddress = ~A15 & ~A14 & ~A13 & ~A12 & ~A11 &  A10 &  A9 & ~A8 & ~A7 & ~A6 & ~A5 & ~A4 & ~A3 &  A2 & ~A1 & ~A0;

    // ========================================================================
    // Full 0xEF ioport decoding (6 bit data bus interface with Timex FDD)
    assign ioport         = ~nIORQ & A7 & A6 & A5 & ~A4 & A3 & A2 & A1 & A0;

    // Page in trigger, activates on 0x0000|0x0008 during instruction fetch cycle
    assign pagein         = pageinaddress   & ~nMREQ & -nRD & ~nM1;

    // Page in trigger, activates on 0x0604 memory read
    assign pageout        = pageoutaddress  & ~nMREQ & -nRD;

    // Interface enabled control
    always @(negedge nMREQ) begin
        if (pagein)  // Page IN
            interface_enabled <= 1'b1;

        if (pageout) // Page OUT
            interface_enabled <= 1'b0;
    end
    
	// Disable ZX Spectrum internal ROM when Interface is enabled
	assign nZX_ROMCS = interface_enabled;

	// Interface 4K ROM enable
	assign nROM_CS = ~(interface_enabled & ~nMREQ & ~A15 & ~A14 & ~A13);
	
	// Interface 2K RAM enable
	assign nRAM_CS = ~(interface_enabled & ~nMREQ & ~A15 & ~A14 &  A13);
	
    // ========================================================================
    // IO port 0xEF data OUT LS273: write strobe (ACTIVE HIGH)
    assign LS273 = ~nWR & ioport;
    // IO port 0xEF data IN nLS244: read strobe (ACTIVE LOW)
    assign nLS244 = ~(~nRD & ioport);

endmodule
