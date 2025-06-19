# Configuration principale de Vault

# Stockage des données
storage "file" {
  path = "/vault/data"
}

# Interface d'écoute
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true  # En développement seulement !
}

# Configuration UI
ui = true

# Désactiver mlock pour Docker
disable_mlock = true

# Configuration des logs
log_level = "INFO"
log_format = "json"

# Configuration du cluster
cluster_addr = "http://0.0.0.0:8201"
api_addr = "http://0.0.0.0:8200"

# TTL par défaut
default_lease_ttl = "168h"
max_lease_ttl = "720h"

# Métriques et monitoring
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}