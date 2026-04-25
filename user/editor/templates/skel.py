import argparse
import tempfile
import sys
import os

class MyContextManager:
  def __init__(self):
    with tempfile.NamedTemporaryFile(mode='w', suffix='', delete=False) as f:
      sys.stdout.write("temp file")
      self.tmp_file = f.name
    print(self.tmp_file)

  def __enter__(self):
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    if hasattr(self, 'tmp_file') and os.path.exists(self.tmp_file):
      os.unlink(self.tmp_file)

def parse_args():
  parser = argparse.ArgumentParser()
  subparsers = parser.add_subparsers(dest="command", required=True)

  cmd_parser = subparsers.add_parser("cmd", help="cmd")
  cmd_parser.add_argument("arg", type=str, help="arg")

  return parser.parse_args()

def main():
  args = parse_args()

  with MyContextManager() as mcm:
    with open(mcm.tmp_file) as f:
      for line in f:
        print(line.strip())


  return 0

if __name__ == "__main__":
  SystemExit(main())
