FROM openjdk:17-jdk-slim


COPY target/medecin-service.jar medecin-service.jar

ENTRYPOINT ["java","-jar","medecin-service.jar"]

EXPOSE 7070