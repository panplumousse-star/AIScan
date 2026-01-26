#!/bin/bash
#
# SonarQube Analysis Script for AIscan
#
# Usage:
#   ./scripts/sonarqube-analyze.sh          # Start SonarQube, analyze, keep running
#   ./scripts/sonarqube-analyze.sh --stop   # Stop SonarQube after analysis
#   ./scripts/sonarqube-analyze.sh --only-start  # Only start SonarQube (no analysis)
#   ./scripts/sonarqube-analyze.sh --only-analyze  # Only run analysis (SonarQube must be running)
#

set -e

# Configuration
CONTAINER_NAME="sonarqube"
SONARQUBE_PORT="9000"
SONARQUBE_URL="http://localhost:${SONARQUBE_PORT}"
PLUGIN_PATH="/tmp/sonarqube-plugins/sonar-flutter-plugin-0.5.2.jar"
PLUGIN_URL="https://github.com/insideapp-oss/sonar-flutter/releases/download/0.5.2/sonar-flutter-plugin-0.5.2.jar"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
STOP_AFTER=false
ONLY_START=false
ONLY_ANALYZE=false

for arg in "$@"; do
    case $arg in
        --stop)
            STOP_AFTER=true
            ;;
        --only-start)
            ONLY_START=true
            ;;
        --only-analyze)
            ONLY_ANALYZE=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --stop          Stop SonarQube after analysis"
            echo "  --only-start    Only start SonarQube (no analysis)"
            echo "  --only-analyze  Only run analysis (SonarQube must be running)"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
    esac
done

# Functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    fi
}

download_plugin() {
    if [ ! -f "$PLUGIN_PATH" ]; then
        print_status "Downloading sonar-flutter plugin..."
        mkdir -p "$(dirname "$PLUGIN_PATH")"
        curl -sL "$PLUGIN_URL" -o "$PLUGIN_PATH"
        print_success "Plugin downloaded"
    fi
}

start_sonarqube() {
    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        # Container exists, check if running
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            print_status "SonarQube is already running"
            return 0
        else
            print_status "Starting existing SonarQube container..."
            docker start "$CONTAINER_NAME"
        fi
    else
        print_status "Creating and starting SonarQube container..."
        download_plugin
        docker run -d --name "$CONTAINER_NAME" \
            -p "${SONARQUBE_PORT}:9000" \
            -v "${PLUGIN_PATH}:/opt/sonarqube/extensions/plugins/sonar-flutter-plugin-0.5.2.jar" \
            sonarqube:latest
    fi
}

wait_for_sonarqube() {
    print_status "Waiting for SonarQube to be ready..."
    local max_attempts=60
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        local status=$(curl -s "${SONARQUBE_URL}/api/system/status" 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$status" = "UP" ]; then
            print_success "SonarQube is ready!"
            return 0
        fi

        echo -ne "\r${BLUE}[INFO]${NC} Status: ${status:-connecting} - attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done

    echo ""
    print_error "SonarQube failed to start within timeout"
    exit 1
}

run_analysis() {
    print_status "Running SonarQube analysis..."

    # Check if sonar-scanner is installed
    if ! command -v sonar-scanner &> /dev/null; then
        print_error "sonar-scanner is not installed"
        print_status "Install it with:"
        echo "  curl -sL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip -o /tmp/sonar-scanner.zip"
        echo "  unzip /tmp/sonar-scanner.zip -d /opt/"
        echo "  sudo ln -sf /opt/sonar-scanner-*/bin/sonar-scanner /usr/local/bin/sonar-scanner"
        exit 1
    fi

    # Check if sonar-project.properties exists
    if [ ! -f "sonar-project.properties" ]; then
        print_error "sonar-project.properties not found in current directory"
        exit 1
    fi

    # Run analysis
    sonar-scanner

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        print_success "Analysis completed successfully!"
        echo ""
        echo -e "${GREEN}Dashboard:${NC} ${SONARQUBE_URL}/dashboard?id=aiscan"
    else
        print_error "Analysis failed with exit code $exit_code"
        exit $exit_code
    fi
}

stop_sonarqube() {
    print_status "Stopping SonarQube..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    print_success "SonarQube stopped"
}

# Main script
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}   SonarQube Analysis for AIscan        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Change to project directory
cd "$(dirname "$0")/.."

check_docker

if [ "$ONLY_ANALYZE" = true ]; then
    # Only run analysis
    run_analysis
else
    # Start SonarQube
    start_sonarqube
    wait_for_sonarqube

    if [ "$ONLY_START" = true ]; then
        echo ""
        print_success "SonarQube is running at ${SONARQUBE_URL}"
        print_status "Run analysis manually with: sonar-scanner"
        exit 0
    fi

    # Run analysis
    run_analysis

    if [ "$STOP_AFTER" = true ]; then
        stop_sonarqube
    else
        echo ""
        print_status "SonarQube is still running at ${SONARQUBE_URL}"
        print_status "To stop it: docker stop sonarqube"
    fi
fi

echo ""
