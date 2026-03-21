# 🎯 Project Recommendation: UART Protocol Subsystem
## Complete RTL → UVM Verification → Embedded System Integration

### For: 3rd-Year ECE Student | Target: ASIC DV Internships (Nvidia, Qualcomm, Meta)
### Resources: Spartan-6 · Cadence Lab · STM32 · ESP32 · Arduino

---

## WHY THIS PROJECT (The Strategic Thinking)

Your FIFO project was a **building block**. The industry question now is:
> "Can you verify a real protocol block — not just write a testbench, but build a full verification environment that a junior DV engineer would be proud of?"

Here's why UART is the exact right answer:

| Factor | Reason |
|--------|--------|
| **Your FIFO skills transfer directly** | A UART uses TX FIFO and RX FIFO internally — you already built that |
| **Protocol complexity is right-sized** | Complex enough to be interesting; well-defined spec = no ambiguity |
| **UVM is the #1 DV interview topic** | 100% of senior DV JDs mention UVM. Cadence Xcelium natively supports it |
| **All hardware integrates naturally** | Spartan-6 (FPGA) ↔ STM32 (embedded peer) ↔ ESP32 (wireless dashboard) |
| **Cadence tools give you a lab-grade project** | No other student has Cadence access. This is your unfair advantage |
| **Interview narrative is compelling** | One clean story: designed → verified → deployed → integrated |

---

## THE PROJECT IN ONE SENTENCE

> **"A configurable UART transceiver, verified to completion using a UVM environment on Cadence Xcelium with formal properties on JasperGold, deployed on an FPGA that communicates with STM32 firmware, with live data monitored wirelessly via ESP32."**

---

## ARCHITECTURE OVERVIEW

```
════════════════════════════════════════════════════════════════════
                     THE FULL SYSTEM
════════════════════════════════════════════════════════════════════

    SIMULATION WORLD (Cadence Lab)          PHYSICAL WORLD
    ─────────────────────────────    ──────────────────────────────

    ┌─────────────────────────┐       ┌──────────────────────────┐
    │  UVM Testbench          │       │  Spartan-6 FPGA Board    │
    │  ┌───────────────────┐  │       │  ┌────────────────────┐  │
    │  │ UVM Agent         │  │       │  │ uart_top.v         │  │
    │  │ ┌──────────────┐  │  │       │  │ ┌────────────────┐ │  │
    │  │ │  Sequencer   │  │  │       │  │ │ uart_tx.v      │ │  │──TX──►
    │  │ └──────┬───────┘  │  │  RTL  │  │ │ fifo_sync.v    │ │  │
    │  │        │           │  │ ──── │  │ │ baud_gen.v     │ │  │◄─RX──
    │  │ ┌──────▼───────┐  │  │       │  │ │ uart_rx.v      │ │  │
    │  │ │   Driver     │◄─┼──┤       │  │ └────────────────┘ │  │
    │  │ └──────────────┘  │  │       │  └──────────┬─────────┘  │
    │  │ ┌──────────────┐  │  │       │             │ UART lines │
    │  │ │   Monitor    │──┼──►       └─────────────┼────────────┘
    │  │ └──────────────┘  │  │                     │
    │  └───────────────────┘  │              ┌──────┴──────┐
    │                         │              │   STM32F4   │
    │  ┌───────────────────┐  │              │  (HAL UART) │
    │  │ Scoreboard        │  │              │  Sends sensor│
    │  │ (Reference Model) │  │              │  data frames │
    │  └───────────────────┘  │              └──────┬──────┘
    │                         │                     │ (SPI or UART)
    │  ┌───────────────────┐  │              ┌──────┴──────┐
    │  │ Coverage Collector│  │              │    ESP32    │
    │  └───────────────────┘  │              │  WiFi Bridge│
    │                         │              │  Web terminal│
    │  ┌───────────────────┐  │              └─────────────┘
    │  │ JasperGold Formal │  │
    │  │ (Prove properties)│  │
    │  └───────────────────┘  │
    └─────────────────────────┘
```

---

## THE RTL DESIGN: What You Will Build

### Module Hierarchy

```
uart_top.v                      ← Top-level integration
├── baud_gen.v                  ← Configurable baud rate generator
├── uart_tx.v                   ← Transmitter (serializer)
│   └── fifo_sync.v             ← TX FIFO (re-use your existing design!)
└── uart_rx.v                   ← Receiver with 16x oversampling
    └── fifo_sync.v             ← RX FIFO (re-use!)
```

### What Each Module Does

**`baud_gen.v`** — Baud Rate Generator
```
Input:  50 MHz system clock, BAUD_RATE parameter
Output: baud_tick (1 pulse per bit period)
        baud_tick_x16 (16 pulses per bit period, for RX oversampling)

Math:  DIVISOR = CLK_FREQ / BAUD_RATE
       If BAUD_RATE = 115200: DIVISOR = 50,000,000 / 115200 ≈ 434
       A counter counts 0→434, then pulses baud_tick for one cycle
       x16 pulse comes every DIVISOR/16 ≈ 27 cycles
```

**`uart_tx.v`** — Transmitter
```
FSM States:
  IDLE       → line is HIGH (mark state)
  START_BIT  → line goes LOW for 1 bit period
  DATA_BITS  → shift out 8 data bits, LSB first, one per baud_tick
  PARITY_BIT → optional, XOR of all data bits (configurable)
  STOP_BIT   → line goes HIGH for 1–2 bit periods
  → back to IDLE

Interface:
  tx_data_in[7:0], tx_valid (write to TX FIFO)
  tx_full (TX FIFO full — backpressure signal)
  uart_tx_line (single serial output pin)
```

**`uart_rx.v`** — Receiver with 16× Oversampling
```
Why 16× oversampling?
  The receiver doesn't know exactly when the sender's baud clock ticks.
  It samples the incoming line 16 times per bit period and uses
  majority voting on samples 7, 8, 9 (centre of the bit) to decide
  if the bit is 0 or 1. This tolerates up to ±6% baud rate mismatch
  and is how every real UART chip works.

FSM States:
  IDLE        → wait for falling edge (start bit detection)
  START_CHECK → wait for 8 x16 ticks to sample centre of start bit
               (verify it's still LOW — filter short glitches)
  DATA_BITS   → wait 16 ticks per bit, sample at tick 8
  PARITY_CHK  → verify parity if enabled; set parity_error flag
  STOP_BIT    → verify stop bit is HIGH; set framing_error if not
  COMPLETE    → push received byte to RX FIFO

Status outputs:
  rx_data_out[7:0], rx_valid
  parity_error, framing_error, rx_overflow
```

**`uart_top.v`** — Integration + Control Registers

Expose a simple register interface (can be simple address-mapped or direct):
```
REG 0: TX_DATA   — write byte to transmit
REG 1: RX_DATA   — read byte received
REG 2: STATUS    — {rx_overflow, framing_err, parity_err, tx_full, rx_empty}
REG 3: CONTROL   — {parity_en, parity_type, stop_bits[1:0], baud_sel[2:0]}
```

---

## PHASE 1: RTL DESIGN ON XILINX ISE / VIVADO (Week 1)

**Goal:** Working UART TX + RX in simulation before touching hardware.

### Deliverables at End of Week 1
- [ ] `baud_gen.v` — verified baud divisor logic
- [ ] `uart_tx.v` — FSM transmits correct frames
- [ ] `uart_rx.v` — receiver correctly decodes frames including parity
- [ ] `uart_top.v` — integrated top-level
- [ ] Basic directed testbench in Vivado simulator (sanity check only)
- [ ] ISim waveform showing complete UART frame (start + 8 data + parity + stop)

**Key design challenge to handle:**
The classic UART student bug: not re-centering the sample window after start bit detection. You must wait 1.5 bit periods (24 oversampled ticks) after the falling edge to hit the centre of bit 0, then exactly 16 ticks for each subsequent bit.

---

## PHASE 2: UVM VERIFICATION ON CADENCE XCELIUM (Weeks 2–3)

This is THE phase that makes your project industry-grade.

### UVM Environment Architecture

```
test_uart_random (extends uvm_test)
└── uart_env (extends uvm_env)
    ├── uart_agent (extends uvm_agent)
    │   ├── uart_driver      (drives bits onto serial line)
    │   ├── uart_monitor     (samples line → extracts frames)
    │   └── uart_sequencer   (feeds transactions to driver)
    ├── uart_scoreboard      (reference model: compares expected vs actual)
    └── uart_coverage        (functional coverage collection)
```

### The UVM Transaction Object

```systemverilog
class uart_transaction extends uvm_sequence_item;
    `uvm_object_utils(uart_transaction)

    // Randomizable fields
    rand bit [7:0] data;
    rand bit       parity_en;
    rand bit       parity_type;   // 0=even, 1=odd
    rand bit [1:0] stop_bits;     // 1 or 2

    // Error injection fields
    rand bit inject_parity_error;
    rand bit inject_framing_error;

    // Constraints
    constraint c_valid_stop   { stop_bits inside {2'b01, 2'b10}; }
    constraint c_error_rare   { inject_parity_error dist {1 := 5, 0 := 95}; }

    // Standard UVM print/copy/compare
    function void do_print(uvm_printer printer);
        printer.print_field_int("data", data, 8, UVM_HEX);
        printer.print_field_int("parity_en", parity_en, 1);
    endfunction
endclass
```

### Test Sequences You Will Write

| Sequence Name | What It Does | Why It Matters |
|---------------|-------------|----------------|
| `seq_basic_loopback` | Send 8'hAA, verify received | Sanity check |
| `seq_full_data_range` | Send 0x00 → 0xFF sequentially | Corner cases |
| `seq_burst_tx` | Fill TX FIFO to full | Overflow behaviour |
| `seq_burst_rx` | Receive faster than drain | RX FIFO fill |
| `seq_parity_error` | Inject wrong parity bit | Error detection |
| `seq_framing_error` | Corrupt stop bit | Framing detection |
| `seq_random_baud` | Randomize baud mismatch ±2% | Tolerance testing |
| `seq_random_all` | 10,000 fully random txns | Main coverage driver |

### The Scoreboard (Reference Model)

```systemverilog
class uart_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_scoreboard)

    // Input from monitor
    uvm_analysis_imp_tx #(uart_transaction, uart_scoreboard) tx_port;
    uvm_analysis_imp_rx #(uart_transaction, uart_scoreboard) rx_port;

    // Reference model: a simple queue
    uart_transaction expected_q[$];
    int pass_count, fail_count;

    // Called when TX monitor sees a frame transmitted
    function void write_tx(uart_transaction txn);
        expected_q.push_back(txn);
    endfunction

    // Called when RX monitor sees a frame received
    function void write_rx(uart_transaction rxn);
        uart_transaction exp;
        if (expected_q.size() == 0) begin
            `uvm_error("SCOREBOARD", "RX frame received but expected queue is empty!")
            return;
        end
        exp = expected_q.pop_front();
        if (rxn.data !== exp.data) begin
            `uvm_error("SCOREBOARD",
                $sformatf("DATA MISMATCH: got 0x%02h, expected 0x%02h", rxn.data, exp.data))
            fail_count++;
        end else begin
            pass_count++;
        end
    endfunction
endclass
```

### Functional Coverage Model

```systemverilog
covergroup uart_coverage @(posedge clk);
    // All byte values must be sent and received
    cp_tx_data: coverpoint tx_data { bins all[256] = {[8'h00:8'hFF]}; }

    // All baud rates exercised
    cp_baud: coverpoint baud_sel {
        bins b9600   = {3'b000};
        bins b19200  = {3'b001};
        bins b38400  = {3'b010};
        bins b115200 = {3'b011};
    }

    // Parity modes
    cp_parity: coverpoint {parity_en, parity_type} {
        bins no_parity  = {2'b00};
        bins even_parity = {2'b10};
        bins odd_parity  = {2'b11};
    }

    // Error conditions
    cp_parity_error:  coverpoint parity_error  { bins hit = {1}; }
    cp_framing_error: coverpoint framing_error { bins hit = {1}; }

    // TX FIFO occupancy
    cp_tx_fifo: coverpoint tx_item_count {
        bins empty    = {0};
        bins low      = {[1:4]};
        bins mid      = {[5:11]};
        bins high     = {[12:14]};
        bins full     = {16};
    }

    // Cross: data values vs parity config
    cx_data_parity: cross cp_tx_data, cp_parity;

endgroup
// TARGET: >95% functional coverage after 10,000 random transactions
```

---

## PHASE 3: FORMAL VERIFICATION ON JASPER GOLD (Day or Two)

If your Cadence lab has JasperGold, this is your biggest differentiator — almost NO student project includes formal verification.

### Properties to Prove Formally

```systemverilog
// Property 1: If TX FIFO is full, no data is lost
// (item_count must never exceed FIFO_DEPTH even with continuous writes)
property p_tx_no_overflow;
    @(posedge clk) disable iff (!rst_n)
    tx_item_count <= TX_FIFO_DEPTH;
endproperty
a_tx_no_overflow: assert property(p_tx_no_overflow);

// Property 2: Parity bit in transmitted frame always matches data
property p_parity_correct;
    @(posedge clk) disable iff (!rst_n || !parity_en)
    (uart_state == PARITY_BIT) |->
    (uart_tx_line == (^tx_shift_reg ^ parity_type));
endproperty
a_parity_correct: assert property(p_parity_correct);

// Property 3: Start bit is always LOW
property p_start_bit_low;
    @(posedge clk) disable iff (!rst_n)
    (uart_state == START_BIT) |-> (uart_tx_line == 1'b0);
endproperty
a_start_bit_low: assert property(p_start_bit_low);

// Property 4: IDLE line is always HIGH (mark state)
property p_idle_is_mark;
    @(posedge clk) disable iff (!rst_n)
    (uart_state == IDLE) |-> (uart_tx_line == 1'b1);
endproperty
a_idle_is_mark: assert property(p_idle_is_mark);
```

JasperGold will **mathematically prove** these hold for ALL possible input sequences, not just the ones you tested. This is a completely different class of confidence than simulation.

**Resume line:** *"Formally verified 4 UART protocol properties using JasperGold Formal Verification, achieving exhaustive proof across all reachable states."*

---

## PHASE 4: FPGA DEPLOYMENT ON SPARTAN-6 (Week 4 — Part 1)

### Hardware Connections

```
SPARTAN-6 EDGE BOARD              STM32F4 DISCOVERY
─────────────────────             ──────────────────
uart_tx_line (P_XX) ──────────► USART1_RX (PA10)
uart_rx_line (P_XX) ◄────────── USART1_TX (PA9)
GND                 ──────────── GND

SPARTAN-6 EDGE BOARD              ESP32
─────────────────────             ──────
uart_tx_line ─────────────────► GPIO16 (RX2)
GND          ─────────────────── GND
```

### UCF Additions (to top_fifo.ucf style)

```ucf
# UART Interface
NET "uart_tx_line"  LOC = "PXX";   # Connect to header pin → STM32 RX
NET "uart_rx_line"  LOC = "PXX";   # Connect to header pin ← STM32 TX

# BAUD select switches
NET "baud_sel<0>"   LOC = "P22";   # Slide switch 0
NET "baud_sel<1>"   LOC = "P21";   # Slide switch 1
NET "baud_sel<2>"   LOC = "P17";   # Slide switch 2
```

---

## PHASE 5: STM32 FIRMWARE — THE PEER COMMUNICATOR (Week 4 — Part 2)

Write simple STM32 HAL firmware in C (CubeIDE is free):

```c
// stm32_uart_peer.c — STM32F4 sends temperature sensor data to FPGA over UART
#include "stm32f4xx_hal.h"

UART_HandleTypeDef huart1;
uint8_t tx_buffer[10];
uint8_t rx_buffer[1];

// Simulate a sensor reading (or use real LM35/DS18B20 on STM32)
float read_temperature() {
    // Return simulated temperature 20.5 - 35.5 °C
    static float temp = 20.5f;
    temp += 0.1f;
    if (temp > 35.5f) temp = 20.5f;
    return temp;
}

void uart_send_frame(float temperature) {
    // Protocol: [0xAA][TEMP_INT][TEMP_FRAC][CHECKSUM][0x55]
    uint8_t temp_int  = (uint8_t)temperature;
    uint8_t temp_frac = (uint8_t)((temperature - temp_int) * 100);
    uint8_t checksum  = temp_int ^ temp_frac;

    tx_buffer[0] = 0xAA;         // Start marker
    tx_buffer[1] = temp_int;     // Integer part
    tx_buffer[2] = temp_frac;    // Fractional part
    tx_buffer[3] = checksum;     // Simple XOR checksum
    tx_buffer[4] = 0x55;         // End marker

    HAL_UART_Transmit(&huart1, tx_buffer, 5, 100);
}

int main(void) {
    HAL_Init();
    // ... clock setup, USART1 config at 115200 8N1 ...
    while (1) {
        float temp = read_temperature();
        uart_send_frame(temp);
        HAL_Delay(500);    // Send every 500ms

        // Also listen for FPGA echo/acknowledgment
        if (HAL_UART_Receive(&huart1, rx_buffer, 1, 10) == HAL_OK) {
            // FPGA acknowledged — toggle LED
            HAL_GPIO_TogglePin(GPIOD, GPIO_PIN_12);
        }
    }
}
```

---

## PHASE 6: ESP32 — WIRELESS MONITORING DASHBOARD (Week 4 — Part 3)

The ESP32 bridges UART data to a WiFi web server. This is your "wow factor" for demos.

```cpp
// esp32_wireless_terminal.cpp (Arduino IDE for ESP32)
#include <WiFi.h>
#include <WebServer.h>

const char* ssid     = "YourWiFi";
const char* password = "YourPass";
WebServer server(80);

String dataLog = "";

// ESP32 RX2 connected to Spartan-6 TX line
void setup() {
    Serial.begin(115200);    // Debug
    Serial2.begin(115200, SERIAL_8N1, 16, 17);  // UART from FPGA

    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) delay(500);

    server.on("/", []() {
        String html = "<html><body>";
        html += "<h2>FPGA UART Live Dashboard</h2>";
        html += "<h3>IP: " + WiFi.localIP().toString() + "</h3>";
        html += "<pre>" + dataLog + "</pre>";
        html += "<script>setTimeout(()=>location.reload(), 1000);</script>";
        html += "</body></html>";
        server.send(200, "text/html", html);
    });
    server.begin();
}

void loop() {
    server.handleClient();

    // Read bytes from FPGA (received via STM32 → FPGA → ESP32 chain)
    if (Serial2.available() >= 5) {
        uint8_t buf[5];
        Serial2.readBytes(buf, 5);
        if (buf[0] == 0xAA && buf[4] == 0x55) {
            uint8_t checksum = buf[1] ^ buf[2];
            if (checksum == buf[3]) {
                float temp = buf[1] + buf[2] / 100.0f;
                String entry = "[OK] Temp: " + String(temp, 2) + "°C";
                dataLog = entry + "\n" + dataLog;
                if (dataLog.length() > 2000) dataLog = dataLog.substring(0, 2000);
            } else {
                dataLog = "[ERR] Checksum fail\n" + dataLog;
            }
        }
    }
}
```

Open `http://192.168.x.x/` on any phone/laptop → live stream of FPGA data over WiFi.

---

## COMPLETE 4-WEEK TIMELINE

```
WEEK 1: RTL DESIGN
──────────────────
Mon: Design baud_gen.v — counter-based divisor, verify in ISim
Tue: Design uart_tx.v FSM — IDLE→START→DATA→PARITY→STOP
Wed: Design uart_rx.v FSM — with 16x oversampling (hardest part)
Thu: Integrate uart_top.v — connect TX FIFO and RX FIFO (your existing code!)
Fri: Basic directed simulation — verify full frame in waveform viewer

WEEK 2: UVM TESTBENCH (Cadence Xcelium)
───────────────────────────────────────
Mon: Write uart_transaction (seq_item) and study UVM phases
Tue: Write uart_driver — drives bit sequences onto serial interface
Wed: Write uart_monitor — samples bit stream, reconstructs frames
Thu: Write uart_scoreboard — reference model with queue comparison
Fri: Run first UVM simulation — basic directed sequence, verify PASS

WEEK 3: UVM SEQUENCES + COVERAGE + FORMAL
──────────────────────────────────────────
Mon: Write 4 directed sequences (basic, burst, errors)
Tue: Add constrained-random sequence — 1000 transactions
Wed: Add covergroup — 6 coverpoints, run until >90% coverage
Thu: JasperGold formal — attempt 4 assertions, report PROVEN/CEX
Fri: Bug hunt — find and fix at least one real bug from random testing

WEEK 4: HARDWARE INTEGRATION
─────────────────────────────
Mon: FPGA synthesis in Vivado — check timing report (fmax)
Tue: Deploy on Spartan-6 — verify UART TX with oscilloscope or logic analyser
Wed: STM32 firmware — basic HAL UART send, verify FPGA receives correctly
Thu: ESP32 bridge — WiFi web server, stream data from FPGA chain
Fri: Full system demo — STM32→FPGA→ESP32→phone browser, record video
```

---

## RESUME BULLETS (Ready to Copy)

After completing this project, here is how to write it:

```
UART Protocol Subsystem — RTL to System Integration                [2026]
Xilinx ISE | Cadence Xcelium/JasperGold | Spartan-6 | STM32 | ESP32

• Designed configurable UART transceiver in Verilog with 16× oversampling RX,
  parameterized baud rate (9600–115200), parity modes, and integrated TX/RX FIFOs

• Built complete UVM verification environment (driver, monitor, scoreboard, sequencer)
  achieving 96.3% functional coverage across 12 coverpoints using 10,000 constrained-
  random transactions on Cadence Xcelium

• Formally verified 4 UART protocol invariants (no TX FIFO overflow, correct parity,
  valid start/stop bits) using JasperGold, achieving exhaustive proof across all
  reachable FSM states

• Deployed on Xilinx Spartan-6 FPGA; integrated STM32F4 peer transmitting real-time
  sensor data frames and ESP32 wireless bridge serving live data dashboard over WiFi

• Diagnosed and resolved 3 RTL bugs discovered exclusively through random testing
  that directed tests did not detect — including an off-by-one in RX sample timing
```

---

## INTERVIEW ANGLES THIS PROJECT UNLOCKS

| Question Type | Example Question |
|--------------|-----------------|
| Protocol knowledge | "How does 16x oversampling tolerate baud rate mismatch?" |
| UVM architecture | "What is the difference between a driver and a monitor in UVM?" |
| Coverage driven | "How did you know when your testbench was done?" |
| Formal verification | "What can formal verification prove that simulation cannot?" |
| Bug finding | "What bugs did your random testing find that directed tests missed?" |
| System thinking | "How does the STM32 know if the FPGA received its data correctly?" |
| Debug story | "Describe a bug you found during hardware bring-up" |

---

## WHAT MAKES THIS STAND OUT VERSUS EVERY OTHER STUDENT

Most student projects stop at: *"I wrote an RTL block and ran three testbench simulations."*

This project demonstrates ALL FIVE pillars of professional ASIC DV:

```
Pillar 1: RTL Design Literacy     ✅ (designed a real protocol block from spec)
Pillar 2: Constrained-Random DV   ✅ (UVM with 10,000 random transactions)
Pillar 3: Assertion-Based Verify  ✅ (SVA in testbench + JasperGold formal)
Pillar 4: Coverage-Driven Closure ✅ (defined coverpoints, measured hit rate)
Pillar 5: Hardware Validation     ✅ (deployed on real silicon, system demo)
```

Qualcomm, Nvidia, and Meta DV teams look for exactly this combination.
The Cadence formal verification angle (JasperGold) is something even many
experienced engineers haven't used — it immediately elevates you to a different
tier of candidates.

---

*Recommendation prepared: 2026-03-19*
*Based on available resources: Spartan-6 · Cadence Lab (Xcelium + JasperGold) · STM32 · ESP32 · Arduino*
