FROM java:8
VOLUME /tmp
ADD ./target/svca-service.jar /app.jar
RUN bash -c 'touch /app.jar'
RUN ln -snf /usr/share/zoneinfo/Asia/Shanghai  /etc/localtime && echo Asia/Shanghai > /etc/timezone
EXPOSE 8080
ENTRYPOINT ["java","-Dapp.id=svcaService","-javaagent:/opt/skywalking/agent/skywalking-agent.jar","-Dskywalking.agent.service_name=svcaService","-Dskywalking.collector.backend_service=skywalking-oap-server:11800","-jar","-Djava.security.egd=file:/dev/./urandom","/app.jar"]