# =====================================================
# Stage 1: Build the React (Vite) frontend
# =====================================================
FROM node:22-alpine AS frontend-build

WORKDIR /app/employee-web

# Copy package files first so npm install is cached
COPY employee-web/package.json employee-web/package-lock.json ./
RUN npm ci

# Copy the rest of the frontend and build it
COPY employee-web/ ./
RUN npm run build
# Output: /app/employee-web/dist


# =====================================================
# Stage 2: Build the Spring Boot JAR (with React inside)
# =====================================================
FROM maven:3.9-eclipse-temurin-21 AS backend-build

WORKDIR /app/employee-service

# Copy pom.xml first so Maven dependencies are cached
COPY employee-service/pom.xml ./
RUN mvn dependency:go-offline -B

# Copy backend source code
COPY employee-service/src ./src

# Put the React build where Spring Boot serves static files
COPY --from=frontend-build /app/employee-web/dist ./src/main/resources/static

# Build the JAR
RUN mvn clean package -DskipTests -B
# Output: /app/employee-service/target/employee-service-0.0.1-SNAPSHOT.jar


# =====================================================
# Stage 3: Runtime image (only Java + the JAR)
# =====================================================
FROM eclipse-temurin:21-jre

WORKDIR /app

# Run as a non-root user (security best practice)
RUN useradd --system --uid 1001 appuser

COPY --from=backend-build /app/employee-service/target/*.jar app.jar

USER appuser

EXPOSE 8085

ENTRYPOINT ["java", "-jar", "app.jar"]