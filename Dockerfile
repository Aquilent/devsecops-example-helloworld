FROM frolvlad/alpine-oraclejdk8:slim
VOLUME /tmp
ADD webapp/target/spring-boot-docker-0.1.0.war app.war
RUN sh -c 'touch /app.war'
ENTRYPOINT ["java","-jar","/app.war"]
#ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-jar","/app.war"]