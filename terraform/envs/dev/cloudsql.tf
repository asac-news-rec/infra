# 뉴스 DB용 Cloud SQL(PostgreSQL). 가장 작은 사양으로 시작한다.
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

  depends_on = [google_project_service.platform_apis]
}

resource "google_sql_database" "news" {
  project  = var.project_id
  instance = google_sql_database_instance.news.name
  name     = "newsdb"
}
