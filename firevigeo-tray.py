#!/usr/bin/python
# -*- coding: UTF-8 -*-
import wx
from pystray import MenuItem as item
import pystray
from PIL import Image
from subprocess import run
import os

xdg_home = os.environ['HOME']
file_path = r''+ xdg_home + '/.config/firevigeo/'

def init_check():
    if not os.path.exists(file_path):
        os.mkdir(file_path)

    if not os.path.exists(file_path + "tray.conf"):
        # create a file
        with open(file_path + "tray.conf", 'w') as fp:
            fp.write('start_port=5090\nend_port=5100')
    read_config()

def settings():
    app = MyApp(0)
    app.MainLoop()

def start():
    print("Start firevigeo!")
    p = run( [ 'firevigeo', '-s', read_config()[0], read_config()[1]] )
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

if not os.path.exists("/usr/share/firevigeo/icon.png"):
	image = Image.open("icon.png")
else:
	image = Image.open("/usr/share/firevigeo/icon.png")
menu = (item('Start firevigeo', start), item('Stop firevigeo', stop), item('Settings', settings), item('Close Tray', close))
icon = pystray.Icon("Firevigeo Control Tray", image, "Firevigeo-Control-Tray", menu)

def read_config():
    start_port = ""
    end_port = ""
    file = open(file_path + "tray.conf", 'r')
    content = file.read()
    paths = content.split("\n") #split it into lines
    for path in paths:
        if path.split("=")[0] == "start_port":
            start_port = path.split("=")[1]
        elif path.split("=")[0] == "end_port":
            end_port = path.split("=")[1]

    if start_port == "" and end_port == "":
        start_port = "5090"
        end_port = "5100"
    return start_port, end_port



def save_val(window, value_start, value_end):
    with open(file_path + "tray.conf", 'w') as fp:
        fp.write('start_port=' + str(value_start) + '\nend_port=' + str(value_end))


def save_val_hide(window, value_start, value_end):
    window.Hide()
    with open(file_path + "tray.conf", 'w') as fp:
        fp.write('start_port=' + str(value_start) + '\nend_port=' + str(value_end))


class settings_window(wx.Dialog):
	def __init__(self, *args, **kwds):
		# begin wxGlade: window.__init__
		kwds["style"] = kwds.get("style", 0) | wx.DEFAULT_DIALOG_STYLE
		wx.Dialog.__init__(self, *args, **kwds)
		self.SetSize((380, 380))
		self.SetTitle("Firevigeo-Controller-Settings")
		start_port = read_config()[0]
		end_port = read_config()[1]
		sizer_1 = wx.BoxSizer(wx.VERTICAL)

		text1 = wx.StaticText(self, wx.ID_ANY, "\nStart Port\n")
		sizer_1.Add(text1, 0, wx.LEFT, 20)

		self.spin_ctrl_1 = wx.SpinCtrl(self, wx.ID_ANY, start_port, min=5000, max=60000)
		sizer_1.Add(self.spin_ctrl_1, 0, wx.LEFT, 20)

		text2 = wx.StaticText(self, wx.ID_ANY, "\nEnd Port\n")
		sizer_1.Add(text2, 0, wx.LEFT, 20)

		self.spin_ctrl_2 = wx.SpinCtrl(self, wx.ID_ANY, end_port, min=5001, max=60000)
		sizer_1.Add(self.spin_ctrl_2, 0, wx.LEFT, 20)

		static_line_1 = wx.StaticLine(self, wx.ID_ANY, style=wx.LI_VERTICAL)
		static_line_1.SetMinSize((10, 30))
		sizer_1.Add(static_line_1, 0, wx.LEFT, 5)

		sizer_2 = wx.StdDialogButtonSizer()
		sizer_1.Add(sizer_2, 0, wx.ALIGN_RIGHT | wx.ALL, 4)

		self.button_OK = wx.Button(self, wx.ID_OK, "")
		self.button_OK.SetDefault()
		sizer_2.AddButton(self.button_OK)
		self.Bind(wx.EVT_BUTTON, lambda event: save_val_hide(self, self.spin_ctrl_1.GetValue(), self.spin_ctrl_2.GetValue()), self.button_OK)

		self.button_CANCEL = wx.Button(self, wx.ID_CANCEL, "")
		sizer_2.AddButton(self.button_CANCEL)

		self.button_APPLY = wx.Button(self, wx.ID_APPLY, "")
		sizer_2.AddButton(self.button_APPLY)
		self.Bind(wx.EVT_BUTTON, lambda event: save_val(self, self.spin_ctrl_1.GetValue(), self.spin_ctrl_2.GetValue()), self.button_APPLY)

		sizer_2.Realize()

		self.SetSizer(sizer_1)

		self.SetAffirmativeId(self.button_OK.GetId())
		self.SetEscapeId(self.button_CANCEL.GetId())

		self.Layout()

# end of class window
class MyApp(wx.App):
    def OnInit(self):
        self.frame = settings_window(None, wx.ID_ANY, "")
        self.SetTopWindow(self.frame)
        self.frame.Show()
        return True


if __name__ == "__main__":
    init_check()
    icon.run()
