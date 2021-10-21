import binascii
import struct
import codecs

print("Calculate NSPanel hex command from JSON payload\n")
value = input("Enter JSON:\n")

def findtype(value):
    if "relation" in value:
        # 86
        type = 134
    elif "ATC" in value:
        # 84
        type = 132
    elif "outlet" in value:
        # 87
        type = 135
    elif "HMI_dimOpen" in value:
        # 87
        type = 135
    elif "index" in value:
        # 86
        type = 134
    elif 'id":"' in value:
        # 86
        type = 134
    elif "params" in value:
        # 86
        type = 134
    elif "wifiState" in value:
        # 85
        type = 133
    elif "HMI_resources" in value:
        # 84
        type = 132
    elif "resourcetype" in value:
        # 84
        type = 132
    elif "temp" in value:
        # 83
        type = 131
    elif "year" in value:
        # 82
        type = 130
    elif "weather" in value:
        # 81
        type = 129
    elif "queryInfo" in value:
        # 80
        type = 128
    elif "ctype" in value:
        # 80
        type = 132    
    else:
        print("Type not found")
        type = 0
    return type

def crc16(data:bytes, poly:hex=0xA001) -> str:
    '''
        CRC-16 MODBUS HASHING ALGORITHM
    '''
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = ((crc >> 1) ^ poly
                   if (crc & 0x0001)
                   else crc >> 1)
    return crc
    
print("ns_type:", findtype(value))

json_payload = bytes(value, 'ascii')

header = binascii.unhexlify('55AA')
btype = binascii.unhexlify('86')
nsp_type = (findtype(value)).to_bytes(1, 'big')

print("length:", len(value))

length = len(value).to_bytes(2, 'little')

bytes_payload = header + nsp_type + length + json_payload

#print("bytes_payload:", bytes_payload)

msg_crc = crc16(bytes_payload)

#print('{:04x}'.format(msg_crc))

crc=struct.pack('H', msg_crc)

command=binascii.hexlify(bytes_payload + crc)

print("\n\n")
print("SSerialSend5", bytes.decode(command))