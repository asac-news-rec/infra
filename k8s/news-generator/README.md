# 뉴스 생성기 PVC

이슈 #59. `airflow` namespace는 Helm(`helm/airflow`)이 만들기 때문에, 이 PVC는 Airflow 설치 뒤에 올립니다.

```bash
kubectl apply -f pvc.yaml
kubectl -n airflow get pvc news-output
```

## 롤백
`standard-rwo`의 기본 회수 정책이 `Delete`라서 PVC를 지우면 디스크와 안의 파일이 함께 삭제됩니다. 안의 파일은 중간 결과물이라 복구가 필요 없는지 확인한 뒤 지웁니다.
```bash
kubectl -n airflow delete pvc news-output
```

## 확정된 값 (태원 님 답변, 11/20)
- 크기 `2Gi`, 보관 기간 7일(7일 지난 파일 정리는 생성기가 한다)
- 동시 실행 Pod 없음(Airflow `max_active_runs=1`) → `ReadWriteOnce`로 확정
- 마운트 경로 `/mnt/news-output`, namespace `airflow`

## 아직 확인 중인 값
- 같은 파일명으로 이미지를 다시 쓰는지(덮어쓰기에는 `storage.objects.delete`가 필요하다). 지금은 삭제 권한 없이 진행하고, 덮어쓰기 오류가 나면 후속으로 추가한다.
