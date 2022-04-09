from stem.control import Controller
from stem.util.str_tools import get_size_label
import stem.connection
import stem.util.str_tools
import stem.util.system as s
import getpass
import argparse
import os
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--ctrlport", help="default: 9051 or 9151")
args = parser.parse_args()
control_port = int(args.ctrlport) if args.ctrlport else 'default'
try:
   controller = Controller.from_port("0.0.0.0", control_port)
except stem.SocketError as exc:
   print("Unable to connect to tor on port: " + str(control_port), str(exc))
   sys.exit(1)

with Controller.from_port("0.0.0.0", control_port) as controller:
   while True:
      try:
         controller.authenticate()
      except stem.connection.MissingPassword:
         pw = getpass.getpass("Enter Controller password: ")
         try:
            controller.authenticate(password = pw)
         except stem.connection.PasswordAuthFailed:
            print("Unable to authenticate, password is incorrect")
            print(":: Retry")
            continue
         except stem.connection.AuthenticationFailure as exc:
            print("Unable to authenticate: %s" % exc)
            sys.exit(1)
      break

   bw_rate = get_size_label(int(controller.get_conf('BandwidthRate', '0')))
   bw_burst = get_size_label(int(controller.get_conf('BandwidthBurst', '0')))
   bw_rerate = get_size_label(int(controller.get_effective_rate(default = controller.get_conf('BandwidthRate', '0'), burst = False)))
   print("The relay are configured at %s/s max, with bursts up to %s/s, effective rate to %s/s" % (bw_rate, bw_burst, bw_rerate))
