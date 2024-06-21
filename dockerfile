# Creating multi-stage build for production
FROM node:18-alpine as build
RUN apk update && apk add --no-cache build-base gcc autoconf automake zlib-dev libpng-dev vips-dev git > /dev/null 2>&1

ARG NPM_AUTH_TOKEN
ENV NPM_AUTH_TOKEN=${NPM_AUTH_TOKEN}

# Conditionally create .npmrc file only if NPM_AUTH_TOKEN is set
RUN if [ -n "$NPM_AUTH_TOKEN" ]; then \
    echo "//npm.pkg.github.com/:_authToken=$NPM_AUTH_TOKEN" > ~/.npmrc; \
    fi
RUN cat ~/.npmrc

ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

ARG DATABASE_CLIENT
ARG DATABASE_HOST
ARG DATABASE_PORT
ARG DATABASE_NAME
ARG DATABASE_USERNAME
ARG DATABASE_PASSWORD
ARG DATABASE_SSL
ARG APP_KEYS
ARG API_TOKEN_SALT
ARG ADMIN_JWT_SECRET
ARG TRANSFER_TOKEN_SALT
ARG JWT_SECRET
ARG HOST
ARG PORT
ARG BASE_URL

ENV DATABASE_CLIENT=${DATABASE_CLIENT}
ENV DATABASE_HOST=${DATABASE_HOST}
ENV DATABASE_PORT=${DATABASE_PORT}
ENV DATABASE_NAME=${DATABASE_NAME}
ENV DATABASE_USERNAME=${DATABASE_USERNAME}
ENV DATABASE_PASSWORD=${DATABASE_PASSWORD}
ENV DATABASE_SSL=${DATABASE_SSL}
ENV APP_KEYS=${APP_KEYS}
ENV API_TOKEN_SALT=${API_TOKEN_SALT}
ENV ADMIN_JWT_SECRET=${ADMIN_JWT_SECRET}
ENV TRANSFER_TOKEN_SALT=${TRANSFER_TOKEN_SALT}
ENV JWT_SECRET=${JWT_SECRET}
ENV HOST=${HOST}
ENV PORT=${PORT}
ENV BASE_URL=${BASE_URL}


WORKDIR /opt/
COPY package.json package-lock.json .npmrc ./
RUN npm install -g node-gyp
RUN npm config set fetch-retry-maxtimeout 600000 -g && npm install --only=production
ENV PATH /opt/node_modules/.bin:$PATH
WORKDIR /opt/app
COPY . .
RUN npm run build

# Creating final production image
FROM node:18-alpine

ARG USER_ID
ENV USER_ID=${USER_ID}
ARG GROUP_ID
ENV GROUP_ID=${GROUP_ID}

RUN apk add --no-cache vips-dev
ARG NODE_ENV=production
ENV NODE_ENV=${NODE_ENV}

USER $USER_ID:$GROUP_ID

WORKDIR /opt/
COPY --from=build /opt/node_modules ./node_modules
WORKDIR /opt/app
COPY --from=build /opt/app ./
ENV PATH /opt/node_modules/.bin:$PATH

USER root:root
RUN echo fs.inotify.max_user_watches=100000 >> /etc/sysctl.conf  # Set limit in container
RUN chown -R $USER_ID:$GROUP_ID /opt/app
USER $USER_ID:$GROUP_ID

EXPOSE 1337
CMD ["npm", "run", "start"]
