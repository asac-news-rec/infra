# Airflow (Helm)

이슈 #35. Airflow 공식 Helm 차트를 `airflow` 네임스페이스에 설치합니다. DAG는 GitHub 저장소 `data-ml-pipeline`의 `dags/` 폴더에서 git sync로 가져옵니다(멘토 11/12, 11/15). 조직 정책으로 deploy key를 쓸 수 없어 읽기 전용 개인 토큰(fine-grained PAT)으로 읽습니다.

## 구성 요약
- 차트 `apache-airflow/airflow` 1.22.0, Airflow 3.2.2
- 실행 방식 `LocalExecutor`, 작업 코드는 KubernetesPodOperator로 별도 파드에서 실행
- 이미지는 모두 우리 Artifact Registry 주소(`dockerhub-mirror`, `news-rec`)를 씁니다. `git-sync`는 `registry.k8s.io`에서 `news-rec`로 복사한 것입니다.
- 메타데이터 DB는 차트에 들어 있는 PostgreSQL(디스크 사용). 나중에 Cloud SQL로 바꿉니다.
- 외부 접속(GitHub 등)은 Cloud NAT(이슈 #36)가 필요합니다.

## 설치 순서 (베스천 안에서)
1. 노드를 켭니다(고정 노드 2개 권장). 메모리와 CPU가 모자라면 파드가 `Pending`으로 남습니다.
2. 읽기 전용 토큰을 만듭니다. 조직 정책으로 deploy key를 쓸 수 없습니다(2026-11-16 확인). GitHub → Settings → Developer settings → Fine-grained tokens → Generate new token.
   - Resource owner: `asac-news-rec`, Repository access: Only select repositories → `data-ml-pipeline`
   - Repository permissions: Contents → **Read-only** (Metadata는 자동)
   - Expiration: 2026-12-31 (최종발표 12/17 이후)
   - 조직이 승인을 요구하면 승인 요청이 가므로 승인 뒤에 사용할 수 있습니다. 토큰은 화면에 한 번만 보이니 채팅과 저장소에 올리지 않습니다.
3. 토큰이 저장소를 읽을 수 있는지 먼저 시험합니다(WSL). 토큰은 화면에 보이지 않게 입력합니다.
   ```bash
   read -rsp "토큰 붙여넣기: " T; echo
   git -c credential.helper= -c http.extraheader="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$T" | base64 -w0)" ls-remote https://github.com/asac-news-rec/data-ml-pipeline.git
   unset T
   ```
   `refs/heads/main` 같은 줄이 나오면 성공입니다. 오류(403, 404)면 토큰 권한이나 조직 승인 대기를 확인합니다.
4. 네임스페이스와 Secret을 만듭니다(베스천 안). 차트가 키 4개를 모두 참조하므로 같은 값을 4개 키로 넣습니다.
   ```bash
   kubectl create namespace airflow
   read -rsp "토큰 붙여넣기: " T; echo
   kubectl -n airflow create secret generic airflow-git-credentials --from-literal=GITSYNC_USERNAME=<GitHub-아이디> --from-literal=GITSYNC_PASSWORD="$T" --from-literal=GIT_SYNC_USERNAME=<GitHub-아이디> --from-literal=GIT_SYNC_PASSWORD="$T"
   unset T
   ```
5. 외부 접속(NAT)이 준비되었는지 확인합니다(이슈 #36).
6. 설치 전에 Secret이 생겼는지 확인합니다.
   ```bash
   kubectl -n airflow get secret airflow-git-credentials
   ```
7. 설치합니다.
   ```bash
   helm upgrade --install airflow apache-airflow/airflow --version 1.22.0 --namespace airflow -f helm/airflow/values.yaml --timeout 10m
   ```
8. 확인합니다. 파드 5개(api-server, dag-processor, postgresql, scheduler, triggerer)가 모두 `Running`이어야 합니다.
   ```bash
   kubectl -n airflow get pods
   ```

## 2026-11-16 설치 결과와 주의
- 설치 완료: 14:56 KST. 파드 5개 `Running`, 웹 화면 접속 확인(베스천 터널). git sync가 저장소를 가져오는 것을 로그로 확인했습니다.
- **권한 표(Role/RoleBinding)**: 베스천 계정에는 이를 만들 권한이 없어서 `rbac.create: false`로 설치했습니다. 설치 시 에러가 나고, 그 상태로 `helm uninstall`도 같은 이유로 실패합니다(이때는 `kubectl delete namespace airflow`로 비웁니다). KubernetesPodOperator에는 권한 표가 필요하므로 베스천 권한을 줄인 뒤 `true`로 바꾸어 `helm upgrade`합니다.
- **디스크 한도**: 서울 리전의 SSD 계열 디스크 합계 한도가 300GB(`SSD_TOTAL_GB`)입니다. 로그 디스크 기본값(스케줄러, triggerer 각 100Gi)으로는 한도를 넘어 triggerer 디스크가 만들어지지 않았습니다. 값 파일에서 5Gi로 줄였습니다. 노드 부팅 디스크(노드당 50GB), postgres 8Gi, MLflow 10Gi와 합쳐 계산합니다.
- **지울 때 디스크는 자동으로 지워지지 않습니다.** `helm uninstall` 뒤 `kubectl -n airflow delete pvc --all`을 실행해야 디스크가 해제됩니다(기록이 사라집니다).
- 기본 관리자 계정은 `admin` / `admin`입니다. 접속은 베스천 터널로만 열리지만 바꿔야 합니다(아래 "확인이 남은 것").

## 접속
공개 주소가 없습니다. 베스천에서 `kubectl -n airflow port-forward`로 접속합니다. 서비스 이름과 포트는 설치 후 `kubectl -n airflow get svc`로 확인합니다(**[확인 필요]**).

## 확인이 남은 것 (설치하면서 채웁니다)
- 관리자 계정 비밀번호 변경(현재 기본값 `admin`/`admin`). 설정 방법은 차트 문서로 확인
- 정적 API 비밀 키 설정(설치 출력에 "동적으로 생성된 키라 재시작이 잦을 수 있다"는 경고)
- 파드별 자원 요청과 한도(설치 후 측정), 작업 파드를 `worker` 노드 풀에 올리기 위한 toleration
- Airflow 표시 시간대(KST)
- `helm template`에서 값 이름이 무시되지 않았는지 이미지 목록으로 확인

## 롤백
```bash
helm -n airflow uninstall airflow
```
메타데이터 DB 디스크(PVC)는 남을 수 있습니다. 완전히 지울 때만 `kubectl -n airflow delete pvc --all`을 실행합니다(기록이 사라집니다).
