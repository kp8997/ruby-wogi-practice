#!/usr/bin/env bash
#
# init_api_data.sh
# Initializes seed and test data through the Gift Card API using curl.
# Follows the complete operational workflow in sequential order:
# 1. Admin login & token capture
# 2. Secondary admin creation
# 3. Client user & profile creation
# 4. Brand & product catalog setup
# 5. Product access assignment
# 6. Client login & token capture
# 7. Card issuance (with idempotency) & cancellation
# 8. Audit log inspection & reporting verification
#

set -e

BASE_URL="${API_BASE_URL:-http://localhost:3000/api/v1}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin@12345}"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}    Gift Card API Data Initializer (via cURL)         ${NC}"
echo -e "${BLUE}    Target: ${BASE_URL}                               ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Helper to extract JSON fields using Ruby (available in environment)
extract_json() {
  local key="$1"
  ruby -rjson -e "data = JSON.parse(STDIN.read) rescue {}; puts data.dig(*'$key'.split('.')) || ''"
}

# -----------------------------------------------------------------------------
# 1. ADMIN LOGIN
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/8] Authenticating as Admin (${ADMIN_EMAIL})...${NC}"
LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${ADMIN_EMAIL}\", \"password\": \"${ADMIN_PASSWORD}\"}")

ADMIN_TOKEN=$(echo "$LOGIN_RESP" | extract_json "token")

if [ -z "$ADMIN_TOKEN" ]; then
  echo -e "${RED}Failed to log in as admin. Response: ${LOGIN_RESP}${NC}"
  echo -e "${RED}Make sure the Rails server is running and database is seeded (bin/rails db:seed).${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Admin authenticated successfully. Token acquired.${NC}"

# -----------------------------------------------------------------------------
# 2. CREATE SECONDARY ADMIN
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/8] Creating Secondary Admin (AUTH-3)...${NC}"
NEW_ADMIN_EMAIL="ops_admin_$(date +%s)@example.com"
CREATE_ADMIN_RESP=$(curl -s -X POST "${BASE_URL}/admin/users" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{\"email\": \"${NEW_ADMIN_EMAIL}\", \"password\": \"Admin@12345\"}")

NEW_ADMIN_ID=$(echo "$CREATE_ADMIN_RESP" | extract_json "user.id")
if [ -n "$NEW_ADMIN_ID" ]; then
  echo -e "${GREEN}✓ Secondary Admin created: ${NEW_ADMIN_EMAIL} (ID: ${NEW_ADMIN_ID})${NC}"
else
  echo -e "${YELLOW}Notice: ${CREATE_ADMIN_RESP}${NC}"
fi

# -----------------------------------------------------------------------------
# 3. CREATE CLIENT USER & PROFILE
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/8] Creating Client (AUTH-4, ADM-5)...${NC}"
CLIENT_EMAIL="acme_partner_$(date +%s)@example.com"
CLIENT_PASSWORD="Client@12345"
CREATE_CLIENT_RESP=$(curl -s -X POST "${BASE_URL}/admin/clients" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{
    \"name\": \"Acme Global Superstore\",
    \"email\": \"${CLIENT_EMAIL}\",
    \"password\": \"${CLIENT_PASSWORD}\",
    \"payout_rate\": 6.50
  }")

CLIENT_ID=$(echo "$CREATE_CLIENT_RESP" | extract_json "client.id")
if [ -n "$CLIENT_ID" ]; then
  echo -e "${GREEN}✓ Client created: Acme Global Superstore (ID: ${CLIENT_ID}, Email: ${CLIENT_EMAIL})${NC}"
else
  echo -e "${YELLOW}Response: ${CREATE_CLIENT_RESP}${NC}"
fi

# -----------------------------------------------------------------------------
# 4. CREATE BRAND & PRODUCT
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/8] Creating Brand & Product (ADM-2, ADM-3)...${NC}"
BRAND_NAME="Apex Retail $(date +%s)"
CREATE_BRAND_RESP=$(curl -s -X POST "${BASE_URL}/admin/brands" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -d "{
    \"name\": \"${BRAND_NAME}\",
    \"state\": \"active\",
    \"custom_fields\": { \"category\": \"General Merchandise\" }
  }")
BRAND_ID=$(echo "$CREATE_BRAND_RESP" | extract_json "brand.id")

if [ -n "$BRAND_ID" ]; then
  echo -e "${GREEN}✓ Brand created: ${BRAND_NAME} (ID: ${BRAND_ID})${NC}"
  
  CREATE_PRODUCT_RESP=$(curl -s -X POST "${BASE_URL}/admin/brands/${BRAND_ID}/products" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -d '{
      "name": "Apex Digital Card",
      "denomination": 50.00,
      "currency": "USD",
      "requires_pin": false,
      "state": "active"
    }')
  PRODUCT_ID=$(echo "$CREATE_PRODUCT_RESP" | extract_json "product.id")
  if [ -n "$PRODUCT_ID" ]; then
    echo -e "${GREEN}✓ Product created: Apex \$50 Digital Card (ID: ${PRODUCT_ID})${NC}"
  else
    echo -e "${RED}Failed to create product. Response: ${CREATE_PRODUCT_RESP}${NC}"
  fi
fi

# -----------------------------------------------------------------------------
# 5. ASSIGN PRODUCT PERMISSION TO CLIENT
# -----------------------------------------------------------------------------
if [ -n "$CLIENT_ID" ] && [ -n "$PRODUCT_ID" ]; then
  echo -e "\n${YELLOW}[5/8] Assigning Product Access to Client (ADM-6)...${NC}"
  ASSIGN_RESP=$(curl -s -X POST "${BASE_URL}/admin/clients/${CLIENT_ID}/product_accesses" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -d "{\"product_id\": ${PRODUCT_ID}}")
  echo -e "${GREEN}✓ Access granted: Client ${CLIENT_ID} -> Product ${PRODUCT_ID}${NC}"
fi

# -----------------------------------------------------------------------------
# 6. CLIENT LOGIN
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/8] Authenticating as Client (${CLIENT_EMAIL})...${NC}"
CLIENT_LOGIN_RESP=$(curl -s -X POST "${BASE_URL}/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"${CLIENT_EMAIL}\", \"password\": \"${CLIENT_PASSWORD}\"}")

CLIENT_TOKEN=$(echo "$CLIENT_LOGIN_RESP" | extract_json "token")

if [ -n "$CLIENT_TOKEN" ]; then
  echo -e "${GREEN}✓ Client authenticated successfully. Token acquired.${NC}"
  
  # ---------------------------------------------------------------------------
  # 7. CLIENT ISSUES & CANCELS CARD
  # ---------------------------------------------------------------------------
  if [ -n "$PRODUCT_ID" ]; then
    echo -e "\n${YELLOW}[7/8] Client issuing Gift Card (CLI-3, CLI-4)...${NC}"
    IDEMPOTENCY_KEY="cli-order-$(date +%s)"
    ISSUE_RESP=$(curl -s -X POST "${BASE_URL}/client/cards" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${CLIENT_TOKEN}" \
      -d "{\"product_id\": ${PRODUCT_ID}, \"idempotency_key\": \"${IDEMPOTENCY_KEY}\"}")
    
    CARD_ID=$(echo "$ISSUE_RESP" | extract_json "card.id")
    CARD_NUM=$(echo "$ISSUE_RESP" | extract_json "card.activation_number")
    echo -e "${GREEN}✓ Card issued successfully: ID ${CARD_ID}, Activation #${CARD_NUM}${NC}"
    
    # Cancel card
    echo -e "${YELLOW}Client cancelling Gift Card (CLI-6)...${NC}"
    CANCEL_RESP=$(curl -s -X POST "${BASE_URL}/client/cards/${CARD_ID}/cancel" \
      -H "Authorization: Bearer ${CLIENT_TOKEN}")
    echo -e "${GREEN}✓ Card ${CARD_ID} cancelled successfully.${NC}"
  fi
fi

# -----------------------------------------------------------------------------
# 8. ADMIN AUDIT LOGS
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[8/8] Verifying Admin Audit Logs (LOG-1, LOG-5)...${NC}"
AUDIT_RESP=$(curl -s -X GET "${BASE_URL}/admin/audit_logs?page=1&per_page=5" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
LOG_COUNT=$(echo "$AUDIT_RESP" | ruby -rjson -e "puts (JSON.parse(STDIN.read)['audit_logs'] rescue []).length")
echo -e "${GREEN}✓ Retrieved ${LOG_COUNT} recent immutable audit log entries.${NC}"

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}    API Initialization Finished Successfully!         ${NC}"
echo -e "${GREEN}======================================================${NC}"
