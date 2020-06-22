#!/usr/bin/env bash
################### 配置信息begin ###################
project_git_url=https://github.com/puhaiyang/spring-boot-cloud.git
#docker镜像仓库地址
image_domain=ccr.ccs.tencentyun.com/spring-boot-cloud
#项目的根目录
git_root_path=~/git
#项目目录
git=$git_root_path/$pname
#通用chart目录
chart_root_path=~/git/helms
#版本号,docker的tag
version=`date +%Y%m%d%H%M`
################### 配置信息end ###################
########################初始化 begin###########################
#不存在项目目录的话，则先进行初始化
if [ ! -d $git_root_path ];then
    echo '不存项目目录，先进行初始化'
	mkdir $git_root_path
	cd $git_root_path
	git clone $project_git_url
fi
########################初始化 end###########################
source /etc/profile
if [ -z "$1" ]; then
    #默认分支名称
    branch=master
else
    branch=$1
fi

echo '----------------------------------------------'
echo ':-D hi,boy!welcome to automatic depoly sh! :-D'
echo '----------------------------------------------'

echo -e "branch:$branch, 系统服务列表:"
ls $git_root_path/  |grep "spring-boot-cloud"
echo -e "请输入模块名称(请输入spring-boot-cloud-xxx后的xxx即可):"
read pname
pname="spring-boot-cloud-$pname"
echo "更新的模块：$pname"

#切换到项目的目录
cd $git
git fetch --all
git reset --hard origin/$branch

git_last_commit=$(git show -s --format=%s)
git_last_commit_author=$(git show -s --format=%an)

echo '统一处理日志文件(logback-spring.xml)配置...'
sed "s/module/$pname/g" ~/config/logback_template.xml > $git/src/main/resources/logback-spring.xml
echo '统一处理启动(bootstrap.properties)配置...'
sed "s/module/$pname/g" ~/config/spring-boot-cloud-template.properties > $git/src/main/resources/bootstrap.properties
#项目是maven聚合项目，需要在git的根目录进打包,-pl --projects <arg> 构建制定的模块，模块间用逗号分隔
#-am --also-make 同时构建所列模块的依赖模块；
cd $git_root_path

echo '下面开始打包(package)...'
mvn clean  package -Dmaven.test.skip=true -pl $pname -am
#mvn clean  package -Dmaven.test.skip=true
echo '好,包打好了！接下来准备打镜像！(docker image package)...'
cd $git
if [ "$pname" == "xxxxxxx" ]; then
	sed "s/module/$pname/g" ~/config/Dockerfile-xxxxxxxxx-with-skywalking-template  > target/Dockerfile
	echo "$pname will update"
else
	sed "s/module/$pname/g" ~/config/Dockerfile-with-skywalking-template  > target/Dockerfile
	echo "$pname 统一处理dockerFile完毕(docker file copy)"
fi

echo '现在拷贝时区文件'
cp ~/config/TimeZone target/
image=$image_domain/$pname:$version
docker_image=$image_domain/$pname
echo '现在开始打镜像...'
cd target
docker build -f  Dockerfile -t $image .
echo '打好了，把镜像推到docker镜像仓库里去(push...)'
docker push $image

echo '好！现在准备发布更新了(pre deploy...)'
echo '现在准备chart文件,通过通用chart文件来生成'
path_common_chart=$chart_root_path/common-modle-springbootcloud
echo $path_common_chart
mkdir chart
echo '复制到target下的chart目录下'
cp -r $path_common_chart chart
#重命名
mv chart/common-modle-springbootcloud chart/$pname
echo '替换chart'
sed -i "s/common-modle-springbootcloud/$pname/g" chart/$pname/Chart.yaml
echo '替换values'
sed -i "s/common-modle-springbootcloud/$pname/g" chart/$pname/values.yaml

#install upgrade
echo '进行发布(deploy...)'
if [ -f "$chart_root_path/values/$pname/values.yaml" ];then
    echo '已经有配置文件了，采用配置文件进行发布'
	helm install $pname chart/$pname -n nnnnnnnnn -f $chart_root_path/values/$pname/values.yaml --set image.tag=$version --set image.repository=$docker_image
else
    echo '直接进行发布'
    helm install $pname chart/$pname -n nnnnnnnnn --set image.tag=$version --set image.repository=$docker_image
fi

Message="发布通知: \n模块:${pname} \ngit提交者:$git_last_commit_author \ngit提交内容:$git_last_commit \n------have a nice day------"

curl 'https://oapi.dingtalk.com/robot/send?access_token=yourToken' \
           -H 'Content-Type: application/json' \
           -d "  {\"msgtype\": \"text\",
              \"text\": {\"content\": \"$Message\"}}"
