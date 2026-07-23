# önce react build alıyoruz
FROM node:20-alpine as builder
WORKDIR /app
COPY packages/frontend/package*.json ./
RUN npm install
COPY packages/frontend/ .
RUN npm run build

# sonra nginx'e atıyoruz
FROM nginx:alpine
# template envsubst ile islenir: BACKEND_HOST compose'da "backend", ECS'te "127.0.0.1"
ENV BACKEND_HOST=backend
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
