# https://stackoverflow.com/a/287944
HEADER = '\033[95m'
OKBLUE = '\033[94m'
OKGREEN = '\033[92m'
WARNING = '\033[93m'
FAIL = '\033[91m'
END = '\033[0m'
BOLD = '\033[1m'
UNDERLINE = '\033[4m'

verbose = False
debug = False

def log_received_request(url_path: str):
  log(f"{OKBLUE}{BOLD}Received {UNDERLINE}{url_path}{END} {OKBLUE}{BOLD}request{END}")

def log_http_request(verb: str, url_path: str, url: str, size: float=0):
  if size == 0:
    log(f"{HEADER}{BOLD}Sending {verb} {UNDERLINE}{url_path}{END} {HEADER}{BOLD}request to {url}{END}")
  else:
    log(f"{HEADER}{BOLD}Sending {verb} {UNDERLINE}{url_path}{END} {HEADER}{BOLD}request to {url} ({size:.1f} KiB){END}")

def log_http_response(verb: str, latency_ms: float):
  log(f"{OKGREEN}{BOLD}Received {verb} response after {latency_ms:.1f} ms{END}")

def log_action(action: str, msg: str):
  log(f"{OKGREEN}{BOLD}{UNDERLINE}{action}{END}: {msg}")

def log_debug(msg: str):
  if debug:
    log(f"{HEADER}{BOLD}{UNDERLINE}DEBUG{END}: {msg}")

def log(msg: str):
  if verbose or debug:
    print(msg)
