/* 
 * Wrapper for Xilinx MIG'd DDR2 controller, allowing 3 masters
 * to contol the single interface.
 */

module xilinx_ddr2
  (
   // Inputs
    input [31:0] wbm0_adr_i, 
    input [1:0]  wbm0_bte_i, 
    input [2:0]  wbm0_cti_i, 
    input 	 wbm0_cyc_i, 
    input [31:0] wbm0_dat_i, 
    input [3:0]  wbm0_sel_i,
  
    input 	 wbm0_stb_i, 
    input 	 wbm0_we_i,
  
   // Outputs
    output 	 wbm0_ack_o, 
    output 	 wbm0_err_o, 
    output 	 wbm0_rty_o, 
    output [31:0] wbm0_dat_o,
  
  
   // Inputs
    input [31:0]  wbm1_adr_i, 
    input [1:0]   wbm1_bte_i, 
    input [2:0]   wbm1_cti_i, 
    input 	  wbm1_cyc_i, 
    input [31:0]  wbm1_dat_i, 
    input [3:0]   wbm1_sel_i,
  
    input 	  wbm1_stb_i, 
    input 	  wbm1_we_i,
  
   // Outputs
    output 	  wbm1_ack_o, 
    output 	  wbm1_err_o, 
    output 	  wbm1_rty_o, 
    output [31:0] wbm1_dat_o,


  
   // Inputs
    input [31:0]  wbm2_adr_i, 
    input [1:0]   wbm2_bte_i, 
    input [2:0]   wbm2_cti_i, 
    input 	  wbm2_cyc_i, 
    input [31:0]  wbm2_dat_i, 
    input [3:0]   wbm2_sel_i,
  
    input 	  wbm2_stb_i, 
    input 	  wbm2_we_i,
  
   // Outputs
    output 	  wbm2_ack_o, 
    output 	  wbm2_err_o, 
    output 	  wbm2_rty_o, 
    output [31:0] wbm2_dat_o,

    input 	  wb_clk,
    input 	  wb_rst,

    output [12:0] ddr2_a,
    output [2:0]  ddr2_ba,
    output 	      ddr2_ras_n,
    output 	      ddr2_cas_n,
    output 	      ddr2_we_n,
    output        ddr2_rzq,
    output        ddr2_zio,

    output        ddr2_odt,
    output        ddr2_cke,
    output        ddr2_dm,
    output        ddr2_udm,
   
    inout [15:0]  ddr2_dq,		  
    inout         ddr2_dqs,
    inout         ddr2_dqs_n,
    inout         ddr2_udqs,
    inout         ddr2_udqs_n,
    output        ddr2_ck,
    output        ddr2_ck_n,

    input 	  ddr2_if_clk,
    input 	  clk100,
    input 	  ddr2_if_rst
   
   );

   // Internal wires to actual RAM
   wire [31:0] 	  wbs_ram_adr_i;
   wire [1:0] 	  wbs_ram_bte_i;
   wire [2:0] 	  wbs_ram_cti_i;
   wire 	  wbs_ram_cyc_i;
   wire [31:0] 	  wbs_ram_dat_i;
   wire [3:0] 	  wbs_ram_sel_i;
   wire 	  wbs_ram_stb_i;
   wire 	  wbs_ram_we_i;
   
   wire 	  wbs_ram_ack_o;
   wire [31:0] 	  wbs_ram_dat_o;

   reg [2:0] 	  input_select, last_selected;
   wire 	  arb_for_wbm0, arb_for_wbm1, arb_for_wbm2;
   // Wires allowing selection of new input
   assign arb_for_wbm0 = (last_selected[1] | last_selected[2] | 
			  !wbm1_cyc_i | !wbm2_cyc_i) & !(|input_select);
   assign arb_for_wbm1 = (last_selected[0] | last_selected[2] | 
			  !wbm0_cyc_i | !wbm2_cyc_i) & !(|input_select);
   assign arb_for_wbm2 = (last_selected[0] | last_selected[1] | 
			  !wbm0_cyc_i | !wbm1_cyc_i) & !(|input_select);
   
   // Master select logic
   always @(posedge wb_clk)
     if (wb_rst)
       input_select <= 0;
     else if ((input_select[0] & !wbm0_cyc_i) | (input_select[1] & !wbm1_cyc_i)
	      | (input_select[2] & !wbm2_cyc_i))
       input_select <= 0;
     else if (!(&input_select) & wbm0_cyc_i & arb_for_wbm0)
       input_select <= 3'b001;
     else if (!(&input_select) & wbm1_cyc_i & arb_for_wbm1)
       input_select <= 3'b010;
     else if (!(&input_select) & wbm2_cyc_i & arb_for_wbm2)
       input_select <= 3'b100;
   
   always @(posedge wb_clk)
     if (wb_rst)
       last_selected <= 0;
     else if (!(&input_select) & wbm0_cyc_i & arb_for_wbm0)
       last_selected <= 3'b001;
     else if (!(&input_select) & wbm1_cyc_i & arb_for_wbm1)
       last_selected <= 3'b010;
     else if (!(&input_select) & wbm2_cyc_i & arb_for_wbm2)
       last_selected <= 3'b100;

   // Mux input signals to RAM (default to wbm0)
   assign wbs_ram_adr_i = (input_select[2]) ? wbm2_adr_i : 
			    (input_select[1]) ? wbm1_adr_i : 
			    (input_select[0]) ? wbm0_adr_i : 0;
   assign wbs_ram_bte_i = (input_select[2]) ? wbm2_bte_i : 
			    (input_select[1]) ? wbm1_bte_i : 
			    (input_select[0]) ? wbm0_bte_i : 0;
   assign wbs_ram_cti_i = (input_select[2]) ? wbm2_cti_i : 
			    (input_select[1]) ? wbm1_cti_i : 
			    (input_select[0]) ? wbm0_cti_i : 0;
   assign wbs_ram_cyc_i = (input_select[2]) ? wbm2_cyc_i : 
			    (input_select[1]) ? wbm1_cyc_i : 
			    (input_select[0]) ? wbm0_cyc_i : 0;
   assign wbs_ram_dat_i = (input_select[2]) ? wbm2_dat_i : 
			    (input_select[1]) ? wbm1_dat_i : 
			    (input_select[0]) ? wbm0_dat_i : 0;
   assign wbs_ram_sel_i = (input_select[2]) ? wbm2_sel_i : 
			    (input_select[1]) ? wbm1_sel_i : 
			    (input_select[0]) ? wbm0_sel_i : 0;
   assign wbs_ram_stb_i = (input_select[2]) ? wbm2_stb_i : 
			    (input_select[1]) ? wbm1_stb_i : 
			    (input_select[0]) ? wbm0_stb_i : 0;
   assign wbs_ram_we_i  = (input_select[2]) ? wbm2_we_i  :
			    (input_select[1]) ? wbm1_we_i  : 
			    (input_select[0]) ? wbm0_we_i : 0;

   // Output from RAM, gate the ACK, ERR, RTY signals appropriately
   assign wbm0_dat_o = wbs_ram_dat_o;
   assign wbm0_ack_o = wbs_ram_ack_o & input_select[0];
   assign wbm0_err_o = 0;   
   assign wbm0_rty_o = 0;

   assign wbm1_dat_o = wbs_ram_dat_o;
   assign wbm1_ack_o = wbs_ram_ack_o & input_select[1];
   assign wbm1_err_o = 0;
   assign wbm1_rty_o = 0;

   assign wbm2_dat_o = wbs_ram_dat_o;
   assign wbm2_ack_o = wbs_ram_ack_o & input_select[2];
   assign wbm2_err_o = 0;
   assign wbm2_rty_o = 0;


    xilinx_ddr2_if xilinx_ddr2_if0
     (

      .wb_dat_o				(wbs_ram_dat_o),
      .wb_ack_o				(wbs_ram_ack_o),
      .wb_adr_i				(wbs_ram_adr_i[31:0]),
      .wb_stb_i				(wbs_ram_stb_i),
      .wb_cti_i				(wbs_ram_cti_i),
      .wb_bte_i				(wbs_ram_bte_i),
      .wb_cyc_i				(wbs_ram_cyc_i),
      .wb_we_i				(wbs_ram_we_i),
      .wb_sel_i				(wbs_ram_sel_i[3:0]),
      .wb_dat_i				(wbs_ram_dat_i[31:0]),

      .ddr2_a				(ddr2_a[12:0]),
      .ddr2_ba				(ddr2_ba),
      .ddr2_ras_n			(ddr2_ras_n),
      .ddr2_cas_n			(ddr2_cas_n),
      .ddr2_we_n			(ddr2_we_n),
      .ddr2_rzq	    		(ddr2_rzq),
      .ddr2_zio 			(ddr2_zio),
      .ddr2_odt				(ddr2_odt),
      .ddr2_cke				(ddr2_cke),
      .ddr2_dm				(ddr2_dm),
      .ddr2_udm				(ddr2_udm),
      .ddr2_ck				(ddr2_ck),
      .ddr2_ck_n			(ddr2_ck_n),
      .ddr2_dq				(ddr2_dq),
      .ddr2_dqs				(ddr2_dqs),
      .ddr2_dqs_n			(ddr2_dqs_n),
      .ddr2_udqs			(ddr2_udqs),
      .ddr2_udqs_n			(ddr2_udqs_n),

      .ddr2_if_clk      		(ddr2_if_clk),
      .idly_clk_100			(clk100), //SJK this can be removed, not needed
      .ddr2_if_rst                      (ddr2_if_rst),
      .wb_clk				(wb_clk),
      .wb_rst				(wb_rst));
  


   
endmodule

