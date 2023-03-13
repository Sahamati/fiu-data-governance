docker tag ccr-init:latest $acrLoginServer/ccr-init:latest
docker tag ccr-sidecar:latest $acrLoginServer/ccr-sidecar:latest
docker tag ccr-skr-sidecar:latest $acrLoginServer/ccr-skr-sidecar:latest
docker tag ccr-proxy:latest $acrLoginServer/ccr-proxy:latest

docker push $acrLoginServer/ccr-init:latest
docker push $acrLoginServer/ccr-sidecar:latest
docker push $acrLoginServer/ccr-skr-sidecar:latest
docker push $acrLoginServer/ccr-proxy:latest
