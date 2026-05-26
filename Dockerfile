FROM eclipse-temurin:25-jdk-alpine AS builder

WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Copy source code
COPY src src

# Build application
RUN chmod +x mvnw && ./mvnw clean package -DskipTests

# Extract jar for faster startup
RUN mkdir -p target/dependency && cd target/dependency && \
    jar -xf ../digest-*.jar

# Runtime stage
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Copy from build stage
COPY --from=builder /app/target/dependency/BOOT-INF/lib ./lib
COPY --from=builder /app/target/dependency/BOOT-INF/classes ./classes
COPY --from=builder /app/target/dependency/META-INF ./META-INF

# Expose port for local testing
EXPOSE 8080

# Run application
ENTRYPOINT ["java", "-cp", ".:classes:lib/*", "com.example.digest.DigestApplication"]
