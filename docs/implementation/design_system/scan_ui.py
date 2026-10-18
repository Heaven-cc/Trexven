from pathlib import Path
import re,json
roots=[Path('lib'),Path('packages/trexven_operations/lib'),Path('../trexvenpos/lib')]
# Lexical matching respects comments and strings (including interpolated strings).
def close(s, start):
    depth=0; quote=None; i=start
    while i<len(s):
        if quote:
            if s[i]=='\\': i+=2; continue
            if s.startswith(quote,i): i+=len(quote);quote=None;continue
        elif s.startswith('//',i):
            j=s.find('\n',i);i=len(s) if j<0 else j;continue
        elif s.startswith('/*',i):
            j=s.find('*/',i+2);i=len(s) if j<0 else j+2;continue
        elif s[i] in "\"'":
            quote=s[i]*3 if s.startswith(s[i]*3,i) else s[i];i+=len(quote);continue
        elif s[i]=='(':depth+=1
        elif s[i]==')':
            depth-=1
            if depth==0:return i
        i+=1
    raise ValueError('unbalanced')
def args(s):
    result=[];start=0;stack=[];quote=None;i=0
    while i<len(s):
        if quote:
            if s[i]=='\\':i+=2;continue
            if s.startswith(quote,i):i+=len(quote);quote=None;continue
        elif s.startswith('//',i):
            j=s.find('\n',i);i=len(s) if j<0 else j;continue
        elif s[i] in "\"'":quote=s[i]*3 if s.startswith(s[i]*3,i) else s[i];i+=len(quote);continue
        elif s[i] in '([{':stack.append(s[i])
        elif s[i] in ')]}':stack.pop()
        elif s[i]==',' and not stack:result.append(s[start:i].strip());start=i+1
        i+=1
    if s[start:].strip():result.append(s[start:].strip())
    return result
if __name__=='__main__':
    data={}
    for p in [p for root in roots for p in root.rglob('*.dart')]:
        s=p.read_text(encoding='utf-8-sig')
        for m in re.finditer(r'\b(TextField|TextFormField|DropdownButtonFormField|InputDecoration)(?:<[^>]+>)?\(',s):
            st=m.end()-1;en=close(s,st)
            data.setdefault(m[1],set()).update(re.match(r'(\w+)\s*:',a)[1] for a in args(s[st+1:en]) if re.match(r'(\w+)\s*:',a))
    print(json.dumps({k:sorted(v) for k,v in data.items()},indent=2))
