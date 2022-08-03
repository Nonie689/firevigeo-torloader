from pystray import MenuItem as item
import pystray
from PIL import Image
from subprocess import run


def start():
    print("Start firevigeo!")
    p = run( [ 'firevigeo', '-s' ] )
    if p.returncode != 0:
        print("Failed to start firevigeo!")
    else:
        print("Firevigeo has started!")

def stop():
    print("Stop firevigeo!")
    p = run( [ 'firevigeo', '-k' ] )
    if p.returncode != 0:
        print("Failed to start firevigeo!")
    else:
        print("Firevigeo has started!")

def close():
    print("Close Firevigeo Control Tray!")
    quit()

image = Image.open("icon.png")
menu = (item('Start firevigeo', start), item('Stop firevigeo', stop), item('Close Tray', close))
icon = pystray.Icon("Firevigeo Control Tray", image, "Firevigeo-Control-Tray", menu)
icon.run()
