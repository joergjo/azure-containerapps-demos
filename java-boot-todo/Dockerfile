FROM eclipse-temurin:17-jre-jammy AS base
EXPOSE 8080

FROM eclipse-temurin:17-jdk-jammy AS build
WORKDIR /build

COPY mvnw  .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw -B dependency:go-offline 

COPY src src
RUN ./mvnw -B -DskipTests clean package 

FROM base AS final
WORKDIR /app
COPY --from=build /build/target/java-boot-todo-*.jar java-boot-todo.jar
ENTRYPOINT ["java", "-jar", "java-boot-todo.jar"]