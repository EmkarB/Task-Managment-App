# önce react build alıyoruz
FROM node:20-alpine as builder
WORKDIR /app
COPY packages/frontend/package*.json ./
RUN npm install
COPY packages/frontend/ .
RUN npm run build

# sonra nginx'e atıyoruz
FROM nginx:alpine
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
