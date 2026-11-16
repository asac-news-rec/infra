# Airflow (Helm)

이슈 #35. Airflow 공식 Helm 차트를 `airflow` 네임스페이스에 설치합니다. DAG는 GitHub 저장소 `data-ml-pipeline`의 `dags/` 폴더에서 git sync로 가져옵니다(멘토 11/12, 11/15).

## 구성 요약
- 차트 `apache-airflow/airflow` 1.22.0, Airflow 3.2.2
- 실행 방식 `LocalExecutor`, 작업 코드는 KubernetesPodOperator로 별도 파드에서 실행
- 이미지는 모두 우리 Artifact Registry 주소(`dockerhub-mirror`, `news-rec`)를 씁니다. `git-sync`는 `registry.k8s.io`에서 `news-rec`로 복사한 것입니다.
- 메타데이터 DB는 차트에 들어 있는 PostgreSQL(디스크 사용). 나중에 Cloud SQL로 바꿉니다.
- 외부 접속(GitHub 등)은 Cloud NAT(이슈 #36)가 필요합니다.

## 설치 순서 (베스천 안에서)
1. 노드를 켭니다(고정 노드 2개 권장). 메모리와 CPU가 모자라면 파드가 `Pending`으로 남습니다.
2. 읽기 전용 열쇠를 만듭니다. 개인 키는 파일로만 두고 채팅이나 저장소에 올리지 않습니다.
   ```bash
   ssh-keygen -t ed25519 -f ~/airflow-git-key -N "" -C "airflow-git-sync"
   ```
3. 공개 키(`~/airflow-git-key.pub`)를 GitHub `data-ml-pipeline` → Settings → Deploy keys에 **쓰기 권한 없이** 등록합니다(저장소 관리자 권한이 필요합니다).
4. GitHub 호스트 키를 받아 공식 지문과 비교합니다.
   ```bash
   ssh-keyscan github.com > ~/known_hosts_github
   ssh-keygen -lf ~/known_hosts_github
   ```
   출력된 지문이 GitHub 문서의 "GitHub's SSH key fingerprints"와 같은지 확인합니다.
5. 네임스페이스와 Secret을 만듭니다.
   ```bash
   kubectl create namespace airflow
   kubectl -n airflow create secret generic airflow-git-ssh-key --from-file=gitSshKey=$HOME/airflow-git-key
   ```
6. 개인 키 파일을 지웁니다(Secret에 들어갔습니다).
   ```bash
   shred -u ~/airflow-git-key
   ```
7. 설치합니다.
   ```bash
   helm upgrade --install airflow apache-airflow/airflow --version 1.22.0 --namespace airflow -f helm/airflow/values.yaml --set-file dags.gitSync.knownHosts=$HOME/known_hosts_github --timeout 10m
   ```
8. 확인합니다.
   ```bash
   kubectl -n airflow get pods
   ```

## 접속
공개 주소가 없습니다. 베스천에서 `kubectl -n airflow port-forward`로 접속합니다. 서비스 이름과 포트는 설치 후 `kubectl -n airflow get svc`로 확인합니다(**[확인 필요]**).

## 확인이 남은 것 (설치하면서 채웁니다)
- 관리자 계정과 비밀번호 설정 방법(기본값은 쓰지 않고 Secret으로 설정)
- 웹 서버 비밀 키 설정과 경고 여부
- 파드별 자원 요청과 한도(설치 후 측정), 작업 파드를 `worker` 노드 풀에 올리기 위한 toleration
- Airflow 표시 시간대(KST)
- `helm template`에서 값 이름이 무시되지 않았는지 이미지 목록으로 확인

## 롤백
```bash
helm -n airflow uninstall airflow
```
메타데이터 DB 디스크(PVC)는 남을 수 있습니다. 완전히 지울 때만 `kubectl -n airflow delete pvc --all`을 실행합니다(기록이 사라집니다).
