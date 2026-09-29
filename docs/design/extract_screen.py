# 시안 소스에서 화면 하나의 마크업만 꺼낸다. 사용: python extract_screen.py menu
import re, sys

SRC = 'startline-flow-export.dc.html'

def load_markup():
    s = open(SRC, encoding='utf-8', errors='replace').read()
    s = re.sub(r'\.ti-[a-z0-9-]+:before\{content:"[^"]*"\}', '', s)
    sc = re.search(r'<script type="text/x-dc"[^>]*>(.*?)</script>', s, re.S)
    return s[:sc.start()] + s[sc.end():]

def screen(key):
    m = load_markup()
    start = m.find('<sc-if value="{{ s_%s }}"' % key)
    if start < 0:
        raise SystemExit('화면 없음: %s' % key)
    depth, i = 0, start
    for t in re.finditer(r'<sc-if\b|</sc-if>', m[start:]):
        depth += 1 if t.group(0).startswith('<sc-if') else -1
        if depth == 0:
            return m[start:start + t.end()]
    raise SystemExit('닫는 태그 없음')

if __name__ == '__main__':
    print(screen(sys.argv[1]))
