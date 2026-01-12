#!/bin/bash

set -e

echo "=========================================="
echo "H5P REST API Setup Script"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

info() {
    echo -e "${YELLOW}→ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        error "$1 is not installed. Please install it first."
    fi
}

echo "Checking prerequisites..."
check_command "node"
check_command "npm"
check_command "docker"
check_command "docker-compose"

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    error "Node.js version 20 or higher is required. Current version: $(node -v)"
fi

success "All prerequisites met"
echo ""

echo "Step 1: Starting Docker services..."
info "Starting MongoDB, MinIO, and Redis..."
docker-compose up -d || error "Failed to start Docker services"

info "Waiting for services to be ready..."
sleep 10

info "Checking MinIO bucket creation..."
docker-compose logs minio_init | grep -q "Bucket created successfully" || {
    info "Buckets might not be created yet, restarting minio_init..."
    docker-compose restart minio_init
    sleep 5
}

success "Docker services started"
echo ""

echo "Step 2: Installing dependencies..."
info "Installing npm dependencies (this may take a few minutes)..."
npm install || error "Failed to install dependencies"
success "Dependencies installed"
echo ""

echo "Step 3: Building packages..."
info "Building H5P packages (this may take a few minutes)..."
npm run build || error "Failed to build packages"
success "Packages built"
echo ""

echo "Step 4: Configuring environment..."
REST_SERVER_DIR="packages/h5p-rest-example-server"
if [ ! -f "$REST_SERVER_DIR/.env" ]; then
    info "Creating .env file from example..."
    cp "$REST_SERVER_DIR/env.example" "$REST_SERVER_DIR/.env" || error "Failed to create .env file"
    success ".env file created"
else
    info ".env file already exists, skipping..."
fi
echo ""

echo "Step 5: Downloading H5P core files..."
info "Downloading H5P core and editor files..."
cd "$REST_SERVER_DIR"
npm run prepare || error "Failed to download H5P core files"
cd - > /dev/null
success "H5P core files downloaded"
echo ""

echo "Step 6: Verifying setup..."
info "Checking Docker services..."
if docker-compose ps | grep -q "Up"; then
    success "Docker services are running"
else
    error "Some Docker services are not running"
fi

info "Checking MinIO buckets..."
if docker-compose logs minio_init 2>/dev/null | grep -q "Bucket created successfully"; then
    success "MinIO buckets created (check logs for details)"
    info "Verify buckets at http://localhost:9001 (minioaccesskey / miniosecret)"
else
    info "Buckets may not be created yet. They will be created automatically."
    info "You can verify at http://localhost:9001"
fi

info "Verifying S3 endpoint configuration..."
if [ -f "$REST_SERVER_DIR/.env" ]; then
    if grep -q "AWS_S3_ENDPOINT=http://localhost:9000" "$REST_SERVER_DIR/.env"; then
        success "S3 endpoint configured correctly"
    else
        S3_ENDPOINT=$(grep AWS_S3_ENDPOINT "$REST_SERVER_DIR/.env" 2>/dev/null || echo "not found")
        info "S3 endpoint in .env: $S3_ENDPOINT"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Setup completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Start the REST API server:"
echo "   ${YELLOW}npm run start:rest:server${NC}"
echo ""
echo "2. In another terminal, start the client (optional):"
echo "   ${YELLOW}cd packages/h5p-rest-example-client${NC}"
echo "   ${YELLOW}npm start${NC}"
echo ""
echo "3. Access the services:"
echo "   - REST API: http://localhost:8080"
echo "   - MinIO Console: http://localhost:9001 (minioaccesskey / miniosecret)"
echo "   - Mongo Express: http://localhost:8081"
echo ""
echo "4. Update content type cache:"
echo "   - Login to the client"
echo "   - Click 'Update now' in the 'H5P Hub content type list' section"
echo ""
echo "5. Install a content type:"
echo "   - Use the Library Administration page to upload an H5P package, or"
echo "   - Install via API: POST /h5p/ajax?action=library-install&id=H5P.DragText"
echo ""
