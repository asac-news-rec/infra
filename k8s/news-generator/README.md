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

## 정해지면 확정할 값
- 크기(`10Gi`는 임시값)와 보관 기간
- 동시 실행 Pod 수(2개 이상이면 `ReadWriteOnce` 대신 다른 방식 검토)
