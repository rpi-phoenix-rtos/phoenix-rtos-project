# Smoke test for the _curses extension module.
#
# Lives here as a FILE rather than a `python3 -c '...'` one-liner because psh
# mangles nested quotes: the one-liner reached the interpreter as a broken
# string and died with "SyntaxError: unterminated string literal", which reads
# like a curses failure and is not one.
#
# Run: python3 /root/curses_smoke.py     (no quoting needed)
import sys

try:
    import curses
except Exception as exc:
    print("CURSES-IMPORT-FAIL", type(exc).__name__, exc)
    sys.exit(1)

print("CURSES-IMPORT-OK", curses.version)

# setupterm is the first thing that actually touches the terminfo database, so
# it separates "the .so loaded" from "curses can initialise". TERM comes from
# psh (which sets TERM=linux); the ncurses port compiles in a linux fallback.
try:
    curses.setupterm()
    print("CURSES-SETUPTERM-OK", "cols=%s" % curses.tigetnum("cols"))
except Exception as exc:
    print("CURSES-SETUPTERM-FAIL", type(exc).__name__, exc)
    sys.exit(2)

print("CURSES-PY-PASS")
