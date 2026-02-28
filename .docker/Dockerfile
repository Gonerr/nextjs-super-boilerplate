FROM node:24.13.1
WORKDIR /usr/src/api

# Проверка и установка корректного значения API_ENV
ARG API_ENV=prod
RUN if [ "$API_ENV" != "prod" ] && [ "$API_ENV" != "stage" ]; then \
    echo "Error: API_ENV must be either 'prod' or 'stage'" && exit 1; \
    fi
ENV API_ENV=$API_ENV

RUN echo "API_ENV: $API_ENV"

# Копируем только необходимые файлы для установки зависимостей
COPY package*.json ./
COPY tsconfig*.json ./

# Проверяем наличие package-lock.json и устанавливаем зависимости
RUN if [ -f "package-lock.json" ]; then \
        echo 'package-lock.json found, using npm ci...' && \
        HUSKY=0 npm ci --prefer-offline --no-audit --legacy-peer-deps; \
    else \
        echo 'package-lock.json not found, falling back to npm install...' && \
        HUSKY=0 npm install --prefer-offline --no-audit --legacy-peer-deps; \
    fi

# Копируем исходники и собираем приложение
COPY . .
RUN npm run build:${API_ENV}

# Очистка dev зависимостей с флагом --legacy-peer-deps
RUN npm prune --production --legacy-peer-deps

HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/v1/healthcheck || exit 1

# Запуск приложения в соответствии с окружением
CMD ["sh", "-c", "npm run start:${API_ENV}"]
