# Mattermost IP Whitelist System

## Overview

The IP whitelist system in Mattermost provides granular access control by restricting which IP addresses can access the platform. This system is particularly useful for organizations that need to limit access to specific network ranges or locations.

## How It Works

### 1. **Whitelist Check Flow**

When a user makes a request to Mattermost:

1. **Authentication Check**: User must be authenticated (have a valid session)
2. **Path Exclusion Check**: If the request path is in the excluded list, skip whitelist check
3. **Admin Bypass Check**: If user is a system admin, bypass whitelist check
4. **IP Whitelist Check**: Check if user's IP is in their whitelist
5. **Access Decision**: Grant or deny access based on whitelist status

### 2. **Key Components**

#### **Backend Implementation**
- **Model**: `model/whitelist_item.go` - Defines the WhitelistItem structure
- **Store**: `store/sqlstore/whitelist_store.go` - Database operations
- **App Layer**: `app/whitelist.go` - Business logic
- **API Layer**: `api4/user.go` - REST API endpoints
- **Middleware**: `web/handlers.go` - Request interception

#### **Database Schema**
```sql
CREATE TABLE Whitelist (
    UserId VARCHAR(26) NOT NULL,
    IP VARCHAR(39) NOT NULL,
    PRIMARY KEY (UserId, IP)
);
```

### 3. **Access Control Rules**

#### **System Admins**
- **Bypass**: System admins bypass IP whitelist completely
- **Reasoning**: Admins need to manage the system from any location
- **Implementation**: Check for `PermissionManageSystem` role

#### **Regular Users**
- **Requirement**: Must have their IP address in the whitelist
- **Blocking**: HTTP 403 Forbidden if IP not whitelisted
- **Error Message**: Clear indication that IP is not whitelisted

#### **Excluded Paths**
The following paths are excluded from whitelist checks:
- `/api/v4/users/login` - Login endpoint
- `/api/v4/users/logout` - Logout endpoint
- `/api/v4/system/ping` - Health check
- `/api/v4/config/client` - Client configuration
- `/login` - Web login page
- `/signup` - Web signup page
- `/static/*` - Static assets
- `/fonts/*` - Font files
- `/images/*` - Image files

### 4. **IP Detection**

The system detects client IP addresses in this order:

1. **X-Forwarded-For Header**: For requests behind load balancers/proxies
2. **X-Real-IP Header**: Common with nginx configurations
3. **RemoteAddr**: Direct connection IP address

### 5. **API Endpoints**

#### **Get User's Whitelist**
```
GET /api/v4/users/{user_id}/whitelist
Authorization: Bearer {token}
```
**Response**: Array of whitelisted IP addresses

#### **Add IP to Whitelist**
```
POST /api/v4/users/{user_id}/whitelist
Authorization: Bearer {token}
Content-Type: application/json

{
    "ip": "192.168.1.100"
}
```

#### **Remove IP from Whitelist**
```
DELETE /api/v4/users/{user_id}/whitelist
Authorization: Bearer {token}
Content-Type: application/json

{
    "ip": "192.168.1.100"
}
```

### 6. **Error Responses**

#### **IP Not Whitelisted**
```json
{
    "id": "api.context.whitelist.access_denied.app_error",
    "message": "Access denied: IP not whitelisted",
    "detailed_error": "ip=192.168.1.100",
    "status_code": 403
}
```

#### **Invalid IP Address**
```json
{
    "id": "app.whitelist.invalid_ip.app_error",
    "message": "Invalid IP address format",
    "detailed_error": "ip=invalid.ip.address",
    "status_code": 400
}
```

### 7. **Testing the System**

#### **Basic Test**
```bash
# Test server ping (should always work)
curl http://localhost:8065/api/v4/system/ping

# Test login (should work without whitelist)
curl -X POST http://localhost:8065/api/v4/users/login \
  -H "Content-Type: application/json" \
  -d '{"login_id":"user@example.com","password":"password"}'
```

#### **Whitelist Management**
```bash
# Add IP to whitelist (requires admin auth)
curl -X POST http://localhost:8065/api/v4/users/USER_ID/whitelist \
  -H "Authorization: Bearer ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ip":"192.168.1.100"}'

# Get user's whitelist
curl http://localhost:8065/api/v4/users/USER_ID/whitelist \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

### 8. **Configuration**

The whitelist system is **always active** for authenticated users on protected endpoints. There is no configuration option to disable it globally, as it's designed to provide consistent security.

### 9. **Security Considerations**

#### **Admin Bypass**
- System admins can access from any IP
- This is intentional for system management
- Consider network-level restrictions for admin accounts

#### **IP Spoofing**
- The system relies on HTTP headers for IP detection
- Ensure proper proxy/load balancer configuration
- Consider additional network-level security measures

#### **Database Security**
- Whitelist data is stored in the database
- Ensure proper database access controls
- Consider encryption for sensitive environments

### 10. **Migration from Legacy System**

The new whitelist system is compatible with the legacy system:
- Same database schema (`Whitelist` table)
- Same API endpoints
- Enhanced error handling and logging
- Improved IP detection

### 11. **Monitoring and Logging**

The system provides detailed logging:
- **Debug**: IP whitelist checks and bypasses
- **Warn**: Access denied due to IP not whitelisted
- **Error**: IP detection failures

Example log entries:
```
DEBUG: System admin bypassing IP whitelist user_id=abc123 ip=192.168.1.100
WARN: Access denied: IP not whitelisted user_id=def456 ip=192.168.1.200 path=/api/v4/users/me
ERROR: Could not determine client IP address for whitelist check
```

### 12. **Troubleshooting**

#### **Common Issues**

1. **Users can't access from expected IPs**
   - Check if IP is in whitelist: `GET /api/v4/users/{user_id}/whitelist`
   - Verify IP detection: Check X-Forwarded-For headers
   - Confirm user is not a system admin

2. **Admin users blocked**
   - Verify user has system admin role
   - Check role permissions in database

3. **Login issues**
   - Login endpoint is excluded from whitelist checks
   - Check authentication credentials
   - Verify server configuration

#### **Debug Commands**
```bash
# Check server logs for whitelist messages
grep -i whitelist /var/log/mattermost/mattermost.log

# Test IP detection
curl -H "X-Forwarded-For: 192.168.1.100" http://localhost:8065/api/v4/system/ping

# Verify database schema
mysql -u mmuser -p mattermost_dev -e "DESCRIBE Whitelist;"
```

## Conclusion

The IP whitelist system provides robust access control for Mattermost deployments. It balances security with usability by allowing system admins to manage the system while restricting regular user access to approved IP addresses. The system is designed to be transparent to users while providing clear error messages when access is denied. 