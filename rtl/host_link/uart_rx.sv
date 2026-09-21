// Copyright 2026 Emil Popovic, Matej Jurasic
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License");
// you may not use this file except in compliance with the License, or,
// at your option, the Apache License version 2.0.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Emil Popovic <mail@emilpopovic.me>

// Raw UART byte stream: 8 data bits, no parity, one stop bit, LSB first.
// The packet layer supplies framing; there is no out-of-band start-of-frame.
module uart_rx #(
  parameter int unsigned Baud = 115200,
  parameter int unsigned FClk = 48_000_000,

  // Require this many identical clock samples before changing the RX level.
  // Keep below half a bit period; ignored when FilterEnable is off.
  parameter int unsigned FilterCycles = 3,
  parameter bit          FilterEnable = 1'b1
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic en_i,    // From PHY select, UART mode active

  // RX pad, asynchronous to clk_i; idle high
  input  logic rx_i,

  // Byte stream to PHY select
  output logic [7:0] data_o,
  output logic       valid_o,  // One-cycle pulse for each accepted byte
  output logic       sof_o,    // Always low; framing belongs to the packet layer

  // Packet layer
  input  logic hold_i,  // Drop a completed byte when the RX FIFO cannot accept it
  output logic err_o    // One-cycle pulse on framing error or a dropped byte
);

  // Round to the nearest integral number of clocks per bit. Both endpoints
  // must tolerate the resulting baud error and their clock-frequency mismatch.
  localparam int unsigned BitCycles     = (Baud > 0) ? (FClk + Baud / 2) / Baud : 0;
  localparam int unsigned HalfBitCycles = BitCycles / 2;
  localparam int unsigned TimerWidth    = (BitCycles > 1) ? $clog2(BitCycles) : 1;

  typedef enum logic [2:0] {
    StWaitIdle, StIdle, StStart, StData, StStop
  } state_e;

  (* async_reg = "true" *) logic rx_meta_q, rx_sync_q;
  logic rx_filtered;
  logic [TimerWidth-1:0] timer_q;
  logic [2:0] bit_index_q;
  logic [7:0] data_q;
  state_e state_q;

  // Keep synchronization and filtering active while the PHY is deselected.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rx_meta_q <= 1'b1;
      rx_sync_q <= 1'b1;
    end else begin
      rx_meta_q <= rx_i;
      rx_sync_q <= rx_meta_q;
    end
  end

  // A run of FilterCycles samples opposite to the current level is required
  // to change it. Equal delays on rising and falling edges preserve bit widths.
  if (FilterEnable) begin : gen_filter
    localparam int unsigned FilterWidth = (FilterCycles > 1) ? $clog2(FilterCycles) : 1;
    logic rx_filtered_q;
    logic [FilterWidth-1:0] filter_count_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        rx_filtered_q  <= 1'b1;
        filter_count_q <= '0;
      end else if (rx_sync_q == rx_filtered_q) begin
        filter_count_q <= '0;
      end else if (filter_count_q == FilterWidth'(FilterCycles - 1)) begin
        rx_filtered_q  <= rx_sync_q;
        filter_count_q <= '0;
      end else begin
        filter_count_q <= filter_count_q + 1'b1;
      end
    end

    assign rx_filtered = rx_filtered_q;
  end else begin : gen_no_filter
    assign rx_filtered = rx_sync_q;
  end

  assign sof_o = 1'b0;

  // Disabling aborts the current byte. After enable or a framing error, wait
  // for a full idle bit before accepting another start. A continuous break
  // therefore reports only one error, rather than a stream of zero bytes.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      bit_index_q <= '0;
      state_q <= StWaitIdle;
      timer_q <= TimerWidth'(BitCycles - 1);
      data_q  <= '0;
      data_o  <= '0;
      valid_o <= 1'b0;
      err_o   <= 1'b0;
    end else begin
      valid_o <= 1'b0;
      err_o   <= 1'b0;

      if (!en_i) begin
        bit_index_q <= '0;
        state_q <= StWaitIdle;
        timer_q <= TimerWidth'(BitCycles - 1);
        data_q  <= '0;
      end else begin
        unique case (state_q)
          StWaitIdle: begin
            if (!rx_filtered) begin
              timer_q <= TimerWidth'(BitCycles - 1);
            end else if (timer_q == '0) begin
              state_q <= StIdle;
            end else begin
              timer_q <= timer_q - 1'b1;
            end
          end

          StIdle: begin
            if (!rx_filtered) begin
              timer_q <= TimerWidth'(HalfBitCycles - 1);
              state_q <= StStart;
            end
          end

          StStart: begin
            if (timer_q != '0) begin
              timer_q <= timer_q - 1'b1;
            end else if (rx_filtered) begin
              // Reject a false start without publishing data or an error.
              state_q <= StIdle;
            end else begin
              timer_q <= TimerWidth'(BitCycles - 1);
              bit_index_q <= '0;
              state_q <= StData;
            end
          end

          StData: begin
            if (timer_q != '0) begin
              timer_q <= timer_q - 1'b1;
            end else begin
              data_q[bit_index_q] <= rx_filtered;
              timer_q <= TimerWidth'(BitCycles - 1);
              if (bit_index_q == 3'd7) begin
                state_q <= StStop;
              end else begin
                bit_index_q <= bit_index_q + 1'b1;
              end
            end
          end

          StStop: begin
            if (timer_q != '0) begin
              timer_q <= timer_q - 1'b1;
            end else if (!rx_filtered) begin
              err_o   <= 1'b1;
              timer_q <= TimerWidth'(BitCycles - 1);
              state_q <= StWaitIdle;
            end else begin
              if (hold_i) begin
                err_o <= 1'b1;
              end else begin
                data_o  <= data_q;
                valid_o <= 1'b1;
              end
              state_q <= StIdle;
            end
          end

          default: begin
            state_q <= StWaitIdle;
            timer_q <= TimerWidth'(BitCycles - 1);
          end
        endcase
      end
    end
  end

  if (Baud == 0) begin : gen_invalid_baud
    $fatal(1, "Baud must be positive");
  end else if (BitCycles < 8) begin : gen_invalid_bit_cycles
    $fatal(1, "UART RX requires at least 8 clocks per bit");
  end
  if (FilterEnable &&
      ((FilterCycles == 0) || (FilterCycles >= HalfBitCycles))) begin : gen_invalid_filter_cycles
    $fatal(1, "FilterCycles must be positive and less than half a bit period");
  end

endmodule : uart_rx
