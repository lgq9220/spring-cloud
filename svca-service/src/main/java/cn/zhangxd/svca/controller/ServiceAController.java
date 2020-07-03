package cn.zhangxd.svca.controller;

import cn.zhangxd.svca.client.ServiceBClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.client.ServiceInstance;
import org.springframework.cloud.client.discovery.DiscoveryClient;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import javax.annotation.Resource;
import java.security.Principal;
import java.util.List;

@RefreshScope
@RestController
public class ServiceAController {

    @Value("${name:unknown}")
    private String name;

    @Autowired
    DiscoveryClient discoveryClient;
    @Resource
    private ServiceBClient serviceBClient;

    @GetMapping(value = "/")
    public String printServiceA() {
        StringBuilder sb = new StringBuilder();
        List<String> services = discoveryClient.getServices();
        for (String service : services) {
            List<ServiceInstance> instances = discoveryClient.getInstances(service);
            System.out.println("------------" + service + "--------------");
            for (ServiceInstance instance : instances) {
                System.out.println("serviceName:" + service + ";instances:" + instance.getHost() + " port:" + instance.getPort());
            }
        }
        return "result:" + sb.toString() + serviceBClient.printServiceB();
    }


    @GetMapping(path = "/test")
    public String test(String param) {
        return "param" + param;
    }

    @GetMapping(path = "/current")
    public Principal getCurrentAccount(Principal principal) {
        return principal;
    }
}