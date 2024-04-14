ARG GOVERSION=1.22.2

FROM golang:${GOVERSION}-alpine AS build

WORKDIR /go/src/cs-spoa-bouncer

RUN apk add --update --no-cache make git
COPY . .

RUN make build

FROM alpine:latest
COPY --from=build /go/src/cs-spoa-bouncer/crowdsec-spoa-bouncer /usr/local/bin/crowdsec-spoa-bouncer
COPY --from=build /go/src/cs-spoa-bouncer/config/crowdsec-spoa-bouncer.yaml /etc/crowdsec/bouncers/crowdsec-spoa-bouncer.yaml
COPY --from=build /go/src/cs-spoa-bouncer/config/crowdsec-spoa-bouncer.yaml.local /etc/crowdsec/bouncers/crowdsec-spoa-bouncer.yaml.local

## Create a socket for the spoa to inherit root:haproxy user from official haproxy image
RUN touch /run/crowdsec-spoa.sock && chown 0:99 /run/crowdsec-spoa.sock && chmod 660 /run/crowdsec-spoa.sock

ENTRYPOINT ["/usr/local/bin/crowdsec-spoa-bouncer", "-c", "/etc/crowdsec/bouncers/crowdsec-spoa-bouncer.yaml"]