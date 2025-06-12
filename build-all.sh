#!/bin/bash

# Script de build complet pour tous les microservices
# Usage: ./build-all.sh

set -e

echo "🚀 Starting complete build process..."
echo "===================================="

# Services à builder
SERVICES=("medecin-service" "patient-service" "rdv-service" "dossier-service" "gateway")

# Fonction de build Maven
build_maven() {
    local service=$1
    echo ""
    echo "📦 Building $service with Maven..."
    echo "=================================="

    if [ -d "$service" ] && [ -f "$service/pom.xml" ]; then
        cd "$service"

        echo "🔧 Running Maven build..."
        mvn clean package -DskipTests

        if [ $? -eq 0 ]; then
            echo "✅ Maven build successful for $service"

            # Vérifier que le JAR a été créé
            if ls target/*.jar 1> /dev/null 2>&1; then
                echo "✅ JAR file created: $(ls target/*.jar)"
            else
                echo "❌ JAR file not found for $service"
                exit 1
            fi
        else
            echo "❌ Maven build failed for $service"
            exit 1
        fi

        cd ..
    else
        echo "⚠️ Skipping $service (directory or pom.xml not found)"
    fi
}

# Fonction de build Docker
build_docker() {
    local service=$1
    echo ""
    echo "🐳 Building Docker image for $service..."
    echo "======================================="

    if [ -d "$service" ] && [ -f "$service/Dockerfile" ]; then
        echo "🔧 Running Docker build..."
        docker build -t $service:latest ./$service

        if [ $? -eq 0 ]; then
            echo "✅ Docker build successful for $service"
        else
            echo "❌ Docker build failed for $service"
            exit 1
        fi
    else
        echo "⚠️ Skipping Docker build for $service (Dockerfile not found)"
    fi
}

# Phase 1: Build Maven projects
echo "🔨 PHASE 1: Building JAR files with Maven"
echo "=========================================="

for service in "${SERVICES[@]}"; do
    build_maven $service
done

echo ""
echo "🎉 All Maven builds completed successfully!"

# Phase 2: Build Docker images
echo ""
echo "🐳 PHASE 2: Building Docker images"
echo "=================================="

for service in "${SERVICES[@]}"; do
    build_docker $service
done

echo ""
echo "🎉 All Docker builds completed successfully!"

# Phase 3: Verification
echo ""
echo "🔍 PHASE 3: Verification"
echo "========================"

echo "📦 Built JAR files:"
for service in "${SERVICES[@]}"; do
    if [ -d "$service/target" ]; then
        jar_file=$(find $service/target -name "*.jar" -not -name "*-sources.jar" 2>/dev/null | head -1)
        if [ -n "$jar_file" ]; then
            size=$(du -h "$jar_file" | cut -f1)
            echo "  ✅ $service: $jar_file ($size)"
        fi
    fi
done

echo ""
echo "🐳 Built Docker images:"
for service in "${SERVICES[@]}"; do
    if docker images | grep -q "^$service "; then
        size=$(docker images --format "table {{.Size}}" $service:latest | tail -1)
        echo "  ✅ $service:latest ($size)"
    fi
done

# Phase 4: Optional - Start services
echo ""
echo "🚀 PHASE 4: Ready to start services"
echo "==================================="

echo "To start all services:"
echo "  docker-compose up -d"
echo ""
echo "To start individual service:"
echo "  docker run -p 8080:8080 medecin-service:latest"
echo ""
echo "To see running containers:"
echo "  docker ps"

echo ""
echo "🎊 Build process completed successfully!"
echo "📊 Summary:"
echo "  Services built: ${#SERVICES[@]}"
echo "  JAR files: $(find */target -name "*.jar" -not -name "*-sources.jar" 2>/dev/null | wc -l)"
echo "  Docker images: $(docker images | grep -E "$(IFS='|'; echo "${SERVICES[*]}")" | wc -l)"