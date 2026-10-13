import socket, json, sys
code = sys.stdin.read()
s = socket.create_connection(("127.0.0.1", 9876), timeout=60)
s.sendall(json.dumps({"type":"execute_code","params":{"code":code}}).encode())
buf=b""
while True:
    c=s.recv(65536)
    if not c: break
    buf+=c
    try: json.loads(buf); break
    except Exception: pass
print(buf.decode())
