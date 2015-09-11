# A tiny (1.9 KB) httpd web server Docker Image Sample

I write a sample httpd server with X64 assembly, so It can build with a Docker image and run with docker daemon.

If you try yourself, first run `make` in src directory, then build Docker image with Dockerfile

```
docker build --no-cache -t httpd:tiny .
```

running image

```
docker run -d -p 8000:80 httpd:tiny
```

test 

```
curl -I localhost:8000
curl -L localhost:8000
```
