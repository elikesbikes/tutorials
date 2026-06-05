FROM alpine:3.19

# Runtime dependencies only — app files are bind-mounted from ./app/
RUN apk add --no-cache restic python3 curl bash tzdata

ENTRYPOINT ["/app/entrypoint.sh"]
