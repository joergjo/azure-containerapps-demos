FROM eclipse-temurin:17-jre-jammy AS base
EXPOSE 8080

FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src src
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests clean package

FROM base AS final
WORKDIR /app
COPY --from=build /build/target/java-boot-todo-*.jar java-boot-todo.jar
ENTRYPOINT ["java", "-jar", "java-boot-todo.jar"]
