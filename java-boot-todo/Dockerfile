FROM eclipse-temurin:11-jre-focal AS base
EXPOSE 8080

FROM eclipse-temurin:11-jdk-focal AS build
WORKDIR /build

COPY mvnw  .
COPY .mvn .mvn
COPY pom.xml .
RUN ./mvnw -B dependency:go-offline 

COPY src src
RUN ./mvnw -B clean package -DskipTests

FROM base AS final
WORKDIR /app
COPY --from=build /build/target/java-boot-todo-*.jar java-boot-todo.jar
ENTRYPOINT ["java", "-jar", "java-boot-todo.jar"]