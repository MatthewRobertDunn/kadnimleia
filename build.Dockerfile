FROM nimlang/nim:2.2.4-alpine-slim as build

RUN apk add --no-cache gdb git build-base