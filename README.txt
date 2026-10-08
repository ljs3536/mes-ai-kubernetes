mes-ai-kubernetes
==================

공장 MES를 Kubernetes에 올리는 매니페스트만 둔다. 앱 소스와 이미지 빌드는 각 서비스 저장소에 있다.

base
  GHCR 이미지(latest)로 만든 공통 Deployment, Service, PVC.
overlays/k3d
  이 Mac의 k3d 클러스터용이다. 이미지를 factory-mes/*:local 로 바꾼다.
argocd/application.yaml
  Argo CD가 overlays/k3d 를 이 저장소 main에서 동기화한다.

로컬 클러스터 이름은 factory-mes 이고 server 1대, agent 3대다.
compose와 포트를 나누었다.

  MES 화면     http://localhost:13000
  센서 분석    http://localhost:13001
  MES API      http://localhost:18000

직접 적용은 작업 폴더에서 다음이다.

  kubectl apply -k kubernetes/overlays/k3d

이 저장소만 클론한 경우에는 경로가 overlays/k3d 이다.
