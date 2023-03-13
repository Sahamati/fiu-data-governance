docker tag business-rule-engine-service:latest $acrLoginServer/business-rule-engine-service:latest
docker tag statement-analysis-service:latest $acrLoginServer/statement-analysis-service:latest
docker tag certificate-registry-service:latest $acrLoginServer/certificate-registry-service:latest
docker tag crypto-sidecar:latest $acrLoginServer/crypto-sidecar:latest
docker tag inmemory-keyprovider:latest $acrLoginServer/inmemory-keyprovider:latest

docker push $acrLoginServer/business-rule-engine-service:latest
docker push $acrLoginServer/statement-analysis-service:latest
docker push $acrLoginServer/certificate-registry-service:latest
docker push $acrLoginServer/crypto-sidecar:latest
docker push $acrLoginServer/inmemory-keyprovider:latest