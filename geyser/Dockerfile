FROM eclipse-temurin:21-jre-alpine
WORKDIR /etc/geyser
RUN wget https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/standalone -O Geyser.jar
CMD ["java", "-Xms512M", "-Xmx512M", "-jar", "Geyser.jar"]
