ARG revision=1.0.0

FROM eclipse-temurin:17-jre-jammy AS base
EXPOSE 8080

FROM eclipse-temurin:17-jdk-jammy AS build
ARG revision
WORKDIR /build
COPY mvnw  .
COPY .mvn .mvn
COPY pom.xml .
COPY src src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -B -DskipTests -Drevision=${revision} clean package

FROM base AS final
WORKDIR /app
COPY --from=build /build/target/java-boot-todo-*.jar java-boot-todo.jar
ENTRYPOINT ["java", "-jar", "java-boot-todo.jar"]