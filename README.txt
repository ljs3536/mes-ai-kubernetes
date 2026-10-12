mes-ai-kubernetes
==================

공장 MES를 Kubernetes에 올리는 매니페스트만 둔다. 앱 소스와 이미지 빌드는 각 서비스 저장소에 있다.

base
  GHCR 이미지(latest)로 만든 Deployment, Service, PVC, Nginx, NetworkPolicy.
overlays/k3d
  이 Mac의 k3d 클러스터용이다. 이미지를 factory-mes/*:local 로 바꾼다.
  create-secrets.sh 가 DB, Influx, MQTT, TLS Secret을 클러스터에만 만든다.
  생성된 키와 비밀번호는 overlays/k3d/generated/ 에 있고 git에 올리지 않는다.
argocd/application.yaml
  Argo CD가 overlays/k3d 를 이 저장소 main에서 동기화한다.
  Secret은 이 저장소에 없으므로, 매니페스트를 올리기 전에 create-secrets.sh 를 한 번 실행한다.

로컬 클러스터 이름은 factory-mes 이고 server 1대, agent 3대다.
밖으로 여는 서비스는 Nginx 하나다. 인증서는 localhost용 자체 서명이다.

  MES 화면     https://localhost:13000
  같은 화면    https://localhost:8443
  센서 분석    https://localhost:13001

DB, Influx, MLflow, MQTT, API, 에뮬레이터는 클러스터 안에서만 받는다.
MQTT는 계정과 ACL로 익명 접속을 닫는다.
NetworkPolicy는 파드가 필요한 상대만 받게 한다. k3s 기본 Flannel은 이 규칙을 강제하지 않으므로 policy/kube-network-policies.yaml 을 같이 적용한다.

  kubectl apply -f kubernetes/policy/kube-network-policies.yaml

직접 적용은 작업 폴더에서 다음이다.

  kubernetes/overlays/k3d/create-secrets.sh
  kubectl apply -k kubernetes/overlays/k3d

이 저장소만 클론한 경우에는 경로가 overlays/k3d 이다.
상태를 볼 때는 다음을 쓴다.

  kubectl config current-context
  kubectl get nodes
  kubectl get pods -n factory-mes
  kubectl get svc -n factory-mes
