FROM node:14.3 as base

ENV APP_DIR /opt/marotinus

WORKDIR $APP_DIR

COPY package-lock.json package.json $APP_DIR/

RUN npm ci



FROM base as estagio_de_dev

ENTRYPOINT ["npx", "nodemon", "src/server.js"]




FROM base as estagio_de_prd

ENTRYPOINT ["node", "src/server.js"]

COPY src $APP_DIR/src