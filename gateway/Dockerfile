FROM openjdk:17-jdk-slim


COPY target/gateway.jar gateway.jar

ENTRYPOINT ["java","-jar","gateway.jar"]

EXPOSE 9999