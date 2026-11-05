# Valkey (Helm)

GKE 클러스터 안에서 쓰는 캐시용 Valkey를 공식 Helm 차트로 설치한다. 설정은 `values.yaml`에 있다.

## 구성

| 항목 | 값 |
|---|---|
| 차트 | `valkey/valkey` 0.12.1(앱 9.1.3), 저장소 `https://valkey.io/valkey-helm/` |
| 위치 | 클러스터 `news-rec-gke`, 네임스페이스 `valkey`, 릴리스 이름 `valkey` |
| 형태 | 단독(standalone) 1개, Deployment |
| 디스크 | 없음(`dataStorage.enabled: false`). 파드가 재시작되면 데이터가 사라진다 |
| 인증 | 없음(`auth.enabled: false`). ClusterIP라 클러스터 안에서만 접근한다 |
| 리소스 | CPU 250m, 메모리 512Mi (Autopilot은 요청한 만큼 과금) |

값 이름 주의: 이 차트 버전(0.12.1)에서 단독 구성의 디스크 설정은 `dataStorage`이다. `persistence`는 복제(replica) 전용(`replica.persistence`)이라서 단독 구성에 적으면 오류 없이 무시된다.

## 설치 (배스천에서)

배스천 접속자는 sudo가 없어서 helm을 홈 디렉터리에 설치한다. WSL에는 helm이 없다.

```bash
# 레포(WSL)에서 values 파일을 배스천으로 복사
gcloud compute scp helm/valkey/values.yaml news-rec-bastion:~/values.yaml --zone asia-northeast3-a --tunnel-through-iap --project final-project-513508

# 배스천에서 helm 설치(홈 디렉터리)
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
mkdir -p ~/bin
USE_SUDO=false HELM_INSTALL_DIR=$HOME/bin bash get_helm.sh
export PATH=$HOME/bin:$PATH

# 차트 저장소 추가와 설치
helm repo add valkey https://valkey.io/valkey-helm/
helm repo update
helm install valkey valkey/valkey --version 0.12.1 -n valkey --create-namespace -f ~/values.yaml
```

설치 전에 `helm show values valkey/valkey --version 0.12.1`로 키 이름을 확인한다. Helm은 모르는 키를 오류 없이 무시하므로, 설치 후 `helm get values valkey -n valkey`로 적용된 값도 확인한다.

## 확인 결과 (2026-11-05)

| 확인 | 결과 |
|---|---|
| `helm list -n valkey` | `valkey-0.12.1`, 앱 9.1.3, STATUS `deployed`, REVISION 1 |
| 파드 | `valkey-6b966c6bf-dj758` 1/1 Running |
| 파드 안 접속 | `kubectl exec -n valkey deploy/valkey -- valkey-cli ping` → `PONG` |
| 서비스 경유 접속 | 임시 파드에서 `valkey-cli -h valkey -p 6379 ping` → `PONG`(임시 파드는 삭제됨) |
| 적용된 값 | `helm get values`에 `auth.enabled: false`, `dataStorage.enabled: false`, 리소스 250m/512Mi |
| 메인 컨테이너 요청값 | CPU 250m, 메모리 512Mi |
| 초기화 컨테이너 요청값 | Autopilot이 CPU 250m, 메모리 512Mi, 임시 저장소 1Gi로 채움 |
| 디스크를 켰을 때 | `dataStorage.enabled=true`, `requestedSize=5Gi`로 렌더링하면 PVC가 생성됨(클러스터에는 적용하지 않음) |

## 한계와 후속 작업

- 디스크가 없어서 파드가 재시작되면 데이터가 사라진다. 재시작하면 안 되는 데이터를 넣을 계획이면 `dataStorage`를 켜야 한다.
- 인증이 없고 ClusterIP라서 클러스터 안의 다른 파드는 접근할 수 있다. 네트워크 정책과 인증은 후속 작업이다.
- 월 비용은 공식 가격 계산기로 확인하지 않았다.
- 차트 버전을 올릴 때는 `helm show values`로 키가 바뀌었는지 확인한다.

## 바꾸기와 삭제

values를 고친 뒤 반영한다(이번에 실행해 보지는 않았다).

```bash
helm upgrade valkey valkey/valkey --version 0.12.1 -n valkey -f ~/values.yaml
```

삭제는 배스천에서 한다(차트 안내문의 명령).

```bash
helm -n valkey uninstall valkey
```

디스크를 켜서 PVC를 만들었다면 삭제 후에 PVC가 남는지 확인하고 따로 지운다.
