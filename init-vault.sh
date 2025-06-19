#!/bin/bash

# Usage: ./init-vault.sh

set -e

VAULT_ADDR="http://localhost:8200"
VAULT_INIT_FILE="vault-keys.json"

echo "🔐 Initialisation de HashiCorp Vault"
echo "===================================="

# Attendre que Vault soit prêt
echo "⏳ Attente du démarrage de Vault..."
until curl -s $VAULT_ADDR/v1/sys/health >/dev/null 2>&1; do
    echo "Waiting for Vault to be ready..."
    sleep 5
done

echo "✅ Vault is ready!"

# Vérifier si Vault est déjà initialisé
if vault status -address=$VAULT_ADDR 2>/dev/null | grep -q "Initialized.*true"; then
    echo "✅ Vault is already initialized"

    if [ -f "$VAULT_INIT_FILE" ]; then
        echo "📄 Loading existing keys from $VAULT_INIT_FILE"
        ROOT_TOKEN=$(jq -r '.root_token' $VAULT_INIT_FILE)
        export VAULT_TOKEN=$ROOT_TOKEN
    else
        echo "❌ Vault keys file not found. Please provide root token manually."
        read -p "Enter root token: " ROOT_TOKEN
        export VAULT_TOKEN=$ROOT_TOKEN
    fi
else
    echo "🔧 Initializing Vault..."

    # Initialiser Vault avec 5 clés, seuil de 3
    vault operator init -address=$VAULT_ADDR -key-shares=5 -key-threshold=3 -format=json > $VAULT_INIT_FILE

    echo "✅ Vault initialized! Keys saved to $VAULT_INIT_FILE"
    echo "🔑 IMPORTANT: Save the $VAULT_INIT_FILE file securely!"

    # Extraire les clés et le token
    ROOT_TOKEN=$(jq -r '.root_token' $VAULT_INIT_FILE)
    UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' $VAULT_INIT_FILE)
    UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' $VAULT_INIT_FILE)
    UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' $VAULT_INIT_FILE)

    # Desceller Vault
    echo "🔓 Unsealing Vault..."
    vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_1
    vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_2
    vault operator unseal -address=$VAULT_ADDR $UNSEAL_KEY_3

    export VAULT_TOKEN=$ROOT_TOKEN
fi

echo "🔧 Configuring Vault for medical microservices..."

# Activer les engines de secrets
echo "📦 Enabling secret engines..."

# KV v2 pour les secrets applicatifs
vault secrets enable -address=$VAULT_ADDR -path=medical kv-v2

# Database secrets engine pour les DB
vault secrets enable -address=$VAULT_ADDR -path=database database

# PKI pour les certificats
vault secrets enable -address=$VAULT_ADDR -path=pki pki
vault secrets tune -address=$VAULT_ADDR -max-lease-ttl=8760h pki

# Configurer les politiques de sécurité
echo "📋 Creating security policies..."

# Politique pour les microservices
vault policy write -address=$VAULT_ADDR microservices-policy - <<EOF
# Politique pour les microservices médicaux
path "medical/data/microservices/*" {
  capabilities = ["read"]
}

path "medical/data/database/*" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

# Politique pour Jenkins
vault policy write -address=$VAULT_ADDR jenkins-policy - <<EOF
# Politique pour Jenkins CI/CD
path "medical/data/ci-cd/*" {
  capabilities = ["read", "list"]
}

path "medical/data/microservices/*" {
  capabilities = ["read", "list"]
}

path "auth/token/create" {
  capabilities = ["update"]
}
EOF

# Politique pour SonarQube
vault policy write -address=$VAULT_ADDR sonarqube-policy - <<EOF
# Politique pour SonarQube
path "medical/data/sonarqube/*" {
  capabilities = ["read"]
}
EOF

# Créer les secrets pour les microservices
echo "🔐 Creating secrets..."

# Secrets pour la base de données
vault kv put -address=$VAULT_ADDR medical/database/postgres \
    username="postgres" \
    password="SecurePostgresPassword123!" \
    host="postgres" \
    port="5432" \
    database="medical_db"

# Secrets pour Keycloak
vault kv put -address=$VAULT_ADDR medical/keycloak/admin \
    username="admin" \
    password="SecureKeycloakAdminPassword123!" \
    realm="medical-realm"

# Secrets pour SonarQube
vault kv put -address=$VAULT_ADDR medical/sonarqube/admin \
    username="admin" \
    password="SecureSonarQubePassword123!" \
    token="sqp_generated_token_here"

# Secrets pour les microservices
vault kv put -address=$VAULT_ADDR medical/microservices/medecin-service \
    db_username="medecin_user" \
    db_password="SecureMedecinDbPassword123!" \
    jwt_secret="medecin_jwt_secret_key_123456789" \
    api_key="medecin_api_key_secure_123"

vault kv put -address=$VAULT_ADDR medical/microservices/patient-service \
    db_username="patient_user" \
    db_password="SecurePatientDbPassword123!" \
    jwt_secret="patient_jwt_secret_key_123456789" \
    api_key="patient_api_key_secure_123"

vault kv put -address=$VAULT_ADDR medical/microservices/rdv-service \
    db_username="rdv_user" \
    db_password="SecureRdvDbPassword123!" \
    jwt_secret="rdv_jwt_secret_key_123456789" \
    api_key="rdv_api_key_secure_123"

vault kv put -address=$VAULT_ADDR medical/microservices/dossier-service \
    db_username="dossier_user" \
    db_password="SecureDossierDbPassword123!" \
    jwt_secret="dossier_jwt_secret_key_123456789" \
    api_key="dossier_api_key_secure_123"

vault kv put -address=$VAULT_ADDR medical/microservices/gateway \
    jwt_secret="gateway_jwt_master_secret_key_123456789" \
    oauth_client_secret="gateway_oauth_client_secret_123" \
    rate_limit_key="gateway_rate_limit_secret"

# Secrets pour CI/CD
vault kv put -address=$VAULT_ADDR medical/ci-cd/jenkins \
    github_token="ghp_jenkins_token_here" \
    docker_registry_username="jenkins_user" \
    docker_registry_password="SecureDockerPassword123!" \
    notification_webhook="https://hooks.slack.com/jenkins"

# Créer des tokens pour les services
echo "🎫 Creating service tokens..."

# Token pour Jenkins
JENKINS_TOKEN=$(vault write -address=$VAULT_ADDR -field=token auth/token/create \
    policies=jenkins-policy \
    ttl=8760h \
    renewable=true \
    display_name="jenkins-ci-cd")

# Token pour les microservices
MICROSERVICES_TOKEN=$(vault write -address=$VAULT_ADDR -field=token auth/token/create \
    policies=microservices-policy \
    ttl=8760h \
    renewable=true \
    display_name="microservices-runtime")

# Sauvegarder les tokens
cat > service-tokens.json << EOF
{
  "jenkins_token": "$JENKINS_TOKEN",
  "microservices_token": "$MICROSERVICES_TOKEN",
  "vault_addr": "$VAULT_ADDR"
}
EOF

echo ""
echo "🎉 Vault configuration completed!"
echo "================================"
echo ""
echo "📊 Configuration Summary:"
echo "  ✅ Vault initialized and unsealed"
echo "  ✅ Secret engines enabled (KV, Database, PKI)"
echo "  ✅ Security policies created"
echo "  ✅ Microservices secrets stored"
echo "  ✅ Service tokens generated"
echo ""
echo "🔗 Access Points:"
echo "  • Vault UI: http://localhost:8200"
echo "  • Vault API: http://localhost:8200/v1/"
echo ""
echo "📄 Files Generated:"
echo "  • $VAULT_INIT_FILE (Vault keys - KEEP SECURE!)"
echo "  • service-tokens.json (Service tokens)"
echo ""
echo "🔑 Root Token: $ROOT_TOKEN"
echo ""
echo "⚠️  SECURITY REMINDER:"
echo "  1. Store $VAULT_INIT_FILE in a secure location"
echo "  2. Do not commit service-tokens.json to Git"
echo "  3. Rotate tokens regularly"
echo "  4. Use TLS in production"
echo ""
echo "🚀 Next steps:"
echo "  1. Update microservices to use Vault secrets"
echo "  2. Configure Jenkins with Vault integration"
echo "  3. Set up secret rotation policies"