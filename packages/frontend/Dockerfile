# Build stage only - nginx will serve the files
FROM node:20-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source files
COPY . .

# Build the application
RUN npm run build

# Final stage - just copy built files to a minimal image for volume sharing
FROM alpine:latest

# Copy built files
COPY --from=builder /app/dist /app/dist

# Keep container running (files will be shared via volume)
CMD ["tail", "-f", "/dev/null"]
