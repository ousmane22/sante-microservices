FROM openjdk:17-jdk-slim

COPY target/rdv-service.jar rdv-service.jar

ENTRYPOINT ["java","-jar","rdv-service.jar"]

EXPOSE 8082