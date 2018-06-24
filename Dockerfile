FROM alpine:3.7

RUN apk --update --no-cache add libc6-compat libstdc++ zlib ca-certificates
ADD ./txtblack.bin /app/txtblack.bin
ADD ./assets /app/assets
ADD ./t /app/t
ENV PORT 80
ENV PROD true
EXPOSE 80
CMD cd /app && ./txtblack.bin