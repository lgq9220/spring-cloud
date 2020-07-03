# 基于 Spring Cloud 的微服务架构

> kubectl create clusterrolebinding permissive-binding   --clusterrole=cluster-admin   --user=admin   --user=kubelet   --group=system:serviceaccounts


本项目Fork自https://github.com/zhangxd1989/spring-boot-cloud，关于原项目的介绍可查看

https://gitee.com/zhangxd/spring-boot-cloud

或 https://github.com/zhangxd1989/spring-boot-cloud

本项目仅对原项目中的打包与部署方面进行了修改，其他地方未进行变动

# 技术栈
* Spring boot - 微服务的入门级微框架，用来简化 Spring 应用的初始搭建以及开发过程。
* Eureka - 云端服务发现，一个基于 REST 的服务，用于定位服务，以实现云端中间层服务发现和故障转移。
* Spring Cloud Config - 配置管理工具包，让你可以把配置放到远程服务器，集中化管理集群配置，目前支持本地存储、Git 以及 Subversion。
* Hystrix - 熔断器，容错管理工具，旨在通过熔断机制控制服务和第三方库的节点,从而对延迟和故障提供更强大的容错能力。
* Zuul - Zuul 是在云平台上提供动态路由，监控，弹性，安全等边缘服务的框架。Zuul 相当于是设备和 Netflix 流应用的 Web 网站后端所有请求的前门。
* Spring Cloud Bus - 事件、消息总线，用于在集群（例如，配置变化事件）中传播状态变化，可与 Spring Cloud Config 联合实现热部署。
* Spring Cloud Sleuth - 日志收集工具包，封装了 Dapper 和 log-based 追踪以及 Zipkin 和 HTrace 操作，为 SpringCloud 应用实现了一种分布式追踪解决方案。
* Ribbon - 提供云端负载均衡，有多种负载均衡策略可供选择，可配合服务发现和断路器使用。
* Turbine - Turbine 是聚合服务器发送事件流数据的一个工具，用来监控集群下 hystrix 的 metrics 情况。
* Spring Cloud Stream - Spring 数据流操作开发包，封装了与 Redis、Rabbit、Kafka 等发送接收消息。
* Feign - Feign 是一种声明式、模板化的 HTTP 客户端。
* Spring Cloud OAuth2 - 基于 Spring Security 和 OAuth2 的安全工具包，为你的应用程序添加安全控制。

此项目新增
* io.fabric8.docker-maven-plugin - dokcer打包插件。
* skywalking - 无侵入的服务监控。

# 应用架构

该项目包含 8 个服务

* registry - 服务注册与发现
* config - 外部配置
* monitor - 监控
* zipkin - 分布式跟踪
* gateway - 代理所有微服务的接口网关
* auth-service - OAuth2 认证服务
* svca-service - 业务服务A
* svcb-service - 业务服务B


# rancher+kubernetes+skywalking部署流程
## linux环境准备
3台linux,笔者这里选择的是通过虚拟机安装的centos7 minimal 

|  ip   | serverName  |
|  ----  | ----  |
| 192.168.113.143  |  rancher-server |
| 192.168.113.144  | k8s-node1 |
| 192.168.113.145  | k8s-node2 |


### centos7 minimal安装ifconfig
> ip addr 找到网卡

> vi /etc/sysconfig/network-scripts/ifcfg-enp0s3

ONBOOT修改为yes

> service network restart

> yum provides ifconfig

> yum install net-tools

### 关闭防火墙
> systemctl stop firewalld

> systemctl disable firewalld

### 关闭selinux
> sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config setenforce 0 //令配置立即生效

### 开启ipvs
使用ipvs替换iptables,kubeproxy中设置

要启用ipvs，必须启用转发功能
```bash
cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl -p
```
永久支持ipvs

```
yum -y install ipvsadm  ipset

# 临时生效
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4

# 永久生效
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF
```


```
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_fo ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
for kernel_module in \${ipvs_modules}; do
    /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        /sbin/modprobe \${kernel_module}
    fi
done
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep ip_vs

```

### 修改每个服务器中的host
```bash
192.168.113.143 rancher-server
192.168.113.144 k8s-node1
192.168.113.145 k8s-node2
```
### 修改hostname
> hostnamectl set-hostname rancher-server

查看hostname

> hostname

## docker安装 

```bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum list docker-ce --showduplicates | sort -r
yum install docker-ce-18.06.3.ce
systemctl start docker
```

配置好加速器
```
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://yourname.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 安装rancher

```
docker pull rancher/rancher
mkdir -p /docker_volume/rancher_home/rancher
mkdir -p /docker_volume/rancher_home/auditlog
```

启动
```
docker run -d --restart=unless-stopped -p 80:80 -p 443:443 \
-v /docker_volume/rancher_home/rancher:/var/lib/rancher \
-v /docker_volume/rancher_home/auditlog:/var/log/auditlog \
--name rancher rancher/rancher
```

待启动完毕后自行搭建好k8s集群，并将kubeproxy设为ipvs工作方式

## 节点安装kubectl

安装kubectl
```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
> yum install -y  kubectl

```
vi ~/.kube/config
```

## 服务安装

```
#-------------定义RabbitMQ部署-----------------
apiVersion: apps/v1
kind: Deployment
metadata:
 name: rabbit
spec:
 replicas: 1
 selector:
   matchLabels:
     app: rabbit
 strategy:
   rollingUpdate:
     maxSurge: 25%
     maxUnavailable: 25%
   type: RollingUpdate
 template:
   metadata:
     labels:
       app: rabbit
   spec:
     containers:
     - image: /rabbitmq:latest
       imagePullPolicy: IfNotPresent
       name: rabbit
       ports:
       - containerPort: 15672
         name: rabbit15672
         protocol: TCP
       - containerPort: 5672 
         name: rabbit5672 
         protocol: TCP
---
#-----------------定义rabbit的代理服务,serviceName一定要和代码中的一致-----------
apiVersion: v1
kind: Service
metadata:
 name: rabbitmq
spec:
 ports:
 - name: rabbit32672
   nodePort: 32672
   port: 15672
   protocol: TCP
   targetPort: 15672
 - name: rabbit30672 
   nodePort: 30672 
   port: 5672 
   protocol: TCP 
   targetPort: 5672
 selector:
   app: rabbit
 type: NodePort
```

在浏览器中输入：http://host:32672/，访问部署好的RabbitMQ。在登录页面输入用户名和密码（此处初始user/bitnami），系统将会进入RabbitMQ的主页。

### 项目打包

> 登录 sudo docker login --username=[username] ccr.ccs.tencentyun.com

```
[root@VM_6_222_centos ~]# sudo docker login --username=aaabbbccc ccr.ccs.tencentyun.com
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@VM_6_222_centos ~]# 
```

进行push
```
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/zipkin:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/svcb-service:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/svca-service:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/auth-service:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/monitor:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/gateway:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/registry:latest
docker push ccr.ccs.tencentyun.com/spring-boot-cloud/config:latest
```

调试网络安装telnet

在docker内安装telnet
```
mv /etc/apt/sources.list /etc/apt/sources.list.bak && echo "deb http://mirrors.163.com/debian/ jessie main non-free contrib" >/etc/apt/sources.list && echo "deb http://mirrors.163.com/debian/ jessie-proposed-updates main non-free contrib" >>/etc/apt/sources.list && echo "deb-src http://mirrors.163.com/debian/ jessie main non-free contrib" >>/etc/apt/sources.list && echo "deb-src http://mirrors.163.com/debian/ jessie-proposed-updates main non-free contrib" >>/etc/apt/sources.list
```

> apt-get update

> apt-get install telnet -y

> apt-get install net-tools -y



### kubernetes中部署skywalking
####  skywalking-oap-server
```
apiVersion: apps/v1
kind: Deployment
metadata:
 name: skywalking-oap-server
spec:
 replicas: 1
 selector:
   matchLabels:
     app: skywalking-oap-server
 template:
   metadata:
     labels:
       app: skywalking-oap-server
   spec:
     containers:
     - image: apache/skywalking-oap-server:latest
       imagePullPolicy: IfNotPresent
       name: skywalking-oap-server
       ports:
        - containerPort: 11800
          name: grpc
        - containerPort: 12800
          name: rest
---
#-----------------定义skywalking的代理服务--------------
apiVersion: v1
kind: Service
metadata:
 name: skywalking-oap-server
spec:
 ports:
 - name: grpcporst
   nodePort: 31800
   port: 11800
   protocol: TCP
   targetPort: 11800
 - name: restport
   nodePort: 32100
   port: 12800
   protocol: TCP 
   targetPort: 12800
 selector:
   app: skywalking-oap-server
 type: NodePort
```

#### skywalking-ui
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: skywalking-ui
  labels:
    app: skywalking-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: skywalking-ui
  template:
    metadata:
      labels:
        app: skywalking-ui
    spec:
      containers:
      - name: skywalking-ui
        image: apache/skywalking-ui:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: httpport
        env:
        - name: SW_OAP_ADDRESS
          value: skywalking-oap-server:12800
---
#-----------------定义skywalking-ui的代理服务--------------
apiVersion: v1
kind: Service
metadata:
  name: skywalking-ui
  labels:
    service: skywalking-ui
spec:
  ports:
  - port: 8080
    name: httpport
    targetPort: 8080
  type: ClusterIP
  selector:
    app: skywalking-ui
---
#-----------------定义skywalking-ui的ingress--------------
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: skywalking-ui
spec:
  rules:
    - host: skywalking-ui.springcloud.com
      http:
        paths:
          - backend:
              serviceName: skywalking-ui
              servicePort: 8080
```

#### skywalking-agent
自建,参考https://hub.docker.com/r/prophet/skywalking-agent
```
FROM alpine:3.8

LABEL maintainer="761396462@qq.com"

ENV SKYWALKING_VERSION=7.0.0

ADD http://mirrors.tuna.tsinghua.edu.cn/apache/skywalking/${SKYWALKING_VERSION}/apache-skywalking-apm-${SKYWALKING_VERSION}.tar.gz /

RUN tar -zxvf /apache-skywalking-apm-${SKYWALKING_VERSION}.tar.gz && \
    mv apache-skywalking-apm-bin skywalking && \
    mv /skywalking/agent/optional-plugins/apm-trace-ignore-plugin* /skywalking/agent/plugins/ && \
    echo -e "\n# Ignore Path" >> /skywalking/agent/config/agent.config && \
    echo "# see https://github.com/apache/skywalking/blob/v7.0.0/docs/en/setup/service-agent/java-agent/agent-optional-plugins/trace-ignore-plugin.md" >> /skywalking/agent/config/agent.config && \
    echo 'trace.ignore_path=${SW_IGNORE_PATH:/health}' >> /skywalking/agent/config/agent.config
```

> docker build -t ccr.ccs.tencentyun.com/haiyang/skywalking-agent:7.0.0 .

将镜像push到远程仓库

> docker push ccr.ccs.tencentyun.com/haiyang/skywalking-agent:7.0.0

项目都打包好后，执行k8s.yaml即可，便可完成整个项目的部署

https://github.com/puhaiyang/spring-boot-cloud/blob/master/k8s.yaml

![skywalking1](/screenshots/springCloud-skywalking1.png)
![skywalking2](/screenshots/springCloud-skywalking2.png)