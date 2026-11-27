# 뉴스 생성기 PVC

이슈 #59. `airflow` namespace는 Helm(`helm/airflow`)이 만들기 때문에, 이 PVC는 Airflow 설치 뒤에 올립니다.

```bash
kubectl apply -f pvc.yaml
kubectl -n airflow get pvc news-output
```

- 적용 직후 STATUS는 **`Pending`이 정상**입니다. `standard-rwo`는 `volumeBindingMode: WaitForFirstConsumer`라서, 이 PVC를 마운트하는 Pod(생성기)가 처음 뜰 때 그 노드 근처에 실제 디스크를 만들고 `Bound`가 됩니다(PR #63 리뷰).
- 실제 디스크 크기: **요청한 `2Gi` 그대로 만들어졌습니다**(11/23 실측: `kubectl get pvc` CAPACITY `2Gi`, Pod 안 `df -h` 2.0G). 리뷰에서 나온 "pd-balanced 최소 10GiB" 가정은 실측과 달랐습니다. 비용은 2GiB 디스크 기준입니다.
- 적용 기록: 2026-11-23 베스천에서 적용, `Pending` 확인. 같은 날 시험 Pod(`airflow-task`, 생성기 이미지)로 처음 마운트해 `Bound`. 생성기 이미지는 root(uid 0)로 돌아 `/mnt/news-output` 쓰기·삭제 성공.

## 롤백
`standard-rwo`의 기본 회수 정책이 `Delete`라서 PVC를 지우면 디스크와 안의 파일이 함께 삭제됩니다. 안의 파일은 중간 결과물이라 복구가 필요 없는지 확인한 뒤 지웁니다.
```bash
kubectl -n airflow delete pvc news-output
```

## 확정된 값 (태원 님 답변, 11/20)
- 크기 `2Gi`, 보관 기간 7일(7일 지난 파일 정리는 생성기가 한다)
- 동시 실행 Pod 없음(Airflow `max_active_runs=1`) → `ReadWriteOnce`로 확정
- 마운트 경로 `/mnt/news-output`, namespace `airflow`

## 버킷 권한과 생성기 코드 (11/23 확인)
- 생성기(backend `generate/generate.py`의 `upload_thumbnail`)는 `client.bucket(이름).blob("images/…")`로 객체를 바로 지정하고(`get_bucket` 호출 없음), `upload_from_filename(..., if_generation_match=0)`으로 **새 이름일 때만** 올립니다. 같은 이름이 있으면 412를 받아 `blob.reload()`로 MD5를 비교만 합니다.
- 그래서 필요한 권한은 `storage.objects.create`(새로 올리기)와 `storage.objects.get`(재시도 때 비교)뿐이고, 덮어쓰기용 `storage.objects.delete`는 필요 없습니다. 이 PR의 커스텀 역할(create·get, `images/` 조건)과 맞습니다.
