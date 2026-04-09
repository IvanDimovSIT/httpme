FROM ziglings/ziglang:latest AS builder

WORKDIR /app
COPY . .

RUN zig build --release=safe

FROM scratch
COPY --from=builder /app/zig-out/bin/httpme /httpme
EXPOSE 8080
CMD ["/httpme"]
