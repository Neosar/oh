module elink(/*AUTOARG*/
   // Outputs
   rx_lclk_div4, tx_lclk_div4, rxo_wr_wait_p, rxo_wr_wait_n,
   rxo_rd_wait_p, rxo_rd_wait_n, txo_lclk_p, txo_lclk_n, txo_frame_p,
   txo_frame_n, txo_data_p, txo_data_n, chipid, chip_resetb, cclk_p,
   cclk_n, rxwr_access, rxwr_packet, rxrd_access, rxrd_packet,
   rxrr_access, rxrr_packet, txwr_wait, txrd_wait, txrr_wait,
   mailbox_not_empty, mailbox_full, timeout,
   // Inputs
   reset, clkin, sys_clk, pll_bypass, testmode, rxi_lclk_p,
   rxi_lclk_n, rxi_frame_p, rxi_frame_n, rxi_data_p, rxi_data_n,
   txi_wr_wait_p, txi_wr_wait_n, txi_rd_wait_p, txi_rd_wait_n,
   rxwr_wait, rxrd_wait, rxrr_wait, txwr_access, txwr_packet,
   txrd_access, txrd_packet, txrr_access, txrr_packet
   );
   
   parameter AW          = 32;
   parameter DW          = 32; 
   parameter PW          = 104;      //packet width   
   parameter ID          = 12'h810;

   /****************************/
   /*CLK AND RESET             */
   /****************************/
   input        reset;               // active high asynchronous hardware reset
   input 	clkin;               // pll input clock
   input 	sys_clk;             // system clock for FIFOs only
   input [3:0] 	pll_bypass;          // pll bypass clocks for elink   
   input 	testmode;            // places elink in testmode
   output 	rx_lclk_div4;        // rx clock for synching with logic
   output 	tx_lclk_div4;        // tx clock for synching with logic

   /********************************/
   /*ELINK I/O PINS                */
   /********************************/          
   //Receiver
   input        rxi_lclk_p,  rxi_lclk_n;     //link rx clock input
   input        rxi_frame_p,  rxi_frame_n;   //link rx frame signal
   input [7:0] 	rxi_data_p,   rxi_data_n;    //link rx data
   output       rxo_wr_wait_p,rxo_wr_wait_n; //link rx write pushback output
   output       rxo_rd_wait_p,rxo_rd_wait_n; //link rx read pushback output
   
   //Transmitter
   output       txo_lclk_p,   txo_lclk_n;    //link tx clock output
   output       txo_frame_p,  txo_frame_n;   //link tx frame signal
   output [7:0] txo_data_p,   txo_data_n;    //link tx data
   input 	txi_wr_wait_p,txi_wr_wait_n; //link tx write pushback input
   input 	txi_rd_wait_p,txi_rd_wait_n; //link tx read pushback input

   /********************************/
   /*EPIPHANY INTERFACE (I/O PINS) */
   /********************************/          
   output [11:0] chipid;			// From etx of etx.v
   output 	 chip_resetb;          //chip reset for Epiphany (active low)
   output 	 cclk_p, cclk_n;       //high speed clock (up to 1GHz) to Epiphany
   
   /*****************************/
   /*"System" Interface         */
   /*****************************/   
   
   //Master Write (from RX)
   output 	   rxwr_access;
   output [PW-1:0] rxwr_packet;
   input 	   rxwr_wait;
      
   //Master Read Request (from RX)
   output 	   rxrd_access;
   output [PW-1:0] rxrd_packet;
   input 	   rxrd_wait;
   
   //Slave Read Response (from RX)
   output 	   rxrr_access;
   output [PW-1:0] rxrr_packet;
   input 	   rxrr_wait;

   //Slave Write (to TX)
   input 	   txwr_access;
   input [PW-1:0]  txwr_packet;
   output 	   txwr_wait;

   //Slave Read Request (to TX) 
   input 	   txrd_access;
   input [PW-1:0]  txrd_packet;
   output 	   txrd_wait;
   
   //Master Read Response (to TX)
   input 	   txrr_access;
   input [PW-1:0]  txrr_packet;
   output 	   txrr_wait;

   /*****************************/
   /*MAILBOX (interrupts)       */
   /*****************************/
   output       mailbox_not_empty;   
   output       mailbox_full;

   /*****************************/
   /*READBACK TIMEOUT           */
   /*****************************/
   output 	timeout;
   
   /*#############################################*/
   /*  END OF BLOCK INTERFACE                     */
   /*#############################################*/
   
   /*AUTOINPUT*/
   /*AUTOOUTPUT*/

   //wires
   wire [31:0] 	 mi_rd_data;
   wire [31:0] 	 mi_dout_ecfg;
   wire [31:0] 	 mi_dout_embox;

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [15:0]		clk_config;		// From ecfg_clocks of ecfg_clocks.v
   wire			elink_reset;		// From ereset of ereset.v
   wire			erx_cfg_access;		// From ecfg_cdc of fifo_cdc.v
   wire [PW-1:0]	erx_cfg_packet;		// From ecfg_cdc of fifo_cdc.v
   wire			erx_cfg_wait;		// From erx of erx.v
   wire			etx_cfg_access;		// From etx of etx.v
   wire [PW-1:0]	etx_cfg_packet;		// From etx of etx.v
   wire			etx_cfg_wait;		// From ecfg_cdc of fifo_cdc.v
   wire			soft_reset;		// From ecfg_clocks of ecfg_clocks.v
   wire			tx_lclk;		// From eclocks of eclocks.v
   wire			tx_lclk90;		// From eclocks of eclocks.v
   // End of automatics
   
   /***********************************************************/
   /*CLOCK AND RESET CONFIG                                   */
   /***********************************************************/

   defparam ecfg_clocks.ID=ID;
   
   ecfg_clocks ecfg_clocks (.hard_reset		(reset),
			    .clk		(sys_clk),
			    .txwr_access_out	(txwr_gated_access),//filter access to etx
			    /*AUTOINST*/
			    // Outputs
			    .soft_reset		(soft_reset),
			    .clk_config		(clk_config[15:0]),
			    // Inputs
			    .txwr_access	(txwr_access),
			    .txwr_packet	(txwr_packet[PW-1:0]));

   /***********************************************************/
   /*RESET CIRCUITRY                                          */
   /***********************************************************/
   ereset ereset (.hard_reset		(reset),
		  /*AUTOINST*/
		  // Outputs
		  .elink_reset		(elink_reset),
		  .chip_resetb		(chip_resetb),
		  // Inputs
		  .soft_reset		(soft_reset));

   /***********************************************************/
   /*CLOCKS                                                   */
   /***********************************************************/
   eclocks eclocks (.hard_reset		(reset),//reset by input pin only
		    /*AUTOINST*/
		    // Outputs
		    .cclk_p		(cclk_p),
		    .cclk_n		(cclk_n),
		    .tx_lclk		(tx_lclk),
		    .tx_lclk90		(tx_lclk90),
		    .tx_lclk_div4	(tx_lclk_div4),
		    // Inputs
		    .clkin		(clkin),
		    .clk_config		(clk_config[15:0]),
		    .pll_bypass		(pll_bypass[3:0]));
   
   /***********************************************************/
   /*RECEIVER                                                 */
   /***********************************************************/
   /*erx AUTO_TEMPLATE ( 
	                .mi_dout      (mi_rx_dout[]),
                        .emwr_\(.*\)  (emaxi_emwr_\1[]),
                        .emrq_\(.*\)  (emaxi_emrq_\1[]),
                        .emrr_\(.*\)  (esaxi_emrr_\1[]),
                        .reset        (elink_reset),
                       );
   */
   
   defparam erx.ID=ID;
   erx erx(
	   /*AUTOINST*/
	   // Outputs
	   .rx_lclk_div4		(rx_lclk_div4),
	   .rxo_wr_wait_p		(rxo_wr_wait_p),
	   .rxo_wr_wait_n		(rxo_wr_wait_n),
	   .rxo_rd_wait_p		(rxo_rd_wait_p),
	   .rxo_rd_wait_n		(rxo_rd_wait_n),
	   .rxwr_access			(rxwr_access),
	   .rxwr_packet			(rxwr_packet[PW-1:0]),
	   .rxrd_access			(rxrd_access),
	   .rxrd_packet			(rxrd_packet[PW-1:0]),
	   .rxrr_access			(rxrr_access),
	   .rxrr_packet			(rxrr_packet[PW-1:0]),
	   .erx_cfg_wait		(erx_cfg_wait),
	   .timeout			(timeout),
	   .mailbox_full		(mailbox_full),
	   .mailbox_not_empty		(mailbox_not_empty),
	   // Inputs
	   .reset			(elink_reset),		 // Templated
	   .sys_clk			(sys_clk),
	   .rxi_lclk_p			(rxi_lclk_p),
	   .rxi_lclk_n			(rxi_lclk_n),
	   .rxi_frame_p			(rxi_frame_p),
	   .rxi_frame_n			(rxi_frame_n),
	   .rxi_data_p			(rxi_data_p[7:0]),
	   .rxi_data_n			(rxi_data_n[7:0]),
	   .rxwr_wait			(rxwr_wait),
	   .rxrd_wait			(rxrd_wait),
	   .rxrr_wait			(rxrr_wait),
	   .erx_cfg_access		(erx_cfg_access),
	   .erx_cfg_packet		(erx_cfg_packet[PW-1:0]));

   /***********************************************************/
   /*TRANSMITTER                                              */
   /***********************************************************/
   /*etx AUTO_TEMPLATE (.mi_dout      (mi_tx_dout[]),
                        .emwr_\(.*\)  (esaxi_emwr_\1[]),
                        .emrq_\(.*\)  (esaxi_emrq_\1[]),
                        .emrr_\(.*\)  (emaxi_emrr_\1[]),
                        .reset        (elink_reset),
                        
                       );
   */

   defparam etx.ID=ID;
   etx etx(.txwr_access  (txwr_gated_access),
	   /*AUTOINST*/
	   // Outputs
	   .chipid			(chipid[11:0]),
	   .txo_lclk_p			(txo_lclk_p),
	   .txo_lclk_n			(txo_lclk_n),
	   .txo_frame_p			(txo_frame_p),
	   .txo_frame_n			(txo_frame_n),
	   .txo_data_p			(txo_data_p[7:0]),
	   .txo_data_n			(txo_data_n[7:0]),
	   .txrd_wait			(txrd_wait),
	   .txwr_wait			(txwr_wait),
	   .txrr_wait			(txrr_wait),
	   .etx_cfg_access		(etx_cfg_access),
	   .etx_cfg_packet		(etx_cfg_packet[PW-1:0]),
	   // Inputs
	   .reset			(elink_reset),		 // Templated
	   .sys_clk			(sys_clk),
	   .tx_lclk			(tx_lclk),
	   .tx_lclk90			(tx_lclk90),
	   .tx_lclk_div4		(tx_lclk_div4),
	   .testmode			(testmode),
	   .txi_wr_wait_p		(txi_wr_wait_p),
	   .txi_wr_wait_n		(txi_wr_wait_n),
	   .txi_rd_wait_p		(txi_rd_wait_p),
	   .txi_rd_wait_n		(txi_rd_wait_n),
	   .txrd_access			(txrd_access),
	   .txrd_packet			(txrd_packet[PW-1:0]),
	   .txwr_packet			(txwr_packet[PW-1:0]),
	   .txrr_access			(txrr_access),
	   .txrr_packet			(txrr_packet[PW-1:0]),
	   .etx_cfg_wait		(etx_cfg_wait));
   
   /***********************************************************/
   /*TX-->RX REGISTER INTERFACE CONNECTION                    */
   /***********************************************************/
   /*fifo_cdc AUTO_TEMPLATE (.clk_in		(tx_lclk_div4),
		             .clk_out		(rx_lclk_div4),
                             .packet_in	        (etx_cfg_packet[PW-1:0]),
                             .packet_out	(erx_cfg_packet[PW-1:0]),
                             .access_in	        (etx_cfg_access),
                             .access_out	(erx_cfg_access),
                             .reset             (elink_reset),
                             .wait_in		(erx_cfg_wait),
                             .wait_out		(etx_cfg_wait),
                       );
   */
   fifo_cdc #(.DW(104)) ecfg_cdc (/*AUTOINST*/
				  // Outputs
				  .wait_out		(etx_cfg_wait),	 // Templated
				  .access_out		(erx_cfg_access), // Templated
				  .packet_out		(erx_cfg_packet[PW-1:0]), // Templated
				  // Inputs
				  .clk_in		(tx_lclk_div4),	 // Templated
				  .clk_out		(rx_lclk_div4),	 // Templated
				  .reset		(elink_reset),	 // Templated
				  .access_in		(etx_cfg_access), // Templated
				  .packet_in		(etx_cfg_packet[PW-1:0]), // Templated
				  .wait_in		(erx_cfg_wait));	 // Templated
   
   
endmodule // elink
// Local Variables:
// verilog-library-directories:("." "../../erx/hdl" "../../etx/hdl"  "../../memory/hdl")
// End:

/*
 Copyright (C) 2014 Adapteva, Inc.
 
 Contributed by Andreas Olofsson <andreas@adapteva.com>

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.This program is distributed in the hope 
 that it will be useful,but WITHOUT ANY WARRANTY; without even the implied 
 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details. You should have received a copy 
 of the GNU General Public License along with this program (see the file 
 COPYING).  If not, see <http://www.gnu.org/licenses/>.
 */
