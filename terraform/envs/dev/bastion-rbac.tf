# 설치 계정(베스천)이 클러스터 안에 쿠버네티스 권한 규칙(Role, RoleBinding)을 만들 수 있게 한다 (이슈 #43).
# Airflow 같은 Helm 차트가 설치할 때 이 규칙을 만든다. 11/16 Airflow 설치에서 베스천 계정(container.developer)에
# 이 권한이 없어 "roles ... forbidden"으로 막혔고, 임시로 rbac.create=false로 설치했다.
# container.admin(클러스터 전체 관리자)은 너무 넓어서, 필요한 권한만 담은 사용자 지정 역할을 쓴다.
resource "google_project_iam_custom_role" "bastion_rbac" {
  project     = var.project_id
  role_id     = "${replace(var.name_prefix, "-", "_")}_bastion_rbac"
  title       = "Bastion RBAC editor"
  description = "GKE 안에 Role/RoleBinding을 만들고 고칠 수 있다. Helm 차트 설치용."

  permissions = [
    "container.roles.create",
    "container.roles.get",
    "container.roles.list",
    "container.roles.update",
    "container.roles.delete",
    # escalate, bind: 쿠버네티스는 자신이 가진 RBAC 권한만 새 Role에 담게 하고, GCP IAM 권한은 이 검사의 "가진 권한"에 포함되지 않는다
    # (11/17 helm upgrade "attempting to grant RBAC permissions not currently held"). 이 둘을 IAM으로 주면 그 검사를 건너뛴다.
    # 주의: 프로젝트 IAM은 네임스페이스를 구분하지 못해서 kube-system을 포함한 모든 네임스페이스에 적용된다(PR #44 리뷰).
    "container.roles.escalate",
    "container.roles.bind",
    "container.roleBindings.create",
    "container.roleBindings.get",
    "container.roleBindings.list",
    "container.roleBindings.update",
    "container.roleBindings.delete",
  ]
}

resource "google_project_iam_member" "bastion_rbac" {
  project = var.project_id
  role    = google_project_iam_custom_role.bastion_rbac.id
  member  = "serviceAccount:${google_service_account.bastion.email}"
}
