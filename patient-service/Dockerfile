FROM openjdk:17-jdk-slim

COPY target/patient-service.jar patient-service.jar

ENTRYPOINT ["java","-jar","patient-service.jar"]

EXPOSE 8081