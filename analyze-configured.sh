#!/bin/bash

# Script d'analyse SonarQube pour tous les microservices
# Usage: ./analyze-all-microservices.sh YOUR_SONARQUBE_TOKEN

if [ -z "$1" ]; then
    echo "❌ Usage: $0 <SONARQUBE_TOKEN>"
    echo ""
    echo "📋 Pour obtenir votre token :"
    echo "1. Aller sur http://localhost:9000"
    echo "2. Se connecter (admin/admin)"
    echo "3. Avatar → My Account → Security → Generate Token"
    echo ""
    exit 1
fi

TOKEN=$1
SONAR_HOST="http://localhost:9000"

echo "🚀 Starting SonarQube analysis for ALL microservices..."
echo "📊 SonarQube URL: $SONAR_HOST"
echo "🔑 Using token: ${TOKEN:0:20}..."
echo ""

# Tous les microservices du projet médical
ALL_SERVICES=(
    "dossier-service"
    "gateway"
    "medecin-service"
    "patient-service"
    "rdv-service"
)

# Compteurs pour statistiques
TOTAL_SERVICES=0
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

for service in "${ALL_SERVICES[@]}"; do
    TOTAL_SERVICES=$((TOTAL_SERVICES + 1))

    if [ -d "$service" ] && [ -f "$service/pom.xml" ]; then
        echo "=============================================="
        echo "🔍 Analyzing $service... (${TOTAL_SERVICES}/${#ALL_SERVICES[@]})"
        echo "=============================================="

        cd "$service"

        # Vérifier si le service a la configuration SonarQube
        if grep -q "sonar.projectKey" pom.xml; then
            echo "✅ SonarQube configuration found in pom.xml"
        else
            echo "⚠️ Adding SonarQube configuration on-the-fly..."
        fi

        echo "📦 Running Maven analysis..."
        mvn clean test sonar:sonar \
            -Dsonar.login="$TOKEN" \
            -Dsonar.projectKey="medical-$service" \
            -Dsonar.projectName="$service" \
            -Dsonar.sources=src/main/java \
            -Dsonar.tests=src/test/java \
            -Dsonar.java.coveragePlugin=jacoco \
            -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
            -Dsonar.junit.reportPaths=target/surefire-reports

        if [ $? -eq 0 ]; then
            echo "✅ $service analysis completed successfully"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "❌ $service analysis failed"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi

        cd ..
        echo ""
    else
        echo "⚠️ Skipping $service (not found or no pom.xml)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
done

echo "=============================================="
echo "🎉 Analysis completed for all microservices!"
echo "=============================================="
echo ""
echo "📊 ANALYSIS SUMMARY:"
echo "  📋 Total services: $TOTAL_SERVICES"
echo "  ✅ Successful: $SUCCESS_COUNT"
echo "  ❌ Failed: $FAILED_COUNT"
echo "  ⚠️ Skipped: $SKIPPED_COUNT"
echo ""
echo "📊 View all results at: $SONAR_HOST/projects"
echo ""
echo "📋 Expected projects in SonarQube:"
for service in "${ALL_SERVICES[@]}"; do
    if [ -d "$service" ]; then
        echo "  🎯 medical-$service"
    fi
done
echo ""
echo "🔗 Direct project links:"
echo "  • All Projects: $SONAR_HOST/projects"
echo "  • Issues Dashboard: $SONAR_HOST/issues"
echo "  • Quality Gates: $SONAR_HOST/quality_gates"
echo ""
echo "📈 What to check in each project:"
echo "  1. 🐛 Bugs and Vulnerabilities (should be 0)"
echo "  2. 📊 Code Coverage percentage"
echo "  3. 💡 Code Smells (technical debt)"
echo "  4. 🔄 Code Duplications"
echo "  5. 🎯 Quality Gate status"
echo ""
echo "🚀 Next steps:"
echo "  1. Review each project's dashboard"
echo "  2. Fix critical issues and vulnerabilities"
echo "  3. Improve test coverage"
echo "  4. Set up quality gates for CI/CD"
echo ""
echo "🎊 DevSecOps analysis complete! Happy coding!"