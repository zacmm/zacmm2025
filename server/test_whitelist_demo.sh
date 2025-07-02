#!/bin/bash

# Mattermost IP Whitelist Demo Script
# This script demonstrates how the IP whitelist blocking works

SERVER_URL="http://localhost:8065"
CURRENT_IP=$(curl -s ifconfig.me)

echo "=== Mattermost IP Whitelist Demo ==="
echo "Server URL: $SERVER_URL"
echo "Current IP: $CURRENT_IP"
echo ""

# Test 1: Server ping (should always work - excluded from whitelist)
echo "1. Testing server ping (excluded from whitelist)..."
PING_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" "$SERVER_URL/api/v4/system/ping")
HTTP_STATUS=$(echo "$PING_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PING_RESPONSE" | grep -v "HTTP_STATUS:")

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ SUCCESS: Server ping works (status: $HTTP_STATUS)"
    echo "   Response: $RESPONSE_BODY"
else
    echo "❌ FAILED: Server ping failed (status: $HTTP_STATUS)"
    echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Test 2: Login attempt (should work - excluded from whitelist)
echo "2. Testing login endpoint (excluded from whitelist)..."
LOGIN_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -X POST "$SERVER_URL/api/v4/users/login" \
    -H "Content-Type: application/json" \
    -d '{"login_id":"test@example.com","password":"password123"}')
HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | grep -v "HTTP_STATUS:")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "✅ SUCCESS: Login endpoint accessible (status: $HTTP_STATUS)"
    echo "   Response: Invalid credentials (expected for test user)"
else
    echo "❌ UNEXPECTED: Login endpoint returned status $HTTP_STATUS"
    echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Test 3: Protected endpoint without authentication (should fail with auth error, not whitelist)
echo "3. Testing protected endpoint without authentication..."
PROTECTED_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    "$SERVER_URL/api/v4/users/me")
HTTP_STATUS=$(echo "$PROTECTED_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$PROTECTED_RESPONSE" | grep -v "HTTP_STATUS:")

if [ "$HTTP_STATUS" = "401" ]; then
    echo "✅ SUCCESS: Protected endpoint returns auth error (status: $HTTP_STATUS)"
    echo "   Response: Authentication required (expected)"
else
    echo "❌ UNEXPECTED: Protected endpoint returned status $HTTP_STATUS"
    echo "   Response: $RESPONSE_BODY"
fi
echo ""

# Test 4: Whitelist API endpoints (should work for system admins)
echo "4. Testing whitelist API endpoints..."
echo "   Note: These require system admin authentication"
echo "   GET /api/v4/users/{user_id}/whitelist - Get user's whitelisted IPs"
echo "   POST /api/v4/users/{user_id}/whitelist - Add IP to user's whitelist"
echo "   DELETE /api/v4/users/{user_id}/whitelist - Remove IP from user's whitelist"
echo ""

# Test 5: Demonstrate what happens when whitelist is active
echo "5. Whitelist Blocking Behavior:"
echo "   - System Admins: Bypass IP whitelist completely"
echo "   - Regular Users: Must have IP in whitelist to access protected endpoints"
echo "   - Excluded Paths: Login, logout, ping, static files, etc."
echo "   - Blocked Access: Returns HTTP 403 Forbidden"
echo ""

# Test 6: Show current whitelist configuration
echo "6. Current Whitelist Configuration:"
echo "   - Whitelist check is ACTIVE for authenticated users"
echo "   - Excluded paths: /api/v4/users/login, /api/v4/users/logout, /api/v4/system/ping, etc."
echo "   - IP detection: X-Forwarded-For, X-Real-IP, then RemoteAddr"
echo ""

echo "=== Demo Complete ==="
echo ""
echo "To test actual whitelist blocking:"
echo "1. Create a user account"
echo "2. Try to access protected endpoints without adding IP to whitelist"
echo "3. Add IP to whitelist using API: POST /api/v4/users/{user_id}/whitelist"
echo "4. Verify access is now allowed"
echo ""
echo "Example whitelist API usage:"
echo "  # Add IP to whitelist (requires admin auth)"
echo "  curl -X POST '$SERVER_URL/api/v4/users/USER_ID/whitelist' \\"
echo "    -H 'Authorization: Bearer YOUR_TOKEN' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"ip\":\"$CURRENT_IP\"}'"
echo ""
echo "  # Get user's whitelisted IPs"
echo "  curl '$SERVER_URL/api/v4/users/USER_ID/whitelist' \\"
echo "    -H 'Authorization: Bearer YOUR_TOKEN'" 