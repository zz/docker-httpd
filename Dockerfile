FROM scratch
COPY src/httpd /httpd
CMD ["/httpd"]
