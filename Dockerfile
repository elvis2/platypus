FROM alpine:3 AS base
RUN apk add --update nodejs npm

FROM base AS builder

ARG IBMID_CLIENT_ID
ARG IBMID_CLIENT_SECRET

WORKDIR /usr/app

COPY package*.json ./
COPY patches patches/
RUN npm ci

COPY converter/textbook-converter/requirements.txt converter/textbook-converter/
# py3-pyzmq is needed by pyyaml but pip is not able to compile it.
RUN apk add --no-cache g++ linux-headers python3 python3-dev py3-pip py3-pyzmq
RUN python3 -m venv .venv && source .venv/bin/activate
RUN python3 -m pip install -U pip \
  && python3 -m pip install -r converter/textbook-converter/requirements.txt

COPY converter converter/
COPY frontend frontend/
COPY server server/
COPY notebooks notebooks/
COPY translations translations/
COPY config.yaml ./

RUN npm run setup:secrets -- --ibmClientId $IBMID_CLIENT_ID --ibmClientSecret $IBMID_CLIENT_SECRET

RUN npm run build
# don't keep the notebooks
RUN find ./translations -type f -iname "*.ipynb" -delete

FROM base
WORKDIR /usr/app

COPY --from=builder /usr/app/package*.json ./
COPY --from=builder /usr/app/patches patches/
# npm ci --production is not working for some unknown reason
RUN npm install
COPY --from=builder /usr/app/server server/
COPY --from=builder /usr/app/config.yaml ./
COPY --from=builder /usr/app/public public/
COPY --from=builder /usr/app/frontend frontend/
COPY --from=builder /usr/app/notebooks/toc.yaml notebooks/
COPY --from=builder /usr/app/working working/
COPY --from=builder /usr/app/translations translations/

CMD ["npm", "start"]
