package com.panda.e2e;

import com.sun.jna.Library;
import com.sun.jna.Native;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.stereotype.Component;
import org.testcharm.dal.runtime.AdaptiveList;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

/**
 * Panda client backed by REAL firmware code from board/main.c compiled as .dylib.
 * Goes through the FULL firmware path: comms_control_handler() → set_safety_mode().
 * Used for mutation testing without hardware.
 */
@Component
public class PandaClient {

    @AllArgsConstructor
    @Getter
    public static class CanMessage {
        private final int address;
        private final int bus;
        private final byte[] data;
        private final boolean rejected;
        private final boolean returned;
        private final boolean extended;
        private final boolean fd;
    }

    public interface PandaLib extends Library {
        String board = System.getProperty("panda.board", "cuatro");
        String libPath = System.getProperty("user.dir") + "/src/test/c/libpanda_" + board + ".dylib";
        PandaLib INSTANCE = Native.load(libPath, PandaLib.class);

        void jna_control_write(byte request, short param1, short param2, short length);

        int jna_can_send(int addr, byte bus, byte[] data, byte len);

        int jna_get_safety_tx_blocked();

        boolean jna_can_pop_rx(int[] outAddr, byte[] outBus, byte[] outRejected, byte[] outReturned, byte[] outData, byte[] outLen, byte[] outExtended, byte[] outFd);

        boolean jna_can_pop_tx(int queueIdx, int[] outAddr, byte[] outReturned, byte[] outData, byte[] outLen, byte[] outExtended, byte[] outFd);

        void jna_can_clear_all();

        // CAN queue state manipulation for coverage testing
        void jna_set_can_queue_state(int queueIdx, int wPtr, int rPtr);

        void jna_get_can_queue_state(int queueIdx, int[] outWPtr, int[] outRPtr, int[] outFifoSize);

        boolean jna_can_push_direct(int queueIdx, int addr, byte bus, byte[] data, byte len);

        boolean jna_can_pop_direct(int queueIdx, int[] outAddr, byte[] outBus, byte[] outData, byte[] outLen);

        int jna_can_slots_empty(int queueIdx);

        // FDCAN register inspection
        int jna_get_fdcan_cccr(int canNumber);

        int jna_get_fdcan_ie(int canNumber);

        int jna_get_fdcan_nbtp(int canNumber);

        int jna_get_fdcan_dbtp(int canNumber);

        int jna_get_fdcan_txbc(int canNumber);

        int jna_get_fdcan_rxf0c(int canNumber);

        int jna_get_fdcan_txesc(int canNumber);

        int jna_get_fdcan_rxesc(int canNumber);

        int jna_get_fdcan_gfc(int canNumber);

        int jna_get_fdcan_ile(int canNumber);

        int jna_get_fdcan_ir(int canNumber);

        int jna_get_fdcan_txfqs(int canNumber);

        int jna_get_fdcan_txbar(int canNumber);

        // Manual interrupt-driven CAN processing (C3)
        void jna_process_can(int canNumber);

        void jna_can_rx(int canNumber);

        // FDCAN RX FIFO injection for can_rx() path coverage (E.4)
        void jna_fdcan_write_rx_fifo(int canNumber, int elementIndex,
                                      int extended, int addr,
                                      int canfdFrame, int brsFrame,
                                      byte dataLenCode, byte[] data);

        void jna_set_fdcan_rxf0s(int canNumber, int val);

        int jna_get_fdcan_rxf0s(int canNumber);

        void jna_set_fdcan_ir(int canNumber, int val);

        int jna_get_fdcan_rxf0a(int canNumber);

        int jna_get_can_health_total_rx_cnt(int bus);

        int jna_get_can_health_total_fwd_cnt(int bus);

        int jna_get_direct_safety_rx_invalid();

        int jna_get_direct_rx_buffer_overflow();

        void jna_set_bus_forwarding_bus(int bus, int fwdBus);

        void jna_reset_bus_config();

        int jna_get_bus_config_canfd_enabled(int bus);

        int jna_get_bus_config_brs_enabled(int bus);

        // Heartbeat state inspection
        int jna_get_heartbeat_counter();

        void jna_set_heartbeat_counter(int val);

        int jna_get_heartbeat_lost();

        int jna_get_heartbeat_disabled();

        int jna_get_heartbeat_engaged();

        int jna_get_controls_allowed();

        void jna_set_controls_allowed(int val);

        int jna_get_current_safety_mode();

        int jna_get_siren_countdown();

        int jna_get_siren_enabled();

        int jna_get_siren_was_active();

        // safety_mode_cnt (declared in opendbc/safety/safety.h)
        int jna_get_safety_mode_cnt();

        void jna_set_safety_mode_cnt(int val);

        // Health packet inspection
        void jna_read_health_pkt();

        int jna_get_health_uptime();

        int jna_get_health_voltage();

        int jna_get_health_current();

        int jna_get_health_safety_tx_blocked();

        int jna_get_health_safety_rx_invalid();

        int jna_get_health_safety_mode();

        int jna_get_health_safety_param();

        int jna_get_health_heartbeat_lost();

        // Power save state inspection
        int jna_get_power_save_enabled();

        // Alternative experience inspection
        int jna_get_alternative_experience();

        // Siren state inspection
        long jna_get_ir_pwm();

        // Power-save hardware call tracking
        int jna_get_irq_enable_call_count();

        int jna_get_irq_disable_call_count();

        int jna_get_last_irq_enabled_bus();

        int jna_get_irq_disabled_bus(int bus);

        int jna_get_ir_power_value_at(int index);

        // NVIC disable IRQ tracking
        int jna_get_nvic_disable_irq_count();

        int jna_get_nvic_disable_irq_at(int index);

        int jna_get_fan_power();

        int jna_get_fan_cooldown_counter();

        // CAN comms buffer inspection
        int jna_get_can_read_buffer_ptr();

        int jna_get_can_read_buffer_tail();

        int jna_get_can_write_buffer_ptr();

        int jna_get_can_write_buffer_tail();

        // USB endpoint simulation
        void jna_usb_ep3_out(byte[] data, int len);

        int jna_usb_ep1_in(byte[] outData, int maxLen);

        int jna_usb_ep1_in_get_len();

        int jna_usb_ep1_in_get_byte(int index);

        // Packet versions (response from 0xdd)
        void jna_get_packet_versions(int[] outHealthVersion, int[] outCanVersionHash);

        // CAN FD bus_config inspection
        int jna_get_bus_canfd_auto(int bus);

        int jna_get_bus_canfd_non_iso(int bus);

        int jna_get_bus_canfd_enabled(int bus);

        int jna_get_bus_brs_enabled(int bus);

        int jna_get_bus_can_data_speed(int bus);

        // Clock source tracking
        int jna_get_TIM1_CCR1();

        int jna_get_TIM1_CCR2();

        int jna_get_TIM8_CCR3();

        int jna_get_TIM1_ARR();

        int jna_get_TIM1_CCR4();

        void jna_clock_source_init(int enable_channel1);

        // TIM1 extended register getters
        int jna_get_TIM1_PSC();

        int jna_get_TIM1_SMCR();

        int jna_get_TIM1_BDTR();

        int jna_get_TIM1_CR1();

        int jna_get_TIM1_CR2();

        int jna_get_TIM1_CCMR1();

        int jna_get_TIM1_CCMR2();

        int jna_get_TIM1_CCER();

        int jna_get_TIM1_DIER();

        // TIM8 extended register getters
        int jna_get_TIM8_PSC();

        int jna_get_TIM8_ARR();

        int jna_get_TIM8_SMCR();

        int jna_get_TIM8_BDTR();

        int jna_get_TIM8_CR1();

        int jna_get_TIM8_CCMR2();

        int jna_get_TIM8_CCER();

        // ---- TIM3 (LED PWM) ----
        int jna_get_TIM3_CR1();
        int jna_get_TIM3_ARR();
        int jna_get_TIM3_CCMR1();
        int jna_get_TIM3_CCMR2();
        int jna_get_TIM3_CCER();
        int jna_get_TIM3_CCR1();
        int jna_get_TIM3_CCR2();
        int jna_get_TIM3_CCR3();
        int jna_get_TIM3_CCR4();

        // GPIO AFR register getters
        long jna_get_reg_GPIOA_AFR0();

        long jna_get_reg_GPIOA_AFR1();

        long jna_get_reg_GPIOB_AFR0();

        long jna_get_reg_GPIOB_AFR1();

        long jna_get_reg_GPIOC_AFR0();

        long jna_get_reg_GPIOC_AFR1();

        long jna_get_reg_GPIOD_AFR0();

        long jna_get_reg_GPIOD_AFR1();

        long jna_get_reg_GPIOE_AFR0();

        long jna_get_reg_GPIOE_AFR1();

        // GPIO OTYPER getters
        long jna_get_reg_GPIOA_OTYPER();

        long jna_get_reg_GPIOB_OTYPER();

        long jna_get_reg_GPIOC_OTYPER();

        long jna_get_reg_GPIOD_OTYPER();

        long jna_get_reg_GPIOE_OTYPER();

        long jna_get_reg_GPIOF_OTYPER();

        long jna_get_reg_GPIOG_OTYPER();

        // GPIO OSPEEDR getters
        long jna_get_reg_GPIOA_OSPEEDR();

        long jna_get_reg_GPIOB_OSPEEDR();

        long jna_get_reg_GPIOC_OSPEEDR();

        long jna_get_reg_GPIOD_OSPEEDR();

        long jna_get_reg_GPIOE_OSPEEDR();

        long jna_get_reg_GPIOF_OSPEEDR();

        long jna_get_reg_GPIOG_OSPEEDR();

        // GPIO PUPDR getters (GPIOB already exists in register accessor section)
        long jna_get_reg_GPIOA_PUPDR();

        long jna_get_reg_GPIOC_PUPDR();

        long jna_get_reg_GPIOD_PUPDR();

        long jna_get_reg_GPIOE_PUPDR();

        long jna_get_reg_GPIOF_PUPDR();

        long jna_get_reg_GPIOG_PUPDR();

        // Board init
        void jna_board_init();


        // Microsecond timer and fan RPM
        void jna_set_microsecond_timer(int val);


        void jna_set_mcu_uid(byte[] hex, int hexLen);


        void jna_set_interrupt_call_rate(byte index, int val);

        int jna_get_interrupt_handler(int irqn);

        int jna_get_interrupt_call_rate_max(int irqn);

        void jna_handle_interrupt(int irqn);
        void jna_interrupt_timer_tick();
        float jna_get_interrupt_load();
        int jna_get_interrupt_call_counter(int irqn);
        int jna_is_unused_handler(int irqn);


        void jna_set_serial(byte[] hex, int hexLen);


        void jna_set_provision(byte[] hex, int hexLen);


        void jna_set_app_code_len(int len);

        void jna_set_signature_chunk(int chunk, byte[] hex, int hexLen);


        int jna_get_enter_bootloader_mode();


        void jna_uart_push(byte[] data, int len);


        int jna_get_relay_malfunction();

        void jna_set_relay_malfunction(int val);

        int jna_get_faults();

        int jna_get_fault_status();

        void jna_trigger_fault(int fault);

        void jna_recover_fault(int fault);


        void jna_call_tick_handler();

        void jna_set_register_divergent(int enable);

        void jna_set_fan_rpm(int val);

        int jna_get_resp_len();

        int jna_get_resp_byte(int index);

        // comms_endpoint2_write (SPI endpoint 2 / USB endpoint 2 bulk write)
        void jna_comms_endpoint2_write(byte[] data, int len);

        int jna_get_endpoint2_debug_len();

        int jna_get_endpoint2_debug_byte(int index);

        // Setup for read-request tests
        void jna_set_hw_type(int val);

        void jna_set_gitversion(String val);

        void jna_set_som_gpio(int val);

        void jna_set_voltage_mV(int val);

        void jna_set_current_mA(int val);

        // Direct state setters (bypass firmware pipeline)
        void jna_set_current_safety_mode(int val);

        void jna_set_alternative_experience(int val);

        void jna_set_heartbeat_disabled(int val);

        int jna_get_nvic_reset_count();


        int jna_get_stop_mode_requested();

        void jna_process_stop_mode();

        void jna_process_wfi_idle();

        void jna_tick_siren();


        // Bootkick FSM inspection and control

        int jna_get_bootkick_state();

        int jna_get_bootkick_reset_triggered();

        int jna_get_bootkick_waiting_countdown();

        int jna_get_bootkick_reset_countdown();


        void jna_set_ignition_line(byte val);

        int jna_get_ignition_can();

        void jna_set_ignition_can(byte val);

        void jna_set_harness_status(byte val);

        byte jna_get_harness_status();

        void jna_detect_harness_orientation();

        void jna_set_sbu1_voltage_mV(int val);

        void jna_set_sbu2_voltage_mV(int val);

        void jna_set_relay_driven(byte val);

        void jna_set_som_uart_wptr(short val);

        // Fake register value accessors
        long jna_get_reg_GPIOA_MODER();

        long jna_get_reg_GPIOB_MODER();

        long jna_get_reg_GPIOC_MODER();

        long jna_get_reg_GPIOD_MODER();

        long jna_get_reg_GPIOE_MODER();

        long jna_get_reg_GPIOF_MODER();

        long jna_get_reg_GPIOG_MODER();

        long jna_get_reg_GPIOA_ODR();

        long jna_get_reg_GPIOB_ODR();

        long jna_get_reg_GPIOC_ODR();

        long jna_get_reg_GPIOD_ODR();

        long jna_get_reg_GPIOB_PUPDR();

        long jna_get_reg_GPIOE_ODR();

        long jna_get_reg_GPIOF_ODR();

        long jna_get_reg_GPIOG_ODR();

        long jna_get_reg_ADC1_CR();

        long jna_get_reg_ADC2_CR();

        long jna_get_reg_RCC_CR();

        long jna_get_reg_RCC_AHB2LPENR();

        long jna_get_reg_RCC_AHB3LPENR();

        long jna_get_reg_RCC_AHB4LPENR();

        long jna_get_reg_SYSCFG_EXTICR0();

        long jna_get_reg_SYSCFG_EXTICR1();

        long jna_get_reg_SYSCFG_EXTICR2();

        long jna_get_reg_SYSCFG_EXTICR3();

        long jna_get_reg_EXTI_IMR1();

        long jna_get_reg_EXTI_RTSR1();

        long jna_get_reg_EXTI_FTSR1();

        long jna_get_reg_EXTI_PR1();

        long jna_get_reg_PWR_CR1();

        long jna_get_reg_PWR_CR3();

        long jna_get_reg_PWR_CPUCR();

        long jna_get_reg_SCB_SCR();

        long jna_get_reg_NVIC_ICER0();

        long jna_get_reg_NVIC_ICER7();

        long jna_get_reg_NVIC_ICPR0();

        long jna_get_reg_NVIC_ICPR7();

        int jna_get_irq_disabled();

        int jna_get_dsb_called();

        int jna_get_isb_called();

        int jna_get_wfi_entered();

        // CAN health inspection
        int jna_get_can_health_speed(int bus);

        int jna_get_can_health_data_speed(int bus);

        int jna_get_can_health_canfd_enabled(int bus);

        int jna_get_can_health_brs_enabled(int bus);

        int jna_get_can_health_canfd_non_iso(int bus);

        int jna_get_can_health_last_error(int bus);

        int jna_get_can_health_receive_error_cnt(int bus);

        int jna_get_can_health_transmit_error_cnt(int bus);

        int jna_get_can_health_can_core_reset_cnt(int bus);

        int jna_get_can_health_bus_off_cnt(int bus);

        int jna_get_can_health_error_warning(int bus);

        int jna_get_can_health_error_passive(int bus);

        int jna_get_can_health_last_data_error(int bus);

        int jna_get_can_health_total_error_cnt(int bus);

        int jna_get_can_health_total_rx_lost_cnt(int bus);


        void jna_call_update_can_health_pkt(int canNumber, int irReg);

        // FDCAN PSR/ECR setters (for test setup)
        void jna_set_fdcan_psr(int bus, int val);

        void jna_set_fdcan_ecr(int bus, int val);

        // SPI version packet (spi_version_packet + crc_checksum)
        int jna_spi_version_packet(byte[] buf);

        // Full firmware init — sets hardware to post-hardware-reset defaults
        void jna_panda_init();

        // Build config constants
        int jna_get_can_init_timeout_ms();

        // unused_funcs.h: init_bootloader (needs JNA since early_init is stubbed in e2e)
        void jna_unused_init_bootloader();

        // unused_funcs.h: set_fan_enabled via board function pointer
        // (needs JNA since has_fan==false on RED skips fan_tick)
        void jna_board_set_fan_enabled(int en);

        // SPI state machine (Phase F.5)
        int jna_spi_get_state();
        void jna_spi_set_state(int state);
        int jna_spi_get_can_tx_ready();
        void jna_spi_set_can_tx_ready(int ready);
        void jna_spi_write_rx_buf(byte[] data, int offset, int len);
        void jna_spi_read_tx_buf(byte[] out, int len);
        int jna_spi_rx_done();
        void jna_spi_tx_done(int reset);
        int jna_spi_get_error_count();
        void jna_spi_reset_error_count();

        // Phase J: additional coverage wrappers
        void jna_set_gpio_output_type_push_pull(int port_idx, int pin);  // J1
        void jna_harness_init();                                          // J2
        int jna_detect_with_pull(int port_idx, int pin, int pull_mode);   // J10
        int jna_get_can_health_total_tx_checksum_error_cnt(int bus);      // J3
        void jna_uart_overwrite_init(int fifo_size);                      // J5
        int jna_uart_put_char_overwrite(byte c);                          // J5
        int jna_uart_injectc_overwrite(byte c);                          // J5
        int jna_uart_get_rx_r_ptr();                                      // J5
        int jna_uart_get_tx_r_ptr();                                      // J5
    }

    private static final String ORIGINAL_LIB_PATH = PandaLib.libPath;
    private PandaLib lib = PandaLib.INSTANCE;

    private void reloadLibrary() {
        try {
            Path original = Path.of(ORIGINAL_LIB_PATH);
            Path temp = Files.createTempFile("libpanda_", ".dylib");
            Files.copy(original, temp, StandardCopyOption.REPLACE_EXISTING);
            temp.toFile().deleteOnExit();
            lib = Native.load(temp.toAbsolutePath().toString(), PandaLib.class);
            lib.jna_panda_init();
        } catch (IOException e) {
            throw new RuntimeException("Failed to reload native library", e);
        }
    }

    public int getSafetyTxBlocked() {
        return lib.jna_get_safety_tx_blocked();
    }

    public AdaptiveList<CanMessage> rxQueue() {
        int[] outAddr = new int[1];
        byte[] outBus = new byte[1];
        byte[] outRejected = new byte[1];
        byte[] outReturned = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];
        byte[] outExtended = new byte[1];
        byte[] outFd = new byte[1];

        var canMessages = new ArrayList<CanMessage>();
        if (lib.jna_can_pop_rx(outAddr, outBus, outRejected, outReturned, outData, outLen, outExtended, outFd)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new CanMessage(outAddr[0], Byte.toUnsignedInt(outBus[0]), data,
                    outRejected[0] != 0, outReturned[0] != 0,
                    outExtended[0] != 0, outFd[0] != 0));
        }
        return AdaptiveList.staticList(canMessages);
    }

    public AdaptiveList<CanMessage> txQueue(int bus) {
        int[] outAddr = new int[1];
        byte[] outReturned = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];
        byte[] outExtended = new byte[1];
        byte[] outFd = new byte[1];

        var canMessages = new ArrayList<CanMessage>();
        if (lib.jna_can_pop_tx(bus, outAddr, outReturned, outData, outLen, outExtended, outFd)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new CanMessage(outAddr[0], bus, data, false, outReturned[0] != 0,
                    outExtended[0] != 0, outFd[0] != 0));
        }
        return AdaptiveList.staticList(canMessages);
    }

    public void clearCanQueues() {
        lib.jna_can_clear_all();
    }

    // ---- CAN queue state manipulation for coverage testing ----

    @AllArgsConstructor
    @Getter
    public static class CanQueueState {
        private final int wPtr;
        private final int rPtr;
        private final int fifoSize;
    }

    public void setCanQueueState(int queueIdx, int wPtr, int rPtr) {
        lib.jna_set_can_queue_state(queueIdx, wPtr, rPtr);
    }

    public CanQueueState getCanQueueState(int queueIdx) {
        int[] outWPtr = new int[1];
        int[] outRPtr = new int[1];
        int[] outFifoSize = new int[1];
        lib.jna_get_can_queue_state(queueIdx, outWPtr, outRPtr, outFifoSize);
        return new CanQueueState(outWPtr[0], outRPtr[0], outFifoSize[0]);
    }

    public boolean canPushDirect(int queueIdx, int address, byte[] data, byte bus) {
        return lib.jna_can_push_direct(queueIdx, address, bus, data, (byte) data.length);
    }

    public AdaptiveList<CanMessage> canPopDirect(int queueIdx) {
        int[] outAddr = new int[1];
        byte[] outBus = new byte[1];
        byte[] outData = new byte[64];
        byte[] outLen = new byte[1];

        var canMessages = new ArrayList<CanMessage>();
        if (lib.jna_can_pop_direct(queueIdx, outAddr, outBus, outData, outLen)) {
            int len = Byte.toUnsignedInt(outLen[0]);
            byte[] data = new byte[len];
            System.arraycopy(outData, 0, data, 0, len);
            canMessages.add(new CanMessage(outAddr[0], Byte.toUnsignedInt(outBus[0]), data, false, false, false, false));
        }
        return AdaptiveList.staticList(canMessages);
    }

    public int canSlotsEmpty(int queueIdx) {
        return lib.jna_can_slots_empty(queueIdx);
    }

    private boolean lastCanPushResult;

    public boolean isCanPushResult() {
        return lastCanPushResult;
    }

    // Stored queue state for DAL assertions (cannot use parameterized getters in expressions)
    private int lastQueueWPtr;
    private int lastQueueRPtr;
    private int lastQueueFifoSize;
    private int lastCanSlotsEmpty;

    public int getLastQueueWPtr() {
        return lastQueueWPtr;
    }

    public int getLastQueueRPtr() {
        return lastQueueRPtr;
    }

    public int getLastQueueFifoSize() {
        return lastQueueFifoSize;
    }

    public int getLastCanSlotsEmptyVal() {
        return lastCanSlotsEmpty;
    }

    public void refreshQueueState(int queueIdx) {
        CanQueueState s = getCanQueueState(queueIdx);
        this.lastQueueWPtr = s.getWPtr();
        this.lastQueueRPtr = s.getRPtr();
        this.lastQueueFifoSize = s.getFifoSize();
    }

    public void refreshCanSlotsEmpty(int queueIdx) {
        this.lastCanSlotsEmpty = canSlotsEmpty(queueIdx);
    }

    public void canPushDirectAndStore(int queueIdx, int address, byte[] data, byte bus) {
        this.lastCanPushResult = canPushDirect(queueIdx, address, data, bus);
    }

    public void controlWrite(byte request, short param1, short param2, short length) {
        lib.jna_control_write(request, param1, param2, length);
    }

    public int canSend(int address, byte[] data, byte bus) {
        return lib.jna_can_send(address, bus, data, (byte) data.length);
    }

    public void clearAll() {
        reloadLibrary();
    }

    // ---- Bootkick FSM ----

    @AllArgsConstructor
    @Getter
    public static class Bootkick {
        private final int state;
        private final int resetTriggered;
        private final int waitingCountdown;
        private final int resetCountdown;
    }

    public Bootkick getBootkick() {
        return new Bootkick(
                lib.jna_get_bootkick_state(),
                lib.jna_get_bootkick_reset_triggered(),
                lib.jna_get_bootkick_waiting_countdown(),
                lib.jna_get_bootkick_reset_countdown()
        );
    }

    public void setIgnitionLine(boolean val) {
        lib.jna_set_ignition_line((byte) (val ? 1 : 0));
    }

    public int getIgnitionCan() {
        return lib.jna_get_ignition_can();
    }

    public void setIgnitionCan(boolean val) {
        lib.jna_set_ignition_can((byte) (val ? 1 : 0));
    }

    public void setHarnessStatus(int val) {
        lib.jna_set_harness_status((byte) val);
    }

    public int getHarnessStatus() {
        return lib.jna_get_harness_status() & 0xFF;
    }

    public void detectHarnessOrientation() {
        lib.jna_detect_harness_orientation();
    }

    public void setSbu1VoltageMV(int val) {
        lib.jna_set_sbu1_voltage_mV(val);
    }

    public void setSbu2VoltageMV(int val) {
        lib.jna_set_sbu2_voltage_mV(val);
    }

    public void setRelayDriven(int val) {
        lib.jna_set_relay_driven((byte) (val != 0 ? 1 : 0));
    }

    public void setSomUartWptr(int val) {
        lib.jna_set_som_uart_wptr((short) val);
    }

    // ---- FDCAN register inspection ----

    /**
     * One FDCAN peripheral's register state, exposed as byte-list properties.
     * Each list holds register bytes in little-endian order (index 0 = least significant byte).
     * <p>
     * CCCR:   Control — protocol config bits
     * IE:     Interrupt Enable — which events trigger IRQ
     * NBTP:   Nominal Bit Timing & Prescaler
     * DBTP:   Data Bit Timing & Prescaler
     * TXBC:   TX Buffer Configuration
     * RXF0C:  RX FIFO 0 Configuration
     * TXESC:  TX Element Size Configuration (64B CAN FD)
     * RXESC:  RX Element Size Configuration (64B CAN FD)
     * GFC:    Global Filter Configuration (0 = promiscuous mode)
     * ILE:    Interrupt Line Enable (INT0 + INT1)
     */
    @AllArgsConstructor
    @Getter
    public static class FdcanRegs {
        private final List<Byte> cccr;
        private final List<Byte> ie;
        private final List<Byte> nbtp;
        private final List<Byte> dbtp;
        private final List<Byte> txbc;
        private final List<Byte> rxf0c;
        private final List<Byte> txesc;
        private final List<Byte> rxesc;
        private final List<Byte> gfc;
        private final List<Byte> ile;
        private final List<Byte> ir;
        private final List<Byte> txfqs;
        private final List<Byte> txbar;
    }

    private static List<Byte> bytes(int val, int count) {
        var list = new ArrayList<Byte>();
        for (int i = 0; i < count; i++) {
            list.add((byte) ((val >>> (i * 8)) & 0xFF));
        }
        return list;
    }

    /**
     * All 3 FDCAN peripheral register snapshots — one per CAN bus.
     * Use in feature test as:
     * fdcanRegs[0]= { cccr: [...], ie: [...], ... }
     * fdcanRegs[1]= { cccr: [...], ie: [...], ... }
     * fdcanRegs[2]= { cccr: [...], ie: [...], ... }
     */
    public AdaptiveList<FdcanRegs> fdcanRegs() {
        var list = new ArrayList<FdcanRegs>();
        for (int i = 0; i < 3; i++) {
            list.add(new FdcanRegs(
                    bytes(lib.jna_get_fdcan_cccr(i), 2),
                    bytes(lib.jna_get_fdcan_ie(i), 4),
                    bytes(lib.jna_get_fdcan_nbtp(i), 4),
                    bytes(lib.jna_get_fdcan_dbtp(i), 4),
                    bytes(lib.jna_get_fdcan_txbc(i), 4),
                    bytes(lib.jna_get_fdcan_rxf0c(i), 4),
                    bytes(lib.jna_get_fdcan_txesc(i), 1),
                    bytes(lib.jna_get_fdcan_rxesc(i), 1),
                    bytes(lib.jna_get_fdcan_gfc(i), 1),
                    bytes(lib.jna_get_fdcan_ile(i), 1),
                    bytes(lib.jna_get_fdcan_ir(i), 4),
                    bytes(lib.jna_get_fdcan_txfqs(i), 4),
                    bytes(lib.jna_get_fdcan_txbar(i), 4)
            ));
        }
        return AdaptiveList.staticList(list);
    }

    // ---- Heartbeat state ----
    @AllArgsConstructor
    @Getter
    public static class Heartbeat {
        private final int counter;
        private final int lost;
        private final int disabled;
        private final int engaged;
    }

    public Heartbeat getHeartbeat() {
        return new Heartbeat(
                lib.jna_get_heartbeat_counter(),
                lib.jna_get_heartbeat_lost(),
                lib.jna_get_heartbeat_disabled(),
                lib.jna_get_heartbeat_engaged()
        );
    }

    // ---- Safety state ----
    @AllArgsConstructor
    @Getter
    public static class SafetyState {
        private final int controlsAllowed;
        private final int safetyMode;
        private final int sirenCountdown;
        private final int sirenEnabled;
        private final int sirenWasActive;
    }

    public SafetyState getSafetyState() {
        return new SafetyState(
                lib.jna_get_controls_allowed(),
                lib.jna_get_current_safety_mode(),
                lib.jna_get_siren_countdown(),
                lib.jna_get_siren_enabled(),
                lib.jna_get_siren_was_active()
        );
    }

    public void setControlsAllowed(int val) {
        lib.jna_set_controls_allowed(val);
    }

    public boolean isPowerSaveEnabled() {
        return lib.jna_get_power_save_enabled() != 0;
    }

    public int getAlternativeExperience() {
        return lib.jna_get_alternative_experience();
    }

    // ---- Power-save hardware call tracking ----

    @AllArgsConstructor
    @Getter
    public static class PowerSaveTracking {
        private final int irqEnableCount;
        private final int irqDisableCount;
        private final int lastIrqEnabledBus;
        private final boolean irqDisabledBus0;
        private final boolean irqDisabledBus1;
        private final boolean irqDisabledBus2;
        private final int irPowerValue;
    }

    public PowerSaveTracking getPowerSaveTracking() {
        return new PowerSaveTracking(
                lib.jna_get_irq_enable_call_count(),
                lib.jna_get_irq_disable_call_count(),
                lib.jna_get_last_irq_enabled_bus(),
                lib.jna_get_irq_disabled_bus(0) != 0,
                lib.jna_get_irq_disabled_bus(1) != 0,
                lib.jna_get_irq_disabled_bus(2) != 0,
                lib.jna_get_ir_power_value_at(0)
        );
    }

    // ---- CAN comms buffer state ----

    @AllArgsConstructor
    @Getter
    public static class CanCommsBuffers {
        private final int readBufferPtr;
        private final int readBufferTail;
        private final int writeBufferPtr;
        private final int writeBufferTail;
    }

    public CanCommsBuffers getCanCommsBuffers() {
        return new CanCommsBuffers(
                lib.jna_get_can_read_buffer_ptr(),
                lib.jna_get_can_read_buffer_tail(),
                lib.jna_get_can_write_buffer_ptr(),
                lib.jna_get_can_write_buffer_tail()
        );
    }

    // ---- USB endpoint simulation ----

    public void usbEp3Out(byte[] data) {
        lib.jna_usb_ep3_out(data, data.length);
    }

    public byte[] usbEp1In(int maxLen) {
        byte[] out = new byte[maxLen];
        int len = lib.jna_usb_ep1_in(out, maxLen);
        byte[] result = new byte[len];
        System.arraycopy(out, 0, result, 0, len);
        return result;
    }

    public List<Byte> getUsbEp1InBytes() {
        int len = lib.jna_usb_ep1_in_get_len();
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add((byte) lib.jna_usb_ep1_in_get_byte(i));
        }
        return list;
    }

    @AllArgsConstructor
    @Getter
    public static class PacketVersions {
        private final int healthVersion;
        private final int canVersionHash;
    }

    public PacketVersions getPacketVersions() {
        int[] outHealth = new int[1];
        int[] outCan = new int[1];
        lib.jna_get_packet_versions(outHealth, outCan);
        return new PacketVersions(outHealth[0], outCan[0]);
    }

    // ---- CAN FD bus_config ----

    @AllArgsConstructor
    @Getter
    public static class CanFdConfig {
        private final boolean canfdAuto0;
        private final boolean canfdAuto1;
        private final boolean canfdAuto2;
        private final boolean canfdNonIso0;
        private final boolean canfdNonIso1;
        private final boolean canfdNonIso2;
        private final boolean canfdEnabled0;
        private final boolean canfdEnabled1;
        private final boolean canfdEnabled2;
        private final boolean brsEnabled0;
        private final boolean brsEnabled1;
        private final boolean brsEnabled2;
        private final int canDataSpeed0;
        private final int canDataSpeed1;
        private final int canDataSpeed2;
    }

    public CanFdConfig getCanFdConfig() {
        return new CanFdConfig(
                lib.jna_get_bus_canfd_auto(0) != 0,
                lib.jna_get_bus_canfd_auto(1) != 0,
                lib.jna_get_bus_canfd_auto(2) != 0,
                lib.jna_get_bus_canfd_non_iso(0) != 0,
                lib.jna_get_bus_canfd_non_iso(1) != 0,
                lib.jna_get_bus_canfd_non_iso(2) != 0,
                lib.jna_get_bus_canfd_enabled(0) != 0,
                lib.jna_get_bus_canfd_enabled(1) != 0,
                lib.jna_get_bus_canfd_enabled(2) != 0,
                lib.jna_get_bus_brs_enabled(0) != 0,
                lib.jna_get_bus_brs_enabled(1) != 0,
                lib.jna_get_bus_brs_enabled(2) != 0,
                lib.jna_get_bus_can_data_speed(0),
                lib.jna_get_bus_can_data_speed(1),
                lib.jna_get_bus_can_data_speed(2)
        );
    }

    @AllArgsConstructor
    @Getter
    public static class ClockSource {
        private final int ccr1;
        private final int ccr2;
        private final int ccr3;
        private final int arr;
        private final int ccr4;
    }

    public ClockSource getClockSource() {
        return new ClockSource(
                lib.jna_get_TIM1_CCR1(),
                lib.jna_get_TIM1_CCR2(),
                lib.jna_get_TIM8_CCR3(),
                lib.jna_get_TIM1_ARR(),
                lib.jna_get_TIM1_CCR4()
        );
    }

    @AllArgsConstructor
    @Getter
    public static class ClockSourceInitState {
        private final int tim1Psc;
        private final int tim1Arr;
        private final int tim1Ccmr1;
        private final int tim1Ccmr2;
        private final int tim1Ccer;
        private final int tim1Ccr1;
        private final int tim1Ccr2;
        private final int tim1Ccr4;
        private final int tim1Dier;
        private final int tim1Smcr;
        private final int tim1Cr1;
        private final int tim1Cr2;
        private final int tim1Bdtr;
        private final int tim8Psc;
        private final int tim8Arr;
        private final int tim8Ccmr2;
        private final int tim8Ccr3;
        private final int tim8Ccer;
        private final int tim8Smcr;
        private final int tim8Cr1;
        private final int tim8Bdtr;
        private final long gpioAModer;
        private final long gpioAAfr1;
        private final long gpioBModer;
        private final long gpioBAfr1;
        private final int nvicDisableIrqCount;
        private final int nvicDisableIrq0;
        private final int nvicDisableIrq1;
    }

    public void clockSourceInit(boolean enableChannel1) {
        lib.jna_clock_source_init(enableChannel1 ? 1 : 0);
    }

    public ClockSourceInitState getClockSourceInit() {
        return new ClockSourceInitState(
                lib.jna_get_TIM1_PSC(),
                lib.jna_get_TIM1_ARR(),
                lib.jna_get_TIM1_CCMR1(),
                lib.jna_get_TIM1_CCMR2(),
                lib.jna_get_TIM1_CCER(),
                lib.jna_get_TIM1_CCR1(),
                lib.jna_get_TIM1_CCR2(),
                lib.jna_get_TIM1_CCR4(),
                lib.jna_get_TIM1_DIER(),
                lib.jna_get_TIM1_SMCR(),
                lib.jna_get_TIM1_CR1(),
                lib.jna_get_TIM1_CR2(),
                lib.jna_get_TIM1_BDTR(),
                lib.jna_get_TIM8_PSC(),
                lib.jna_get_TIM8_ARR(),
                lib.jna_get_TIM8_CCMR2(),
                lib.jna_get_TIM8_CCR3(),
                lib.jna_get_TIM8_CCER(),
                lib.jna_get_TIM8_SMCR(),
                lib.jna_get_TIM8_CR1(),
                lib.jna_get_TIM8_BDTR(),
                lib.jna_get_reg_GPIOA_MODER(),
                lib.jna_get_reg_GPIOA_AFR1(),
                lib.jna_get_reg_GPIOB_MODER(),
                lib.jna_get_reg_GPIOB_AFR1(),
                lib.jna_get_nvic_disable_irq_count(),
                lib.jna_get_nvic_disable_irq_at(0),
                lib.jna_get_nvic_disable_irq_at(1)
        );
    }

    // ---- LED PWM state (TIM3 registers configured by led_init / tres_init) ----
    @AllArgsConstructor
    @Getter
    public static class LedPwmState {
        private final int tim3Cr1;
        private final int tim3Arr;
        private final int tim3Ccmr1;
        private final int tim3Ccmr2;
        private final int tim3Ccer;
        private final int tim3Ccr1;
        private final int tim3Ccr2;
        private final int tim3Ccr3;
        private final int tim3Ccr4;
    }

    public LedPwmState getLedPwmState() {
        return new LedPwmState(
                lib.jna_get_TIM3_CR1(),
                lib.jna_get_TIM3_ARR(),
                lib.jna_get_TIM3_CCMR1(),
                lib.jna_get_TIM3_CCMR2(),
                lib.jna_get_TIM3_CCER(),
                lib.jna_get_TIM3_CCR1(),
                lib.jna_get_TIM3_CCR2(),
                lib.jna_get_TIM3_CCR3(),
                lib.jna_get_TIM3_CCR4()
        );
    }

    @AllArgsConstructor
    @Getter
    public static class BoardInitState {
        private final long gpioAModer;
        private final long gpioBModer;
        private final long gpioCModer;
        private final long gpioDModer;
        private final long gpioEModer;
        private final long gpioFModer;
        private final long gpioGModer;
        private final long gpioAOtyper;
        private final long gpioBOtyper;
        private final long gpioCOtyper;
        private final long gpioDOtyper;
        private final long gpioEOtyper;
        private final long gpioFOtyper;
        private final long gpioGOtyper;
        private final long gpioAOspeedr;
        private final long gpioBOspeedr;
        private final long gpioCOspeedr;
        private final long gpioDOspeedr;
        private final long gpioEOspeedr;
        private final long gpioFOspeedr;
        private final long gpioGOspeedr;
        private final long gpioAPupdr;
        private final long gpioBPupdr;
        private final long gpioCPupdr;
        private final long gpioDPupdr;
        private final long gpioEPupdr;
        private final long gpioFPupdr;
        private final long gpioGPupdr;
        private final long gpioAAfr0;
        private final long gpioAAfr1;
        private final long gpioBAfr0;
        private final long gpioBAfr1;
        private final long gpioCAfr0;
        private final long gpioCAfr1;
        private final long gpioDAfr0;
        private final long gpioDAfr1;
        private final long gpioEAfr0;
        private final long gpioEAfr1;
        private final long gpioAOdr;
        private final long gpioBOdr;
        private final long gpioCOdr;
        private final long gpioDOdr;
        private final long gpioEOdr;
        private final long gpioFOdr;
        private final long gpioGOdr;
        private final long pwrCr3;
    }

    public void boardInit() {
        lib.jna_board_init();
    }

    public BoardInitState getBoardInit() {
        return new BoardInitState(
                lib.jna_get_reg_GPIOA_MODER(),
                lib.jna_get_reg_GPIOB_MODER(),
                lib.jna_get_reg_GPIOC_MODER(),
                lib.jna_get_reg_GPIOD_MODER(),
                lib.jna_get_reg_GPIOE_MODER(),
                lib.jna_get_reg_GPIOF_MODER(),
                lib.jna_get_reg_GPIOG_MODER(),
                lib.jna_get_reg_GPIOA_OTYPER(),
                lib.jna_get_reg_GPIOB_OTYPER(),
                lib.jna_get_reg_GPIOC_OTYPER(),
                lib.jna_get_reg_GPIOD_OTYPER(),
                lib.jna_get_reg_GPIOE_OTYPER(),
                lib.jna_get_reg_GPIOF_OTYPER(),
                lib.jna_get_reg_GPIOG_OTYPER(),
                lib.jna_get_reg_GPIOA_OSPEEDR(),
                lib.jna_get_reg_GPIOB_OSPEEDR(),
                lib.jna_get_reg_GPIOC_OSPEEDR(),
                lib.jna_get_reg_GPIOD_OSPEEDR(),
                lib.jna_get_reg_GPIOE_OSPEEDR(),
                lib.jna_get_reg_GPIOF_OSPEEDR(),
                lib.jna_get_reg_GPIOG_OSPEEDR(),
                lib.jna_get_reg_GPIOA_PUPDR(),
                lib.jna_get_reg_GPIOB_PUPDR(),
                lib.jna_get_reg_GPIOC_PUPDR(),
                lib.jna_get_reg_GPIOD_PUPDR(),
                lib.jna_get_reg_GPIOE_PUPDR(),
                lib.jna_get_reg_GPIOF_PUPDR(),
                lib.jna_get_reg_GPIOG_PUPDR(),
                lib.jna_get_reg_GPIOA_AFR0(),
                lib.jna_get_reg_GPIOA_AFR1(),
                lib.jna_get_reg_GPIOB_AFR0(),
                lib.jna_get_reg_GPIOB_AFR1(),
                lib.jna_get_reg_GPIOC_AFR0(),
                lib.jna_get_reg_GPIOC_AFR1(),
                lib.jna_get_reg_GPIOD_AFR0(),
                lib.jna_get_reg_GPIOD_AFR1(),
                lib.jna_get_reg_GPIOE_AFR0(),
                lib.jna_get_reg_GPIOE_AFR1(),
                lib.jna_get_reg_GPIOA_ODR(),
                lib.jna_get_reg_GPIOB_ODR(),
                lib.jna_get_reg_GPIOC_ODR(),
                lib.jna_get_reg_GPIOD_ODR(),
                lib.jna_get_reg_GPIOE_ODR(),
                lib.jna_get_reg_GPIOF_ODR(),
                lib.jna_get_reg_GPIOG_ODR(),
                lib.jna_get_reg_PWR_CR3()
        );
    }

    public void setMicrosecondTimer(int val) {
        lib.jna_set_microsecond_timer(val);
    }

    public void setMcuUid(byte[] hex) {
        lib.jna_set_mcu_uid(hex, hex.length);
    }

    public void setInterruptCallRate(int index, int val) {
        lib.jna_set_interrupt_call_rate((byte) index, val);
    }

    // C3: Verify REGISTER_INTERRUPT populated the interrupts[] array
    public boolean isInterruptHandlerRegistered(int irqn) {
        var i = lib.jna_get_interrupt_handler(irqn);
        return i != 0;
    }

    public int getInterruptMaxCallRate(int irqn) {
        return lib.jna_get_interrupt_call_rate_max(irqn);
    }

    public void handleInterrupt(int irqn) {
        lib.jna_handle_interrupt(irqn);
    }

    public void interruptTimerTick() {
        lib.jna_interrupt_timer_tick();
    }

    public float getInterruptLoad() {
        return lib.jna_get_interrupt_load();
    }

    public int getInterruptCallCounter(int irqn) {
        return lib.jna_get_interrupt_call_counter(irqn);
    }

    public boolean isUnusedHandler(int irqn) {
        return lib.jna_is_unused_handler(irqn) != 0;
    }

    public void setSerial(byte[] hex) {
        lib.jna_set_serial(hex, hex.length);
    }

    public void setProvision(byte[] hex) {
        lib.jna_set_provision(hex, hex.length);
    }

    public void setAppCodeLen(int len) {
        lib.jna_set_app_code_len(len);
    }

    public void setSignatureChunk(int chunk, byte[] hex) {
        lib.jna_set_signature_chunk(chunk, hex, hex.length);
    }

    public void uartPush(byte[] data) {
        lib.jna_uart_push(data, data.length);
    }

    public int getRelayMalfunction() {
        return lib.jna_get_relay_malfunction();
    }

    public void setRelayMalfunction(int val) {
        lib.jna_set_relay_malfunction(val);
    }

    public void setRegisterDivergent(int enable) {
        lib.jna_set_register_divergent(enable);
    }

    public int readFaults() {
        return lib.jna_get_faults();
    }

    public int getFaultStatus() {
        return lib.jna_get_fault_status();
    }

    // Phase J: GPIO register getters for DAL assertions
    public int getGpiobOtyper()   { return (int) lib.jna_get_reg_GPIOB_OTYPER(); }
    public int getGpioaOtyper()   { return (int) lib.jna_get_reg_GPIOA_OTYPER(); }
    public int getGpioaOdr()      { return (int) lib.jna_get_reg_GPIOA_ODR(); }
    public int getGpiobPupdr()    { return (int) lib.jna_get_reg_GPIOB_PUPDR(); }

    public void triggerFault(int fault) {
        lib.jna_trigger_fault(fault);
    }

    public void recoverFault(int fault) {
        lib.jna_recover_fault(fault);
    }

    public void callTickHandler() {
        lib.jna_call_tick_handler();
    }

    public void setFanRpm(int val) {
        lib.jna_set_fan_rpm(val);
    }

    public void setHwType(int val) {
        lib.jna_set_hw_type(val);
    }

    public void setGitversion(String val) {
        lib.jna_set_gitversion(val);
    }

    public void setSomGpio(int val) {
        lib.jna_set_som_gpio(val);
    }

    public void setVoltageMV(int val) {
        lib.jna_set_voltage_mV(val);
    }

    public void setCurrentMA(int val) {
        lib.jna_set_current_mA(val);
    }

    // Direct state setters (bypass firmware pipeline)
    public void setCurrentSafetyMode(int val) {
        lib.jna_set_current_safety_mode(val);
    }

    public void setAlternativeExperience(int val) {
        lib.jna_set_alternative_experience(val);
    }

    public void setHeartbeatDisabled(int val) {
        lib.jna_set_heartbeat_disabled(val);
    }

    public void setHeartbeatCounter(int val) {
        lib.jna_set_heartbeat_counter(val);
    }

    public int getSafetyModeCnt() {
        return lib.jna_get_safety_mode_cnt();
    }

    public void setSafetyModeCnt(int val) {
        lib.jna_set_safety_mode_cnt(val);
    }

    public int getNvicResetCount() {
        return lib.jna_get_nvic_reset_count();
    }

    public int getEnterBootloaderMode() {
        return lib.jna_get_enter_bootloader_mode();
    }

    public boolean isStopModeRequested() {
        return lib.jna_get_stop_mode_requested() != 0;
    }

    // ---- enter_stop_mode tracking ----

    @AllArgsConstructor
    @Getter
    public static class StopModeRegs {
        private final long gpioAModer;
        private final long gpioBModer;
        private final long gpioCModer;
        private final long gpioDModer;
        private final long gpioEModer;
        private final long gpioFModer;
        private final long gpioGModer;
        private final long gpioAOdr;
        private final long gpioBOdr;
        private final long gpioCOdr;
        private final long gpioDOdr;
        private final long gpioEOdr;
        private final long gpioFOdr;
        private final long gpioGOdr;
        private final long gpioBPupdr;
        private final long adc1Cr;
        private final long adc2Cr;
        private final long rccCr;
        private final long rccAhb2lpenr;
        private final long rccAhb3lpenr;
        private final long rccAhb4lpenr;
        private final long syscfgExticr0;
        private final long syscfgExticr1;
        private final long syscfgExticr2;
        private final long syscfgExticr3;
        private final long extiImr1;
        private final long extiRtsr1;
        private final long extiFtsr1;
        private final long extiPr1;
        private final long pwrCr1;
        private final long pwrCpucr;
        private final long scbScr;
        private final long nvicIcer0;
        private final long nvicIcer7;
        private final long nvicIcpr0;
        private final long nvicIcpr7;
        private final boolean irqDisabled;
        private final boolean dsbCalled;
        private final boolean isbCalled;
        private final boolean wfiEntered;
    }

    public int getIrPwm() {
        return (int) lib.jna_get_ir_pwm();
    }

    public StopModeRegs getStopModeRegs() {
        return new StopModeRegs(
                lib.jna_get_reg_GPIOA_MODER(),
                lib.jna_get_reg_GPIOB_MODER(),
                lib.jna_get_reg_GPIOC_MODER(),
                lib.jna_get_reg_GPIOD_MODER(),
                lib.jna_get_reg_GPIOE_MODER(),
                lib.jna_get_reg_GPIOF_MODER(),
                lib.jna_get_reg_GPIOG_MODER(),
                lib.jna_get_reg_GPIOA_ODR(),
                lib.jna_get_reg_GPIOB_ODR(),
                lib.jna_get_reg_GPIOC_ODR(),
                lib.jna_get_reg_GPIOD_ODR(),
                lib.jna_get_reg_GPIOE_ODR(),
                lib.jna_get_reg_GPIOF_ODR(),
                lib.jna_get_reg_GPIOG_ODR(),
                lib.jna_get_reg_GPIOB_PUPDR(),
                lib.jna_get_reg_ADC1_CR(),
                lib.jna_get_reg_ADC2_CR(),
                lib.jna_get_reg_RCC_CR(),
                lib.jna_get_reg_RCC_AHB2LPENR(),
                lib.jna_get_reg_RCC_AHB3LPENR(),
                lib.jna_get_reg_RCC_AHB4LPENR(),
                lib.jna_get_reg_SYSCFG_EXTICR0(),
                lib.jna_get_reg_SYSCFG_EXTICR1(),
                lib.jna_get_reg_SYSCFG_EXTICR2(),
                lib.jna_get_reg_SYSCFG_EXTICR3(),
                lib.jna_get_reg_EXTI_IMR1(),
                lib.jna_get_reg_EXTI_RTSR1(),
                lib.jna_get_reg_EXTI_FTSR1(),
                lib.jna_get_reg_EXTI_PR1(),
                lib.jna_get_reg_PWR_CR1(),
                lib.jna_get_reg_PWR_CPUCR(),
                lib.jna_get_reg_SCB_SCR(),
                lib.jna_get_reg_NVIC_ICER0(),
                lib.jna_get_reg_NVIC_ICER7(),
                lib.jna_get_reg_NVIC_ICPR0(),
                lib.jna_get_reg_NVIC_ICPR7(),
                lib.jna_get_irq_disabled() != 0,
                lib.jna_get_dsb_called() != 0,
                lib.jna_get_isb_called() != 0,
                lib.jna_get_wfi_entered() != 0
        );
    }

    public void processStopMode() {
        lib.jna_process_stop_mode();
    }

    public void processWfiIdle() {
        lib.jna_process_wfi_idle();
    }

    public void tickSiren() {
        lib.jna_tick_siren();
    }

    // ---- CAN health inspection ----

    @AllArgsConstructor
    @Getter
    public static class CanHealth {
        private final int canSpeed;
        private final int canDataSpeed;
        private final boolean canfdEnabled;
        private final boolean brsEnabled;
        private final boolean canfdNonIso;
        private final int lastError;
        private final int lastDataError;
        private final int receiveErrorCnt;
        private final int transmitErrorCnt;
        private final int errorWarning;
        private final int errorPassive;
        private final int busOffCnt;
        private final int totalErrorCnt;
        private final int totalRxLostCnt;
        private final int canCoreResetCnt;
        private final int totalRxCnt;
        private final int totalFwdCnt;
        private final int totalTxChecksumErrorCnt;
    }

    public CanHealth getCanHealth(int bus) {
        return new CanHealth(
                lib.jna_get_can_health_speed(bus),
                lib.jna_get_can_health_data_speed(bus),
                lib.jna_get_can_health_canfd_enabled(bus) != 0,
                lib.jna_get_can_health_brs_enabled(bus) != 0,
                lib.jna_get_can_health_canfd_non_iso(bus) != 0,
                lib.jna_get_can_health_last_error(bus),
                lib.jna_get_can_health_last_data_error(bus),
                lib.jna_get_can_health_receive_error_cnt(bus),
                lib.jna_get_can_health_transmit_error_cnt(bus),
                lib.jna_get_can_health_error_warning(bus),
                lib.jna_get_can_health_error_passive(bus),
                lib.jna_get_can_health_bus_off_cnt(bus),
                lib.jna_get_can_health_total_error_cnt(bus),
                lib.jna_get_can_health_total_rx_lost_cnt(bus),
                lib.jna_get_can_health_can_core_reset_cnt(bus),
                lib.jna_get_can_health_total_rx_cnt(bus),
                lib.jna_get_can_health_total_fwd_cnt(bus),
                lib.jna_get_can_health_total_tx_checksum_error_cnt(bus)
        );
    }

    public CanHealth getCanHealth0() {
        return getCanHealth(0);
    }

    public void callUpdateCanHealthPkt(int canNumber, int irReg) {
        lib.jna_call_update_can_health_pkt(canNumber, irReg);
    }

    public void setFdcanPsr(int bus, int val) {
        lib.jna_set_fdcan_psr(bus, val);
    }

    public void setFdcanEcr(int bus, int val) {
        lib.jna_set_fdcan_ecr(bus, val);
    }

    // C3: Manual interrupt-driven CAN processing
    public void processCan(int canNumber) {
        lib.jna_process_can(canNumber);
    }

    public void canRx(int canNumber) {
        lib.jna_can_rx(canNumber);
    }

    // ---- FDCAN RX FIFO injection for can_rx() path coverage (E.4) ----

    public void writeRxFifo(int canNumber, int elementIndex, boolean extended, int addr,
                            boolean canfdFrame, boolean brsFrame, int dataLenCode, byte[] data) {
        lib.jna_fdcan_write_rx_fifo(canNumber, elementIndex,
                extended ? 1 : 0, addr,
                canfdFrame ? 1 : 0, brsFrame ? 1 : 0,
                (byte) dataLenCode, data);
    }

    public void setFdcanRxf0s(int canNumber, int val) {
        lib.jna_set_fdcan_rxf0s(canNumber, val);
    }

    public int getFdcanRxf0s(int canNumber) {
        return lib.jna_get_fdcan_rxf0s(canNumber);
    }

    public void setFdcanIr(int canNumber, int val) {
        lib.jna_set_fdcan_ir(canNumber, val);
    }

    public int getFdcanRxf0a(int canNumber) {
        return lib.jna_get_fdcan_rxf0a(canNumber);
    }

    public int getCanHealthTotalRxCnt(int bus) {
        return lib.jna_get_can_health_total_rx_cnt(bus);
    }

    public int getCanHealthTotalFwdCnt(int bus) {
        return lib.jna_get_can_health_total_fwd_cnt(bus);
    }

    public int getDirectSafetyRxInvalid() {
        return lib.jna_get_direct_safety_rx_invalid();
    }

    public int getDirectRxBufferOverflow() {
        return lib.jna_get_direct_rx_buffer_overflow();
    }

    public void setBusForwardingBus(int bus, int fwdBus) {
        lib.jna_set_bus_forwarding_bus(bus, fwdBus);
    }

    public void resetBusConfig() {
        lib.jna_reset_bus_config();
    }

    public boolean getBusConfigCanfdEnabled(int bus) {
        return lib.jna_get_bus_config_canfd_enabled(bus) != 0;
    }

    public boolean getBusConfigBrsEnabled(int bus) {
        return lib.jna_get_bus_config_brs_enabled(bus) != 0;
    }

    // ---- DAL-accessible properties for Then verification ----
    public int directSafetyRxInvalid() {
        return getDirectSafetyRxInvalid();
    }

    public int directRxBufferOverflow() {
        return getDirectRxBufferOverflow();
    }

    // Must use "is" prefix for boolean: DAL's isGetter() requires startsWith("is") for boolean return
    public boolean isCanfdEnabled0() {
        return getBusConfigCanfdEnabled(0);
    }

    public boolean isBrsEnabled0() {
        return getBusConfigBrsEnabled(0);
    }

    public int getFdcanRxf0aBus0() {
        return getFdcanRxf0a(0);
    }

    @AllArgsConstructor
    @Getter
    public static class RespBuffer {
        private final AdaptiveList<Byte> bytes;
        private final int len;
    }

    public RespBuffer getRespBuffer() {
        int len = lib.jna_get_resp_len();
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add((byte) lib.jna_get_resp_byte(i));
        }
        return new RespBuffer(AdaptiveList.staticList(list), len);
    }

    // ---- comms_endpoint2_write (SPI/USB endpoint 2 bulk write) ----

    @AllArgsConstructor
    @Getter
    public static class Endpoint2WriteResult {
        private final AdaptiveList<Byte> bytes;
        private final int len;
    }

    public void endpoint2Write(byte[] data) {
        lib.jna_comms_endpoint2_write(data, data.length);
    }

    public Endpoint2WriteResult getEndpoint2WriteResult() {
        int len = lib.jna_get_endpoint2_debug_len();
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add((byte) lib.jna_get_endpoint2_debug_byte(i));
        }
        return new Endpoint2WriteResult(AdaptiveList.staticList(list), len);
    }

    public int getFanPower() {
        return lib.jna_get_fan_power();
    }

    public int getFanCooldownCounter() {
        return lib.jna_get_fan_cooldown_counter();
    }

    // ---- Build config constants ----

    public int getCanInitTimeoutMs() {
        return lib.jna_get_can_init_timeout_ms();
    }

    // ---- unused_funcs.h: init_bootloader + set_fan_enabled (JNA since unreachable via e2e paths) ----

    public void unusedInitBootloader() {
        lib.jna_unused_init_bootloader();
    }

    public void boardSetFanEnabled(boolean en) {
        lib.jna_board_set_fan_enabled(en ? 1 : 0);
    }

    // ---- Health packet inspection ----

    @AllArgsConstructor
    @Getter
    public static class HealthPacket {
        private final int uptime;
        private final int voltage;
        private final int current;
        private final int safetyTxBlocked;
        private final int safetyRxInvalid;
        private final int safetyMode;
        private final int safetyParam;
        private final int heartbeatLost;
    }

    public HealthPacket getHealthPacket() {
        lib.jna_read_health_pkt();
        return new HealthPacket(
                lib.jna_get_health_uptime(),
                lib.jna_get_health_voltage(),
                lib.jna_get_health_current(),
                lib.jna_get_health_safety_tx_blocked(),
                lib.jna_get_health_safety_rx_invalid(),
                lib.jna_get_health_safety_mode(),
                lib.jna_get_health_safety_param(),
                lib.jna_get_health_heartbeat_lost()
        );
    }

    // ---- SPI version packet (spi_version_packet + crc_checksum) ----

    @AllArgsConstructor
    @Getter
    public static class SpiVersionResult {
        private final AdaptiveList<Byte> bytes;
        private final int len;
        private final byte crc8;
    }

    private SpiVersionResult spiVersionResult;

    public void spiVersionPacket() {
        byte[] buf = new byte[64];
        int len = lib.jna_spi_version_packet(buf);
        var list = new ArrayList<Byte>();
        for (int i = 0; i < len; i++) {
            list.add(buf[i]);
        }
        byte crc8 = (len > 0) ? buf[len - 1] : 0;
        this.spiVersionResult = new SpiVersionResult(AdaptiveList.staticList(list), len, crc8);
    }

    public SpiVersionResult getSpiVersionResult() {
        return spiVersionResult;
    }

    // ---- SPI state machine (Phase F.5) ----

    @AllArgsConstructor
    @Getter
    public static class SpiRxDetail {
        private final AdaptiveList<Byte> txBytes;
        private final int txLen;
        private final boolean ack;
    }

    @AllArgsConstructor
    @Getter
    public static class SpiStateResult {
        private final int state;
        private final int errorCount;
        private final SpiRxDetail rx;
    }

    private SpiStateResult spiStateResult;

    public void spiRxDone() {
        int txLen = lib.jna_spi_rx_done();
        int state = lib.jna_spi_get_state();
        int errorCount = lib.jna_spi_get_error_count();
        byte firstByte = 0;
        if (txLen > 0) {
            byte[] b = new byte[1];
            lib.jna_spi_read_tx_buf(b, 1);
            firstByte = b[0];
        }
        boolean ack = firstByte != 0x1F;
        var list = new ArrayList<Byte>();
        byte[] buf = new byte[txLen];
        lib.jna_spi_read_tx_buf(buf, txLen);
        for (int i = 0; i < txLen; i++) {
            list.add(buf[i]);
        }
        this.spiStateResult = new SpiStateResult(state, errorCount,
                new SpiRxDetail(AdaptiveList.staticList(list), txLen, ack));
    }

    public void spiTxDone(boolean reset) {
        lib.jna_spi_tx_done(reset ? 1 : 0);
        this.spiStateResult = new SpiStateResult(lib.jna_spi_get_state(), lib.jna_spi_get_error_count(), null);
    }

    public SpiStateResult getSpiStateResult() {
        return spiStateResult;
    }

    public int getSpiState() {
        return lib.jna_spi_get_state();
    }

    public void setSpiState(int state) {
        lib.jna_spi_set_state(state);
    }

    public void spiWriteRxBuf(byte[] data, int offset) {
        lib.jna_spi_write_rx_buf(data, offset, data.length);
    }

    public void resetSpiErrorCount() {
        lib.jna_spi_reset_error_count();
    }

    public boolean isSpiCanTxReady() {
        return lib.jna_spi_get_can_tx_ready() != 0;
    }

    public void setSpiCanTxReady(boolean ready) {
        lib.jna_spi_set_can_tx_ready(ready ? 1 : 0);
    }

    // ---- Phase J: Additional coverage wrappers ----

    // J1: set GPIO output type to PUSH_PULL
    public void setGpioOutputTypePushPull(int portIdx, int pin) {
        lib.jna_set_gpio_output_type_push_pull(portIdx, pin);
    }

    // J2: harness_init
    public void harnessInit() {
        lib.jna_harness_init();
    }

    public int detectWithPull(int portIdx, int pin, int pullMode) {
        return lib.jna_detect_with_pull(portIdx, pin, pullMode);
    }

    // J3: CAN health total_tx_checksum_error_cnt
    public int getCanHealthTotalTxChecksumErrorCnt(int bus) {
        return lib.jna_get_can_health_total_tx_checksum_error_cnt(bus);
    }

    // J5: uart overwrite tests
    public void uartOverwriteInit(int fifoSize) {
        lib.jna_uart_overwrite_init(fifoSize);
    }

    public int uartPutCharOverwrite(byte c) {
        return lib.jna_uart_put_char_overwrite(c);
    }

    public int uartInjectcOverwrite(byte c) {
        return lib.jna_uart_injectc_overwrite(c);
    }

    public int uartGetRxRPtr() {
        return lib.jna_uart_get_rx_r_ptr();
    }

    public int uartGetTxRPtr() {
        return lib.jna_uart_get_tx_r_ptr();
    }

    // DAL-accessible getters for uart overwrite test assertions
    public int getUartTxRPtr() { return uartGetTxRPtr(); }
    public int getUartRxRPtr() { return uartGetRxRPtr(); }
}
