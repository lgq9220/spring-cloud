FROM java:8
VOLUME /tmp
ADD ./target/auth-service.jar /app.jar
RUN bash -c 'touch /app.jar'
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime && echo Asia/Shanghai > /etc/timezone
EXPOSE 5000
ENTRYPOINT ["java","-Dapp.id=authService","-javaagent:/opt/skywalking/agent/skywalking-agent.jar","-Dskywalking.agent.service_name=authService","-Dskywalking.collector.backend_service=skywalking-oap-server:11800","-jar","-Djava.security.egd=file:/dev/./urandom","/app.jar"]