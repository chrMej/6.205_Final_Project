import serial
import time

PORT = "/dev/cu.usbserial-8874292300961"
BAUDRATE = 115200

try:
    ser = serial.Serial(
        port=PORT,
        baudrate=BAUDRATE,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE
    )
    

    ser.write(bytes([0xAA]))
    
    ser.reset_input_buffer()
    
    while True:
        if ser.in_waiting >= 3:
            data = ser.read(3)
            
            byte1_data = data[0] & 0x3F  # Bottom 6 bits
            byte2_data = data[1] & 0x3F  # Bottom 6 bits
            byte3_data = data[2] & 0x1F  # Bottom 5 bits
            
            alignment1 = (data[0] >> 6) & 0x3  # Should be 0b00
            alignment2 = (data[1] >> 6) & 0x3  # Should be 0b01
            alignment3 = (data[2] >> 6) & 0x3  # Should be 0b11
            
            value = (byte1_data | 
                    (byte2_data << 6) |
                    (byte3_data << 12))
            
            y = value & 0xFF          
            x = (value >> 8) & 0x1FF 
            
            print(f"Bits: {value:017b} <- {data.hex()} (alignments: {alignment1:02b},{alignment2:02b},{alignment3:02b}) -> ({x}, {y})")
                
        time.sleep(0.001)
            
except KeyboardInterrupt:
    print("\nExiting...")
except Exception as e:
    print(f"Error: {e}")
finally:
    try:
        ser.close()
        print("Port closed")
    except:
        pass