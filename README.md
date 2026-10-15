# mes-ai-kubernetes

공장 MES를 Kubernetes에 올리는 매니페스트만 둔다. 앱 소스와 이미지 빌드는 각 서비스 저장소에 있다.

## 폴더

- `base`: GHCR 이미지(latest)로 만든 Deployment, Service, PVC, Nginx, NetworkPolicy.
- `overlays/k3d`: 이 Mac의 k3d 클러스터용이다. 이미지를 `factory-mes/*:local` 로 바꾼다. `create-secrets.sh`가 DB, Influx, MQTT, TLS Secret을 클러스터에만 만든다. 생성된 키와 비밀번호는 `overlays/k3d/generated/`에 있고 git에 올리지 않는다.
- `argocd/application.yaml`: Argo CD가 `overlays/k3d`를 이 저장소 `main`에서 동기화한다. Secret은 이 저장소에 없으므로, 매니페스트를 올리기 전에 `create-secrets.sh`를 한 번 실행한다.
- `policy/kube-network-policies.yaml`: k3s 기본 Flannel은 NetworkPolicy를 강제하지 않는다. 이 DaemonSet이 규칙을 적용한다.
- `headlamp/headlamp.yaml`: 파드와 로그를 보는 Headlamp다. `factory-mes` Application 밖에 두고 따로 적용한다.

## 클러스터

로컬 클러스터 이름은 `factory-mes`이고 server 1대, agent 3대다. kubectl 컨텍스트는 `k3d-factory-mes`다.

밖으로 여는 서비스는 Nginx 하나다. 인증서는 localhost용 자체 서명이다.

- MES 화면: https://localhost:13000
- 같은 화면: https://localhost:8443
- 센서 분석: https://localhost:13001

DB, Influx, MLflow, MQTT, API, 에뮬레이터는 클러스터 안에서만 받는다. MQTT는 계정과 ACL로 익명 접속을 닫는다. NetworkPolicy는 파드가 필요한 상대만 받게 한다.

직접 적용은 작업 폴더에서 다음이다. 이 저장소만 클론한 경우에는 `kubernetes/`를 경로에서 뺀다.

```bash
kubectl apply -f kubernetes/policy/kube-network-policies.yaml
kubernetes/overlays/k3d/create-secrets.sh
kubectl apply -k kubernetes/overlays/k3d
```

## Argo CD

Argo CD는 `argocd` 네임스페이스에 있고, 화면 Service는 ClusterIP다. 이 Mac에서 여는 방법은 port-forward다. `8443`은 MES 화면이 이미 쓰고 있으므로 Argo CD는 `18080`으로 연다.

```bash
kubectl config use-context k3d-factory-mes
kubectl -n argocd port-forward svc/argocd-server 18080:443
```

브라우저 주소는 https://localhost:18080 이다. 인증서 경고가 나오면 통과한다.

- 사용자: `admin`
- 비밀번호: 클러스터에 있는 초기 관리자 Secret

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
```

등록된 앱 이름은 `factory-mes`다. 이 클러스터에서는 자동 동기화를 꺼 두었다. 화면에서 `factory-mes`를 연 뒤 Sync를 누르면 GitHub `main`의 `overlays/k3d`와 맞춘다.

## Headlamp

Headlamp가 클러스터 안의 파드, 상태, 로그를 보여 준다. 이 Mac에서만 연다.

```bash
kubectl apply -f kubernetes/headlamp/headlamp.yaml
k3d cluster edit factory-mes --port-add 127.0.0.1:4466:4466@loadbalancer
```

브라우저 주소는 http://localhost:4466 이다. 클러스터 `main`을 연 뒤, 네임스페이스 `factory-mes`의 Pods에서 로그를 본다. port-forward는 쓰지 않는다. 그 프로세스가 없으면 브라우저가 서버에 연결하지 못한다.

## k3d 상태

노드와 앱 상태는 터미널에서도 본다.

```bash
k3d cluster list
kubectl config current-context
kubectl get nodes
kubectl get pods -n factory-mes
kubectl get svc -n factory-mes
```

`factory-mes`가 `1/1` 서버, `3/3` 에이전트, 로드밸런서 `true`이면 클러스터가 떠 있는 것이다.
