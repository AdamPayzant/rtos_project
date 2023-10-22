const locks = @import("locks.zig");

const Spinlock = locks.Spinlock;

// UART register offsets

/// Receive Holding Register
///
/// Receives data
const RHR = 0b000;
/// Transmit Holding Register
///
/// Transmits data, set to 1 when transmitter is empty or data is transferred
/// to the transmit shift register
const THR = 0b000;
/// Interrupt control fields
const IER = 0b001;
const IERFields = enum(u8) {
    RECEIVE_HOLDING_STATE = 0, // Disables(0)/Enables(1) Receiver Ready Interrupt
    TRANSMIT_HOLDING_STATE, // Disables(0)/Enables(1) Transmit Ready Interrupt
    RECEIVE_LINE_STATE, // Disables(0)/Enables(1) Receive line Interrupt
    MODEM_LINE_STATE, // Disables(0)/Enables(1) Modem line Interrupt
};
/// Used for configuring and controlling the FIFOs and selecting the dma
/// signaling type
const FCR = 0b010;
const FCRFields = enum(u8) {
    FIFO_STATE = 0, // Disables(0)/Enables(1) the transmit and receive FIFO
    // Enable should be configured before setting FIFO trigger
    // levels
    RECEIVER_FIFO_RESET = 1, // Clears the content of the Receive FIFO if set
    // and returns to 0 after clearing
    TRASMIT_FIFO_RESET = 2, // Clears the content of the transmit FIFO if set
    // and returns to 0 after clearing
    DMA_MODE = 3, // If set, changes the RXRDY and TXRDY pins from mode 0 to mode 1

    // The next 2 are used to set the trigger level for the receiver FIFO interrupts
    RCVR_TRIGGER_LSB = 6,
    RCVR_TRIGGER_MSB = 7,
};
/// Interrupt Status register
///
/// This register provides the source of of the interrupt in prioritized manner
const ISR = 0b010;
const ISRFields = enum(u8) {
    INTERRUPT_STATUS = 0,
    PREV_INT_0 = 1,
    PREV_INT_1 = 2,
    PREV_INT_2 = 3,
    FIFO_STATE = 6,
    FIFO_STATE2 = 7,
};
// TODO: Add Interrupt parser
/// Line Control Register
///
/// Used to specify data communication format
const LCR = 0b011;
const LCRFields = enum(u8) {
    // These two bits specify word length for messaging
    WORD_LENGTH0 = 0,
    WORD_LENGTH1,
    STOP_BIT, // The number of stop bits
    PARITY_ENABLE, // Set whether parity bit is enabled
    PARITY_FORMAT, // Set whether parity uses odd (0) or even (1) format
    SET_PARITY, // Force parity bit to always opposite to PARITY_FORMAT setting
    SET_BREAK, // Causes a break condition to be transmitted when set to 1
    DIVISOR_LATCH, // Set internal baud rate counter latch
};
/// Modem Control Register
///
/// Controls the interface with the MODEM or peripheral device
const MCR = 0b100;
const MCRFields = enum(u8) {
    DTR = 0, // Forces data terminal ready to high (0) or low (1)
    RTS, // Forces request to send to high (0) or low (1)
    OP1, // Sets option1's output to high (0) or low (1)
    OP2, // Sets option2's output to high (0) or low (1)
    LOOPBACK, // Set loopback mode (1) (debug mode)
};
/// Line Status Register
///
/// Provides the status of data transfer
const LSR = 0b101;
const LSRFields = enum(u8) {
    RECEIVE_DATA_READY = 0, // If 1, data has been received and saved
    OVERRUN_ERR, // If 1, a character arrived before holding register was emptied
    // or FIFO is full and next character has been received in shift register
    PARITY_ERR, // Receive data does not have correct parity information
    FRAMING_ERR, // Receive data does not have valid stop bit
    BREAK_INTERRUPT, // Receiver received a break interrupt
    TRANSIT_HOLDING_EMPTY, // 1 if transmitter hold register is empty and ready to receive
    TRANSMIT_EMPTY, // 1 if transmit holding register is empty. In FIFO mode,
    // this bit is set whenever the transmitter FIFO and transit
    // shift registers are empty
    FIFO_ERR, // At least one error is in the FIFO, cleared when LSR is read
};
/// Modem Status Register
///
/// Provides the current state of the control lines coming from modem or
/// peripheral
const MSR = 0b110;
const MSRFields = enum(u8) {
    DELTA_CTS = 0, // CTS changed state
    DELTA_DSR, // DSR changed state
    DELTA_RI, // RI changed state
    DELTA_CD, // CD changed state
    CTS, // RTS changed state
    DSR, // The compliment of the CTS input
    RI, // Equivalent to OP1 in the MCR during local loopback
    CD, // Equivalent to OP2 in the MCR during local loopback
};
/// Scratchpad Register
///
/// Stores 8 bits of information
const SPR = 0b111;

pub const UART = struct {
    const Self = @This();

    uart_reg: [*c]volatile u8,
    lock: Spinlock,

    pub fn init(address: usize) UART {
        return UART{
            .uart_reg = @ptrFromInt(address),
            .lock = Spinlock.init(),
        };
    }

    pub fn set_FIFO(self: *Self) void {
        // Disable interrupts, configure FIFO mode, reenable interrupts
        self.uart_reg[IER] = 0x0;
        self.uart_reg[FCR] = 1 << @intFromEnum(FCRFields.FIFO_STATE) |
            1 << @intFromEnum(FCRFields.RECEIVER_FIFO_RESET) |
            1 << @intFromEnum(FCRFields.TRASMIT_FIFO_RESET);
        self.uart_reg[IER] = 1 << @intFromEnum(IERFields.RECEIVE_LINE_STATE);
    }

    pub fn write_byte(self: *Self, byte: u8) void {
        self.lock.lock();
        defer self.lock.unlock();

        // Wait for data to be flushed
        while (self.uart_reg[LSR] & 1 << @intFromEnum(LSRFields.TRANSIT_HOLDING_EMPTY) == 0) {}
        self.uart_reg[THR] = byte;
    }

    pub fn read_byte(self: *Self) ?u8 {
        self.lock.lock();
        defer self.lock.unlock();

        if (self.uart_reg[LSR] & 1 << @intFromEnum(LSRFields.RECEIVE_DATA_READY) == 1) {
            return self.uart_reg[RHR];
        } else {
            return null;
        }
    }
};

pub fn write_string(uart: *UART, str: []const u8) void {
    for (str) |char| {
        uart.write_byte(char);
    }
}

pub fn read_string(uart: *UART, return_array: *[128]u8) usize {
    var i: usize = 0;
    while (true) {
        var b = uart.read_byte() orelse continue;
        if (b == '\r') {
            // For quality of life we'll just swap a CR for a newline
            b = '\n';
        }
        uart.write_byte(b);

        return_array.*[i] = b;
        if (b == '\n') {
            return i;
        }
    }
}
