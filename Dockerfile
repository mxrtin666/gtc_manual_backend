FROM node:20-alpine

LABEL authors="mxrtin666"

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 8080

CMD ["node","index.js"]