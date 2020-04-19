FROM java:8
VOLUME /tmp
ADD ./target/svcb-service.jar /app.jar
RUN bash -c 'touch /app.jar'
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime && echo Asia/Shanghai > /etc/timezone
EXPOSE 8070
ENTRYPOINT ["java","-jar","-Djava.security.egd=file:/dev/./urandom", "/app.jar"]