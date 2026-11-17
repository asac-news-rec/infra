# 뉴스 DB용 Cloud SQL(PostgreSQL). 공유 코어 사양(db_tier)으로 운영한다. 여러 서비스가 함께 쓰므로 f1-micro에서 g1-small로 올렸다.
# 공개 IP는 있지만 "허용 네트워크"를 하나도 열지 않아서 직접 접속은 막혀 있다.
# 접속은 Cloud SQL Auth Proxy(구글 계정 인증, 암호화)로만 한다.
# DB 사용자 비밀번호는 코드와 상태 파일에 남기지 않기 위해 Terraform으로 만들지 않는다(README 참고).
resource "google_sql_database_instance" "news" {
  project          = var.project_id
  name             = "${var.name_prefix}-pg"
  region           = var.region
  database_version = var.db_version

  # 실수로 지우는 것을 막는다. 지워야 할 때는 이 값을 false로 바꾸고 apply한 뒤 destroy한다.
  deletion_protection = true

  settings {
    edition           = "ENTERPRISE"
    tier              = var.db_tier
    availability_type = "ZONAL"

    disk_type       = "PD_SSD"
    disk_size       = 10
    disk_autoresize = true

    deletion_protection_enabled = true

    user_labels = local.labels

    backup_configuration {
      enabled    = true
      start_time = "18:00" # UTC, 한국 시간 새벽 3시

      backup_retention_settings {
        retained_backups = 7
      }
    }

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
    }
  }

  # Cloud SQL은 비용 때문에 gcloud로 켜고 끈다(activation-policy ALWAYS/NEVER).
  # Terraform이 이 값을 되돌려서 꺼 둔 DB를 apply 때 다시 켜지 않도록 변경을 무시한다.
  lifecycle {
    ignore_changes = [settings[0].activation_policy]
  }

  depends_on = [google_project_service.platform_apis]
}

resource "google_sql_database" "news" {
  project  = var.project_id
  instance = google_sql_database_instance.news.name
  name     = "newsdb"
}
