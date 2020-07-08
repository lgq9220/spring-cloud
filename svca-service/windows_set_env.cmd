//新增或修改值
setx FEIGN_URL_SVCBSERVICE http://127.0.0.1:8070

//删除值
wmic ENVIRONMENT where "name='FEIGN_URL_SVCBSERVICE'" delete