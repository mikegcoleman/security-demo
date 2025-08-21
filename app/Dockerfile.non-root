# Use vulnerable Node.js version for security demo
FROM node:14.15.0-alpine

# Better version 
# FROM 22.18.0-alpine3.21

# Set working directory and fix ownership
WORKDIR /app
RUN chown node:node /app

USER node

# Copy package files
COPY --chown=node:node package.json wizexercise.txt ./

# Install dependencies 
RUN npm install --production

# Copy static directories (less likely to change)
COPY --chown=node:node views/ ./views/

# Copy application code (more likely to change)
COPY --chown=node:node app.js .

# Expose port
EXPOSE 8080

 

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8080/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1))"

# Start application
CMD ["node", "app.js"]