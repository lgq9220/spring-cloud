#!/usr/bin/env bash
################### 配置信息begin ###################
project_git_url=https://github.com/puhaiyang/spring-boot-cloud.git
#docker镜像仓库地址
image_domain=ccr.ccs.tencentyun.com/spring-boot-cloud
#项目的根目录
git_root_path=~/git
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
#自定义分支名
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
################################列目录 begin############################
pom_files=$(dirname $(find git/spring-boot-cloud/ -name pom.xml))
echo $pom_files
igrone_pro="spring-boot-cloud"
index=0

for i in ${pom_files[@]};do
  pro_name=$(basename $i)
  if [ "$pro_name" = "$igrone_pro" ]; then
     continue
  fi
  ((index++))
  echo $index')'$pro_name
done
################################列目录 end############################



ls $git_root_path/  |grep "spring-boot-cloud"
echo -e "请输入模块名称(请输入spring-boot-cloud-xxx后的xxx即可):"
read pname
pname="spring-boot-cloud-$pname"
echo "更新的模块：$pname"
#项目目录
git=$git_root_path/$pname
#切换到项目的目录
cd $git
#获取到新的代码
git fetch --all
git reset --hard origin/$branch
#获取到最后一次提交的内容
git_last_commit=$(git show -s --format=%s)
#获取到最后一次提交者
git_last_commit_author=$(git show -s --format=%an)
#如果项目是maven聚合项目，需要在git的根目录进打包,-pl --projects <arg> 构建制定的模块，模块间用逗号分隔
#-am --also-make 同时构建所列模块的依赖模块；
cd $git_root_path
echo '下面开始打包(package)...'
mvn clean  package -Dmaven.test.skip=true -pl $pname -am
#mvn clean  package -Dmaven.test.skip=true
echo '好,包打好了！接下来准备打镜像！(docker image package)...'
cd $git
#docker镜像名
docker_image=$image_domain/$pname
#docker镜像名
image=$docker_image:$version
echo '现在开始打镜像...'
cd target
docker build -f  Dockerfile -t $image .
echo '打好了，把镜像推到docker镜像仓库里去(push...)'
docker push $image

echo '好！现在准备发布更新了(pre deploy...)'
echo '现在准备chart文件,通过通用chart文件来生成'
path_common_chart=$chart_root_path/common-modle-springbootcloud
echo $path_common_chart
#在项目的target目录下创建chart目录
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
