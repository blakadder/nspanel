# Reenigne.py  (c) Max Zuidberg MPL2.0
# Automatic reverse engineer (got it?) tool for nextion displays
# Adjust the following settings as you need and then run the script. no CLI.

import serial
import time
import struct

ser = serial.Serial()

# Adjust as needed
ser.port = "COM9"
ser.baudrate = 115200
ser.open()

# timeout in seconds
timeout = 2

# by default reading text from the screen is disabled because it's not possible
# to always read a string correctly with unknown hmi applications.
readText = False

# List of attributes that return a string (f.ex. .txt or file path attributes)
attTxt = ["txt"]

# Components and what to read from them
components = {
    121: {
        "name": "Page",
        "attributes": ["vscope", "sta"],
    },
    52: {
        "name": "Variable",
        "attributes": ["vscope", "sta", "val", "txt_maxl", "txt"],
    },
    54: {
        "name": "Number",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    59: {
        "name": "XFloat",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    116: {
        "name": "Text",
        "attributes": ["vscope", "x", "y", "w", "h", "txt_maxl", "txt"],
    },
    55: {
        "name": "Scrolling Text",
        "attributes": ["vscope", "x", "y", "w", "h", "txt_maxl", "txt"],
    },
    112: {
        "name": "Picture",
        "attributes": ["vscope", "x", "y", "w", "h", "pic"],
    },
    113: {
        "name": "Crop Picture",
        "attributes": ["vscope", "x", "y", "w", "h", "pic"],
    },
    58: {
        "name": "QR Code",
        "attributes": ["vscope", "x", "y", "w", "h", "txt_maxl", "txt"],
    },
    106: {
        "name": "Progress Bar",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    122: {
        "name": "Gauge",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    0: {
        "name": "Waveform",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    1: {
        "name": "Slider",
        "attributes": ["vscope", "x", "y", "w", "h", "minval", "maxval", "val"],
    },
    98: {
        "name": "Button",
        "attributes": ["vscope", "x", "y", "w", "h", "sta", "txt_maxl", "txt", "val"],
    },
    53: {
        "name": "Dual-state Button",
        "attributes": ["vscope", "x", "y", "w", "h", "sta", "txt_maxl", "txt", "val"],
    },
    56: {
        "name": "Checkbox",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    57: {
        "name": "Radio",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    67: {
        "name": "Switch",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    61: {
        "name": "Combo Box",
        "attributes": ["vscope", "x", "y", "w", "h", "val"],
    },
    68: {
        "name": "Text Select",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    62: {
        "name": "SLText",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    4: {
        "name": "Audio",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    60: {
        "name": "External Picture",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    2: {
        "name": "Gmov",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    3: {
        "name": "Video",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    66: {
        "name": "Data Record",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    63: {
        "name": "File Stream",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    65: {
        "name": "File Browser",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    109: {
        "name": "Hotspot",
        "attributes": ["vscope", "x", "y", "w", "h"],
    },
    51: {
        "name": "Timer",
        "attributes": ["vscope", "tim", "en"],
    },
    -1: {
        "name": "Unknown",
        "attributes": ["vscope", ],
    },
}

# Helper functions to interface with nextion
def acknowledge(code=0x01, timeout=2):
    termination = 0
    response = -1
    t = time.time()
    while termination < 3:
        if time.time() - t > timeout:
            return False
        if ser.in_waiting:
            temp = ser.read(1)[0]
            if temp == 0xff:
                termination += 1
            else:
                response = temp
    return (response == code)

def sendCmd(cmd, ack=True, timeout=2):
    if isinstance(cmd, str):
        cmd = cmd.encode("ascii")
    elif not isinstance(cmd, bytes):
        cmd = bytes(cmd)
    ser.reset_input_buffer()
    ser.write(cmd)
    ser.write(bytes(3 * [0xff]))
    if ack:
        return acknowledge(timeout=timeout)
    else:
        return True

def getVal(var:str, ext=".val", timeout=2):
    ser.reset_input_buffer()
    if ext and ext[0] != ".":
        ext = "." + ext
    sendCmd(("get " + var + ext).encode("ascii"), ack=False, timeout=timeout)
    data = b""
    done = False
    t = time.time()
    while not done:
        if time.time() - t > timeout:
            return None
        if ser.in_waiting:
            data += ser.read(1)
            if len(data) > 8:
                data = data[1:]
            if len(data) == 8:
                if data[0] == 0x71 and data[-1] == 0xff and data[-2] == 0xff and data[-3] == 0xff:
                    done = True
    return struct.unpack_from("<I", data, 1)[0]

def getTxt(var:str, ext=".txt", encoding="utf-8", timeout=2):
    ser.reset_input_buffer()
    if ext and ext[0] != ".":
        ext = "." + ext
    sendCmd(("get " + var + ext).encode("ascii"), ack=False, timeout=timeout)
    data = b""
    start = False
    end = 0
    done = False
    t = time.time()
    while not done:
        if time.time() - t > timeout:
            return None
        if ser.in_waiting:
            if not start:
                data = ser.read(1)
                if data[0] == 0x70:
                    start = True
                data = b""
            else:
                data += ser.read(1)
                if data[-1] == 0xff:
                    end += 1
                    if end == 3:
                        done = True
                    data = data[:-1]
    return data.decode(encoding=encoding)

def getType(id:int, timeout=2):
    ser.reset_input_buffer()
    sendCmd("prints b[{}].type,1".format(id), ack=False)
    t = time.time()
    while time.time() - t < timeout:
        if ser.in_waiting:
            return ser.read(1)[0]
            break
    return None

# Just in case, exit reparse mode
sendCmd("DRAKJHSUYDGBNCJHGJKSHBDN")

# Enable acknowledge on Nextion
if not sendCmd("bkcmd=3", timeout=timeout):
    raise Exception("Could not enable acknowledge on nextion. ")

# Count number of pages and objects
for page in range(0,255):
    if not sendCmd("page {}".format(page), timeout=timeout):
        break
    print("Page {: >3}:".format(page))
    for component in range(1,255):
        # check if we're still in range
        if component != getVal("b[{}].id".format(component), ext="", timeout=timeout):
            break
        type = getType(component, timeout=timeout)
        if type is None:
            break
        typeStr = "Unknown"
        typeSafe = -1
        if type in components:
            typeStr = components[type]["name"]
            typeSafe = type
        print(4 * " " + "Component {: >3}: ".format(component))
        padding = max([len("type")] + [len(e) for e in components[typeSafe]["attributes"]]) + 1
        print(8 * " " + "{} {} ({})".format("Type:".ljust(padding), type, typeStr))
        for att in components[typeSafe]["attributes"]:
            val = None
            if att in attTxt:
                if readText:
                    val = getTxt("b[{}].{}".format(component, att), ext="", timeout=timeout)
                    if val:
                        val = "\"" + val + "\""
            else:
                val = getVal("b[{}].{}".format(component, att), ext="", timeout=timeout)
            if val is None:
                continue
            print(8 * " " + "{} {}".format((att + ":").ljust(padding), val))

ser.close()
print("\nDone.")