import serial
import time
import pygame
import sys

PORT = "/dev/cu.usbserial-8874292300961" 
BAUDRATE = 115200

WINDOW_WIDTH = 320
WINDOW_HEIGHT = 180
POINT_RADIUS = 3
POINT_COLOR = (255, 0, 0)  
BACKGROUND_COLOR = (0, 0, 0)  

try:
    ser = serial.Serial(
        port=PORT,
        baudrate=BAUDRATE,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE
    )

    pygame.init()
    screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
    clock = pygame.time.Clock()

    ser.write(bytes([0xAA]))

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                ser.close()
                sys.exit()

        if ser.in_waiting >= 3:  # Wait for 3 bytes
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

            print(f"({x}, {y})")
            
            screen.fill(BACKGROUND_COLOR)
            
            pygame.draw.circle(screen, POINT_COLOR, (x, y), POINT_RADIUS)
            
            pygame.display.flip()
            
        clock.tick(60)

except KeyboardInterrupt:
    print("\nEnd")
except serial.SerialException as e:
    print(f"Error opening serial port: {e}")
finally:
    pygame.quit()
    ser.close()