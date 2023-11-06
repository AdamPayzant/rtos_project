// TODO: Complete
pub const irq_table = enum(usize) {
    TEMPSENS = 16,
    RTC_Alarm = 17,
    RTC_Longpress = 18,
    VBAT_DET = 19,
    JPEG = 20,
    H264 = 21,
    H265 = 22,
    VC_SBM = 23,
    ISP = 24,
    SC_TOP = 25,
    CSI_MAC0 = 26,
    CSI_MAC1 = 27,
    LDC = 28,
    System_DMA = 29,
};
