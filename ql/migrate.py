import re
import sys
import os.path

import glob

def migrate():
  print glob.glob("schema/*.sql")
