import socket

HOST = "127.0.0.1"  # The server's hostname or IP address
PORT = 8080  # The port used by the server

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))
    b = bytearray(b"GET /f HTTP/1.1\r\n\r\n")
    b[5] = 169
    s.sendall(b)
    data = s.recv(1024)

print(f"Received {data!r}")