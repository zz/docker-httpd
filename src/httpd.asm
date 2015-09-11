; httpd.asm
;
 
BITS 64
[list -]
      %include "unistd.inc"
      %include "sys/wait.inc"
      %include "sys/socket.inc"
[list +]

section .bss
 
sockfd:                 resq 1
sock_addr:              resq 1
 
section .data
 
; message to keep user confortable that the server is actually running
lf                        db 10
 
; the buffer to read the client request, in this application we only read and show the contents of such a request.
; Sometimes there is interesting info in it.  In more advanced webserver applications we need to parse the required
; page, serve the page and eventually perform cgi scripts.
buffer:                   times 16 db 0
.length: equ $-buffer
 
; A full webserver reply 200.  We can send other pages too. A full list of status codes can be found at
; http://en.wikipedia.org/wiki/List_of_HTTP_status_codes

reply:               ;   db 'HTTP/1.1 301 Moved Permanently', 10
                     ;   db 'Location: http://www.agguro.be/index.php', 10, 10   <-- example of redirect -->
                     
                        db 'HTTP/1.1 200 OK',10
                        db 'Content-length: 16',10                   ; the length of the webpage we will send back, calculated last-first+1
                        db 'Content-Type: text/html',10,10            ; the content type
                        db 'HTTP Hello World'
reply.length:           equ $-reply
 
port:                   db 0,80           ; port 4444 (256 * 17 + 92)

section .text
 
global _start
 
_start:
 
; create a socket
        mov     rax, SYS_SOCKET          ; call socket(SOCK_STREAM, AF_NET, 0);
        mov     rdi, PF_INET             ; PF_INET = 2
        mov     rsi, SOCK_STREAM         ; SOCK_STREAM = 1
        mov     rdx, IPPROTO_IP          ; IPPROTO_IP = 0
        syscall
        cmp     rax, 0
;        jz      .socketerror
        mov     QWORD[sockfd], rax
 
; fill in sock_addr structure (on stack)
        xor     r8, r8                   ; clear the value of r8
        mov     r8, INADDR_ANY           ; (INADDR_ANY = 0) - if changed to 100007Fx(IP address : 127.0.0.1) we can only connect locally
        push    r8                       ; push r8 to the stack
        push    WORD [port]              ; push our port number to the stack
        push    WORD AF_INET             ; push protocol argument to the stack (AF_INET = 2)
        mov     QWORD[sock_addr], rsp    ; Save the sock_addr_in
 
; bind the socket to the address, keep trying until we succeed.
; if the address is still in use, bind will fail, we can avoid this with the setsockopt syscall, but we use INADDR_ANY so anyone can
; bind to the server's socket.  Therefor I don't use setsockopt.
; You can read more here: http://hea-www.harvard.edu/~fine/Tech/addrinuse.html
; Instead I keep trying until the server allows us to bind again, in the mainwhile we wait ....
 
.tryagain: 
        mov     rax, SYS_BIND             ; bind(sockfd, sockaddr, addrleng);
        mov     rdi, qword[sockfd]        ; sockfd from socket syscall
        mov     rsi, qword[sock_addr]     ; sockaddr 
        mov     rdx, 16                   ; addrleng the ip address length
       syscall
        and     rax, rax
        jnz     .tryagain
 
.bindsucces:
        ; first end the previous line with LF
        mov     rsi, lf
        mov     rdx, 1
        syscall
 
        mov     rax, SYS_LISTEN           ; int listen(sockfd, backlog);
        mov     rdi, qword[sockfd]        ; sockfd
        xor     rsi, rsi                  ; backlog
        syscall
 
.acceptloop:
        mov     rax, SYS_ACCEPT           ; int accept(sockfd, sockaddr, socklen);
        mov     rdi, qword[sockfd]        ; sockfd
        xor     rsi, rsi                  ; sockaddr
        xor     rdx, rdx                  ; socklen
        syscall 
        cmp     rax, 0
        js      .acceptloop
        mov     r12, rax                  ; use the accept socket from here
 
        mov     rdi, -1                   ; following the original source we need two
        mov     rsi, 0                    ; WAIT4 to prevent zombies. I tried without it,
        mov     rdx, WNOHANG              ; with zombies as a result
        mov     rcx, 0
        mov     rax, SYS_WAIT4
        syscall
 
        mov     rdi, -1
        mov     rsi, 0
        mov     rdx, WNOHANG
        mov     rcx, 0
        mov     rax, SYS_WAIT4
        syscall
 
        ; we have accepted a connection, let a child do the work while the parent wait to accept other connections
        mov     rax, SYS_FORK
        syscall
        and     rax, rax
        jz      .serveclient              ; Child continues here
 
        mov     rdi, r12                  ; parent closes the connection
        mov     rax, SYS_CLOSE
        syscall
        jmp     .acceptloop               ; and go back to accept new incoming connections
 
.serveclient:
        ; the client has send a request, we read this and put it in a buffer
        mov     rax, SYS_READ
        mov     rdi, r12
        mov     rsi, buffer
        mov     rdx, buffer.length
        syscall
 
        ; here we should parse the request from client that's put in STDIN
        ; now we just reply with the so called "reply"
        ; decision making stuff comes here, exp: CGI scripts, request for additional pages etc...
        ; see the original source
 
        ; send the reply to the client
        mov     rdi, r12
        mov     rsi, reply
        mov     rdx, reply.length
        mov     rax, SYS_WRITE
        syscall
 
        ; we are done, exit Child process
        xor     rdi, rdi
        mov     rax, SYS_EXIT
        syscall
 
.exit:  
        xor     rdi, rdi
        mov     rax, SYS_EXIT
        syscall
