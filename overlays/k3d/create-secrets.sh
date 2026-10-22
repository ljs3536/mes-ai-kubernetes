#!/bin/sh
# 클러스터에만 두는 Secret을 만든다. 출력 파일은 generated/ 에 있고 git에 올리지 않는다.
# DB와 Influx 값은 이미 만들어진 볼륨과 같아야 하므로, 처음 한 번은 실행 중인 파드에서 읽는다.
set -eu
cd "$(dirname "$0")"
GEN=generated
NS=factory-mes
mkdir -p "$GEN"

ensure_key() {
  file=$1
  key=$2
  if ! grep -q "^${key}=" "$file"; then
    umask 077
    printf '%s=%s\n' "$key" "$(openssl rand -base64 32 | tr -d '\n')" >> "$file"
  fi
}

if [ ! -f "$GEN/data.env" ]; then
  root=$(kubectl exec -n "$NS" deploy/db -- printenv MARIADB_ROOT_PASSWORD)
  db=$(kubectl exec -n "$NS" deploy/db -- printenv MARIADB_PASSWORD)
  influx_pw=$(kubectl exec -n "$NS" deploy/influxdb -- printenv DOCKER_INFLUXDB_INIT_PASSWORD)
  token=$(kubectl exec -n "$NS" deploy/sensor-collector -- printenv INFLUX_TOKEN)
  umask 077
  cat > "$GEN/data.env" <<EOF
MARIADB_ROOT_PASSWORD=$root
MARIADB_PASSWORD=$db
INFLUX_PASSWORD=$influx_pw
INFLUX_TOKEN=$token
DATABASE_URL=mysql+pymysql://mes:${db}@db:3306/mes?charset=utf8mb4
EOF
fi
ensure_key "$GEN/data.env" AUTH_SECRET
ensure_key "$GEN/data.env" INTERNAL_TOKEN

if [ ! -f "$GEN/mqtt.env" ]; then
  umask 077
  cat > "$GEN/mqtt.env" <<EOF
backend=$(openssl rand -base64 18 | tr -d '\n')
collector=$(openssl rand -base64 18 | tr -d '\n')
gateway=$(openssl rand -base64 18 | tr -d '\n')
machine=$(openssl rand -base64 18 | tr -d '\n')
waveform=$(openssl rand -base64 18 | tr -d '\n')
analytics=$(openssl rand -base64 18 | tr -d '\n')
probe=$(openssl rand -base64 18 | tr -d '\n')
EOF
fi

set -a
. ./$GEN/mqtt.env
set +a
rm -f "$GEN/passwd"
docker run --rm -v "$PWD/$GEN:/work" eclipse-mosquitto:2 \
  sh -c "mosquitto_passwd -b -c /work/passwd backend '$backend' \
    && mosquitto_passwd -b /work/passwd collector '$collector' \
    && mosquitto_passwd -b /work/passwd gateway '$gateway' \
    && mosquitto_passwd -b /work/passwd machine '$machine' \
    && mosquitto_passwd -b /work/passwd waveform '$waveform' \
    && mosquitto_passwd -b /work/passwd analytics '$analytics' \
    && mosquitto_passwd -b /work/passwd probe '$probe'"

if [ ! -f "$GEN/tls.key" ]; then
  openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "$GEN/tls.key" -out "$GEN/tls.crt" \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi

set -a
. ./$GEN/data.env
set +a
kubectl create secret generic mes-data -n "$NS" \
  --from-literal=mariadb-root-password="$MARIADB_ROOT_PASSWORD" \
  --from-literal=mariadb-password="$MARIADB_PASSWORD" \
  --from-literal=influx-password="$INFLUX_PASSWORD" \
  --from-literal=influx-token="$INFLUX_TOKEN" \
  --from-literal=database-url="$DATABASE_URL" \
  --from-literal=auth-secret="$AUTH_SECRET" \
  --from-literal=internal-token="$INTERNAL_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic mes-mqtt -n "$NS" \
  --from-file=passwd="$GEN/passwd" \
  --from-literal=backend-password="$backend" \
  --from-literal=collector-password="$collector" \
  --from-literal=gateway-password="$gateway" \
  --from-literal=machine-password="$machine" \
  --from-literal=waveform-password="$waveform" \
  --from-literal=analytics-password="$analytics" \
  --from-literal=probe-password="$probe" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls mes-tls -n "$NS" \
  --cert="$GEN/tls.crt" --key="$GEN/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "secrets applied in $NS"
