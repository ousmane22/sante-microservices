pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'localhost:5000'
        TRIVY_SEVERITY = 'HIGH,CRITICAL'
        TRIVY_EXIT_CODE = '1'
    }

    stages {
        stage('🏗️ Build Docker Images') {
            parallel {
                stage('Build Medecin Service') {
                    steps {
                        script {
                            def image = docker.build("${DOCKER_REGISTRY}/medecin-service:${BUILD_NUMBER}", "./medecin-service")
                            env.MEDECIN_IMAGE = "${DOCKER_REGISTRY}/medecin-service:${BUILD_NUMBER}"
                        }
                    }
                }
                stage('Build Patient Service') {
                    steps {
                        script {
                            def image = docker.build("${DOCKER_REGISTRY}/patient-service:${BUILD_NUMBER}", "./patient-service")
                            env.PATIENT_IMAGE = "${DOCKER_REGISTRY}/patient-service:${BUILD_NUMBER}"
                        }
                    }
                }
                stage('Build RDV Service') {
                    steps {
                        script {
                            def image = docker.build("${DOCKER_REGISTRY}/rdv-service:${BUILD_NUMBER}", "./rdv-service")
                            env.RDV_IMAGE = "${DOCKER_REGISTRY}/rdv-service:${BUILD_NUMBER}"
                        }
                    }
                }
                stage('Build Dossier Service') {
                    steps {
                        script {
                            def image = docker.build("${DOCKER_REGISTRY}/dossier-service:${BUILD_NUMBER}", "./dossier-service")
                            env.DOSSIER_IMAGE = "${DOCKER_REGISTRY}/dossier-service:${BUILD_NUMBER}"
                        }
                    }
                }
                stage('Build Gateway') {
                    steps {
                        script {
                            def image = docker.build("${DOCKER_REGISTRY}/gateway:${BUILD_NUMBER}", "./gateway")
                            env.GATEWAY_IMAGE = "${DOCKER_REGISTRY}/gateway:${BUILD_NUMBER}"
                        }
                    }
                }
            }
        }

        stage('🔒 Security Scans') {
            parallel {
                stage('Trivy - Vulnerability Scan') {
                    steps {
                        script {
                            def images = [
                                env.MEDECIN_IMAGE,
                                env.PATIENT_IMAGE,
                                env.RDV_IMAGE,
                                env.DOSSIER_IMAGE,
                                env.GATEWAY_IMAGE
                            ]

                            images.each { imageName ->
                                if (imageName) {
                                    echo "🔍 Scanning ${imageName} with Trivy..."

                                    // Scan de vulnérabilités
                                    sh """
                                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                                        aquasec/trivy:latest image \\
                                        --format json \\
                                        --output ${imageName.split(':')[0].split('/')[1]}-trivy-report.json \\
                                        --severity ${TRIVY_SEVERITY} \\
                                        ${imageName}
                                    """

                                    // Scan avec seuil d'échec
                                    sh """
                                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                                        aquasec/trivy:latest image \\
                                        --severity ${TRIVY_SEVERITY} \\
                                        --exit-code ${TRIVY_EXIT_CODE} \\
                                        ${imageName}
                                    """
                                }
                            }
                        }
                    }
                    post {
                        always {
                            // Archiver les rapports Trivy
                            archiveArtifacts artifacts: '*-trivy-report.json', allowEmptyArchive: true

                            // Publier les rapports HTML
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: '.',
                                reportFiles: '*-trivy-report.json',
                                reportName: 'Trivy Security Reports'
                            ])
                        }
                    }
                }

                stage('Docker Scout - Advanced Scan') {
                    steps {
                        script {
                            def images = [
                                env.MEDECIN_IMAGE,
                                env.PATIENT_IMAGE,
                                env.RDV_IMAGE,
                                env.DOSSIER_IMAGE,
                                env.GATEWAY_IMAGE
                            ]

                            images.each { imageName ->
                                if (imageName) {
                                    echo "🔍 Scanning ${imageName} with Docker Scout..."
                                    sh """
                                        docker scout cves ${imageName} \\
                                        --format json \\
                                        --output ${imageName.split(':')[0].split('/')[1]}-scout-report.json || true
                                    """
                                }
                            }
                        }
                    }
                }

                stage('Grype - Additional Scan') {
                    steps {
                        script {
                            def images = [
                                env.MEDECIN_IMAGE,
                                env.PATIENT_IMAGE,
                                env.RDV_IMAGE,
                                env.DOSSIER_IMAGE,
                                env.GATEWAY_IMAGE
                            ]

                            images.each { imageName ->
                                if (imageName) {
                                    echo "🔍 Scanning ${imageName} with Grype..."
                                    sh """
                                        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \\
                                        anchore/grype:latest ${imageName} \\
                                        -o json > ${imageName.split(':')[0].split('/')[1]}-grype-report.json || true
                                    """
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('📊 Security Report Analysis') {
            steps {
                script {
                    echo '📋 Analyzing security scan results...'

                    // Compter les vulnérabilités par service
                    sh '''
                        echo "🔍 SECURITY SCAN SUMMARY:"
                        echo "========================"

                        for report in *-trivy-report.json; do
                            if [ -f "$report" ]; then
                                service=$(echo $report | sed 's/-trivy-report.json//')
                                critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' $report 2>/dev/null || echo "0")
                                high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' $report 2>/dev/null || echo "0")

                                echo "📦 $service:"
                                echo "  🔴 Critical: $critical"
                                echo "  🟠 High: $high"
                                echo ""
                            fi
                        done

                        echo "📊 Overall Security Status:"
                        total_critical=$(jq -s 'map(.[].Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")) | length' *-trivy-report.json 2>/dev/null || echo "0")
                        total_high=$(jq -s 'map(.[].Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")) | length' *-trivy-report.json 2>/dev/null || echo "0")

                        echo "🔴 Total Critical: $total_critical"
                        echo "🟠 Total High: $total_high"

                        if [ "$total_critical" -gt 0 ]; then
                            echo "❌ SECURITY GATE: FAILED - Critical vulnerabilities found"
                            exit 1
                        elif [ "$total_high" -gt 5 ]; then
                            echo "⚠️ SECURITY GATE: WARNING - Too many high severity vulnerabilities"
                        else
                            echo "✅ SECURITY GATE: PASSED - No critical issues"
                        fi
                    '''
                }
            }
        }

        stage('🚀 Deploy Secure Images') {
            when {
                expression { currentBuild.result == null || currentBuild.result == 'SUCCESS' }
            }
            steps {
                echo '🚀 Deploying security-approved images...'
                sh '''
                    echo "Images passed security scanning:"
                    echo "✅ ${MEDECIN_IMAGE}"
                    echo "✅ ${PATIENT_IMAGE}"
                    echo "✅ ${RDV_IMAGE}"
                    echo "✅ ${DOSSIER_IMAGE}"
                    echo "✅ ${GATEWAY_IMAGE}"

                    # Déploiement avec docker-compose
                    docker-compose down
                    docker-compose up -d
                '''
            }
        }
    }

    post {
        always {
            // Nettoyer les images temporaires
            sh 'docker system prune -f'

            // Archiver tous les rapports de sécurité
            archiveArtifacts artifacts: '*-*-report.json', allowEmptyArchive: true
        }

        success {
            echo """
            🎉 ===== SECURITY PIPELINE SUCCESS =====
            ✅ All images built successfully
            ✅ Security scans completed
            ✅ No critical vulnerabilities found
            ✅ Images deployed securely

            📊 Security Reports Available:
            • Trivy vulnerability reports
            • Docker Scout analysis
            • Grype additional scanning

            🔗 Access security dashboards for detailed analysis
            ====================================
            """
        }

        failure {
            echo """
            ❌ ===== SECURITY PIPELINE FAILED =====
            🔍 Security vulnerabilities detected
            📋 Review security reports for details
            🛠️ Fix vulnerabilities before deployment

            📊 Check archived security reports
            ===================================
            """
        }
    }
}