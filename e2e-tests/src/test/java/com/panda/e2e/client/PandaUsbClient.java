package com.panda.e2e.client;

import com.sun.jna.*;
import com.sun.jna.ptr.IntByReference;
import com.sun.jna.ptr.PointerByReference;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * Minimal USB client for panda firmware communication.
 * Uses JNA to call the system libusb-1.0 directly.
 */
public class PandaUsbClient implements PandaClient {

    private static final int USB_VID = 0x3801;
    private static final int USB_PID = 0xddee;

    private static final byte REQUEST_OUT = (byte) (0x00 | (0x02 << 5) | 0x00);
    private static final byte REQUEST_IN  = (byte) (0x80 | (0x02 << 5) | 0x00);

    private static final byte CTRL_SET_SAFETY_MODE = (byte) 0xdc;
    private static final byte CTRL_SET_CAN_LOOPBACK = (byte) 0xe5;
    private static final byte CTRL_CAN_CLEAR = (byte) 0xf1;
    private static final byte CTRL_HEALTH = (byte) 0xd2;

    private static final byte BULK_EP_OUT = 3;
    private static final byte BULK_EP_IN  = 1;

    private final LibUsb libusb;
    private Pointer handle;

    public PandaUsbClient() {
        this.libusb = LibUsb.INSTANCE;
        int rc = libusb.libusb_init(null);
        if (rc != 0) throw new RuntimeException("libusb_init failed: " + rc);
    }

    @Override
    public void connect() {
        Pointer device = findPandaDevice();
        if (device == null) throw new RuntimeException("No panda found (VID=0x3801, PID=0xddee)");
        PointerByReference handleRef = new PointerByReference();
        int rc = libusb.libusb_open(device, handleRef);
        if (rc != 0) throw new RuntimeException("libusb_open: " + libusb.libusb_error_name(rc));
        handle = handleRef.getValue();
        int claimRc = libusb.libusb_claim_interface(handle, 0);
        if (claimRc != 0) {
            libusb.libusb_close(handle);
            handle = null;
            throw new RuntimeException("libusb_claim_interface: " + libusb.libusb_error_name(claimRc));
        }
    }

    private Pointer findPandaDevice() {
        PointerByReference listRef = new PointerByReference();
        long count = libusb.libusb_get_device_list(null, listRef);
        if (count < 0) throw new RuntimeException("get_device_list: " + count);
        try {
            Pointer[] devices = listRef.getValue().getPointerArray(0, (int) count);
            for (Pointer device : devices) {
                var desc = new LibUsbDeviceDescriptor();
                if (libusb.libusb_get_device_descriptor(device, desc) == 0
                        && desc.idVendor == USB_VID && desc.idProduct == USB_PID) {
                    return device;
                }
            }
        } finally {
            libusb.libusb_free_device_list(listRef.getValue(), 1);
        }
        return null;
    }

    // ---- Control commands ----

    @Override
    public void setSafetyMode(int mode, int param) {
        controlWrite(REQUEST_OUT, CTRL_SET_SAFETY_MODE, mode, param, new byte[0], 1000);
    }

    @Override
    public void setCanLoopback(boolean enable) {
        controlWrite(REQUEST_OUT, CTRL_SET_CAN_LOOPBACK, enable ? 1 : 0, 0, new byte[0], 1000);
    }

    @Override
    public void canClear(int bus) {
        controlWrite(REQUEST_OUT, CTRL_CAN_CLEAR, bus, 0, new byte[0], 1000);
    }

    @Override
    public int getHealthSafetyMode() {
        byte[] data = controlRead(REQUEST_IN, CTRL_HEALTH, 0, 0, 59, 1000);
        return Byte.toUnsignedInt(data[36]);
    }

    // ---- CAN ----

    @Override
    public void canSend(int address, byte[] data, int bus) {
        byte[] packet = packCanBuffer(address, data, bus);
        IntByReference transferred = new IntByReference();
        int rc = libusb.libusb_bulk_transfer(handle, BULK_EP_OUT, packet, packet.length, transferred, 100);
        if (rc != 0) throw new RuntimeException("CAN send: " + libusb.libusb_error_name(rc));
    }

    public byte[] canRecv(int timeoutMs) {
        byte[] buffer = new byte[16384];
        IntByReference transferred = new IntByReference();
        int rc = libusb.libusb_bulk_transfer(handle, BULK_EP_IN, buffer, buffer.length, transferred, timeoutMs);
        if (rc != 0) {
            if (rc == LibUsb.LIBUSB_ERROR_TIMEOUT) return new byte[0];
            throw new RuntimeException("CAN recv: " + libusb.libusb_error_name(rc));
        }
        byte[] result = new byte[transferred.getValue()];
        System.arraycopy(buffer, 0, result, 0, result.length);
        return result;
    }

    // ---- Raw control ----

    private void controlWrite(byte reqType, byte req, int value, int index, byte[] data, int timeout) {
        int rc = libusb.libusb_control_transfer(handle, reqType, req,
                (short) value, (short) index, data, (short) data.length, timeout);
        if (rc < 0) throw new RuntimeException("controlWrite(0x" + Integer.toHexString(req & 0xFF) + "): " + libusb.libusb_error_name(rc));
    }

    private byte[] controlRead(byte reqType, byte req, int value, int index, int length, int timeout) {
        byte[] data = new byte[length];
        int rc = libusb.libusb_control_transfer(handle, reqType, req,
                (short) value, (short) index, data, (short) length, timeout);
        if (rc < 0) throw new RuntimeException("controlRead(0x" + Integer.toHexString(req & 0xFF) + "): " + libusb.libusb_error_name(rc));
        if (rc == length) return data;
        byte[] trimmed = new byte[rc];
        System.arraycopy(data, 0, trimmed, 0, rc);
        return trimmed;
    }

    // ---- CAN wire format (matching python/__init__.py pack_can_buffer) ----

    private static final int[] DLC_TO_LEN = {0, 1, 2, 3, 4, 5, 6, 7, 8, 12, 16, 20, 24, 32, 48, 64};
    private static final int[] LEN_TO_DLC = new int[65];
    static {
        for (int dlc = 0; dlc < DLC_TO_LEN.length; dlc++) {
            LEN_TO_DLC[DLC_TO_LEN[dlc]] = dlc;
        }
    }

    private static byte[] packCanBuffer(int address, byte[] data, int bus) {
        int dataLenCode = LEN_TO_DLC[data.length];
        // header[0] = (data_len_code << 4) | (bus << 1) | fd
        byte byte0 = (byte) ((dataLenCode << 4) | (bus << 1));
        // word_4b = (address << 3) | (extended << 2)
        int extended = (address >= 0x800) ? 1 : 0;
        int word4b = (address << 3) | (extended << 2);
        byte[] header = new byte[6];
        header[0] = byte0;
        header[1] = (byte) (word4b & 0xFF);
        header[2] = (byte) ((word4b >> 8) & 0xFF);
        header[3] = (byte) ((word4b >> 16) & 0xFF);
        header[4] = (byte) ((word4b >> 24) & 0xFF);
        // checksum
        byte checksum = 0;
        for (int i = 0; i < 5; i++) checksum ^= header[i];
        for (byte b : data) checksum ^= b;
        header[5] = checksum;

        byte[] packet = new byte[6 + data.length];
        System.arraycopy(header, 0, packet, 0, 6);
        System.arraycopy(data, 0, packet, 6, data.length);
        return packet;
    }

    /**
     * Unpack raw CAN buffer into (address, bus, data) tuples.
     * Bus values: 0-2 normal, 128+ = returned (echo), 192+ = rejected by safety.
     */
    public static List<PandaClient.CanMessage> unpackCanBuffer(byte[] dat) {
        List<PandaClient.CanMessage> msgs = new ArrayList<>();
        int pos = 0;
        while (pos + 6 <= dat.length) {
            int dataLen = DLC_TO_LEN[(dat[pos] >> 4) & 0xF];
            if (dataLen > dat.length - pos - 6) break;
            int bus = (dat[pos] >> 1) & 0x7;
            int word4b = ((dat[pos + 4] & 0xFF) << 24) | ((dat[pos + 3] & 0xFF) << 16)
                       | ((dat[pos + 2] & 0xFF) << 8) | (dat[pos + 1] & 0xFF);
            int address = word4b >> 3;
            if (((dat[pos + 1] >> 1) & 0x1) != 0) bus += 128;  // returned
            if ((dat[pos + 1] & 0x1) != 0) bus += 192;          // rejected
            byte[] msgData = Arrays.copyOfRange(dat, pos + 6, pos + 6 + dataLen);
            msgs.add(new PandaClient.CanMessage(address, bus, msgData));
            pos += 6 + dataLen;
        }
        return msgs;
    }

    @Override
    public List<PandaClient.CanMessage> canRecvParsed(int timeoutMs) {
        byte[] raw = canRecv(timeoutMs);
        return raw.length == 0 ? List.of() : unpackCanBuffer(raw);
    }

    @Override
    public void controlWrite(byte request, short param1, short param2) {
        controlWrite(REQUEST_OUT, request, param1, param2, new byte[0], 1000);
    }

    public record CanMessage(int address, int bus, byte[] data) {}

    /** Send an arbitrary safety mode value (for testing invalid mode fallback). */
    @Override
    public void setSafetyModeRaw(int mode, int param) {
        controlWrite(REQUEST_OUT, CTRL_SET_SAFETY_MODE, mode, param, new byte[0], 1000);
    }

    // ---- Lifecycle ----

    @Override
    public void close() {
        if (handle != null) {
            libusb.libusb_release_interface(handle, 0);
            libusb.libusb_close(handle);
            handle = null;
        }
        libusb.libusb_exit(null);
    }

    /**
     * JNA mapping for libusb-1.0.
     */
    public interface LibUsb extends Library {
        LibUsb INSTANCE = Native.load(
            System.getProperty("os.arch").equals("aarch64") && System.getProperty("os.name").contains("Mac")
                ? "/opt/homebrew/lib/libusb-1.0.dylib"
                : "usb-1.0",
            LibUsb.class);
        int LIBUSB_SUCCESS = 0;
        int LIBUSB_ERROR_TIMEOUT = -7;

        int libusb_init(PointerByReference ctx);
        void libusb_exit(Pointer ctx);
        long libusb_get_device_list(Pointer ctx, PointerByReference list);
        void libusb_free_device_list(Pointer list, int unrefDevices);
        int libusb_get_device_descriptor(Pointer device, LibUsbDeviceDescriptor desc);
        int libusb_open(Pointer device, PointerByReference handle);
        void libusb_close(Pointer handle);
        int libusb_claim_interface(Pointer handle, int iface);
        int libusb_release_interface(Pointer handle, int iface);
        int libusb_control_transfer(Pointer handle, byte requestType, byte request,
                                    short value, short index, byte[] data, short length, int timeout);
        int libusb_bulk_transfer(Pointer handle, byte endpoint, byte[] data, int length,
                                 IntByReference transferred, int timeout);
        String libusb_error_name(int code);
    }

    @Structure.FieldOrder({"bLength", "bDescriptorType", "bcdUSB", "bDeviceClass", "bDeviceSubClass",
            "bDeviceProtocol", "bMaxPacketSize0", "idVendor", "idProduct", "bcdDevice",
            "iManufacturer", "iProduct", "iSerialNumber", "bNumConfigurations"})
    public static class LibUsbDeviceDescriptor extends Structure {
        public byte bLength, bDescriptorType;
        public short bcdUSB;
        public byte bDeviceClass, bDeviceSubClass, bDeviceProtocol, bMaxPacketSize0;
        public short idVendor, idProduct, bcdDevice;
        public byte iManufacturer, iProduct, iSerialNumber, bNumConfigurations;
    }
}
